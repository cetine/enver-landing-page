#!/usr/bin/env bash
#
# Weekly article pipeline — fires Saturdays 14:00 via launchd.
#
#   1. Claude proposes 4 topics (web-researched, checked against what is already published)
#   2. Telegram asks Enver: tap a proposal, or type a topic of his own
#   3. Claude researches and writes the article on a local branch, in ultracode
#   4. `npm run verify` is a hard gate
#   5. `vercel deploy` publishes a PREVIEW from the local tree — nothing reaches
#      GitHub, and nothing reaches production, before Enver has seen it
#   6. Telegram asks for approval, with the preview link
#   7. On "Publish" the article is SCHEDULED, not published: a one-shot job goes
#      live the following Friday 19:00-21:00 or Saturday 10:00-13:00, at random
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
RESUME_BRANCH=""
if [[ "${1:-}" == "--resume" ]]; then
  RESUME_BRANCH="${2:?usage: run.sh --resume <branch>}"
fi

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
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
STAMP="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/$STAMP.log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Every long step below can hang instead of failing — a model call waiting on a
# socket that will never answer, a deploy against a dead endpoint. A hang holds
# the repo lock, and from then on every Saturday is skipped with "a previous run
# is still going". These are ceilings, not expectations: a real writing run takes
# about 25 minutes.
PROPOSE_TIMEOUT="${ENVERCETIN_PROPOSE_TIMEOUT_SEC:-1800}"
WRITE_TIMEOUT="${ENVERCETIN_WRITE_TIMEOUT_SEC:-7200}"
VERIFY_TIMEOUT="${ENVERCETIN_VERIFY_TIMEOUT_SEC:-2700}"
DEPLOY_TIMEOUT="${ENVERCETIN_DEPLOY_TIMEOUT_SEC:-900}"
NET_TIMEOUT="${ENVERCETIN_NET_TIMEOUT_SEC:-600}"

# shellcheck source=lib/with_timeout.sh
source "$HERE/lib/with_timeout.sh"
# shellcheck source=lib/approval.sh
source "$HERE/lib/approval.sh"
# shellcheck source=lib/repo_lock.sh
source "$HERE/lib/repo_lock.sh"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "=== weekly-article $STAMP $(date +%H:%M:%S) ==="

# Goes through envercetin-notify, which queues what it cannot send: the most
# likely reason a run fails is that there is no network, and that is exactly when
# a direct tg.py send drops the message telling you so.
notify() {
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

on_error() {
  local line=$1
  echo "FAILED at line $line"
  notify "⚠️ Weekly article failed at line $line. Log: $LOG"
}
trap 'on_error $LINENO' ERR

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
command -v envercetin-notify >/dev/null 2>&1 && envercetin-notify --flush || true

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

CLAUDE_FLAGS=(--model opus --permission-mode acceptEdits
  --allowed-tools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,Workflow,TodoWrite,TaskCreate,TaskUpdate")

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
  TOPICS_JSON="$(with_timeout "$PROPOSE_TIMEOUT" "$CLAUDE_BIN" -p "$PROPOSE_PROMPT" "${CLAUDE_FLAGS[@]}" | sed -n '/\[/,/\]/p')"

  if [[ -z "$TOPICS_JSON" ]]; then
    notify "⚠️ Weekly article: topic proposal returned nothing. Log: $LOG"
    exit 1
  fi
  echo "$TOPICS_JSON" > "$LOG_DIR/$STAMP-topics.json"

  LIB="scripts/weekly-article/lib/topics.py"
  QUESTION="$(python3 "$LIB" question "$LOG_DIR/$STAMP-topics.json")"
  OPTIONS="$(python3 "$LIB" options "$LOG_DIR/$STAMP-topics.json")"

  # --- 2. Ask Enver -------------------------------------------------------------
  # Ask more than once before giving up. A Saturday afternoon is exactly when a
  # single unanswered question loses the week, and the cost of a nudge is one
  # message. Each round holds the personal-os ask lock, which pauses kb_daemon,
  # so the rounds are bounded rather than open-ended.
  ASK_ROUNDS="${ENVERCETIN_ASK_ROUNDS:-3}"
  ASK_ROUND_MIN="${ENVERCETIN_ASK_ROUND_MIN:-150}"
  echo "--- asking for the topic (up to $ASK_ROUNDS rounds of $ASK_ROUND_MIN min)"

  ASK_RC=2
  for ROUND in $(seq 1 "$ASK_ROUNDS"); do
    if [[ $ROUND -eq 1 ]]; then
      PROMPT_TEXT="$QUESTION"
    elif [[ $ROUND -lt $ASK_ROUNDS ]]; then
      PROMPT_TEXT="Still open — this week's article is waiting on a topic.

$QUESTION"
    else
      PROMPT_TEXT="Last call for this week's article. If you skip this one, nothing gets written and I will ask again next Saturday.

$QUESTION"
    fi

    set +e
    # tg.py enforces its own deadline; this one only catches it hanging past it.
    ASK_OUT="$(cd "$PERSONAL_OS" && with_timeout $(( ASK_ROUND_MIN * 60 + 600 )) python3 "$TG" ask "$PROMPT_TEXT" --options "$OPTIONS" --timeout-min "$ASK_ROUND_MIN")"
    ASK_RC=$?
    set -e

    [[ $ASK_RC -ne 2 ]] && break
    echo "round $ROUND: no reply after $ASK_ROUND_MIN min"
  done

  if [[ $ASK_RC -eq 2 ]]; then
    notify "No topic chosen after $ASK_ROUNDS reminders — skipping this week. Nothing was written, and I will ask again next Saturday."
    exit 0
  elif [[ $ASK_RC -ne 0 ]]; then
    notify "⚠️ Weekly article: Telegram ask failed (rc=$ASK_RC). Log: $LOG"
    exit 1
  fi

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
  BRANCH="article/$STAMP"
  git checkout -b "$BRANCH" --quiet
  notify "✍️ Writing this week's article: $TOPIC — I'll send a preview link when it's ready."

  echo "--- writing"
  PROMPT="$(sed "s|{{TOPIC}}|$TOPIC_BRIEF|" scripts/weekly-article/prompts/write-article.md)"
  set +e
  WRITE_OUT="$(with_timeout "$WRITE_TIMEOUT" "$CLAUDE_BIN" -p "$PROMPT" "${CLAUDE_FLAGS[@]}")"
  WRITE_RC=$?
  set -e
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
  SLUG="$(printf '%s\n' "$WRITE_OUT" | grep '^SLUG: ' | tail -1 | sed 's/^SLUG: //' | tr -d '[:space:]')"
  if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
    DRAFT="$(git status --porcelain --untracked-files=all -- src/content/writing/en/ | grep -c '\.mdx' || true)"
    if [[ "$DRAFT" -gt 0 ]]; then
      notify "⚠️ Weekly article: the writer stopped before naming its article, but a draft IS on \`$BRANCH\`.

Resume it with:
scripts/weekly-article/run.sh --resume $BRANCH

Log: $LOG"
    else
      notify "⚠️ Weekly article: no usable article was produced. Branch $BRANCH kept locally. Log: $LOG"
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
git add -A
git commit --quiet -m "feat: article — $SLUG"

# --- 5. Preview (local tree → Vercel; nothing pushed to GitHub) ---------------
echo "--- deploying preview"
PREVIEW="$(with_timeout "$DEPLOY_TIMEOUT" "$VERCEL_BIN" deploy --yes 2>/dev/null | grep -Eo 'https://[a-z0-9.-]+\.vercel\.app' | tail -1)"
if [[ -z "$PREVIEW" ]]; then
  notify "⚠️ Weekly article: preview deploy produced no URL. Branch $BRANCH is committed locally. Log: $LOG"
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

  set +e
  APPROVE_OUT="$(cd "$PERSONAL_OS" && with_timeout $(( APPROVE_MIN * 60 + 600 )) \
    python3 "$TG" ask "$APPROVE_TEXT" --options "Publish,Keep as draft" --timeout-min "$APPROVE_MIN")"
  APPROVE_RC=$?
  set -e

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
SLOT="$(python3 scripts/weekly-article/lib/schedule_publish.py "$BRANCH")"
SLOT_HUMAN="${SLOT#*|}"

notify "🗓 Approved. \"$SLUG\" is scheduled to go live on $SLOT_HUMAN.

Preview stays up: $PREVIEW
To cancel: $REPO/scripts/weekly-article/cancel-publish.sh $BRANCH"
echo "scheduled for $SLOT_HUMAN"
echo "=== done $(date +%H:%M:%S) ==="
