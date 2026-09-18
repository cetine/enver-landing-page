#!/usr/bin/env bash
#
# Tests for lib/with_timeout.sh.
#
# This Mac has no `timeout` and no `gtimeout`, so the pipeline carries its own.
# The bug it exists to prevent: a hung `claude -p` or a `vercel deploy` waiting
# on a dead socket holds the guard's locks forever, and every following week is
# skipped as "a previous run is still going".
#
# Deliberately NOT built on SIGALRM: alarms do not fire while the Mac sleeps, and
# a lid closed on battery is the normal state of this machine.

set -uo pipefail

# run.sh only asks between 09:00 and 21:00, and a suite whose result depends on
# the hour it is run is not a test. Pinned here rather than in run-all.sh so a
# single suite run by hand behaves the same. Cases that test the window itself
# override these per case.
: "${ENVERCETIN_ASK_FROM_HOUR:=0}"
: "${ENVERCETIN_ASK_UNTIL_HOUR:=24}"
export ENVERCETIN_ASK_FROM_HOUR ENVERCETIN_ASK_UNTIL_HOUR

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/with_timeout.sh
source "$DIR/../lib/with_timeout.sh"

if ! declare -f with_timeout >/dev/null; then
  echo "  FAIL — lib/with_timeout.sh does not define with_timeout" >&2
  exit 1
fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

# Poll fast, so the whole suite stays under a few seconds.
export WITH_TIMEOUT_POLL_SEC=1

echo "with_timeout"

# --- 1. A command that finishes in time is left alone --------------------------
START=$(date +%s)
OUT="$(with_timeout 10 echo hello)"
RC=$?
[[ $RC -eq 0 ]] && ok "a fast command keeps its exit code" \
  || bad "a fast command keeps its exit code" "rc=$RC"
[[ "$OUT" == "hello" ]] && ok "stdout is passed through unchanged" \
  || bad "stdout is passed through unchanged" "got: '$OUT' (job-control noise?)"
(( $(date +%s) - START < 5 )) && ok "a fast command returns immediately" \
  || bad "a fast command returns immediately" "waited the full budget"

# --- 2. A failing command keeps its own exit code ------------------------------
with_timeout 10 bash -c 'exit 3'
[[ $? -eq 3 ]] && ok "a failing command keeps its own exit code" \
  || bad "a failing command keeps its own exit code" "expected 3"

# --- 3. A hanging command is killed, and says so -------------------------------
# 124 is what GNU timeout returns, so callers can tell "it hung" from "it failed".
START=$(date +%s)
with_timeout 2 sleep 300
RC=$?
ELAPSED=$(( $(date +%s) - START ))
[[ $RC -eq 124 ]] && ok "a hung command returns 124, not the signal code" \
  || bad "a hung command returns 124, not the signal code" "rc=$RC"
(( ELAPSED < 30 )) && ok "a hung command is killed near its deadline" \
  || bad "a hung command is killed near its deadline" "took ${ELAPSED}s"

# --- 4. The whole process group dies, not just the command ---------------------
# `claude -p` and `npm run verify` spawn children. Killing only the parent leaves
# them holding the network and the repo — which is the hang, still hanging.
TAG="envercetin-timeout-child-$$"
STARTED="$(mktemp -t envercetin-timeout-test)"
with_timeout 2 bash -c "bash -c 'echo yes > $STARTED; sleep 300 # $TAG' & sleep 300"
RC4=$?
[[ $RC4 -eq 124 ]] && ok "a command that spawns children still reports the timeout" \
  || bad "a command that spawns children still reports the timeout" "rc=$RC4"
[[ -s "$STARTED" ]] && ok "the child really was running before the deadline" \
  || bad "the child really was running before the deadline" "the fixture never started — test 4 proves nothing"
sleep 2
if pgrep -f "$TAG" >/dev/null 2>&1; then
  bad "a killed command takes its children with it" "orphan child ($TAG) still running"
  pkill -f "$TAG" 2>/dev/null
else
  ok "a killed command takes its children with it"
fi
rm -f "$STARTED"

# --- 4b. It must work where it is actually used -------------------------------
# Every real call site is a command substitution or a pipeline. A watcher that
# holds the caller's stdout open makes both of them hang forever after the
# command has already finished — the pipeline's own failure mode, rebuilt inside
# the thing meant to prevent it. This is what it cost to find out once.
START=$(date +%s)
OUT="$(with_timeout 60 bash -c 'echo first; echo second' | tail -1)"
ELAPSED=$(( $(date +%s) - START ))
[[ "$OUT" == "second" ]] && ok "it works inside a pipeline" \
  || bad "it works inside a pipeline" "got '$OUT'"
(( ELAPSED < 15 )) && ok "a pipeline returns when the command does, not when the budget runs out" \
  || bad "a pipeline returns when the command does, not when the budget runs out" "took ${ELAPSED}s of a 60s budget"

# --- 4b. A survivor must not hold the caller's pipe open ------------------------
# 2026-09-18: `claude -p` was still running SEVEN AND A HALF HOURS into a step
# whose ceiling is thirty minutes, reparented to pid 1, while run.sh sat in
# `PROPOSE_OUT="$(with_timeout ...)"` waiting for it. The deadline had nothing to
# do with it: a command substitution ends when the PIPE closes, not when the
# child exits, and any grandchild that outlives the child keeps the write end
# open. The timeout can fire perfectly and the caller still never returns.
#
# So: when the command is done, whatever it left behind in its process group goes
# with it. This case runs in the background against a wall-clock deadline,
# because a regression here does not fail — it hangs, and would take the whole
# suite with it.
LEAK_OUT="$(mktemp -t envercetin-timeout-leak)"
(
  # The inner bash exits at once; the subshell it backgrounded inherits stdout
  # and lives on. That is the shape of `claude -p` spawning a child and dying.
  RESULT="$(with_timeout 30 bash -c '( sleep 45 ) & echo done; exit 0')"
  printf '%s' "$RESULT" > "$LEAK_OUT"
) & LEAK_PID=$!

LEAK_WAITED=0
while (( LEAK_WAITED < 15 )) && kill -0 "$LEAK_PID" 2>/dev/null; do
  sleep 1
  LEAK_WAITED=$(( LEAK_WAITED + 1 ))
done

if kill -0 "$LEAK_PID" 2>/dev/null; then
  kill -KILL "$LEAK_PID" 2>/dev/null
  bad "a survivor of the command does not hold the caller's pipe open" \
      "still blocked after ${LEAK_WAITED}s — the orphan is holding stdout, exactly as on 18.09."
else
  if [[ "$(cat "$LEAK_OUT" 2>/dev/null)" == "done" ]]; then
    ok "a survivor of the command does not hold the caller's pipe open"
  else
    bad "a survivor of the command does not hold the caller's pipe open" \
        "returned, but the output was '$(cat "$LEAK_OUT" 2>/dev/null)' rather than 'done'"
  fi
fi
rm -f "$LEAK_OUT"

# --- 5. Timing out must not leave the caller's shell in job-control mode --------
# with_timeout turns on `set -m` to get a process group. Leaving it on changes how
# every later background job in run.sh behaves.
case "$-" in
  *m*) bad "the caller's job-control setting is restored" "set -m leaked" ;;
  *)   ok "the caller's job-control setting is restored" ;;
esac

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
