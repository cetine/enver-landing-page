#!/usr/bin/env bash
#
# Tests for what happens when the Claude subscription's usage limit is spent.
#
#   scripts/weekly-article/tests/limit-retry.test.sh
#
# Three Saturdays in a row died here and none of them came back:
#
#   2026-09-09  the writer hit the session limit mid-article
#   2026-09-12  the OAuth login had expired
#   2026-09-16  the proposer hit the session limit, 31 minutes in
#
# The login case genuinely needs a human. The limit case does not: the CLI prints
# the exact minute the limit lifts ("resets 2:20pm (Europe/Copenhagen)"), and the
# pipeline threw that line away, reported "nothing was written", and waited a full
# week for the next Saturday. A run that knows when it may continue and does not
# is the whole bug.
#
# So: a spent limit re-arms the run for just after the reset, and only gives up
# after a cap. These tests drive that end to end — no launchd, because the seam
# under test is the exit code and the armed plist, not the loading of it.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WA="$REPO/scripts/weekly-article"
RUN="$WA/run.sh"
GUARD="$WA/guard.sh"
TMP="$(mktemp -d -t envercetin-limit)"
FIXTURE="$TMP/repo"
BIN="$TMP/bin"
FAKE_OS="$TMP/personal-os"
AGENTS="$TMP/agents"
LOGS="$TMP/logs"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$(printf '%s' "${2:-}" | head -6 | tr '\n' ' ')"; return 0; }

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$BIN" "$FAKE_OS" "$AGENTS" "$LOGS"

# --- Fakes --------------------------------------------------------------------
# Same shape as model.test.sh: the CLI is a script that says what we tell it to.
cat > "$BIN/claude" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" ]]; then
  printf '%s\n' '{"loggedIn": true, "authMethod": "claude.ai", "subscriptionType": "max"}'
  exit 0
fi
prompt=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "-p" ]] && { prompt="$2"; shift 2; continue; }
  shift
done
if [[ "$prompt" == *"ALREADY COVERED"* ]]; then
  echo "propose" >> "$CLAUDE_CALLS"
  if [[ -n "${PROPOSE_SAYS:-}" ]]; then echo "$PROPOSE_SAYS"; exit 1; fi
  printf '[{"label":"A test topic","thesis":"A claim","why_now":"now","can_measure":"a thing"}]\n'
else
  echo "write" >> "$CLAUDE_CALLS"
  if [[ -n "${WRITE_SAYS:-}" ]]; then echo "$WRITE_SAYS"; exit 1; fi
  mkdir -p src/content/writing/en
  printf -- '---\ntitle: "A test topic"\n---\n\nBody.\n' > src/content/writing/en/a-test-topic.mdx
  echo "SLUG: a-test-topic"
fi
FAKE

cat > "$BIN/vercel" <<'FAKE'
#!/usr/bin/env bash
echo "https://envercetin-test-preview.vercel.app"
FAKE

cat > "$FAKE_OS/tg.py" <<'FAKE'
#!/usr/bin/env python3
import sys
if sys.argv[1] == "send":
    print("Sent.")
    sys.exit(0)
print("REPLY: Keep as draft" if "Publish" in " ".join(sys.argv) else "REPLY: A test topic")
FAKE
chmod +x "$BIN/claude" "$BIN/vercel" "$FAKE_OS/tg.py"

build_fixture() {
  rm -rf "$FIXTURE" "$TMP/origin.git"
  git init --bare --quiet "$TMP/origin.git"
  mkdir -p "$FIXTURE/scripts/weekly-article" "$FIXTURE/src/content/writing/en"
  ln -s "$WA/prompts" "$FIXTURE/scripts/weekly-article/prompts"
  ln -s "$WA/lib" "$FIXTURE/scripts/weekly-article/lib"
  git init --quiet "$FIXTURE"
  git -C "$FIXTURE" config user.email "test@example.com"
  git -C "$FIXTURE" config user.name "Test"
  git -C "$FIXTURE" config commit.gpgsign false
  git -C "$FIXTURE" symbolic-ref HEAD refs/heads/main
  echo "old" > "$FIXTURE/src/content/writing/en/already-there.mdx"
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit --quiet -m "chore: base"
  git -C "$FIXTURE" remote add origin "$TMP/origin.git"
  git -C "$FIXTURE" push --quiet -u origin main
}

run_pipeline() {
  build_fixture
  : > "$TMP/claude-calls"
  rm -f "$LOGS/retry-at"
  env PATH="$BIN:$PATH" \
      ENVERCETIN_TEST_SILENT=1 \
      ENVERCETIN_TEST_NO_LAUNCHCTL=1 \
      ENVERCETIN_REPO="$FIXTURE" \
      ENVERCETIN_PERSONAL_OS="$FAKE_OS" \
      ENVERCETIN_VERIFY_CMD=true \
      ENVERCETIN_CLAUDE_BIN="$BIN/claude" \
      ENVERCETIN_VERCEL_BIN="$BIN/vercel" \
      ENVERCETIN_AGENTS_DIR="$AGENTS" \
      ENVERCETIN_LOG_DIR="$LOGS" \
      ENVERCETIN_ASK_FROM_HOUR=0 \
      ENVERCETIN_ASK_UNTIL_HOUR=24 \
      ENVERCETIN_APPROVE_ROUNDS=1 \
      ENVERCETIN_APPROVE_MIN=1 \
      ENVERCETIN_ASK_ROUND_MIN=1 \
      ENVERCETIN_PROPOSE_TIMEOUT_SEC=30 \
      CLAUDE_CALLS="$TMP/claude-calls" \
      "$@" \
      /bin/bash "$RUN" > "$TMP/run.log" 2>&1
  RUN_RC=$?
  rm -f "$LOGS/$(date +%Y-%m-%d)-deferrals" "$LOGS/$(date +%Y-%m-%d)-topics.json"
}

notified() { sed -n '/would notify:/,$p' "$TMP/run.log" | grep -q -- "$1"; }

echo "limit-retry"

# --- 1. The reset time is read out of what the CLI actually printed -------------
# The only source of truth for when the limit lifts is that one line. Parsing it
# wrong is worse than not parsing it: an early retry burns an attempt against a
# limit that is still spent, a late one parks the article for a day.
reset_epoch() {
  env ENVERCETIN_CLAUDE_BIN=/bin/true /bin/bash -c '
    source "$1/lib/with_timeout.sh"
    CLAUDE_BIN=/bin/true
    source "$1/lib/model.sh"
    model_limit_reset_epoch "$2"
  ' _ "$WA" "$1"
}

EPOCH="$(reset_epoch "You've hit your session limit · resets 2:30pm (Europe/Berlin)")"
if [[ -n "$EPOCH" ]]; then
  WHEN="$(TZ=Europe/Berlin date -r "$EPOCH" '+%H:%M')"
  if [[ "$WHEN" == "14:30" ]]; then
    ok "\"resets 2:30pm (Europe/Berlin)\" is read as 14:30 Berlin time"
  else
    bad "\"resets 2:30pm (Europe/Berlin)\" is read as 14:30 Berlin time" "got $WHEN (epoch $EPOCH)"
  fi
else
  bad "\"resets 2:30pm (Europe/Berlin)\" is read as 14:30 Berlin time" "nothing parsed"
fi

if [[ -n "$EPOCH" ]] && (( EPOCH > $(date +%s) )); then
  ok "the reset is always in the future — never a time that has already passed"
else
  bad "the reset is always in the future — never a time that has already passed" "epoch=$EPOCH now=$(date +%s)"
fi

EPOCH_CPH="$(reset_epoch "You've hit your session limit · resets 2:20pm (Europe/Copenhagen)")"
if [[ -n "$EPOCH_CPH" ]] && [[ "$(TZ=Europe/Copenhagen date -r "$EPOCH_CPH" '+%H:%M')" == "14:20" ]]; then
  ok "the 2026-09-16 line parses too, in its own timezone"
else
  bad "the 2026-09-16 line parses too, in its own timezone" "epoch=$EPOCH_CPH"
fi

if [[ -z "$(reset_epoch "Failed to authenticate: OAuth session expired")" ]]; then
  ok "a line that names no time parses to nothing rather than to a guess"
else
  bad "a line that names no time parses to nothing rather than to a guess" "$(reset_epoch 'Failed to authenticate: OAuth session expired')"
fi

# --- 2. A spent limit asks to be resumed, instead of ending the week ------------
run_pipeline PROPOSE_SAYS="You've hit your session limit · resets 2:30pm (Europe/Berlin)"
if [[ $RUN_RC -eq 75 ]]; then
  ok "the proposer's spent limit exits 75 — retry me, do not report me as broken"
else
  bad "the proposer's spent limit exits 75 — retry me, do not report me as broken" "rc=$RUN_RC $(tail -4 "$TMP/run.log")"
fi

if [[ -s "$LOGS/retry-at" ]] && (( $(cat "$LOGS/retry-at") > $(date +%s) )); then
  ok "and it leaves the minute to come back at where the guard will find it"
else
  bad "and it leaves the minute to come back at where the guard will find it" "$(cat "$LOGS/retry-at" 2>/dev/null || echo 'no file')"
fi

if notified "usage limit" && notified "try again automatically"; then
  ok "the message says it will come back by itself, not that the week is lost"
else
  bad "the message says it will come back by itself, not that the week is lost" "$(sed -n '/would notify:/,$p' "$TMP/run.log" | head -5)"
fi

# An expired login is a human's job. It must NOT be retried in a loop.
run_pipeline PROPOSE_SAYS="Failed to authenticate: OAuth session expired and could not be refreshed"
if [[ $RUN_RC -ne 75 ]] && [[ ! -s "$LOGS/retry-at" ]]; then
  ok "an expired login is not re-armed — no retry can fix it and only you can"
else
  bad "an expired login is not re-armed — no retry can fix it and only you can" "rc=$RUN_RC retry-at=$(cat "$LOGS/retry-at" 2>/dev/null)"
fi

# The writer hits the same limit half-way through, which is the 2026-09-09 case.
run_pipeline WRITE_SAYS="You've hit your session limit · resets 2:30pm (Europe/Berlin)"
if [[ $RUN_RC -eq 75 ]] && [[ -s "$LOGS/retry-at" ]]; then
  ok "a limit that stops the writer mid-article is resumable too"
else
  bad "a limit that stops the writer mid-article is resumable too" "rc=$RUN_RC $(tail -4 "$TMP/run.log")"
fi

# --- 3. The guard turns exit 75 into a job that actually fires ------------------
# ENVERCETIN_TEST_NO_LAUNCHCTL keeps launchctl out of it: the plist on disk is
# what is under test here, and guard.test.sh already drives the real loading.
# The guard resolves the repo as dirname(script)/../.. and refuses to run a
# target that is not inside one — so the stand-in lives in the fixture repo.
build_fixture
LIMIT_TARGET="$FIXTURE/scripts/weekly-article/limited.sh"
RESET_AT=$(( $(date +%s) + 3600 ))

guard_run() {
  local rc="$1" attempts_reset="${2:-}"
  cat > "$LIMIT_TARGET" <<EOF
#!/usr/bin/env bash
echo "$RESET_AT" > "$LOGS/retry-at"
exit $rc
EOF
  chmod +x "$LIMIT_TARGET"
  [[ -n "$attempts_reset" ]] && rm -f "$LOGS/limittest-limit-attempts"
  env ENVERCETIN_TEST_SILENT=1 \
      ENVERCETIN_TEST_NO_LAUNCHCTL=1 \
      ENVERCETIN_AGENTS_DIR="$AGENTS" \
      ENVERCETIN_LOG_DIR="$LOGS" \
      ENVERCETIN_SKIP_NET_CHECK=1 \
      /bin/bash "$GUARD" limittest "$LIMIT_TARGET" > "$TMP/guard.log" 2>&1
  GUARD_RC=$?
}

rm -rf "$HOME/Library/Caches/envercetin-guard/limittest.lock"
guard_run 75 reset
PLIST="$AGENTS/com.enver.envercetin.retry-limittest.plist"
if [[ $GUARD_RC -eq 0 ]]; then
  ok "the guard treats exit 75 as deferred work, not as a failed run"
else
  bad "the guard treats exit 75 as deferred work, not as a failed run" "rc=$GUARD_RC $(tail -5 "$TMP/guard.log")"
fi

if [[ -f "$PLIST" ]] \
   && grep -q "<integer>$(date -r "$RESET_AT" +%-H)</integer>" "$PLIST" \
   && grep -q "<integer>$(date -r "$RESET_AT" +%-d)</integer>" "$PLIST"; then
  ok "it arms a one-shot job pinned to the hour the limit lifts"
else
  bad "it arms a one-shot job pinned to the hour the limit lifts" "$(cat "$PLIST" 2>/dev/null | head -20)"
fi

if ! grep -q "exited with code 75" "$TMP/guard.log"; then
  ok "and it does not also send the generic \"something broke\" alarm"
else
  bad "and it does not also send the generic \"something broke\" alarm" "$(grep 'would notify' "$TMP/guard.log")"
fi

# --- 4. A limit that never lifts must not retry until the heat death ------------
rm -f "$LOGS/limittest-limit-attempts"
LAST_RC=0
for i in 1 2 3 4 5 6 7 8; do
  rm -rf "$HOME/Library/Caches/envercetin-guard/limittest.lock"
  guard_run 75
  LAST_RC=$GUARD_RC
  grep -q "giving up" "$TMP/guard.log" && break
done
if grep -q "giving up" "$TMP/guard.log" && [[ ! -f "$PLIST" ]]; then
  ok "after the cap it stops re-arming and leaves no job behind"
else
  bad "after the cap it stops re-arming and leaves no job behind" "attempts=$(cat "$LOGS/limittest-limit-attempts" 2>/dev/null) $(tail -4 "$TMP/guard.log")"
fi

# A run that gets through clears the counter, or next month's first limit
# inherits this month's exhausted budget and gives up immediately.
rm -rf "$HOME/Library/Caches/envercetin-guard/limittest.lock"
cat > "$LIMIT_TARGET" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$LIMIT_TARGET"
env ENVERCETIN_TEST_SILENT=1 ENVERCETIN_TEST_NO_LAUNCHCTL=1 \
    ENVERCETIN_AGENTS_DIR="$AGENTS" ENVERCETIN_LOG_DIR="$LOGS" \
    /bin/bash "$GUARD" limittest "$LIMIT_TARGET" > "$TMP/guard.log" 2>&1
if [[ ! -s "$LOGS/limittest-limit-attempts" ]]; then
  ok "a run that succeeds forgets the attempts that came before it"
else
  bad "a run that succeeds forgets the attempts that came before it" "$(cat "$LOGS/limittest-limit-attempts")"
fi

rm -rf "$HOME/Library/Caches/envercetin-guard/limittest.lock"

printf '  %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
