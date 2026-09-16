#!/usr/bin/env bash
#
# Tests for how the pipeline reaches its model: Fable, through the Claude
# subscription login on this Mac, never through an API key.
#
#   scripts/weekly-article/tests/model.test.sh
#
# 2026-09-09: the writer hit the subscription's session limit, printed one line
# saying so, and the run died at the SLUG assignment. It left an empty
# `article/2026-09-09` branch behind, which the watchdog then reported for a week
# as "written and stuck".
#
# 2026-09-12: the OAuth login had expired. Both propose attempts failed in
# fifteen seconds with "Failed to authenticate", and the only message was a
# generic "no topics after 2 attempts".
#
# Neither case had ever been run on purpose. They are run here.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WA="$REPO/scripts/weekly-article"
RUN="$WA/run.sh"
TMP="$(mktemp -d -t envercetin-model)"
FIXTURE="$TMP/repo"
BIN="$TMP/bin"
FAKE_OS="$TMP/personal-os"
AGENTS="$TMP/agents"
LOGS="$TMP/logs"
STAMP="$(date +%Y-%m-%d)"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$(printf '%s' "${2:-}" | head -6 | tr '\n' ' ')"; return 0; }

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$BIN" "$FAKE_OS" "$AGENTS" "$LOGS"

# --- Fakes --------------------------------------------------------------------
# AUTH_JSON:    what `claude auth status` prints
# PROPOSE_SAYS: if set, the proposer prints this and exits 1
# WRITE_SAYS:   if set, the writer prints this and exits 1, writing nothing
# Every call records its arguments and whether an API key reached it.
cat > "$BIN/claude" <<'FAKE'
#!/usr/bin/env bash
{
  printf 'call:'; printf ' %s' "${@//$'\n'/ }"; printf '\n'
  printf 'api_key=%s base_url=%s\n' "${ANTHROPIC_API_KEY:-unset}" "${ANTHROPIC_BASE_URL:-unset}"
} >> "$CLAUDE_CALLS"
if [[ "${1:-}" == "auth" ]]; then
  logged_in='{"loggedIn": true, "authMethod": "claude.ai", "subscriptionType": "max"}'
  printf '%s\n' "${AUTH_JSON:-$logged_in}"
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
"""Stand-in for personal-os tg.py: every ask picks the first topic, then keeps it as a draft."""
import os, sys
if sys.argv[1] == "send":
    print("Sent.")
    sys.exit(0)
with open(os.environ["TG_ASKS"], "a") as fh:
    fh.write("ask\n")
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

# run_pipeline <extra env assignments...>
# Pins the civil window open so the result does not depend on the time of day.
run_pipeline() {
  build_fixture
  : > "$TMP/claude-calls"
  : > "$TMP/tg-asks"
  env PATH="$BIN:$PATH" \
      ANTHROPIC_API_KEY="sk-ant-must-not-arrive" \
      ANTHROPIC_BASE_URL="http://localhost:1234" \
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
      TG_ASKS="$TMP/tg-asks" \
      "$@" \
      /bin/bash "$RUN" > "$TMP/run.log" 2>&1
  RUN_RC=$?
  rm -f "$LOGS/$STAMP-deferrals" "$LOGS/$STAMP-topics.json"
}

# notified <text> — whether a notification carried <text>. Notifications span
# several lines and only the first one carries the "would notify:" prefix.
notified() { sed -n '/would notify:/,$p' "$TMP/run.log" | grep -q -- "$1"; }

# Model calls only, with the prompt cut out so a failure prints the flags.
model_calls() { grep '^call: -p' "$TMP/claude-calls" | sed 's/^call: -p .* --model /call: --model /' || true; }

echo "model"

# --- 1. The happy path runs on Fable and on the subscription -------------------
run_pipeline
if [[ $RUN_RC -eq 0 ]] && grep -q "kept as a draft" "$TMP/run.log"; then
  ok "a logged-in subscription carries the run through to the approval"
else
  bad "a logged-in subscription carries the run through to the approval" "rc=$RUN_RC $(tail -6 "$TMP/run.log")"
fi

CALLS="$(model_calls)"
if [[ "$(printf '%s\n' "$CALLS" | grep -c . )" -eq 2 ]] \
   && ! printf '%s\n' "$CALLS" | grep -qv -- '--model fable'; then
  ok "both the proposer and the writer run on Fable"
else
  bad "both the proposer and the writer run on Fable" "$CALLS"
fi

if printf '%s\n' "$CALLS" | grep -q -- '--allowed-tools [^ ]*Agent'; then
  ok "the writer may delegate to subagents"
else
  bad "the writer may delegate to subagents" "$CALLS"
fi

if ! grep -q 'api_key=sk-ant' "$TMP/claude-calls" \
   && ! grep -q 'base_url=http' "$TMP/claude-calls"; then
  ok "an API key or foreign backend in the environment never reaches the model"
else
  bad "an API key or foreign backend in the environment never reaches the model" "$(grep 'api_key=' "$TMP/claude-calls" | sort -u)"
fi

# --- 2. Logged out: say so before anyone is asked anything ----------------------
run_pipeline AUTH_JSON='{"loggedIn": false}'
if [[ $RUN_RC -ne 0 ]] && [[ -z "$(model_calls)" ]] && [[ ! -s "$TMP/tg-asks" ]]; then
  ok "a logged-out CLI stops the run before any model call or question"
else
  bad "a logged-out CLI stops the run before any model call or question" "rc=$RUN_RC calls=$(model_calls) asks=$(wc -l < "$TMP/tg-asks")"
fi
if notified "/login"; then
  ok "and the message says how to log back in"
else
  bad "and the message says how to log back in" "$(tail -4 "$TMP/run.log")"
fi

# --- 3. An API-key login is not the subscription -------------------------------
run_pipeline AUTH_JSON='{"loggedIn": true, "authMethod": "api_key"}'
if [[ $RUN_RC -ne 0 ]] && [[ -z "$(model_calls)" ]]; then
  ok "an API-key login is refused — the pipeline runs on the subscription only"
else
  bad "an API-key login is refused — the pipeline runs on the subscription only" "rc=$RUN_RC calls=$(model_calls)"
fi

# --- 4. Expired OAuth mid-flight: one attempt, and the right message ------------
run_pipeline PROPOSE_SAYS="Failed to authenticate: OAuth session expired and could not be refreshed"
if [[ "$(grep -c '^propose$' "$TMP/claude-calls")" -eq 1 ]]; then
  ok "an expired login is not retried — the second attempt cannot succeed"
else
  bad "an expired login is not retried — the second attempt cannot succeed" "proposes=$(grep -c '^propose$' "$TMP/claude-calls")"
fi
if notified "/login" && [[ $RUN_RC -ne 0 ]]; then
  ok "an expired login is reported as a login problem"
else
  bad "an expired login is reported as a login problem" "rc=$RUN_RC $(tail -4 "$TMP/run.log")"
fi

# --- 5. Usage limit on the proposer ---------------------------------------------
run_pipeline PROPOSE_SAYS="You've hit your session limit · resets 2:30pm (Europe/Berlin)"
if [[ "$(grep -c '^propose$' "$TMP/claude-calls")" -eq 1 ]] \
   && notified "usage limit" \
   && grep -q "resets 2:30pm" "$TMP/run.log"; then
  ok "a usage limit is named, with its reset time, and not retried"
else
  bad "a usage limit is named, with its reset time, and not retried" "$(tail -5 "$TMP/run.log")"
fi

# --- 6. Usage limit on the writer: no empty branch left behind -----------------
run_pipeline WRITE_SAYS="You've hit your session limit · resets 2:30pm (Europe/Berlin)"
if [[ $RUN_RC -ne 0 ]] && notified "usage limit"; then
  ok "a writer that hits the usage limit says so"
else
  bad "a writer that hits the usage limit says so" "rc=$RUN_RC $(tail -5 "$TMP/run.log")"
fi
if [[ -z "$(git -C "$FIXTURE" for-each-ref 'refs/heads/article/*')" ]] \
   && [[ "$(git -C "$FIXTURE" symbolic-ref --short HEAD)" == "main" ]]; then
  ok "an empty article branch is removed, so the watchdog does not call it stuck"
else
  bad "an empty article branch is removed, so the watchdog does not call it stuck" "$(git -C "$FIXTURE" branch)"
fi
if notified "run.sh --topics"; then
  ok "and the message says how to write the chosen topic later"
else
  bad "and the message says how to write the chosen topic later" "$(tail -4 "$TMP/run.log")"
fi

echo
echo "model: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
