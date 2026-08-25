#!/usr/bin/env bash
#
# Tests for lib/approval.sh — what an answer to "Publish it?" actually means.
#
# The defect this pins down: run.sh treated ANY non-zero exit from `tg.py ask` as
# "Keep as draft". A Telegram outage, an expired token, a dropped poll — all of
# them silently answered "no" on Enver's behalf. The article stays a draft, the
# branch keeps the topic marked COVERED forever, and the message he gets says he
# chose that. A failed question is not a rejection.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/approval.sh
source "$DIR/../lib/approval.sh"

if ! declare -f classify_approval >/dev/null; then
  echo "  FAIL — lib/approval.sh does not define classify_approval" >&2
  exit 1
fi

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

# expect <want> <rc> <reply> <why>
expect() {
  local want="$1" rc="$2" reply="$3" why="$4" got
  got="$(classify_approval "$rc" "$reply")"
  [[ "$got" == "$want" ]] && ok "$why" || bad "$why" "rc=$rc reply='$reply' → '$got', wanted '$want'"
}

echo "classify_approval"

# --- Answered ------------------------------------------------------------------
expect publish 0 "Publish"        "tapping Publish publishes"
expect draft   0 "Keep as draft"  "tapping Keep as draft keeps it as a draft"

# tg.py returns whatever was typed if Enver ignores the buttons. Accept the option
# labels in any casing — he types on a phone — but nothing beyond them.
expect publish 0 "publish"        "typing the word publishes too"
expect publish 0 "  Publish  "    "surrounding whitespace does not change the answer"
expect draft   0 "KEEP AS DRAFT"  "casing does not change the answer"

# --- Answered with something else ----------------------------------------------
# Not a rejection: it is an answer nobody can act on. Ask again rather than guess.
expect undecided 0 "später"        "an answer that is neither option decides nothing"
expect undecided 0 ""              "an empty reply decides nothing"

# --- Not answered --------------------------------------------------------------
# rc 2 is tg.py's timeout. Nobody said no; nobody said anything.
expect undecided 2 ""             "a timed-out question is not a rejection"
expect undecided 2 "Publish"      "a timeout wins over stale output on stdout"

# --- Broken --------------------------------------------------------------------
# rc 1 is ConfigError / NotConnected / TelegramAPIError, and any other code is a
# crash. Either way the question never reached him, and the run must say so
# instead of filing it as his decision.
expect error 1 ""                 "a Telegram error is an error, not a No"
expect error 1 "Publish"          "an error wins over whatever was on stdout"
expect error 127 ""               "a crashed ask is an error, not a No"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
