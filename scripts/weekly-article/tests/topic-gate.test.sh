#!/usr/bin/env bash
#
# Tests for the topic gate: the step that lost two weeks in a row.
#
#   scripts/weekly-article/tests/topic-gate.test.sh
#
# 2026-08-29: the proposer finished at 21:39, so the three reminders went out at
# 21:39, 00:09 and 02:39, nobody was awake, and at 05:10 the run announced that
# no topic had been chosen and threw four researched topics away. Along the way
# each unanswered round fired the ERR trap — `set +e` does not suppress it — so
# Enver also got three "⚠️ Weekly article failed at line 200" messages for a run
# that had not failed.
#
# 2026-09-05: `claude -p` hung for thirty fully awake minutes without reaching
# its first model turn, was killed at the ceiling, and the single attempt was the
# whole week.
#
# None of those branches had ever been executed outside a real Saturday. They are
# executed here.

set -uo pipefail

# run.sh only asks between 09:00 and 21:00, and a suite whose result depends on
# the hour it is run is not a test. The one case below that exercises the closed
# window sets its own hours explicitly.
: "${ENVERCETIN_ASK_FROM_HOUR:=0}"
: "${ENVERCETIN_ASK_UNTIL_HOUR:=24}"
export ENVERCETIN_ASK_FROM_HOUR ENVERCETIN_ASK_UNTIL_HOUR

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WA="$REPO/scripts/weekly-article"
RUN="$WA/run.sh"
TMP="$(mktemp -d -t envercetin-topicgate)"
FIXTURE="$TMP/repo"
BIN="$TMP/bin"
FAKE_OS="$TMP/personal-os"
AGENTS="$TMP/agents"
LOGS="$TMP/logs"
STAMP="$(date +%Y-%m-%d)"
TMP_TOPICS="$TMP/saved-topics.json"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$(printf '%s' "${2:-}" | head -6 | tr '\n' ' ')"; return 0; }

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$BIN" "$FAKE_OS" "$AGENTS" "$LOGS"

# --- Fakes --------------------------------------------------------------------
# The proposer records every invocation, so a test can prove --topics did NOT
# call it and that a retry DID.
cat > "$BIN/claude" <<'FAKE'
#!/usr/bin/env bash
if [[ "${1:-}" == "auth" ]]; then echo '{"loggedIn": true, "authMethod": "claude.ai"}'; exit 0; fi
prompt=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "-p" ]] && { prompt="$2"; shift 2; continue; }
  shift
done
if [[ "$prompt" == *"ALREADY COVERED"* ]]; then
  echo "propose" >> "$CLAUDE_CALLS"
  n="$(grep -c propose "$CLAUDE_CALLS")"
  # PROPOSE_FAIL_UNTIL attempts produce nothing at all, like 2026-09-05.
  if [[ "$n" -le "${PROPOSE_FAIL_UNTIL:-0}" ]]; then
    exit "${PROPOSE_FAIL_RC:-124}"
  fi
  printf '[{"label":"A test topic","thesis":"A claim","why_now":"now","can_measure":"a thing"}]\n'
else
  echo "write" >> "$CLAUDE_CALLS"
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
"""Scripted stand-in for personal-os tg.py: pops one answer per ask."""
import os, sys
if sys.argv[1] == "send":
    print("Sent.")
    sys.exit(0)
with open(os.environ["TG_ASKS"], "a") as fh:
    fh.write("ask\n")
path = os.environ["TG_SCRIPT"]
with open(path) as fh:
    lines = [l.rstrip("\n") for l in fh if l.strip()]
answer = lines[0] if lines else "2:"
with open(path, "w") as fh:
    fh.write("\n".join(lines[1:]) + ("\n" if lines[1:] else ""))
rc, _, reply = answer.partition(":")
if reply:
    print(f"REPLY: {reply}")
else:
    print("TIMEOUT: nobody answered", file=sys.stderr)
sys.exit(int(rc))
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

# run_gate <extra env assignments...> -- <run.sh args...>
run_gate() {
  local -a envs=("ENVERCETIN_TEST_SEAM=1") args=("--help-never-used")
  while [[ $# -gt 0 ]]; do
    [[ "$1" == "--" ]] && { shift; args=(); [[ $# -gt 0 ]] && args=("$@"); break; }
    envs+=("$1"); shift
  done
  build_fixture
  : > "$TMP/claude-calls"
  : > "$TMP/tg-asks"
  rm -f "$LOGS/$STAMP-deferrals" "$AGENTS/com.enver.envercetin.topics-retry.plist"
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
      ENVERCETIN_APPROVE_MIN=1 \
      ENVERCETIN_ASK_ROUND_MIN=1 \
      ENVERCETIN_PROPOSE_TIMEOUT_SEC=30 \
      CLAUDE_CALLS="$TMP/claude-calls" \
      TG_ASKS="$TMP/tg-asks" \
      TG_SCRIPT="$TMP/tg-answers" \
      "${envs[@]}" \
      /bin/bash "$RUN" ${args[@]+"${args[@]}"} > "$TMP/run.log" 2>&1
  RUN_RC=$?
}

answers() { printf '%s\n' "$@" > "$TMP/tg-answers"; }

echo "topic gate"

# --- 1. An unanswered round is not a failure ----------------------------------
# The whole point: on 2026-08-29 each timed-out round fired the ERR trap and told
# Enver the run had failed at line 200, which was the `for` keyword.
answers "2:" "2:" "2:"
run_gate -- 
if grep -q "FAILED at line" "$TMP/run.log"; then
  bad "an unanswered topic question does not report a failure" "$(grep 'FAILED at line' "$TMP/run.log")"
else
  ok "an unanswered topic question does not report a failure"
fi

# --- 2. Running out of the day defers instead of dropping the week ------------
if grep -q "would notify: 🌙" "$TMP/run.log" && [[ -f "$LOGS/$STAMP-deferrals" ]]; then
  ok "an unanswered day is deferred, not written off"
else
  bad "an unanswered day is deferred, not written off" "$(tail -6 "$TMP/run.log")"
fi

if [[ -f "$AGENTS/com.enver.envercetin.topics-retry.plist" ]] &&
   grep -q -- "--topics" "$AGENTS/com.enver.envercetin.topics-retry.plist"; then
  ok "the deferral arms a reminder that asks rather than researches again"
else
  bad "the deferral arms a reminder that asks rather than researches again"
fi

if [[ $RUN_RC -eq 0 ]]; then
  ok "a deferral exits 0 — nothing failed"
else
  bad "a deferral exits 0 — nothing failed" "rc=$RUN_RC"
fi

# --- 3. Outside the civil window it does not ask at all ------------------------
# 21:39, 00:09 and 02:39 were three questions nobody could answer. Spending the
# escalation ladder on a sleeping man is worse than not asking.
answers "0:A test topic"
run_gate ENVERCETIN_ASK_FROM_HOUR=23 ENVERCETIN_ASK_UNTIL_HOUR=23 --
if [[ ! -s "$TMP/tg-asks" ]] && grep -q "would notify: 🌙" "$TMP/run.log"; then
  ok "outside the civil window nobody is asked"
else
  bad "outside the civil window nobody is asked" "asks=$(wc -l < "$TMP/tg-asks") $(tail -3 "$TMP/run.log")"
fi
if [[ -f "$LOGS/$STAMP-topics.json" ]]; then
  ok "the research is kept for the morning"
else
  bad "the research is kept for the morning"
fi

# --- 3b. A window that has not opened yet costs an hour, not a day -------------
# 2026-09-18: a hand-started run finished its proposals at 07:51, an hour and
# nine minutes before the window opened, and parked the question until 10:00 the
# NEXT day — in a week that had already lost three Saturdays to the usage limit.
# "Not yet" and "not any more" are different silences.
# arm_job writes key and value on one line, so -A1 would also pick up the Hour.
plist_day() {
  sed -n 's|.*<key>Day</key><integer>\([0-9]*\)</integer>.*|\1|p' \
    "$AGENTS/com.enver.envercetin.topics-retry.plist" 2>/dev/null | head -1
}

answers "0:A test topic"
rm -f "$AGENTS/com.enver.envercetin.topics-retry.plist"
# from=23 means the window opens tonight — unless the suite is itself run at
# 23:xx, in which case it has already shut and tomorrow is the right answer.
run_gate ENVERCETIN_ASK_FROM_HOUR=23 ENVERCETIN_ASK_UNTIL_HOUR=23 --
NOW_HOUR="$(date +%H)"; NOW_HOUR="${NOW_HOUR#0}"; NOW_HOUR="${NOW_HOUR:-0}"
if (( NOW_HOUR < 23 )); then
  if [[ "$(plist_day)" == "$(date +%-d)" ]] && grep -q "later today at 23:00" "$TMP/run.log"; then
    ok "a window that opens later today is waited out today, not slept off"
  else
    bad "a window that opens later today is waited out today, not slept off" \
        "armed for day $(plist_day), today is $(date +%-d): $(grep -o 'I will ask again [a-z ]*at [0-9:]*' "$TMP/run.log" | head -1)"
  fi
else
  ok "a window that opens later today is waited out today, not slept off (skipped: run at 23:xx)"
fi

answers "0:A test topic"
rm -f "$AGENTS/com.enver.envercetin.topics-retry.plist"
# from=0 means the window opened long ago and has already shut for the evening.
run_gate ENVERCETIN_ASK_FROM_HOUR=0 ENVERCETIN_ASK_UNTIL_HOUR=0 --
if [[ "$(plist_day)" == "$(date -v+1d +%-d)" ]] && grep -q "tomorrow at" "$TMP/run.log"; then
  ok "a window that has shut for the evening still waits for tomorrow morning"
else
  bad "a window that has shut for the evening still waits for tomorrow morning" \
      "armed for day $(plist_day), tomorrow is $(date -v+1d +%-d)"
fi

# --- 4. --topics asks without researching again -------------------------------
printf '[{"label":"Saved topic","thesis":"A claim","why_now":"now","can_measure":"a thing"}]\n' > "$TMP_TOPICS"
answers "0:Saved topic" "0:Keep as draft"
run_gate -- --topics "$TMP_TOPICS"
if ! grep -q propose "$TMP/claude-calls"; then
  ok "--topics does not re-run the proposer"
else
  bad "--topics does not re-run the proposer" "$(cat "$TMP/claude-calls")"
fi
if grep -q "^write$" "$TMP/claude-calls"; then
  ok "--topics carries the chosen topic through to the writer"
else
  bad "--topics carries the chosen topic through to the writer" "$(tail -6 "$TMP/run.log")"
fi

# --- 5. The last deferral gives up cleanly ------------------------------------
answers "2:" "2:" "2:"
run_gate ENVERCETIN_MAX_DEFERRALS=0 --
if grep -q "run.sh --topics" "$TMP/run.log"; then
  ok "giving up still tells you how to pick a topic later"
else
  bad "giving up still tells you how to pick a topic later" "$(tail -6 "$TMP/run.log")"
fi
if [[ ! -f "$LOGS/$STAMP-deferrals" ]]; then
  ok "giving up clears the marker, so the watchdog stops nagging"
else
  bad "giving up clears the marker, so the watchdog stops nagging"
fi

# --- 6. A hung proposer is retried, not fatal ---------------------------------
# 2026-09-05: one attempt, thirty awake minutes, nothing written, week lost.
answers "0:A test topic" "0:Keep as draft"
run_gate PROPOSE_FAIL_UNTIL=1 PROPOSE_FAIL_RC=124 --
if [[ "$(grep -c propose "$TMP/claude-calls")" -eq 2 ]]; then
  ok "a proposer that produces nothing is tried once more"
else
  bad "a proposer that produces nothing is tried once more" "calls=$(cat "$TMP/claude-calls")"
fi
if grep -q "^write$" "$TMP/claude-calls"; then
  ok "the retry's topics carry the run through to the writer"
else
  bad "the retry's topics carry the run through to the writer" "$(tail -8 "$TMP/run.log")"
fi

# --- 7. Every attempt failing is reported as the hang it is -------------------
answers "2:"
run_gate PROPOSE_FAIL_UNTIL=99 PROPOSE_FAIL_RC=124 --
if grep -q "no topics after" "$TMP/run.log" && grep -q "hangs during startup" "$TMP/run.log"; then
  ok "a proposer that never answers is named for what it did"
else
  bad "a proposer that never answers is named for what it did" "$(tail -6 "$TMP/run.log")"
fi
if [[ $RUN_RC -ne 0 ]]; then
  ok "and the run fails rather than pretending it published"
else
  bad "and the run fails rather than pretending it published"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
