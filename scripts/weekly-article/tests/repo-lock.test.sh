#!/usr/bin/env bash
#
# Tests for the guard's REPO lock and its hung-run sweeper.
#
# The guard used to lock per JOB. Two different jobs — the Saturday writing run
# and a publish job that launchd deferred to the next wake — therefore had every
# right to be inside the same working tree at the same moment: `git checkout main`
# against a half-finished article, `git reset --hard` against a fresh commit.
# Nothing in the pipeline noticed, and the loser was whichever article existed.
#
# The second half is the sweeper. A run that hangs holds its locks forever, and
# from then on every week is skipped with "a previous run is still going". It is
# deliberately NOT a background daemon: this MacBook lives with its lid closed,
# and a sweeper would sleep along with everything else. The lock carries its age,
# and the next run to arrive is what clears it.
#
# These drive guard.sh directly. Nothing here needs launchd — unlike guard.test.sh,
# which does, because the bug it covers only exists under launchd.

set -uo pipefail

# run.sh only asks between 09:00 and 21:00, and a suite whose result depends on
# the hour it is run is not a test. Pinned here rather than in run-all.sh so a
# single suite run by hand behaves the same. Cases that test the window itself
# override these per case.
: "${ENVERCETIN_ASK_FROM_HOUR:=0}"
: "${ENVERCETIN_ASK_UNTIL_HOUR:=24}"
export ENVERCETIN_ASK_FROM_HOUR ENVERCETIN_ASK_UNTIL_HOUR

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GUARD="$REPO/scripts/weekly-article/guard.sh"
LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
AGENTS="$HOME/Library/LaunchAgents"
UID_NUM="$(id -u)"

TMP="$(mktemp -d -t envercetin-repolock)"
FAKE_REPO="$TMP/repo"
TARGET="$FAKE_REPO/scripts/weekly-article/target.sh"
RAN="$TMP/target-ran"
PROBE="$TMP/zen"          # a file:// probe, so the tests do not need a network
HOLDERS=()
LABELS=()

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

cleanup() {
  local p l
  for p in ${HOLDERS+"${HOLDERS[@]}"}; do kill -KILL "$p" 2>/dev/null; done
  for l in ${LABELS+"${LABELS[@]}"}; do
    launchctl bootout "gui/$UID_NUM/$l" 2>/dev/null
    rm -f "$AGENTS/$l.plist"
  done
  rm -rf "$TMP" "$LOCK_ROOT"/repolocktest*.lock
  rm -rf "$LOCK_ROOT/repo-${REPO_KEY:-unset}.lock" 2>/dev/null
}
trap cleanup EXIT

mkdir -p "$FAKE_REPO/scripts/weekly-article"
git -C "$FAKE_REPO" init --quiet
printf 'be careful\n' > "$PROBE"
cat > "$TARGET" <<EOF
#!/usr/bin/env bash
echo ran > "$RAN"
exit 0
EOF
chmod +x "$TARGET"

# The guard keys the repo lock by the resolved repo path. The tests need the same
# key to plant a holder, so the convention is asserted here too: if the guard ever
# changes how it names the lock, these tests must be told.
REPO_KEY="$(printf '%s' "$(cd "$FAKE_REPO" && pwd -P)" | shasum | cut -c1-12)"
REPO_LOCK="$LOCK_ROOT/repo-$REPO_KEY.lock"

# Start a process that is its own process-group leader, exactly as launchd starts
# the guard — so a sweeper that kills the group cannot reach anything else.
start_holder() {
  # >/dev/null matters: without it the background process inherits the pipe of
  # the command substitution around this function, and the caller waits for a
  # `sleep 600` to finish before it sees the pid.
  set -m
  sleep 600 >/dev/null 2>&1 &
  local pid=$!
  set +m
  HOLDERS+=("$pid")
  printf '%s' "$pid"
}

# Plant a repo lock as if another guard run held it. `since` is what the sweeper
# reads to decide between "busy" and "hung".
plant_repo_lock() {
  local pid="$1" since="$2" job="${3:-repolocktest-other}"
  rm -rf "$REPO_LOCK"
  mkdir -p "$REPO_LOCK"
  printf '%s' "$pid" > "$REPO_LOCK/pid"
  printf '%s' "$since" > "$REPO_LOCK/since"
  printf '%s' "$job" > "$REPO_LOCK/job"
}

run_guard() {
  local job="$1"; shift
  LABELS+=("com.enver.envercetin.retry-$job")
  rm -f "$RAN"
  rm -rf "$LOCK_ROOT/$job.lock"
  env ENVERCETIN_TEST_SILENT=1 \
      ENVERCETIN_PROBE_URL="file://$PROBE" \
      ENVERCETIN_RETRY_IN_MIN=30 \
      "$@" \
      /bin/bash "$GUARD" "$job" "$TARGET" > "$TMP/guard.log" 2>&1
  GUARD_RC=$?
  GUARD_LOG="$TMP/guard.log"
}

echo "guard.sh — repo lock and sweeper"

# --- 1. A free repo runs normally, and gives the lock back ---------------------
JOB=repolocktest-clean
rm -rf "$REPO_LOCK"
run_guard "$JOB"
[[ -f "$RAN" ]] && ok "a run with a free repo reaches its target" \
  || bad "a run with a free repo reaches its target" "last line: $(tail -1 "$GUARD_LOG")"
[[ ! -d "$REPO_LOCK" ]] && ok "a finished run releases the repo lock" \
  || bad "a finished run releases the repo lock" "$REPO_LOCK survived"
[[ ! -d "$LOCK_ROOT/$JOB.lock" ]] && ok "a finished run releases its job lock" \
  || bad "a finished run releases its job lock" "stale job lock"

# --- 2. A busy repo is not entered — and the run is not lost -------------------
# The important half is the second one. Refusing to start is worthless if the
# publish it refused is then simply forgotten.
JOB=repolocktest-busy
HOLDER="$(start_holder)"
plant_repo_lock "$HOLDER" "$(date +%s)" "repolocktest-writer"
run_guard "$JOB"

[[ ! -f "$RAN" ]] && ok "a second job does not enter a repo another job is working in" \
  || bad "a second job does not enter a repo another job is working in" "the target ran anyway"
grep -q "another article job is working in this repo" "$GUARD_LOG" \
  && ok "the log names the job that has the repo" \
  || bad "the log names the job that has the repo" "last line: $(tail -1 "$GUARD_LOG")"
# One label per arming — a retry that re-armed under its own name boot-ed itself
# out mid-arm (guard.test.sh case 4), so the name now carries a timestamp.
compgen -G "$AGENTS/com.enver.envercetin.retry-$JOB-*.plist" > /dev/null \
  && ok "a run that found the repo busy arms a retry instead of losing the work" \
  || bad "a run that found the repo busy arms a retry instead of losing the work" "no retry plist"
grep -q "would notify:" "$GUARD_LOG" \
  && ok "it tells you the run was deferred" \
  || bad "it tells you the run was deferred" "no notification"
[[ -d "$REPO_LOCK" && "$(cat "$REPO_LOCK/pid")" == "$HOLDER" ]] \
  && ok "it leaves the other run's lock alone" \
  || bad "it leaves the other run's lock alone" "the holder's lock was taken or removed"
[[ ! -d "$LOCK_ROOT/$JOB.lock" ]] \
  && ok "it releases its own job lock on the way out" \
  || bad "it releases its own job lock on the way out" "stale job lock at $LOCK_ROOT/$JOB.lock"
kill -KILL "$HOLDER" 2>/dev/null

# --- 3. A repo lock whose holder is gone is just taken over --------------------
JOB=repolocktest-stale
plant_repo_lock "999999" "$(date +%s)" "repolocktest-dead"
run_guard "$JOB"
[[ -f "$RAN" ]] && ok "a lock whose holder is dead does not block next week" \
  || bad "a lock whose holder is dead does not block next week" "the target never ran"

# --- 4. A hung run is swept, killed, and reported ------------------------------
# The failure this prevents: one hang, and every following Saturday is skipped
# with "a previous run is still going" — forever, in silence.
JOB=repolocktest-hung
HOLDER="$(start_holder)"
plant_repo_lock "$HOLDER" "$(( $(date +%s) - 40 * 3600 ))" "repolocktest-zombie"
run_guard "$JOB"

[[ -f "$RAN" ]] && ok "a run hung past the cap does not block the next one" \
  || bad "a run hung past the cap does not block the next one" "the target never ran"
sleep 1
kill -0 "$HOLDER" 2>/dev/null \
  && { bad "the hung run is actually killed, not just ignored" "pid $HOLDER survived"; kill -KILL "$HOLDER" 2>/dev/null; } \
  || ok "the hung run is actually killed, not just ignored"
grep -q "would notify:" "$GUARD_LOG" && grep -qi "hung\|stuck\|hing" "$GUARD_LOG" \
  && ok "killing a hung run is reported, never silent" \
  || bad "killing a hung run is reported, never silent" "no notification about the sweep"

# --- 5. A lock with no age is treated as busy, not as hung --------------------
# Locks written before the sweeper existed have no `since` file. Guessing "old"
# there would kill a healthy run mid-article.
JOB=repolocktest-ageless
HOLDER="$(start_holder)"
rm -rf "$REPO_LOCK"; mkdir -p "$REPO_LOCK"
printf '%s' "$HOLDER" > "$REPO_LOCK/pid"
run_guard "$JOB"
kill -0 "$HOLDER" 2>/dev/null \
  && ok "a lock of unknown age is left alone rather than swept" \
  || bad "a lock of unknown age is left alone rather than swept" "an ageless lock got its holder killed"
[[ ! -f "$RAN" ]] && ok "a lock of unknown age still blocks" \
  || bad "a lock of unknown age still blocks" "the target ran"
kill -KILL "$HOLDER" 2>/dev/null
rm -rf "$REPO_LOCK"

# --- 6. The early exits must not leak locks -----------------------------------
# Every `exit` in the guard used to need its own `rm -rf`, and the pre-flight
# paths did not have one: an unreadable target left a lock behind that blocked
# every later run.
JOB=repolocktest-noscript
rm -rf "$LOCK_ROOT/$JOB.lock" "$REPO_LOCK"
env ENVERCETIN_TEST_SILENT=1 ENVERCETIN_PROBE_URL="file://$PROBE" \
    /bin/bash "$GUARD" "$JOB" "$TMP/does-not-exist.sh" > "$TMP/guard.log" 2>&1
[[ ! -d "$LOCK_ROOT/$JOB.lock" ]] \
  && ok "an unreadable target does not leave a lock behind" \
  || bad "an unreadable target does not leave a lock behind" "stale lock at $LOCK_ROOT/$JOB.lock"

# --- 7. The same lock, honoured by a hand-run script ---------------------------
# The watchdog's own advice is "run deploy-scheduled.sh <branch>". A human doing
# that at 20:58 on a Friday must not walk into the working tree at the same
# moment as the job scheduled for 21:00 — and must not be blocked by the guard
# that is running that very script on their behalf either.
LIB="$REPO/scripts/weekly-article/lib/repo_lock.sh"
if [[ ! -f "$LIB" ]]; then
  bad "lib/repo_lock.sh exists" "no $LIB"
  bad "a hand-run script takes the same lock the guard takes" "no lib"
  bad "a hand-run script refuses to enter a busy repo" "no lib"
  bad "a script running under its own guard is not blocked by it" "no lib"
  bad "a hand-run script gives the lock back when it exits" "no lib"
else
  ok "lib/repo_lock.sh exists"
  rm -rf "$REPO_LOCK"

  # Same key as the guard computes — one convention, or the lock protects nothing.
  ( source "$LIB"; repo_lock_hold "$FAKE_REPO" "manual-test" >/dev/null; sleep 3 ) &
  LIBHOLDER=$!
  HOLDERS+=("$LIBHOLDER")
  sleep 1
  [[ -d "$REPO_LOCK" ]] && ok "a hand-run script takes the same lock the guard takes" \
    || bad "a hand-run script takes the same lock the guard takes" "nothing at $REPO_LOCK"

  # A second hand-run script, while the first still holds it.
  ( source "$LIB"; repo_lock_hold "$FAKE_REPO" "manual-test-2" >/dev/null 2>&1 ) 
  [[ $? -ne 0 ]] && ok "a hand-run script refuses to enter a busy repo" \
    || bad "a hand-run script refuses to enter a busy repo" "it took the lock anyway"

  # Under the guard: the lock is already held FOR us, and we must proceed.
  ( export ENVERCETIN_REPO_LOCK="$REPO_LOCK"; source "$LIB"; repo_lock_hold "$FAKE_REPO" "under-guard" >/dev/null 2>&1 )
  [[ $? -eq 0 ]] && ok "a script running under its own guard is not blocked by it" \
    || bad "a script running under its own guard is not blocked by it" "it refused its own guard's lock"

  wait "$LIBHOLDER" 2>/dev/null
  [[ ! -d "$REPO_LOCK" ]] && ok "a hand-run script gives the lock back when it exits" \
    || bad "a hand-run script gives the lock back when it exits" "$REPO_LOCK survived its holder"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
