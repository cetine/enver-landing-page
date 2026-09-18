#!/usr/bin/env bash
#
# Failure guard for the launchd-driven article jobs.
#
#   guard.sh <job-name> <script> [script-args...]
#
# The scheduled jobs used to point launchd straight at a script inside the repo.
# That has one silent failure mode, and it bit on 2026-08-15: if the script is
# unreachable — the repo moved, a sync client took it away, macOS refused the
# path — launchd cannot even start bash, so the script's own error handling never
# runs and nothing is reported. The week is simply lost, quietly.
#
# This wrapper lives OUTSIDE the repo (installed at ~/.local/bin/envercetin-guard)
# precisely so it still runs, and still reaches Telegram, in that case. It:
#
#   * refuses to start a second copy of the same job
#   * checks the target script is actually readable BEFORE trying to run it
#   * reports any non-zero exit to Telegram, with the log path
#   * releases the personal-os ask lock if the run died holding it, so kb_daemon
#     does not stay paused forever
#
# It is intentionally generic — it takes the script to run as an argument — so
# changes on the repo side never require reinstalling it.
#
# Canonical source: scripts/weekly-article/guard.sh in the envercetin repo.
# Install/update with: scripts/weekly-article/install.sh

# No `set -e`: a failing command here must reach the reporting path, not skip it.
set -uo pipefail

JOB="${1:-}"
SCRIPT="${2:-}"
if [[ -z "$JOB" || -z "$SCRIPT" ]]; then
  echo "usage: guard.sh <job-name> <script> [script-args...]" >&2
  exit 64
fi
ORIG_ARGV=("$JOB" "$SCRIPT" "${@:3}")
RETRY_ARGV=("${ORIG_ARGV[@]}")
shift 2

PERSONAL_OS="$HOME/Projects/personal-os"
TG="$PERSONAL_OS/tg.py"
ASK_LOCK="$PERSONAL_OS/data/ask-active.lock"
LOG_DIR="${ENVERCETIN_LOG_DIR:-$HOME/Library/Logs/envercetin-weekly-article}"
LOG="$LOG_DIR/guard-$JOB-$(date +%Y-%m-%d-%H%M).log"
LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
LOCK_DIR="$LOCK_ROOT/$JOB.lock"
# Every arming gets its own label. `launchctl bootout` on the label you are
# running under kills the process executing that line, so a retry that re-arms
# under the same name kills itself mid-arm — it leaves the plist on disk, never
# loaded, and the chain stops dead. That is what happened on 2026-09-17: the
# 14:00 retry deferred to 19:00, wrote the plist, and died at the bootout. 19:00
# came and went. A unique label per arming makes the collision impossible rather
# than handled.
RETRY_PREFIX="com.enver.envercetin.retry-$JOB"
RETRY_LABEL="$RETRY_PREFIX"

# What separates "still working" from "hung forever". A legitimate run can take
# most of a day — the topic question waits up to three rounds of 150 minutes and
# the approval question up to twelve hours — so the cap sits well above a real
# run, and far below the seven days until the next one.
MAX_RUN_SEC=$(( ${ENVERCETIN_MAX_RUN_HOURS:-36} * 3600 ))

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$LOG_DIR" "$LOCK_ROOT"
exec > >(tee -a "$LOG") 2>&1
echo "=== guard: $JOB — $(date) ==="
echo "target: $SCRIPT ${*:-}"

# --- Reporting ----------------------------------------------------------------
# Telegram is the primary channel. A macOS notification is the fallback for the
# case where Telegram itself is what is broken — otherwise a failure to report a
# failure would be just as silent as the bug this guard exists to kill.
notify() {
  local msg="$1"
  # The launchd tests run the real guard end to end. Without this they would send
  # Telegram messages every time the suite runs.
  if [[ -n "${ENVERCETIN_TEST_SILENT:-}" ]]; then
    echo "[test-silent] would notify: $msg"
    return 0
  fi
  # envercetin-notify spools what it cannot send and delivers it on the next run
  # that has a network — the alert about an offline failure would otherwise be
  # destroyed by the very outage it was reporting.
  if command -v envercetin-notify >/dev/null 2>&1; then
    envercetin-notify "$msg"
    return 0
  fi
  if [[ -x "$TG" || -f "$TG" ]]; then
    (cd "$PERSONAL_OS" && python3 "$TG" send "$msg") && return 0
  fi
  echo "TELEGRAM FAILED, falling back to a desktop notification: $msg"
  osascript -e "display notification \"envercetin: $JOB failed. See $LOG\" with title \"Weekly article\"" 2>/dev/null
  return 0
}

# A retry re-arms itself for as long as its condition holds. Reporting on every
# attempt turns one problem into an alarm clock — a dozen identical messages for
# a single long wait, all delivered at once when the network returns. Say it on
# the run that first hit it, and then keep quiet about it.
# True when this process IS one of the retries armed for this job — by the label
# launchd is running us under, or by the stamp arm_retry puts in the plist.
running_as_retry() {
  [[ "${XPC_SERVICE_NAME:-}" == "$RETRY_PREFIX" \
     || "${XPC_SERVICE_NAME:-}" == "$RETRY_PREFIX-"* \
     || "${ENVERCETIN_RETRY_OF:-}" == "$JOB" ]]
}

notify_unless_retry() {
  if running_as_retry; then
    echo "(reported already on the first attempt, staying quiet) $1"
    return 0
  fi
  notify "$1"
}

# --- Locks --------------------------------------------------------------------
# Two of them, both mkdir-atomic:
#
#   job lock  — do not start the same job twice
#   repo lock — do not let two DIFFERENT jobs into the same working tree
#
# The repo lock is the one that was missing. A publish job that launchd deferred
# to the next wake and the Saturday writing run are different jobs with equal
# right to run, and both begin with `git checkout` in the same directory: one
# `git reset --hard` lands on the other's half-written article, and nothing in
# the pipeline notices which one lost.
#
# Each lock records its holder's pid, the epoch it was taken and the job that
# took it. The age is what makes a hung run recoverable WITHOUT a daemon: no
# process has to stay awake watching — and none could, on a MacBook that spends
# its life with the lid shut — because the next run to arrive is what judges it.
LOCKS_HELD=()
LOCK_BUSY_PID=""
LOCK_BUSY_JOB=""

lock_take() {
  local dir="$1"
  mkdir "$dir" 2>/dev/null || return 1
  echo $$ > "$dir/pid"
  date +%s > "$dir/since"
  printf '%s' "$JOB" > "$dir/job"
  LOCKS_HELD+=("$dir")
  return 0
}

# Only ever removes locks this run actually holds — a lock belonging to someone
# else must survive our exit, however we exit.
release_locks() {
  local dir
  for dir in ${LOCKS_HELD+"${LOCKS_HELD[@]}"}; do
    rm -rf "$dir"
  done
  LOCKS_HELD=()
}
trap release_locks EXIT

# Kill a process, and the whole process group when it leads one — which is how
# launchd starts every job here. `claude -p` and `npm run verify` leave children
# that would otherwise keep holding the network and the repo: the hang, still
# hanging, just without anything left to report it.
kill_tree() {
  local pid="$1" pgid
  pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  if [[ -n "$pgid" && "$pgid" == "$pid" ]]; then
    kill -TERM "-$pid" 2>/dev/null
    sleep 2
    kill -KILL "-$pid" 2>/dev/null
  else
    kill -TERM "$pid" 2>/dev/null
    sleep 2
    kill -KILL "$pid" 2>/dev/null
  fi
}

# 0 = acquired, 1 = someone else is legitimately working.
lock_acquire() {
  local dir="$1" what="$2"
  lock_take "$dir" && return 0

  local pid since job age
  pid="$(cat "$dir/pid" 2>/dev/null || echo "")"
  since="$(cat "$dir/since" 2>/dev/null || echo 0)"
  job="$(cat "$dir/job" 2>/dev/null || echo unknown)"
  [[ "$since" =~ ^[0-9]+$ ]] || since=0
  age=$(( $(date +%s) - since ))
  LOCK_BUSY_PID="$pid"
  LOCK_BUSY_JOB="$job"

  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    # A lock with no timestamp was written before the cap existed. Unknown age is
    # not evidence of a hang, and killing a healthy run in the middle of writing
    # an article is far worse than waiting one cycle.
    if (( since > 0 && age > MAX_RUN_SEC )); then
      echo "$what lock held by $job (pid $pid) for $(( age / 3600 ))h — past the $(( MAX_RUN_SEC / 3600 ))h cap, treating it as hung"
      kill_tree "$pid"
      notify "🧹 Found a hung run: \`$job\` had been holding the $what lock since $(date -r "$since" '+%d.%m. %H:%M') — $(( age / 3600 )) hours. I killed it so $JOB could run, and it may have left something half-done. Log: $LOG"
      rm -rf "$dir"
      lock_take "$dir" && return 0
      return 1
    fi
    return 1
  fi

  echo "taking over a stale $what lock (job $job, pid ${pid:-unknown} is gone)"
  rm -rf "$dir"
  lock_take "$dir" && return 0
  return 1
}

# --- Single instance ----------------------------------------------------------
if ! lock_acquire "$LOCK_DIR" "job"; then
  echo "another $JOB run is active (pid $LOCK_BUSY_PID) — exiting without starting a second one"
  notify "⚠️ Skipped $JOB: a previous run (pid $LOCK_BUSY_PID) is still going. Nothing was started."
  exit 0
fi

# --- Pre-flight ---------------------------------------------------------------
# This is the check that would have caught 2026-08-15 before the week was lost.
if [[ ! -r "$SCRIPT" ]]; then
  echo "target script is not readable: $SCRIPT"
  notify "⚠️ The weekly article job could not start: \`$SCRIPT\` is missing or unreadable.

Nothing ran. The repo has probably moved, or macOS is denying access to its folder. Log: $LOG"
  exit 66
fi

REPO_DIR="$(cd "$(dirname "$SCRIPT")/../.." 2>/dev/null && pwd)"
if [[ -z "$REPO_DIR" || ! -d "$REPO_DIR/.git" ]]; then
  echo "not a git repo above the script: ${REPO_DIR:-<unresolvable>}"
  notify "⚠️ The weekly article job could not start: no git repo above \`$SCRIPT\`.

Nothing ran. Log: $LOG"
  exit 66
fi
echo "repo: $REPO_DIR"

# --- Network ------------------------------------------------------------------
# launchd already handles "the Mac was asleep or off": StartCalendarInterval
# defers the job to the next wake or login. It does NOT handle "the Mac woke up
# without a connection" — every stage of this pipeline needs the network, and so
# does the Telegram message that would report the failure. Offline was therefore
# the one failure mode that stayed silent.
#
# So: wait for a connection rather than failing, and if it stays down, arm a
# one-shot retry instead of losing the run.
NET_WAIT_MIN="${ENVERCETIN_NET_WAIT_MIN:-90}"
RETRY_IN_MIN="${ENVERCETIN_RETRY_IN_MIN:-30}"

# A captive portal answers everything with 200 and a login page, so "the request
# completed" is not the same as "we have the internet". `-f` rejects non-2xx, and
# the body check rejects a portal that returns 200 anyway: /zen serves a short
# plaintext aphorism, never markup. Hotel Wi-Fi you have not clicked through is
# the exact case that would otherwise sail past this and die at the first git call.
# ENVERCETIN_PROBE_URL exists so the tests can drive the offline path against an
# address that always fails, rather than asking someone to pull the Wi-Fi.
online() {
  local body
  body="$(curl -fsS --max-time 8 "${ENVERCETIN_PROBE_URL:-https://api.github.com/zen}" 2>/dev/null)" || return 1
  [[ -n "$body" && "$body" != *"<html"* && "$body" != *"<!DOCTYPE"* && "$body" != *"<HTML"* ]]
}

# Re-arm this exact invocation a little later. Date-pinned and one-shot; the
# guard clears any leftover retry for the job as soon as a run gets going.
arm_retry() {
  local when label plist args at="${1:-}"
  # An absolute epoch when the caller knows exactly when to come back — a usage
  # limit prints the minute it lifts — and a fixed delay when it does not.
  if [[ -n "$at" ]]; then
    when="$(date -r "$at" "+%Y %-m %-d %-H %-M")"
  else
    when="$(date -v "+${RETRY_IN_MIN}M" "+%Y %-m %-d %-H %-M")"
  fi
  set -- $when
  # Unique per arming, so the bootout below can never be aimed at us.
  label="$RETRY_PREFIX-$(date +%Y%m%d%H%M%S)"
  plist="${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}/$label.plist"
  mkdir -p "$(dirname "$plist")"
  args=""
  for a in "${RETRY_ARGV[@]}"; do
    args="$args    <string>$a</string>
"
  done
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$HOME/.local/bin/envercetin-guard</string>
$args  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Month</key><integer>$2</integer>
    <key>Day</key><integer>$3</integer>
    <key>Hour</key><integer>$4</integer>
    <key>Minute</key><integer>$5</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <!-- So the run this job starts can recognise that it IS the retry, and not
         boot out the label it is running under. See the retry-clearing block. -->
    <key>ENVERCETIN_RETRY_OF</key><string>$JOB</string>
  </dict>
  <key>StandardOutPath</key><string>$LOG_DIR/retry-launchd.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/retry-launchd.err.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
PLIST
  if [[ -n "${ENVERCETIN_TEST_NO_LAUNCHCTL:-}" ]]; then
    echo "retry armed for $3.$2. $4:$5 (label $label, not loaded — test)"
    return 0
  fi
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
  launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null
  echo "retry armed for $3.$2. $4:$5 (label $label)"
}

# A run that is actually starting supersedes any retry waiting for this job —
# unless this run IS that retry.
#
# `launchctl bootout` on your own label terminates the process executing the line.
# That is how 2026-08-22 was lost: both retries died right here, three lines before
# the network check, without running, without reporting, and without releasing
# their lock. The offline recovery had therefore never worked at all — every retry
# it armed killed itself the moment it started.
#
# launchd sets XPC_SERVICE_NAME to the running job's own label, and arm_retry also
# stamps ENVERCETIN_RETRY_OF into the plist it writes; either identifies us.
RETRY_AGENTS="${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
clear_pending_retries() {
  local plist label
  shopt -s nullglob
  for plist in "$RETRY_AGENTS/$RETRY_PREFIX.plist" "$RETRY_AGENTS/$RETRY_PREFIX-"*.plist; do
    label="$(basename "$plist" .plist)"
    if [[ "${XPC_SERVICE_NAME:-}" == "$label" ]]; then
      # Deleting the plist is enough, and is the only safe half. The job is
      # one-shot with a StartCalendarInterval already in the past, so it cannot
      # fire again; with the file gone it is not reloaded at next login either.
      rm -f "$plist"
      echo "this run is the retry for $JOB — dropped its plist, kept the process"
    else
      [[ -n "${ENVERCETIN_TEST_NO_LAUNCHCTL:-}" ]] || launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
      rm -f "$plist"
      echo "cleared a pending retry for $JOB ($label)"
    fi
  done
  shopt -u nullglob
}
clear_pending_retries

# --- One job at a time per working tree ---------------------------------------
# Keyed by the physical repo path, so two checkouts of the same project do not
# block each other and a symlinked path cannot slip past as a different repo.
REPO_KEY="$(printf '%s' "$(cd "$REPO_DIR" && pwd -P)" | shasum | cut -c1-12)"
REPO_LOCK="$LOCK_ROOT/repo-$REPO_KEY.lock"

if ! lock_acquire "$REPO_LOCK" "repo"; then
  echo "another article job is working in this repo: $LOCK_BUSY_JOB (pid $LOCK_BUSY_PID) — deferring rather than joining it"
  arm_retry
  notify_unless_retry "⏳ $JOB is waiting: \`$LOCK_BUSY_JOB\` is still working in $REPO_DIR.

Two jobs in one working tree would overwrite each other's article, so I re-armed this one for ${RETRY_IN_MIN} min from now and will keep re-arming. Nothing was lost."
  exit 0
fi
# So run.sh and deploy-scheduled.sh know the lock is already held on their behalf
# and do not refuse to start inside their own guard.
export ENVERCETIN_REPO_LOCK="$REPO_LOCK"

if [[ -z "${ENVERCETIN_SKIP_NET_CHECK:-}" ]] && ! online; then
  echo "offline at start — waiting for up to ${NET_WAIT_MIN} min of awake time"

  # The budget is AWAKE time, not wall-clock. A closed MacBook wakes for a few
  # seconds every ~15 minutes and sleeps again; a wall-clock deadline is spent
  # almost entirely while the process is not running. On 2026-08-22 a 90-minute
  # budget burned from 11:00 to 13:30 and bought perhaps two minutes of runtime,
  # then declared the machine hopeless and gave up.
  #
  # So credit each poll with the time it actually took, capped: an iteration that
  # ran straight through credits its ~30 s, and one that spanned a system sleep
  # credits the same 30 s rather than the quarter hour the clock advanced.
  NET_POLL_SEC="${ENVERCETIN_NET_POLL_SEC:-30}"
  NET_BUDGET_SEC=$(( NET_WAIT_MIN * 60 ))
  # A ceiling so a machine that is awake and permanently offline cannot sit here
  # until next Saturday. Generous, because the budget above is the real limit.
  NET_HARD_DEADLINE=$(( $(date +%s) + ${ENVERCETIN_NET_MAX_HOURS:-12} * 3600 ))
  AWAKE=0

  until online; do
    if (( AWAKE >= NET_BUDGET_SEC )) || (( $(date +%s) >= NET_HARD_DEADLINE )); then
      echo "still offline after $(( AWAKE / 60 )) min awake — arming a retry instead of failing"
      arm_retry
      # Silence here is what made 2026-08-22 invisible: the run ended with exit 0
      # and no message, so a lost Saturday looked exactly like a normal one. The
      # notifier spools this and delivers it as soon as anything gets a network.
      notify_unless_retry "📴 $JOB could not start: the Mac has had no usable connection for $(( AWAKE / 60 )) min of awake time.

Nothing was lost — I re-armed the job for ${RETRY_IN_MIN} min from now and will keep re-arming. Log: $LOG"
      exit 0
    fi
    BEFORE=$(date +%s)
    sleep "$NET_POLL_SEC"
    DELTA=$(( $(date +%s) - BEFORE ))
    (( DELTA > NET_POLL_SEC * 2 )) && DELTA=$NET_POLL_SEC
    AWAKE=$(( AWAKE + DELTA ))
  done
  echo "network came up after $(( AWAKE / 60 )) min awake — continuing"
fi

# --- Stay awake for the run ----------------------------------------------------
# Writing an article takes 20+ minutes of continuous network. Idle sleep in the
# middle of it kills the run. This holds the machine awake for exactly as long as
# the guard lives, and dies with it.
#
# It is a partial defence and worth being honest about: `caffeinate` cannot stop
# CLAMSHELL sleep on battery, which is what actually happened on 2026-08-22. A lid
# closed on battery will still sleep through the whole job. The only real fix for
# that case is to run the schedule somewhere that does not sleep.
if command -v caffeinate >/dev/null 2>&1; then
  caffeinate -i -m -w $$ &
  echo "holding an idle-sleep assertion for the duration of this run"
fi

# Remember whether the ask lock was already held by someone else, so cleanup only
# ever removes a lock this run is responsible for.
ASK_LOCK_PRE_EXISTING=no
[[ -e "$ASK_LOCK" ]] && ASK_LOCK_PRE_EXISTING=yes

# --- Run ----------------------------------------------------------------------
cd "$REPO_DIR" || true
rm -f "$LOG_DIR/reported"
/bin/bash "$SCRIPT" "$@"
RC=$?
echo "--- $JOB exited with $RC"

# --- Cleanup ------------------------------------------------------------------
if [[ "$ASK_LOCK_PRE_EXISTING" == "no" && -e "$ASK_LOCK" ]]; then
  echo "releasing the personal-os ask lock left behind by this run"
  rm -f "$ASK_LOCK"
fi
release_locks

# --- Exit 75: the run asked to be resumed, it did not fail ---------------------
# run.sh exits 75 (EX_TEMPFAIL) when the Claude subscription's usage limit is
# spent, and leaves the minute it lifts in retry-at. Before this existed, that
# exit was a plain 1: the run reported "nothing was written" and the next attempt
# was the following Saturday. 2026-09-09 and 2026-09-16 both died that way, and
# in both cases the limit had lifted within hours.
#
# The counter is what keeps a limit that never lifts from re-arming forever.
LIMIT_ATTEMPTS_FILE="$LOG_DIR/$JOB-limit-attempts"
RETRY_AT_FILE="$LOG_DIR/retry-at"
RETRY_ARGS_FILE="$LOG_DIR/retry-args"
LIMIT_MAX="${ENVERCETIN_LIMIT_MAX_ATTEMPTS:-6}"

if [[ $RC -eq 75 ]]; then
  ATTEMPT=$(( $(cat "$LIMIT_ATTEMPTS_FILE" 2>/dev/null || echo 0) + 1 ))
  if (( ATTEMPT > LIMIT_MAX )); then
    echo "giving up: $LIMIT_MAX deferrals in a row and the limit is still spent"
    rm -f "$LIMIT_ATTEMPTS_FILE" "$RETRY_AT_FILE" "$RETRY_ARGS_FILE"
    clear_pending_retries
    notify "🛑 $JOB has now waited $LIMIT_MAX times for the Claude limit to lift and it is still spent, so I stopped re-arming it.

Nothing was published and nothing was lost. Start it again by hand when there is budget:
$REPO_DIR/scripts/weekly-article/run.sh

Log: $LOG"
    echo "=== guard done $(date) ==="
    exit 1
  fi
  printf '%s' "$ATTEMPT" > "$LIMIT_ATTEMPTS_FILE"

  RETRY_AT="$(cat "$RETRY_AT_FILE" 2>/dev/null || true)"
  [[ "$RETRY_AT" =~ ^[0-9]+$ ]] || RETRY_AT=$(( $(date +%s) + RETRY_IN_MIN * 60 ))
  # A time already gone fires the job the instant it is loaded, straight back
  # into the same spent limit. Never schedule into the past.
  (( RETRY_AT <= $(date +%s) )) && RETRY_AT=$(( $(date +%s) + 300 ))

  # Resume arguments, when the run knows how to carry on rather than start over.
  if [[ -s "$RETRY_ARGS_FILE" ]]; then
    RETRY_ARGV=("$JOB" "$SCRIPT")
    while IFS= read -r resume_arg; do
      [[ -n "$resume_arg" ]] && RETRY_ARGV+=("$resume_arg")
    done < "$RETRY_ARGS_FILE"
  fi

  arm_retry "$RETRY_AT"
  # run.sh has already said what happened and when it will be back. A second
  # message from the guard would turn one wait into two alarms.
  echo "attempt $ATTEMPT of $LIMIT_MAX — deferred, not failed"
  echo "=== guard done $(date) ==="
  exit 0
fi

# A run that got through clears the ledger: otherwise the first limit of the next
# month inherits the last one's exhausted budget and gives up on the first try.
[[ $RC -eq 0 ]] && rm -f "$LIMIT_ATTEMPTS_FILE"

# The scripts report their own handled failures. This catches everything they
# could not: a crash, a kill, an exit path with no message of its own.
#
# "Could not" is the point, and it used to be guesswork: every handled failure
# arrived twice, the run's own account and then this one. On 2026-09-18 Enver got
# "no topics after 2 attempts" and, sixty seconds later, "weekly-article exited
# with code 1" — the same event, reading like two. run.sh now leaves a marker the
# moment it notifies, so this fires only for a run that died without a word.
if [[ $RC -ne 0 ]]; then
  if [[ -f "$LOG_DIR/reported" ]]; then
    echo "$JOB exited $RC and had already reported it — not sending a second message"
  else
    notify "⚠️ $JOB exited with code $RC and said nothing about why. Check whether anything was left half-done. Log: $LOG"
  fi
fi
rm -f "$LOG_DIR/reported"

echo "=== guard done $(date) ==="
exit $RC
