#!/usr/bin/env bash
#
# Tests for what run.sh actually DOES with the answer to "Publish it?".
#
# lib/approval.sh is unit-tested next door; this drives the real run.sh end to
# end — fake `claude`, fake `vercel`, fake `tg.py`, a temp git repo — because the
# defect was never in the classification. It was in the wiring: one `if` that
# collapsed "Telegram is broken" and "he did not answer" into the same branch as
# "he said no", and then told him he had chosen it. Those branches had never run
# outside a real Saturday, which is why nobody saw it for two weeks.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WA="$REPO/scripts/weekly-article"
RUN="$WA/run.sh"
TMP="$(mktemp -d -t envercetin-approval)"
FIXTURE="$TMP/repo"
BIN="$TMP/bin"
FAKE_OS="$TMP/personal-os"
AGENTS="$TMP/agents"
TG_SCRIPT="$TMP/tg-answers"       # one "rc:reply" per ask, consumed in order

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

mkdir -p "$BIN" "$FAKE_OS" "$AGENTS" "$TMP/logs"

# --- Fakes --------------------------------------------------------------------
cat > "$BIN/claude" <<'FAKE'
#!/usr/bin/env bash
# Two calls: propose (prompt carries the ALREADY COVERED list) and write.
prompt=""
while [[ $# -gt 0 ]]; do
  [[ "$1" == "-p" ]] && { prompt="$2"; shift 2; continue; }
  shift
done
if [[ "$prompt" == *"ALREADY COVERED"* ]]; then
  printf '[{"label":"A test topic","thesis":"A claim","why_now":"now","can_measure":"a thing"}]\n'
else
  mkdir -p src/content/writing/en
  printf -- '---\ntitle: "A test topic"\n---\n\nBody.\n' > src/content/writing/en/a-test-topic.mdx
  echo "SLUG: a-test-topic"
fi
FAKE

cat > "$BIN/vercel" <<'FAKE'
#!/usr/bin/env bash
# VERCEL_MODE: ok (default) | silent (deploys, prints no URL) | fail (exits 1)
case "${VERCEL_MODE:-ok}" in
  silent) echo "Deploying..."; exit 0 ;;
  fail)   echo "Error: no credentials" >&2; exit 1 ;;
  *)      echo "https://envercetin-test-preview.vercel.app" ;;
esac
FAKE

cat > "$FAKE_OS/tg.py" <<'FAKE'
#!/usr/bin/env python3
"""Scripted stand-in for personal-os tg.py: pops one answer per ask."""
import os, sys

if sys.argv[1] == "send":
    print("Sent.")
    sys.exit(0)

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
  # The prompts and topics.py are read relative to the repo root at runtime.
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
  # run.sh pulls before it starts: a fixture without a remote fails at the door
  # and never reaches the branch under test.
  git -C "$FIXTURE" remote add origin "$TMP/origin.git"
  git -C "$FIXTURE" push --quiet -u origin main
}

# answers... → run run.sh with those scripted replies (first is the topic choice)
run_pipeline() {
  printf '%s\n' "$@" > "$TG_SCRIPT"
  build_fixture
  env PATH="$BIN:$PATH" \
      ENVERCETIN_TEST_SILENT=1 \
      ENVERCETIN_REPO="$FIXTURE" \
      ENVERCETIN_PERSONAL_OS="$FAKE_OS" \
      ENVERCETIN_VERIFY_CMD=true \
      ENVERCETIN_CLAUDE_BIN="$BIN/claude" \
      ENVERCETIN_VERCEL_BIN="$BIN/vercel" \
      ENVERCETIN_AGENTS_DIR="$AGENTS" \
      ENVERCETIN_LOG_DIR="$TMP/logs" \
      ENVERCETIN_TEST_NO_LAUNCHCTL=1 \
      ENVERCETIN_APPROVE_MIN=1 \
      ENVERCETIN_ASK_ROUND_MIN=1 \
      TG_SCRIPT="$TG_SCRIPT" \
      VERCEL_MODE="${VERCEL_MODE:-ok}" \
      /bin/bash "$RUN" > "$TMP/run.log" 2>&1
  RUN_RC=$?
}

branch_exists() { git -C "$FIXTURE" rev-parse --verify "article/$(date +%Y-%m-%d)" >/dev/null 2>&1; }
notified() { grep -q "would notify: $1" "$TMP/run.log"; }

echo "run.sh — what an answer to \"Publish it?\" leads to"

# --- 1. Publish ---------------------------------------------------------------
run_pipeline "0:A test topic" "0:Publish"
[[ $RUN_RC -eq 0 ]] && ok "an approved article finishes cleanly" \
  || bad "an approved article finishes cleanly" "rc=$RUN_RC: $(tail -2 "$TMP/run.log")"
ls "$AGENTS"/com.enver.envercetin.publish-*.plist >/dev/null 2>&1 \
  && ok "an approved article is scheduled" \
  || bad "an approved article is scheduled" "no publish plist was written"
notified "🗓" && ok "the schedule is reported" || bad "the schedule is reported" "no 🗓 message"
rm -f "$AGENTS"/*.plist

# --- 2. An explicit No ---------------------------------------------------------
run_pipeline "0:A test topic" "0:Keep as draft"
[[ $RUN_RC -eq 0 ]] && ok "a declined article ends cleanly" \
  || bad "a declined article ends cleanly" "rc=$RUN_RC"
branch_exists && ok "a declined article keeps its branch" || bad "a declined article keeps its branch" "branch gone"
notified "Article kept as a draft" && ok "a declined article is reported as his decision" \
  || bad "a declined article is reported as his decision" "wrong message: $(grep 'would notify' "$TMP/run.log" | tail -1)"
ls "$AGENTS"/com.enver.envercetin.publish-*.plist >/dev/null 2>&1 \
  && bad "a declined article schedules nothing" "a publish job was armed anyway" \
  || ok "a declined article schedules nothing"

# --- 3. Telegram is broken — the defect ---------------------------------------
# rc 1 is ConfigError / NotConnected / TelegramAPIError. The question never
# reached him. Before the fix this printed "Article kept as a draft", which is a
# decision he never made, and the run exited 0 so nothing else raised the alarm.
run_pipeline "0:A test topic" "1:"
notified "Article kept as a draft" \
  && bad "a Telegram error is never reported as his decision" "it still claims he chose to keep it as a draft" \
  || ok "a Telegram error is never reported as his decision"
notified "⚠️" && ok "a Telegram error is reported as a failure" \
  || bad "a Telegram error is reported as a failure" "no ⚠️: $(grep 'would notify' "$TMP/run.log" | tail -1)"
[[ $RUN_RC -ne 0 ]] && ok "a Telegram error fails the run, so the guard reports it too" \
  || bad "a Telegram error fails the run, so the guard reports it too" "rc=0"
branch_exists && ok "a Telegram error keeps the finished article" \
  || bad "a Telegram error keeps the finished article" "the branch was lost"
ls "$AGENTS"/com.enver.envercetin.publish-*.plist >/dev/null 2>&1 \
  && bad "a Telegram error publishes nothing" "a publish job was armed" \
  || ok "a Telegram error publishes nothing"

# --- 4. He simply did not answer ----------------------------------------------
# A timeout is not a No either. It is asked again, and then reported as what it
# is: undecided, with both ways out spelled out.
run_pipeline "0:A test topic" "2:" "2:"
[[ $RUN_RC -eq 0 ]] && ok "an unanswered question ends the run without failing it" \
  || bad "an unanswered question ends the run without failing it" "rc=$RUN_RC"
notified "Article kept as a draft" \
  && bad "silence is never reported as his decision" "it claims he chose to keep it as a draft" \
  || ok "silence is never reported as his decision"
grep -q "No answer on this week's article" "$TMP/run.log" && ok "silence is reported as undecided" \
  || bad "silence is reported as undecided" "$(grep 'would notify' "$TMP/run.log" | tail -1)"
grep -q "cancel-publish.sh" "$TMP/run.log" && ok "the undecided message says how to drop it for good" \
  || bad "the undecided message says how to drop it for good" "no cancel-publish hint"
grep -c "round .*: rc=2" "$TMP/run.log" | grep -q "^2$" && ok "an unanswered question is asked again before giving up" \
  || bad "an unanswered question is asked again before giving up" "asked $(grep -c 'round .*: rc=' "$TMP/run.log") time(s)"
branch_exists && ok "an unanswered question keeps the finished article" \
  || bad "an unanswered question keeps the finished article" "the branch was lost"

# --- 5. An answer that is neither option ---------------------------------------
# Typed free text, not a tapped button. Ask again rather than guess — and if the
# second answer is a real one, act on it.
run_pipeline "0:A test topic" "0:später" "0:Publish"
ls "$AGENTS"/com.enver.envercetin.publish-*.plist >/dev/null 2>&1 \
  && ok "an unusable answer is re-asked, and the real answer wins" \
  || bad "an unusable answer is re-asked, and the real answer wins" "nothing was scheduled: $(grep 'round' "$TMP/run.log")"
rm -f "$AGENTS"/*.plist

# --- 6. The preview deploy produced no URL -------------------------------------
# The assignment used to be bare, so `grep -Eo` exiting 1 on output with no URL
# — or with_timeout returning 124 on a hung deploy — killed the run AT the
# assignment, under `set -euo pipefail`, and the handler below it that says
# something useful could never run. By this line the article is written,
# verified and committed, so the message is the difference between a resumable
# article and a mystery.
VERCEL_MODE=silent run_pipeline "0:A test topic" "0:Publish"
VERCEL_MODE=ok
[[ $RUN_RC -ne 0 ]] && ok "a deploy with no preview URL fails the run" \
  || bad "a deploy with no preview URL fails the run" "rc=$RUN_RC"
grep -q "no preview to show you" "$TMP/run.log" && ok "a deploy with no URL says so in plain words" \
  || bad "a deploy with no URL says so in plain words" "$(grep 'would notify' "$TMP/run.log" | tail -1)"
grep -q "run.sh --resume" "$TMP/run.log" && ok "a failed deploy tells you how to resume the finished article" \
  || bad "a failed deploy tells you how to resume the finished article" "no --resume hint"
branch_exists && ok "a failed deploy keeps the article it could not show you" \
  || bad "a failed deploy keeps the article it could not show you" "the branch was lost"
ls "$AGENTS"/com.enver.envercetin.publish-*.plist >/dev/null 2>&1 \
  && bad "a failed deploy publishes nothing" "a publish job was armed" \
  || ok "a failed deploy publishes nothing"

# --- 7. The deploy command itself failed ---------------------------------------
VERCEL_MODE=fail run_pipeline "0:A test topic" "0:Publish"
VERCEL_MODE=ok
grep -q "exited 1" "$TMP/run.log" && ok "a deploy that exits non-zero is reported with its exit code" \
  || bad "a deploy that exits non-zero is reported with its exit code" "$(grep 'would notify' "$TMP/run.log" | tail -1)"
branch_exists && ok "a broken deploy keeps the finished article too" \
  || bad "a broken deploy keeps the finished article too" "the branch was lost"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
