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
shift 2

PERSONAL_OS="$HOME/Projects/personal-os"
TG="$PERSONAL_OS/tg.py"
ASK_LOCK="$PERSONAL_OS/data/ask-active.lock"
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
LOG="$LOG_DIR/guard-$JOB-$(date +%Y-%m-%d-%H%M).log"
LOCK_DIR="$HOME/Library/Caches/envercetin-guard/$JOB.lock"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

mkdir -p "$LOG_DIR" "$(dirname "$LOCK_DIR")"
exec > >(tee -a "$LOG") 2>&1
echo "=== guard: $JOB — $(date) ==="
echo "target: $SCRIPT ${*:-}"

# --- Reporting ----------------------------------------------------------------
# Telegram is the primary channel. A macOS notification is the fallback for the
# case where Telegram itself is what is broken — otherwise a failure to report a
# failure would be just as silent as the bug this guard exists to kill.
notify() {
  local msg="$1"
  if [[ -x "$TG" || -f "$TG" ]]; then
    (cd "$PERSONAL_OS" && python3 "$TG" send "$msg") && return 0
  fi
  echo "TELEGRAM FAILED, falling back to a desktop notification: $msg"
  osascript -e "display notification \"envercetin: $JOB failed. See $LOG\" with title \"Weekly article\"" 2>/dev/null
  return 0
}

# --- Single instance ----------------------------------------------------------
# mkdir is atomic. A lock whose PID is gone is stale — a previous run that was
# killed — and gets taken over rather than blocking every future week.
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  STALE_PID="$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")"
  if [[ -n "$STALE_PID" ]] && kill -0 "$STALE_PID" 2>/dev/null; then
    echo "another $JOB run is active (pid $STALE_PID) — exiting without starting a second one"
    notify "⚠️ Skipped $JOB: a previous run (pid $STALE_PID) is still going. Nothing was started."
    exit 0
  fi
  echo "taking over a stale lock (pid ${STALE_PID:-unknown} is gone)"
  rm -rf "$LOCK_DIR"
  mkdir -p "$LOCK_DIR"
fi
echo $$ > "$LOCK_DIR/pid"

# --- Pre-flight ---------------------------------------------------------------
# This is the check that would have caught 2026-08-15 before the week was lost.
if [[ ! -r "$SCRIPT" ]]; then
  echo "target script is not readable: $SCRIPT"
  notify "⚠️ The weekly article job could not start: \`$SCRIPT\` is missing or unreadable.

Nothing ran. The repo has probably moved, or macOS is denying access to its folder. Log: $LOG"
  rm -rf "$LOCK_DIR"
  exit 66
fi

REPO_DIR="$(cd "$(dirname "$SCRIPT")/../.." 2>/dev/null && pwd)"
if [[ -z "$REPO_DIR" || ! -d "$REPO_DIR/.git" ]]; then
  echo "not a git repo above the script: ${REPO_DIR:-<unresolvable>}"
  notify "⚠️ The weekly article job could not start: no git repo above \`$SCRIPT\`.

Nothing ran. Log: $LOG"
  rm -rf "$LOCK_DIR"
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

online() { curl -sS --max-time 8 -o /dev/null https://api.github.com/zen 2>/dev/null; }

# Re-arm this exact invocation a little later. Date-pinned and one-shot; the
# guard clears any leftover retry for the job as soon as a run gets going.
arm_retry() {
  local when label plist args
  when="$(date -v "+${RETRY_IN_MIN}M" "+%Y %m %d %H %M")"
  set -- $when
  label="com.enver.envercetin.retry-$JOB"
  plist="$HOME/Library/LaunchAgents/$label.plist"
  args=""
  for a in "${ORIG_ARGV[@]}"; do
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
  </dict>
  <key>StandardOutPath</key><string>$LOG_DIR/retry-launchd.out.log</string>
  <key>StandardErrorPath</key><string>$LOG_DIR/retry-launchd.err.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
PLIST
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
  launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null
  echo "retry armed for $4:$5 (label $label)"
}

# A run that is actually starting supersedes any retry waiting for this job.
RETRY_LABEL="com.enver.envercetin.retry-$JOB"
if [[ -f "$HOME/Library/LaunchAgents/$RETRY_LABEL.plist" ]]; then
  launchctl bootout "gui/$(id -u)/$RETRY_LABEL" 2>/dev/null
  rm -f "$HOME/Library/LaunchAgents/$RETRY_LABEL.plist"
  echo "cleared a pending retry for $JOB"
fi

if ! online; then
  echo "offline at start — waiting up to ${NET_WAIT_MIN} min for a connection"
  NET_DEADLINE=$(( $(date +%s) + NET_WAIT_MIN * 60 ))
  until online; do
    if (( $(date +%s) >= NET_DEADLINE )); then
      echo "still offline after ${NET_WAIT_MIN} min — arming a retry instead of failing"
      arm_retry
      rm -rf "$LOCK_DIR"
      exit 0
    fi
    sleep 30
  done
  echo "network came up — continuing"
fi

# Remember whether the ask lock was already held by someone else, so cleanup only
# ever removes a lock this run is responsible for.
ASK_LOCK_PRE_EXISTING=no
[[ -e "$ASK_LOCK" ]] && ASK_LOCK_PRE_EXISTING=yes

# --- Run ----------------------------------------------------------------------
cd "$REPO_DIR" || true
/bin/bash "$SCRIPT" "$@"
RC=$?
echo "--- $JOB exited with $RC"

# --- Cleanup ------------------------------------------------------------------
if [[ "$ASK_LOCK_PRE_EXISTING" == "no" && -e "$ASK_LOCK" ]]; then
  echo "releasing the personal-os ask lock left behind by this run"
  rm -f "$ASK_LOCK"
fi
rm -rf "$LOCK_DIR"

# The scripts report their own handled failures. This catches everything they
# could not: a crash, a kill, an exit path with no message of its own.
if [[ $RC -ne 0 ]]; then
  notify "⚠️ $JOB exited with code $RC. Check whether anything was left half-done. Log: $LOG"
fi

echo "=== guard done $(date) ==="
exit $RC
