#!/usr/bin/env bash
#
# Weekly article pipeline — fires Saturdays 14:00 via launchd.
#
#   1. Fable proposes 4 topics (web-researched, checked against what is already published)
#   2. Telegram asks Enver: tap a proposal, or type a topic of his own
#   3. Fable orchestrates subagents that research, write and review the article
#      on a local branch
#   4. `npm run verify` is a hard gate
#   5. `vercel deploy` publishes a PREVIEW from the local tree — nothing reaches
#      GitHub, and nothing reaches production, before Enver has seen it
#   6. Telegram asks for approval, with the preview link
#   7. On "Publish" the article is SCHEDULED, not published: a one-shot job goes
#      live the following Friday 19:00-21:00 or Saturday 10:00-13:00, at random
#
# The model runs in the local Claude Code CLI on the subscription login, never on
# an API key — see lib/model.sh.
#
# Anything that fails sends a Telegram message and stops. The working tree is
# never touched unless it was clean to begin with.
#
# To run it now instead of waiting for Saturday, just execute it:
#   scripts/weekly-article/run.sh

set -euo pipefail

# --resume <branch> picks up a run that died AFTER the article was written —
# skipping topics and writing, and continuing at the verify gate. On 2026-08-15
# the writer finished the article and then hit the monthly spend limit before it
# could print its SLUG line, so run.sh threw away 24 minutes of finished work.
# Nothing downstream of the writer needs a model, so a resume always can run.
#
# --topics <topics.json> is the other half of that argument, one step earlier.
# The topic gate used to end a run by throwing away the proposals: the research
# had happened, the JSON was on disk, and no entry point could consume it, so
# the only way on was a full re-run of the step that had just cost thirty
# minutes. On 2026-08-29 that is exactly how a week was lost — the questions
# went out at 21:39, 00:09 and 02:39, nobody was awake, and four researched
# topics were discarded. This skips the proposer and asks straight away.
RESUME_BRANCH=""
TOPICS_FILE=""
case "${1:-}" in
  --resume) RESUME_BRANCH="${2:?usage: run.sh --resume <branch>}" ;;
  --topics) TOPICS_FILE="${2:?usage: run.sh --topics <topics.json>}" ;;
  "")       ;;
  *)        echo "usage: run.sh [--resume <branch> | --topics <topics.json>]" >&2; exit 2 ;;
esac

# Derived from this script's own location, never hardcoded: moving the repo must
# not require editing it. scripts/weekly-article/run.sh → ../.. is the root.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ENVERCETIN_* here are test seams. The approval branches below decide whether a
# finished article is published, kept, or left undecided, and before these seams
# existed not one of them had ever been executed outside a real Saturday.
REPO="${ENVERCETIN_REPO:-$(cd "$HERE/../.." && pwd)}"
PERSONAL_OS="${ENVERCETIN_PERSONAL_OS:-/Users/ece/Projects/personal-os}"
TG="$PERSONAL_OS/tg.py"
VERIFY_CMD="${ENVERCETIN_VERIFY_CMD:-npm run verify}"
# Named explicitly rather than found on PATH: this script prepends ~/.local/bin
# to PATH a few lines below, so a test that puts a stand-in earlier on PATH is
# silently overruled and ends up driving the real model against a fixture repo.
CLAUDE_BIN="${ENVERCETIN_CLAUDE_BIN:-claude}"
VERCEL_BIN="${ENVERCETIN_VERCEL_BIN:-vercel}"
# Seam: the tests plant and inspect deferral markers and proposal JSON, and doing
# that in the real log directory means a test run leaves state a real run reads.
LOG_DIR="${ENVERCETIN_LOG_DIR:-$HOME/Library/Logs/envercetin-weekly-article}"
STAMP="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/$STAMP.log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Every long step below can hang instead of failing — a model call waiting on a
# socket that will never answer, a deploy against a dead endpoint. A hang holds
# the repo lock, and from then on every Saturday is skipped with "a previous run
# is still going". These are ceilings, not expectations: a real writing run takes
# about 25 minutes.
# 3600, not 1800. Raised on 2026-09-18 after three attempts in a row died at the
# ceiling: the proposer fans out five research subagents, waits for all of them,
# and then judges four candidates against the thesis rule and the reach rule.
# Thirty minutes was a number from when it did less. Confining the CLI to this
# repo (lib/model.sh) cut the startup weight from 19 MCP servers and 166 tools to
# none, and it still was not enough — so the ceiling was simply too low.
PROPOSE_TIMEOUT="${ENVERCETIN_PROPOSE_TIMEOUT_SEC:-3600}"
WRITE_TIMEOUT="${ENVERCETIN_WRITE_TIMEOUT_SEC:-7200}"
VERIFY_TIMEOUT="${ENVERCETIN_VERIFY_TIMEOUT_SEC:-2700}"
DEPLOY_TIMEOUT="${ENVERCETIN_DEPLOY_TIMEOUT_SEC:-900}"
NET_TIMEOUT="${ENVERCETIN_NET_TIMEOUT_SEC:-600}"

# The topic question is only worth asking when Enver can answer it. The rounds
# below used to be a pure elapsed-time ladder with no idea what time it was, so
# a run that reached the gate at 21:39 spent its whole escalation between then
# and 02:39 and declared the week lost at dawn. Asking now happens only inside
# these hours; outside them the proposals are kept and the question is re-armed
# for the next morning, up to MAX_DEFERRALS times.
ASK_FROM_HOUR="${ENVERCETIN_ASK_FROM_HOUR:-9}"
ASK_UNTIL_HOUR="${ENVERCETIN_ASK_UNTIL_HOUR:-21}"
ASK_DEFER_HOUR="${ENVERCETIN_ASK_DEFER_HOUR:-10}"
MAX_DEFERRALS="${ENVERCETIN_MAX_DEFERRALS:-2}"

# shellcheck source=lib/with_timeout.sh
source "$HERE/lib/with_timeout.sh"
# shellcheck source=lib/approval.sh
source "$HERE/lib/approval.sh"
# shellcheck source=lib/repo_lock.sh
source "$HERE/lib/repo_lock.sh"
# shellcheck source=lib/arm_job.sh
source "$HERE/lib/arm_job.sh"
# shellcheck source=lib/model.sh
source "$HERE/lib/model.sh"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "=== weekly-article $STAMP $(date +%H:%M:%S) ==="

# Goes through envercetin-notify, which queues what it cannot send: the most
# likely reason a run fails is that there is no network, and that is exactly when
# a direct tg.py send drops the message telling you so.
# REPORTED_FILE is how the guard knows this run has already spoken for itself.
# Without it every handled failure arrives twice: the run's own account of what
# happened, and then the guard's "exited with code 1", which adds nothing and
# reads like a second, separate problem. The guard still speaks up for a run that
# died without a word — that is the whole reason it exists.
REPORTED_FILE="$LOG_DIR/reported"

notify() {
  # Marked before sending, not after: a notifier that fails still means this run
  # tried to account for itself, and a duplicate is better than a lie.
  : > "$REPORTED_FILE" 2>/dev/null || true
  if [[ -n "${ENVERCETIN_TEST_SILENT:-}" ]]; then
    echo "[test-silent] would notify: $1"
    return 0
  fi
  if command -v envercetin-notify >/dev/null 2>&1; then
    envercetin-notify "$1" || true
  else
    (cd "$PERSONAL_OS" && python3 "$TG" send "$1") || echo "TELEGRAM SEND FAILED: $1"
  fi
}

# --- A spent usage limit is a wait, not a failure ------------------------------
# The subscription's limit is shared with every interactive session, so a heavy
# day at the keyboard before 14:00 on a Saturday leaves the writer with nothing.
# That happened on 2026-09-09 and again on 2026-09-16, and both times the run
# said "nothing was written" and waited a full week — while the CLI had printed
# the exact minute the limit would lift, three hours later.
#
# So: leave that minute where the guard can find it and exit 75. The guard arms a
# one-shot job for then and the run picks up where it stopped. 75 is EX_TEMPFAIL,
# and the guard treats it as "come back", never as "something broke".
RETRY_AT_FILE="$LOG_DIR/retry-at"
RETRY_ARGS_FILE="$LOG_DIR/retry-args"
rm -f "$RETRY_AT_FILE" "$RETRY_ARGS_FILE"

# defer_until_limit_lifts <model-output> [resume-arg...] — prints when it will
# come back, in words fit for a message.
defer_until_limit_lifts() {
  local out="$1" epoch
  shift
  epoch="$(model_limit_reset_epoch "$out")"
  # No time in the line is not a reason to give up for a week. A fixed hour is a
  # worse guess than the CLI's own answer and a far better one than next Saturday.
  [[ -n "$epoch" ]] || epoch=$(( $(date +%s) + ${ENVERCETIN_LIMIT_FALLBACK_MIN:-60} * 60 ))
  printf '%s' "$epoch" > "$RETRY_AT_FILE"
  # Resuming with the topic already chosen, rather than asking a second time for
  # something that was answered before the limit hit.
  [[ $# -gt 0 ]] && printf '%s\n' "$@" > "$RETRY_ARGS_FILE"
  date -r "$epoch" '+%d.%m. at %H:%M'
}

# `set +e` turns off errexit but NOT this trap. Every handled non-zero therefore
# used to fire it: on the night of 2026-08-29 a topic question nobody answered —
# the designed, fully handled path — sent Enver three "⚠️ Weekly article failed
# at line 200" messages, each contradicted moments later by the correct one, and
# line 200 was the `for` keyword rather than anything that had failed. Fallible
# steps are now run as `if VAR="$(...)"; then` conditions, which bash exempts
# from the trap, and this is left for the genuinely unexpected. It reports the
# command as well as the line, because a trap that fires inside a compound
# statement reports the line of the compound, not of the failure — that is how
# 2026-09-05 came to blame a closing `fi`.
on_error() {
  local line=$1 cmd=${2:-}
  echo "FAILED at line $line: $cmd"
  notify "⚠️ Weekly article failed at line $line: \`$cmd\`. Log: $LOG"
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR

# --- Preconditions ------------------------------------------------------------
cd "$REPO"

# One article job at a time in this working tree. Under the guard this lock is
# already held on our behalf and this is a no-op; it matters when this script is
# started by hand while a scheduled publish is due.
if ! repo_lock_hold "$REPO" "run.sh"; then
  notify "⚠️ Weekly article skipped: \`$REPO_LOCK_BUSY_JOB\` is working in the repo right now. Nothing was written or changed."
  exit 0
fi

# Connectivity is the guard's job — it waits for the network before starting this
# script at all, and arms a retry rather than giving up. So by this line the
# network is known good: the first chance all week to deliver anything an earlier
# offline run had to queue.
#
# Gated on the same seam as notify(): install.sh runs the test suite before it
# installs, and an ungated flush here drove the real notifier against Enver's
# real spool five times per test run.
if [[ -z "${ENVERCETIN_TEST_SILENT:-}" ]] && command -v envercetin-notify >/dev/null 2>&1; then
  envercetin-notify --flush || true
fi

# A resume expects a dirty tree — the half-finished article is the whole point.
if [[ -z "$RESUME_BRANCH" ]]; then
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    notify "⚠️ Weekly article skipped: the repo has uncommitted changes. I did not touch them."
    exit 0
  fi

  git checkout main --quiet
  if ! with_timeout "$NET_TIMEOUT" git pull --ff-only --quiet; then
    notify "⚠️ Weekly article stopped before it started: \`git pull\` failed or hung. Nothing was written."
    exit 1
  fi
fi

# A resume needs no model. Everything else does, and a login that is gone must be
# found before Enver is asked for a topic, not after: on 2026-09-12 the OAuth
# session had expired and the run spent both propose attempts finding that out.
if [[ -z "$RESUME_BRANCH" ]] && LOGIN_PROBLEM="$(model_login_problem)"; then
  notify "⚠️ Weekly article did not start: $LOGIN_PROBLEM, so nobody was asked anything.

$MODEL_LOGIN_FIX. Then start it again:
$REPO/scripts/weekly-article/run.sh${TOPICS_FILE:+ --topics $TOPICS_FILE}

Log: $LOG"
  exit 1
fi

if [[ -n "$RESUME_BRANCH" ]]; then
  # --- Resume -------------------------------------------------------------------
  # Steps 1-3 already happened in the run that died. Adopt its branch and read the
  # slug off the draft on disk rather than off the writer's stdout, which is the
  # thing that went missing.
  BRANCH="$RESUME_BRANCH"
  if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git checkout "$BRANCH" --quiet
  else
    git checkout -b "$BRANCH" --quiet
  fi

  SLUG="$(
    {
      git status --porcelain --untracked-files=all -- src/content/writing/en/
      git diff --name-only main...HEAD -- src/content/writing/en/
    } 2>/dev/null | grep -oE '[^/ ]+\.mdx' | sed 's/\.mdx$//' | sort -u | head -1
  )"

  if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
    notify "⚠️ Resume of \`$BRANCH\` found no article to publish. Nothing was done. Log: $LOG"
    exit 1
  fi
  echo "resuming $BRANCH at the verify gate — slug: $SLUG"
else
  # --- 1. Propose topics --------------------------------------------------------
  # ...unless a previous run already did, and nobody was awake to answer it.
  # `--topics` hands those proposals straight back to the question below.
  if [[ -n "$TOPICS_FILE" ]]; then
    [[ -f "$TOPICS_FILE" ]] || { notify "⚠️ Weekly article: --topics $TOPICS_FILE does not exist. Nothing was done."; exit 1; }
    cp "$TOPICS_FILE" "$LOG_DIR/$STAMP-topics.json"
    echo "reusing topics from $TOPICS_FILE"
    # The reminder that started this run has fired and is now inert. Drop it, so
    # that "a marker with no reminder loaded" means what the watchdog reads it to
    # mean: nothing will ask again. Deferring below re-arms it.
    if [[ -z "${ENVERCETIN_TEST_NO_LAUNCHCTL:-}" ]]; then
      launchctl bootout "gui/$(id -u)/com.enver.envercetin.topics-retry" 2>/dev/null || true
    fi
    rm -f "${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}/com.enver.envercetin.topics-retry.plist"
    # A deferral chain is counted per question, not per day: carry the count of
    # the day the topics were researched into today.
    SRC_STAMP="$(basename "$TOPICS_FILE")"; SRC_STAMP="${SRC_STAMP%-topics.json}"
    if [[ "$SRC_STAMP" != "$STAMP" && -f "$LOG_DIR/$SRC_STAMP-deferrals" ]]; then
      mv "$LOG_DIR/$SRC_STAMP-deferrals" "$LOG_DIR/$STAMP-deferrals"
    fi
  else
  # What counts as "already covered" is NOT what is in the working tree. Approved
  # articles wait on their own branch for up to a week before merging, so during
  # that week the subject is finished and scheduled while `src/content/writing/en/`
  # still looks empty of it. On 2026-08-15 the proposer offered the exact article
  # that was queued to publish the next morning. Ask git, across every branch.
  COVERED="$(
    {
      git ls-tree -r --name-only main src/content/writing/en/
      for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/article/*'); do
        git ls-tree -r --name-only "$b" src/content/writing/en/
      done
    } 2>/dev/null | sed 's|.*/||; s|\.[^.]*$||' | sort -u
  )"
  echo "already covered: $(printf '%s' "$COVERED" | tr '\n' ' ')"

  echo "--- proposing topics"
  PROPOSE_PROMPT="$(cat scripts/weekly-article/prompts/propose-topics.md)

ALREADY COVERED — published, or written and waiting for its scheduled publish:
$COVERED"

  # Two attempts, not one. On 2026-09-05 this call produced nothing whatsoever
  # for thirty fully awake minutes — no stdout, no stderr, and not one entry in
  # its own session transcript, so it never completed a single model turn — and
  # was killed at the ceiling. The identical call ran in four minutes two days
  # later. A stalled model call is a transient thing; the cost of proving that
  # is one more attempt, and the cost of assuming otherwise is a lost week.
  #
  # `< /dev/null` because the CLI otherwise waits on stdin before starting, and
  # a step that must not hang should not begin by waiting for something that is
  # never coming.
  #
  # `if VAR="$(...)"` rather than `set +e`: see on_error. sed runs afterwards
  # rather than in the pipeline, so the exit code belongs to claude and a
  # timeout can be told apart from a model that answered with prose.
  TOPICS_JSON=""
  PROPOSE_ATTEMPTS="${ENVERCETIN_PROPOSE_ATTEMPTS:-2}"
  for ATTEMPT in $(seq 1 "$PROPOSE_ATTEMPTS"); do
    PROPOSE_STARTED=$(date +%s)
    if PROPOSE_OUT="$(with_timeout "$PROPOSE_TIMEOUT" model_run "$PROPOSE_PROMPT")"; then
      PROPOSE_RC=0
    else
      PROPOSE_RC=$?
    fi
    echo "propose attempt $ATTEMPT took $(( ( $(date +%s) - PROPOSE_STARTED ) / 60 )) min (ceiling $(( PROPOSE_TIMEOUT / 60 )))"
    TOPICS_JSON="$(printf '%s\n' "$PROPOSE_OUT" | sed -n '/\[/,/\]/p')"
    [[ -n "$TOPICS_JSON" ]] && break
    if [[ $PROPOSE_RC -eq 124 ]]; then
      echo "propose attempt $ATTEMPT: still running after $(( PROPOSE_TIMEOUT / 60 )) min — killed"
    else
      # Print what it actually said. On 2026-09-07 both attempts exited 1 in
      # three minutes and the log recorded only the exit code, so the run looked
      # like the 09-05 hang when it was almost certainly a usage limit — the CLI
      # prints that reason on stdout and this threw it away. Never diagnose a
      # failed model call from an exit code alone.
      echo "propose attempt $ATTEMPT: exited $PROPOSE_RC with no JSON in its output"
      PROPOSE_SAID="$(printf '%s' "$PROPOSE_OUT" | tail -5)"
      if [[ -n "$PROPOSE_SAID" ]]; then
        printf '%s\n' "$PROPOSE_SAID" | sed 's/^/  claude said: /'
      else
        echo "  claude said: nothing at all"
      fi
      # A dead login or a spent limit fails every attempt the same way, and the
      # retry exists for hangs, not for those.
      PROPOSE_KIND="$(model_failure_kind "$PROPOSE_OUT")"
      [[ "$PROPOSE_KIND" == other ]] || break
    fi
  done

  if [[ -z "$TOPICS_JSON" ]]; then
    if [[ $PROPOSE_RC -eq 124 ]]; then
      # This used to assert "that is the 2026-09-05 failure: the CLI hangs during
      # startup". On 2026-09-18 it said exactly that three times while the CLI
      # was demonstrably fine — the same binary answered a one-line prompt in
      # ten seconds, and the proposer was working, just slower than a ceiling
      # set when it did less. A message that names a cause it cannot know sends
      # you hunting the wrong thing; this one reports what was observed.
      WHY="every attempt was still running after $(( PROPOSE_TIMEOUT / 60 )) minutes and was killed at the ceiling. That is a deadline, not a diagnosis — it does not say whether the CLI was stuck or simply slower than the ceiling allows. The log records how long each attempt actually ran; if they died at the ceiling rather than before it, raise ENVERCETIN_PROPOSE_TIMEOUT_SEC before assuming a hang"
    elif [[ "${PROPOSE_KIND:-other}" != other ]]; then
      WHY="$(model_failure_line "$PROPOSE_KIND" "$PROPOSE_OUT")"
    else
      WHY="the last attempt exited $PROPOSE_RC with no JSON anywhere in its output. It said: ${PROPOSE_SAID:-nothing at all}"
    fi
    if [[ "${PROPOSE_KIND:-other}" == limit ]]; then
      RETRY_WHEN="$(defer_until_limit_lifts "$PROPOSE_OUT")"
      notify "⏳ Weekly article: $WHY.

Nothing is lost — I'll try again automatically on $RETRY_WHEN, once the limit has lifted. Log: $LOG"
      exit 75
    fi
    notify "⚠️ Weekly article: no topics after $ATTEMPT attempt$([[ $ATTEMPT -eq 1 ]] || echo s) — $WHY.

Nothing was written. To try again by hand:
$REPO/scripts/weekly-article/run.sh

Log: $LOG"
    exit 1
  fi
  echo "$TOPICS_JSON" > "$LOG_DIR/$STAMP-topics.json"
  fi

  LIB="scripts/weekly-article/lib/topics.py"
  QUESTION="$(python3 "$LIB" question "$LOG_DIR/$STAMP-topics.json")"
  OPTIONS="$(python3 "$LIB" options "$LOG_DIR/$STAMP-topics.json")"

  # --- 2. Ask Enver -------------------------------------------------------------
  # Ask more than once before giving up, but only while he could plausibly be
  # awake. The rounds used to be a pure elapsed-time ladder: on 2026-08-29 the
  # proposer finished at 21:39, so the three reminders went out at 21:39, 00:09
  # and 02:39, and at 05:10 the run announced that no topic had been chosen and
  # threw the research away. Nobody ignored anything — nobody was asked.
  #
  # So: rounds are clipped to the civil window, and running out of window is not
  # a No. The proposals are kept and the same question is re-armed for the next
  # morning, up to MAX_DEFERRALS times, before the week is finally let go.
  ASK_ROUNDS="${ENVERCETIN_ASK_ROUNDS:-3}"
  ASK_ROUND_MIN="${ENVERCETIN_ASK_ROUND_MIN:-150}"
  TOPICS_KEPT="$LOG_DIR/$STAMP-topics.json"
  DEFERRALS_FILE="$LOG_DIR/$STAMP-deferrals"
  DEFERRALS="$(cat "$DEFERRALS_FILE" 2>/dev/null || echo 0)"

  # Minutes from now until the civil window shuts. Negative or zero means it is
  # already shut. Computed with `date`, never by arithmetic on the hour alone,
  # so it stays right across a DST change.
  minutes_of_window_left() {
    local now_min until_min hour
    hour="$(date +%H)"; hour="${hour#0}"; hour="${hour:-0}"
    now_min=$(( hour * 60 + 10#$(date +%M) ))
    until_min=$(( ASK_UNTIL_HOUR * 60 ))
    echo $(( until_min - now_min ))
  }

  # Keep the proposals, re-arm the question for tomorrow morning, and stop. The
  # retry re-enters run.sh through the guard — which holds the locks, waits for
  # the network and keeps the Mac awake — with `--topics`, so it asks rather
  # than researches.
  defer_topic_question() {
    local why="$1" next_label mm dd next_hour
    if [[ "$DEFERRALS" -ge "$MAX_DEFERRALS" ]]; then
      # The marker is what tells the watchdog a question is still outstanding.
      # Leaving it here would have the watchdog report a dead chain every day
      # until Saturday; the message below is the last word on this week.
      rm -f "$DEFERRALS_FILE"
      notify "No topic chosen after $(( MAX_DEFERRALS + 1 )) days of asking, so nothing was written this week.

The four proposals are still on disk if you want one of them:
$REPO/scripts/weekly-article/run.sh --topics $TOPICS_KEPT

Otherwise I will research fresh ones next Saturday."
      exit 0
    fi

    next_label="com.enver.envercetin.topics-retry"

    # Two different silences. If the window has not OPENED yet — a hand-started
    # run at 07:51, which is how 2026-09-18 went — the wait is one hour, and
    # jumping to tomorrow morning for it threw away a whole day of a week that
    # had already lost three. If the window has SHUT for the evening, tomorrow
    # is genuinely the next civil moment.
    local now_hour when_word
    now_hour="$(date +%H)"; now_hour="${now_hour#0}"; now_hour="${now_hour:-0}"
    if (( now_hour < ASK_FROM_HOUR )); then
      mm="$(date +%m)"; dd="$(date +%d)"
      next_hour="$ASK_FROM_HOUR"
      when_word="later today at $(printf '%02d' "$ASK_FROM_HOUR"):00"
    else
      mm="$(date -v+1d +%m)"; dd="$(date -v+1d +%d)"
      next_hour="$ASK_DEFER_HOUR"
      when_word="tomorrow at $(printf '%02d' "$ASK_DEFER_HOUR"):00"
    fi

    if arm_job "$next_label" "${mm#0}" "${dd#0}" "$next_hour" 0 \
         "$HOME/.local/bin/envercetin-guard" weekly-article \
         "$REPO/scripts/weekly-article/run.sh" --topics "$TOPICS_KEPT"; then
      echo $(( DEFERRALS + 1 )) > "$DEFERRALS_FILE"
      notify "🌙 $why — so I did not burn this week's question on it.

The four topics are researched and waiting. I will ask again $when_word.

To pick one right now instead:
$REPO/scripts/weekly-article/run.sh --topics $TOPICS_KEPT"
      exit 0
    fi

    # A retry that failed to arm must not be reported as scheduled.
    notify "⚠️ $why, and I could not schedule tomorrow's reminder either.

The four topics are researched and waiting. Pick one with:
$REPO/scripts/weekly-article/run.sh --topics $TOPICS_KEPT"
    exit 1
  }

  WINDOW_LEFT="$(minutes_of_window_left)"
  HOUR_NOW="$(date +%H)"; HOUR_NOW="${HOUR_NOW#0}"; HOUR_NOW="${HOUR_NOW:-0}"
  if (( HOUR_NOW < ASK_FROM_HOUR || WINDOW_LEFT <= 0 )); then
    defer_topic_question "It is $(date +%H:%M) and I only ask between ${ASK_FROM_HOUR}:00 and ${ASK_UNTIL_HOUR}:00"
  fi

  echo "--- asking for the topic (up to $ASK_ROUNDS rounds of $ASK_ROUND_MIN min, window shuts at $ASK_UNTIL_HOUR:00)"

  ASK_RC=2
  for ROUND in $(seq 1 "$ASK_ROUNDS"); do
    WINDOW_LEFT="$(minutes_of_window_left)"
    (( WINDOW_LEFT > 0 )) || defer_topic_question "Nobody answered before ${ASK_UNTIL_HOUR}:00"

    # Never let a round run past the window: a question posted at 20:50 with a
    # 150-minute deadline is a question that expires at 23:20.
    ROUND_MIN="$ASK_ROUND_MIN"
    (( ROUND_MIN > WINDOW_LEFT )) && ROUND_MIN="$WINDOW_LEFT"

    if [[ $ROUND -eq 1 ]]; then
      PROMPT_TEXT="$QUESTION"
    elif [[ $ROUND -lt $ASK_ROUNDS ]]; then
      PROMPT_TEXT="Still open — this week's article is waiting on a topic.

$QUESTION"
    else
      PROMPT_TEXT="Last call for today. If nobody picks one, I will ask again tomorrow morning rather than drop the week.

$QUESTION"
    fi

    # tg.py enforces its own deadline; this one only catches it hanging past it.
    # The `if` form matters: `set +e` does not suppress the ERR trap, and this
    # timing out is the normal path, not a failure. See on_error.
    if ASK_OUT="$(cd "$PERSONAL_OS" && with_timeout $(( ROUND_MIN * 60 + 600 )) python3 "$TG" ask "$PROMPT_TEXT" --options "$OPTIONS" --timeout-min "$ROUND_MIN")"; then
      ASK_RC=0
    else
      ASK_RC=$?
    fi

    [[ $ASK_RC -ne 2 ]] && break
    echo "round $ROUND: no reply after $ROUND_MIN min"
  done

  if [[ $ASK_RC -eq 2 ]]; then
    defer_topic_question "No answer after $ASK_ROUNDS asks today"
  elif [[ $ASK_RC -ne 0 ]]; then
    notify "⚠️ Weekly article: Telegram ask failed (rc=$ASK_RC), so the question never reached you. Nothing was written.

The four topics are researched and waiting:
$REPO/scripts/weekly-article/run.sh --topics $TOPICS_KEPT

Log: $LOG"
    exit 1
  fi

  # Answered. Any reminder armed by an earlier day of this same question is now
  # stale — leaving it loaded means being asked again about an article that is
  # already being written.
  rm -f "$DEFERRALS_FILE"
  if [[ -z "${ENVERCETIN_TEST_NO_LAUNCHCTL:-}" ]]; then
    launchctl bootout "gui/$(id -u)/com.enver.envercetin.topics-retry" 2>/dev/null || true
  fi
  rm -f "${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}/com.enver.envercetin.topics-retry.plist"

  # sed, not grep: grep exits 1 when nothing matched, and under `set -e` with
  # pipefail that kills the run at the assignment — on precisely the paths where
  # there is no reply to read, which are the ones that must stay recoverable.
  TOPIC="$(printf '%s\n' "$ASK_OUT" | sed -n 's/^REPLY: //p' | tail -1)"
  if [[ -z "$TOPIC" ]]; then
    notify "⚠️ Weekly article: could not read your reply. Log: $LOG"
    exit 1
  fi
  echo "topic: $TOPIC"

  # If Enver tapped a button, hand the full proposal to the writer, not just the label.
  TOPIC_BRIEF="$(python3 "$LIB" brief "$LOG_DIR/$STAMP-topics.json" "$TOPIC")"

  # --- 3. Write -----------------------------------------------------------------
  # `checkout -b` fails outright if the branch exists, and under the ERR trap
  # that ends the run — after Enver has already been interrupted for a topic.
  # A second attempt on the same day is exactly when that happens.
  BRANCH="article/$STAMP"
  ATTEMPT_N=2
  while git rev-parse --verify "$BRANCH" >/dev/null 2>&1; do
    BRANCH="article/$STAMP-$ATTEMPT_N"
    ATTEMPT_N=$(( ATTEMPT_N + 1 ))
  done
  git checkout -b "$BRANCH" --quiet
  notify "✍️ Writing this week's article: $TOPIC — I'll send a preview link when it's ready."

  echo "--- writing"
  PROMPT="$(sed "s|{{TOPIC}}|$TOPIC_BRIEF|" scripts/weekly-article/prompts/write-article.md)"
  # `if`, not `set +e`: the trap fires regardless of errexit, and a writer that
  # times out is a case this block handles rather than a failure to announce.
  if WRITE_OUT="$(with_timeout "$WRITE_TIMEOUT" model_run "$PROMPT")"; then
    WRITE_RC=0
  else
    WRITE_RC=$?
  fi
  echo "$WRITE_OUT" | tail -40

  if [[ $WRITE_RC -eq 124 ]]; then
    notify "⚠️ Weekly article: the writer was still running after $(( WRITE_TIMEOUT / 60 )) minutes, so I stopped it rather than let it hold the repo until next week.

Whatever it managed is on \`$BRANCH\`. If there is a draft there:
$REPO/scripts/weekly-article/run.sh --resume $BRANCH

Log: $LOG"
    exit 1
  fi

  # The writer prints SLUG last. If it dies after writing the article but before
  # printing — a crash, a spend limit — the article is on disk and only this line
  # is missing. Say so, so the work can be resumed instead of rewritten.
  # sed, not grep: on 2026-09-09 the writer printed only its usage-limit line,
  # grep exited 1, and the run died right here instead of in the handler below.
  SLUG="$(printf '%s\n' "$WRITE_OUT" | sed -n 's/^SLUG: //p' | tail -1 | tr -d '[:space:]')"
  if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
    DRAFT="$(git status --porcelain --untracked-files=all -- src/content/writing/en/ | grep -c '\.mdx' || true)"
    WRITE_KIND="$(model_failure_kind "$WRITE_OUT")"
    # The 2026-09-09 case: the limit ran out mid-article. The topic is chosen and
    # the research is done, so coming back to it is worth far more than asking a
    # fresh question next Saturday — resume the branch if there is a draft on it,
    # otherwise re-enter with the same proposals.
    if [[ "$WRITE_KIND" == limit ]]; then
      if [[ "$DRAFT" -gt 0 ]]; then
        RETRY_WHEN="$(defer_until_limit_lifts "$WRITE_OUT" --resume "$BRANCH")"
        RETRY_WHAT="picks \`$BRANCH\` up where it stopped"
      else
        git checkout main --quiet
        git branch -d "$BRANCH" --quiet 2>/dev/null || true
        RETRY_WHEN="$(defer_until_limit_lifts "$WRITE_OUT" --topics "$LOG_DIR/$STAMP-topics.json")"
        RETRY_WHAT="writes \"$TOPIC\" without asking you again"
      fi
      notify "⏳ Weekly article: $(model_failure_line limit "$WRITE_OUT").

Nothing is lost — I'll try again automatically on $RETRY_WHEN and $RETRY_WHAT. Log: $LOG"
      exit 75
    fi
    if [[ "$DRAFT" -gt 0 ]]; then
      notify "⚠️ Weekly article: the writer stopped before naming its article, but a draft IS on \`$BRANCH\`.

Resume it with:
scripts/weekly-article/run.sh --resume $BRANCH

Log: $LOG"
    elif [[ -z "$(git status --porcelain --untracked-files=all)" && -z "$(git rev-list main..HEAD)" ]]; then
      # Nothing at all on the branch. Leaving it made the watchdog report
      # `article/2026-09-09` as "written and stuck" for a week.
      git checkout main --quiet
      git branch -d "$BRANCH" --quiet
      notify "⚠️ Weekly article: nothing was written — $(model_failure_line "$(model_failure_kind "$WRITE_OUT")" "$WRITE_OUT").

To write \"$TOPIC\" later, pick it again with:
$REPO/scripts/weekly-article/run.sh --topics $LOG_DIR/$STAMP-topics.json

Log: $LOG"
    else
      notify "⚠️ Weekly article: no usable article was produced — $(model_failure_line "$(model_failure_kind "$WRITE_OUT")" "$WRITE_OUT"). Branch $BRANCH kept locally. Log: $LOG"
    fi
    exit 1
  fi
fi

# --- 4. Hard gate -------------------------------------------------------------
echo "--- verifying"
if ! with_timeout "$VERIFY_TIMEOUT" bash -c "$VERIFY_CMD" > "$LOG_DIR/$STAMP-verify.log" 2>&1; then
  notify "⚠️ Weekly article: \`$VERIFY_CMD\` failed, so nothing was deployed. Branch $BRANCH is on your Mac. Log: $LOG_DIR/$STAMP-verify.log"
  exit 1
fi

# A writing run creates a throwaway page to look at its own figure. It is not
# part of the article, and `git add -A` would otherwise commit and publish it.
rm -f src/pages/diagram-preview.astro src/pages/preview.astro
# Named paths, not `git add -A`. The writer is told to install and run things in
# order to measure them, and whatever that leaves behind — a virtualenv, a model
# download, a cache — would otherwise be committed and deployed with the article.
# Only paths that exist are passed: `git add` fails the whole invocation on one
# unmatched pathspec, and a fixture repo does not have every directory the site
# has.
STAGE=()
for PATHSPEC in src/content/writing/en src/content/writing/de src/components \
                src/lib src/pages src/data src/styles src/assets public docs tests; do
  [[ -e "$PATHSPEC" ]] && STAGE+=("$PATHSPEC")
done
# bash 3.2 treats an empty array under `set -u` as unbound, so never expand one.
[[ ${#STAGE[@]} -gt 0 ]] && git add "${STAGE[@]}"
git add -u   # tracked deletions anywhere, which the list above would miss

# A commit that does not contain the article is worse than no commit: verify has
# already passed, the deploy would go out, and the preview would show nothing.
# A resume may arrive here with the article already committed by the run that
# died, so the branch counts as well as the index.
if ! { git diff --cached --name-only
       git diff --name-only main...HEAD 2>/dev/null
     } | grep -q "src/content/writing/.*/$SLUG\."; then
  notify "⚠️ Weekly article: \"$SLUG\" was written but did not end up staged, so nothing was committed or deployed. Branch \`$BRANCH\` is on your Mac. Log: $LOG"
  exit 1
fi
if ! git diff --cached --quiet; then
  git commit --quiet -m "feat: article — $SLUG"
else
  echo "nothing new to commit — the article is already on $BRANCH"
fi

# --- 5. Preview (local tree → Vercel; nothing pushed to GitHub) ---------------
echo "--- deploying preview"
# The same shape that killed the propose step, one stage later and with more at
# stake: by this line the article is written, verified and committed. A bare
# assignment under `set -euo pipefail` fails the run at the assignment itself —
# `grep -Eo` exits 1 when the output holds no URL, and with_timeout returns 124
# when the deploy hangs — so the handler two lines below, which is the one that
# says something useful, could never run. The `if` form keeps the exit code and
# reaches the handler.
if DEPLOY_OUT="$(with_timeout "$DEPLOY_TIMEOUT" "$VERCEL_BIN" deploy --yes 2>/dev/null)"; then
  DEPLOY_RC=0
else
  DEPLOY_RC=$?
fi
PREVIEW="$(printf '%s\n' "$DEPLOY_OUT" | grep -Eo 'https://[a-z0-9.-]+\.vercel\.app' | tail -1 || true)"
if [[ -z "$PREVIEW" ]]; then
  if [[ $DEPLOY_RC -eq 124 ]]; then
    WHY="the deploy was still running after $(( DEPLOY_TIMEOUT / 60 )) minutes and had to be killed"
  elif [[ $DEPLOY_RC -ne 0 ]]; then
    WHY="\`$VERCEL_BIN deploy\` exited $DEPLOY_RC"
  else
    WHY="the deploy finished but printed no preview URL"
  fi
  notify "⚠️ Weekly article: no preview to show you — $WHY.

\"$SLUG\" is written, verified and committed on \`$BRANCH\`. Nothing was published.

Retry the deploy and the approval with:
$REPO/scripts/weekly-article/run.sh --resume $BRANCH

Log: $LOG"
  exit 1
fi
echo "preview: $PREVIEW"

# --- 6. Approval --------------------------------------------------------------
# A failed question is not a No. run.sh used to treat every non-zero exit from
# `tg.py ask` as "Keep as draft": an expired token or a dropped poll answered on
# Enver's behalf, the finished article became a permanent draft, its topic stayed
# marked COVERED on the branch so it could never be proposed again — and the
# message he got told him he had chosen that. lib/approval.sh separates the four
# outcomes; this block does something different with each.
APPROVE_ROUNDS="${ENVERCETIN_APPROVE_ROUNDS:-2}"
APPROVE_MIN="${ENVERCETIN_APPROVE_MIN:-720}"

DECISION=undecided
APPROVE_RC=1
for ROUND in $(seq 1 "$APPROVE_ROUNDS"); do
  if [[ $ROUND -eq 1 ]]; then
    APPROVE_TEXT="📄 This week's article is ready.

$PREVIEW/writing/$SLUG

Publish it to envercetin.de?"
  else
    APPROVE_TEXT="Still waiting on this week's article — it is written and the preview is up.

$PREVIEW/writing/$SLUG

Publish it to envercetin.de?"
  fi

  # `if`, not `set +e`: an unanswered approval is classified below, not a crash.
  if APPROVE_OUT="$(cd "$PERSONAL_OS" && with_timeout $(( APPROVE_MIN * 60 + 600 )) \
    python3 "$TG" ask "$APPROVE_TEXT" --options "Publish,Keep as draft" --timeout-min "$APPROVE_MIN")"; then
    APPROVE_RC=0
  else
    APPROVE_RC=$?
  fi

  APPROVAL="$(printf '%s\n' "$APPROVE_OUT" | sed -n 's/^REPLY: //p' | tail -1)"
  DECISION="$(classify_approval "$APPROVE_RC" "$APPROVAL")"
  echo "round $ROUND: rc=$APPROVE_RC reply='${APPROVAL:-}' → $DECISION"

  # Only "nothing usable came back" is worth asking again. An error means the
  # question never arrived, and repeating it just fails twice.
  [[ "$DECISION" == "undecided" ]] || break
done

case "$DECISION" in
  publish)
    ;;

  draft)
    git checkout main --quiet
    notify "Article kept as a draft on branch \`$BRANCH\`. Nothing was published. Preview stays at $PREVIEW"
    exit 0
    ;;

  undecided)
    # He was asked and did not answer. That is not a decision, and it must not be
    # filed as one — say plainly that nothing was decided and how to decide later.
    git checkout main --quiet
    notify "🤔 No answer on this week's article after $APPROVE_ROUNDS asks, so I published nothing — and I did not read the silence as a No.

It is finished and waiting on \`$BRANCH\`. Preview: $PREVIEW

Publish it whenever you like:
$REPO/scripts/weekly-article/deploy-scheduled.sh $BRANCH

Drop it for good (and stop the reminders):
$REPO/scripts/weekly-article/cancel-publish.sh $BRANCH"
    exit 0
    ;;

  error)
    git checkout main --quiet
    notify "⚠️ I could not ask you about this week's article — Telegram returned an error (rc=$APPROVE_RC). Nobody decided anything, so nothing was published.

The article is finished on \`$BRANCH\` and the preview is up: $PREVIEW

Publish it with:
$REPO/scripts/weekly-article/deploy-scheduled.sh $BRANCH

Log: $LOG"
    exit 1
    ;;
esac

# --- 7. Schedule the publish ---------------------------------------------------
# Approved articles do not go live immediately. They are held and published at a
# randomised time in one of two windows — the following Friday 19:00-21:00 or the
# following Saturday 10:00-13:00 — so the site does not read as cron-driven.
echo "--- scheduling publish"
git checkout main --quiet
# Guarded for the same reason: an unguarded assignment dies at the assignment,
# and by this line Enver has already been told his article was approved.
if SLOT="$(python3 scripts/weekly-article/lib/schedule_publish.py "$BRANCH")" && [[ -n "$SLOT" ]]; then
  SLOT_HUMAN="${SLOT#*|}"
else
  notify "⚠️ Weekly article: you approved \"$SLUG\", but I could not schedule its publish.

It is finished and waiting on \`$BRANCH\`. Publish it whenever you like:
$REPO/scripts/weekly-article/deploy-scheduled.sh $BRANCH

Log: $LOG"
  exit 1
fi

notify "🗓 Approved. \"$SLUG\" is scheduled to go live on $SLOT_HUMAN.

Preview stays up: $PREVIEW
To cancel: $REPO/scripts/weekly-article/cancel-publish.sh $BRANCH"
echo "scheduled for $SLOT_HUMAN"
echo "=== done $(date +%H:%M:%S) ==="
