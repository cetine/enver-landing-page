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
