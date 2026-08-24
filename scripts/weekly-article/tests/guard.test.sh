#!/usr/bin/env bash
#
# Tests for guard.sh — the launchd-facing behaviour that unit tests cannot reach.
#
#   scripts/weekly-article/tests/guard.test.sh
#
# These drive the guard through REAL launchd jobs, because the bug they exist to
# catch only exists under launchd: on 2026-08-22 the guard boot-ed out its own
# label and killed the process executing the line, so every offline retry died in
# silence and the week was lost. Nothing short of an actual launchd job with the
# right label reproduces that.
#
# Every probe job is labelled com.enver.envercetin.retry-guardtest-* and is booted
# out and deleted in the EXIT trap, so a failed run cannot leave a job loaded.
#
# Run by install.sh, which is what you run after editing guard.sh — the gate sits
# where the regression would be introduced.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GUARD="$REPO/scripts/weekly-article/guard.sh"
UID_NUM="$(id -u)"
AGENTS="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
CACHE="$HOME/Library/Caches/envercetin-guard"

# The guard resolves the repo as `dirname <script>/../..`, so the target it runs
# must sit directly in scripts/weekly-article/. Written at setup, removed at
# teardown — the repo carries no fixture of its own.
TARGET="$REPO/scripts/weekly-article/.test-target.sh"

PASS=0
FAIL=0
LABELS=()
JOBS=()

cleanup() {
  rm -f "$TARGET"
  local l
  for l in ${LABELS+"${LABELS[@]}"}; do
    launchctl bootout "gui/$UID_NUM/$l" 2>/dev/null
    rm -f "$AGENTS/$l.plist"
  done
  for l in ${JOBS+"${JOBS[@]}"}; do
    rm -rf "$CACHE/$l.lock"
  done
}
trap cleanup EXIT

ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

cat > "$TARGET" <<'EOF'
#!/usr/bin/env bash
echo "test-target ran with args: $*"
exit 0
EOF
chmod +x "$TARGET"

# Bootstrap a one-shot job under `label` that runs the guard with `job`, kick it,
# and block until the guard has actually finished.
#
# Waiting on `launchctl print ... state = running` is not enough: these jobs last
# under a second, so the poll routinely misses the window entirely and returns
# while the guard is still starting. The next case then launches on top of it and
# the two runs race over the same fixture. Wait for the guard's own output to stop
# growing instead — that is the thing under test, and it cannot be missed.
run_guard_as_job() {
  local label="$1" job="$2"
  local plist="$AGENTS/$label.plist"
  local EXTRA_ENV="${EXTRA_ENV:-}"
  GUARD_LOG="$LOG_DIR/test-$label.out.log"
  LABELS+=("$label")
  JOBS+=("$job")
  rm -f "$GUARD_LOG"
  rm -rf "$CACHE/$job.lock"

  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$GUARD</string>
    <string>$job</string>
    <string>$TARGET</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
    <key>ENVERCETIN_TEST_SILENT</key><string>1</string>
$EXTRA_ENV  </dict>
  <key>StandardOutPath</key><string>$GUARD_LOG</string>
  <key>StandardErrorPath</key><string>$GUARD_LOG</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
EOF
  plutil -lint "$plist" >/dev/null || { bad "invalid plist for $label"; return 1; }
  [[ -r "$TARGET" ]] || { bad "fixture vanished before $label"; return 1; }

  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null
  launchctl bootstrap "gui/$UID_NUM" "$plist" 2>/dev/null || { bad "could not bootstrap $label"; return 1; }
  launchctl kickstart "gui/$UID_NUM/$label" >/dev/null 2>&1

  local size=-1 prev=-2 quiet=0 waited=0
  while (( waited < 120 )); do
    # 2>/dev/null cannot silence a redirection failure — the shell reports that
    # itself, before wc runs. Check the file exists instead.
    size=0
    [[ -f "$GUARD_LOG" ]] && size="$(wc -c < "$GUARD_LOG")"
    if [[ "$size" == "$prev" && "$size" != "0" ]]; then
      quiet=$((quiet+1))
      (( quiet >= 3 )) && return 0
    else
      quiet=0
    fi
    prev="$size"
    sleep 1; waited=$((waited+1))
  done
  bad "$label never produced output"
  return 1
}

echo "guard.sh — launchd behaviour"

# --- 1. A retry run must survive clearing its own pending retry ----------------
# The 2026-08-22 bug. The guard clears a pending retry for the job it is about to
# run. When the guard IS that retry, the label it boots out is its own, and
# `launchctl bootout` kills the process executing that line. Before the fix the
# log stops after "repo:" and nothing else happens: no network check, no run, no
# Telegram, not even lock cleanup.
JOB=guardtest-self
RETRY_LABEL="com.enver.envercetin.retry-$JOB"
run_guard_as_job "$RETRY_LABEL" "$JOB"
LOG="$GUARD_LOG"

grep -q "test-target ran with args" "$LOG" 2>/dev/null \
  && ok "a retry run reaches its target instead of booting itself out" \
  || bad "a retry run reaches its target instead of booting itself out" \
         "guard died early. Last line: $(tail -1 "$LOG" 2>/dev/null || echo '<no log>')"

grep -q -- "--- $JOB exited with 0" "$LOG" 2>/dev/null \
  && ok "a retry run reports its exit code" \
  || bad "a retry run reports its exit code" "no '--- $JOB exited with' line"

[[ ! -f "$AGENTS/$RETRY_LABEL.plist" ]] \
  && ok "a retry run deletes its own one-shot plist" \
  || bad "a retry run deletes its own one-shot plist" "$AGENTS/$RETRY_LABEL.plist still exists"

[[ ! -d "$CACHE/$JOB.lock" ]] \
  && ok "a retry run releases its lock" \
  || bad "a retry run releases its lock" "stale lock at $CACHE/$JOB.lock"

# --- 2. A normal run must still cancel a foreign pending retry -----------------
# The fix must not go too far. A scheduled run that finds a retry waiting for the
# same job has to cancel it, or the retry fires afterwards and does the work twice.
JOB2=guardtest-foreign
RETRY_LABEL2="com.enver.envercetin.retry-$JOB2"
cat > "$AGENTS/$RETRY_LABEL2.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$RETRY_LABEL2</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>-c</string><string>true</string></array>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
EOF
LABELS+=("$RETRY_LABEL2")
launchctl bootstrap "gui/$UID_NUM" "$AGENTS/$RETRY_LABEL2.plist" 2>/dev/null

run_guard_as_job "com.enver.envercetin.retry-guardtest-plain" "$JOB2"
LOG2="$GUARD_LOG"

[[ ! -f "$AGENTS/$RETRY_LABEL2.plist" ]] \
  && ok "a normal run still cancels a pending retry for the same job" \
  || bad "a normal run still cancels a pending retry for the same job" "$AGENTS/$RETRY_LABEL2.plist survived"

grep -q "test-target ran with args" "$LOG2" 2>/dev/null \
  && ok "a normal run reaches its target" \
  || bad "a normal run reaches its target" "last line: $(tail -1 "$LOG2" 2>/dev/null || echo '<no log>')"

# --- 3. The offline path must arm a retry AND say so --------------------------
# 2026-08-22 ended here twice: the run gave up, armed a retry and exited 0 without
# a word, so a lost Saturday was indistinguishable from a normal one. Drive the
# probe at an address that cannot resolve, with a zero-minute budget, so the
# give-up branch runs immediately.
JOB3=guardtest-offline
RETRY_LABEL3="com.enver.envercetin.retry-$JOB3"
rm -f "$AGENTS/$RETRY_LABEL3.plist"
LABELS+=("$RETRY_LABEL3")
EXTRA_ENV="    <key>ENVERCETIN_PROBE_URL</key><string>http://127.0.0.1:9/offline-probe</string>
    <key>ENVERCETIN_NET_WAIT_MIN</key><string>0</string>
    <key>ENVERCETIN_NET_POLL_SEC</key><string>1</string>
    <key>ENVERCETIN_RETRY_IN_MIN</key><string>45</string>
"
run_guard_as_job "com.enver.envercetin.retry-guardtest-offrun" "$JOB3"
LOG3="$GUARD_LOG"
EXTRA_ENV=""

grep -q "arming a retry instead of failing" "$LOG3" 2>/dev/null \
  && ok "an offline run arms a retry rather than losing the week" \
  || bad "an offline run arms a retry rather than losing the week" "last line: $(tail -1 "$LOG3" 2>/dev/null)"

grep -q "would notify: 📴" "$LOG3" 2>/dev/null \
  && ok "an offline run tells you it could not start" \
  || bad "an offline run tells you it could not start" "no notification on the give-up path"

grep -q "min awake" "$LOG3" 2>/dev/null \
  && ok "the network budget is counted in awake time, not wall-clock" \
  || bad "the network budget is counted in awake time, not wall-clock" "no 'min awake' in the log"

if [[ -f "$AGENTS/$RETRY_LABEL3.plist" ]]; then
  ok "an offline run leaves a retry plist behind"
  plutil -lint "$AGENTS/$RETRY_LABEL3.plist" >/dev/null 2>&1 \
    && ok "the armed retry plist is valid XML" \
    || bad "the armed retry plist is valid XML" "plutil rejected it — check argv escaping"
  grep -q "ENVERCETIN_RETRY_OF" "$AGENTS/$RETRY_LABEL3.plist" \
    && ok "the armed retry stamps itself so it will not boot itself out" \
    || bad "the armed retry stamps itself so it will not boot itself out" "no ENVERCETIN_RETRY_OF in the plist"
else
  bad "an offline run leaves a retry plist behind" "$AGENTS/$RETRY_LABEL3.plist missing"
  bad "the armed retry plist is valid XML" "no plist to check"
  bad "the armed retry stamps itself so it will not boot itself out" "no plist to check"
fi

[[ ! -d "$CACHE/$JOB3.lock" ]] \
  && ok "an offline run releases its lock before exiting" \
  || bad "an offline run releases its lock before exiting" "stale lock at $CACHE/$JOB3.lock"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
