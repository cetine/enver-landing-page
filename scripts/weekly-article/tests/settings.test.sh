#!/usr/bin/env bash
#
# Tests for .claude/settings.json — the guardrails every Claude session started
# in this repository runs under, including the unattended weekly article run.
#
#   scripts/weekly-article/tests/settings.test.sh
#
# This file has exactly one way to be written and two ways to be wrong, and both
# wrong ways are silent. Measured on 2026-09-18, three runs of three each:
#
#   Read(~/Projects/**)          runs, and denies            <- correct
#   Read(//Users/ece/Projects/**) HANGS. Headless `claude -p` emits the Read and
#                                never receives a result. No error, no denial,
#                                no output. One run sat for 7h39m.
#   Read(/Users/ece/Projects/**)  runs, and denies NOTHING. One leading slash
#                                reads as relative to this directory and matches
#                                nothing. A test read of ~/Projects went through
#                                and a Glob of ~/.ssh returned the names of five
#                                private keys.
#
# The second cost four Saturdays. The third is worse: it looks like the fix.
#
# These checks are static on purpose. Proving the hang needs a real model call,
# which does not belong in a suite that has to run offline in seconds — so this
# pins the exact spelling that caused it instead.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SETTINGS="$REPO/.claude/settings.json"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

echo "settings.json — the guardrails"

if [[ -f "$SETTINGS" ]]; then
  ok "the repo has a settings file at all"
else
  bad "the repo has a settings file at all" "$SETTINGS is missing — the unattended run would have no guardrails"
  echo "  $PASS passed, $((FAIL+1)) failed"
  exit 1
fi

if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS" 2>/dev/null; then
  ok "it is valid JSON"
else
  bad "it is valid JSON" "$(python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$SETTINGS" 2>&1 | tail -1)"
  echo "  $PASS passed, $FAIL failed"
  exit 1
fi

REPORT="$(python3 - "$SETTINGS" <<'PY'
import json, sys

rules = json.load(open(sys.argv[1]))["permissions"]["deny"]
path_rules = [r for r in rules if not r.startswith("Bash(")]
bash_rules = [r for r in rules if r.startswith("Bash(")]

hangs   = [r for r in path_rules if "(//" in r]
useless = [r for r in path_rules if "(/" in r and "(//" not in r]
odd     = [r for r in path_rules if "(~/" not in r]

TREES = ["Projects/**", "Documents/**", "Desktop/**", "Downloads/**",
         "Library/CloudStorage/**", ".ssh/**", ".aws/**", ".gnupg/**", ".config/**"]
# Read only -- plus Edit for writes. NOT Glob or Grep: the CLI rejects those on
# startup ("only Read(path) rules are" matched by file permission checks) and a
# Read rule already covers every file-reading tool, Glob and Grep included.
TOOLS = ["Read", "Edit"]
missing = [f"{t}(~/{tree})" for t in TOOLS for tree in TREES
           if f"{t}(~/{tree})" not in path_rules]

print(json.dumps({
    "n_path": len(path_rules), "n_bash": len(bash_rules),
    "hangs": hangs, "useless": useless, "odd": odd, "missing": missing,
}))
PY
)"

field() { python3 -c "import json,sys; print(json.dumps(json.loads(sys.argv[1])[sys.argv[2]]))" "$REPORT" "$1"; }

if [[ "$(field hangs)" == "[]" ]]; then
  ok "no rule uses the //absolute form that hangs every headless run"
else
  bad "no rule uses the //absolute form that hangs every headless run" "$(field hangs)"
fi

if [[ "$(field useless)" == "[]" ]]; then
  ok "no rule uses the /single-slash form that denies nothing"
else
  bad "no rule uses the /single-slash form that denies nothing" "$(field useless)"
fi

NOOPS="$(python3 -c "
import json,sys
rules = json.load(open(sys.argv[1]))['permissions']['deny']
print(json.dumps([r for r in rules if r.startswith(('Glob(', 'Grep('))]))
" "$SETTINGS")"
if [[ "$NOOPS" == "[]" ]]; then
  ok "no Glob or Grep rules — the CLI rejects them and Read already covers them"
else
  bad "no Glob or Grep rules — the CLI rejects them and Read already covers them" "$NOOPS"
fi

if [[ "$(field odd)" == "[]" ]]; then
  ok "every path rule is written ~/..."
else
  bad "every path rule is written ~/..." "$(field odd)"
fi

if [[ "$(field missing)" == "[]" ]]; then
  ok "Read and Edit are denied on every protected tree"
else
  bad "Read and Edit are denied on every protected tree" "fehlt: $(field missing)"
fi

# Denying Read while leaving Glob open still hands over the filenames — which is
# how ~/.ssh gave up five private key names on 2026-09-18.
if [[ "$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['n_bash'])" "$REPORT")" -ge 11 ]]; then
  ok "the Bash guardrails from the 2026-08-12 incident are still there"
else
  bad "the Bash guardrails from the 2026-08-12 incident are still there" "$REPORT"
fi

echo
echo "  $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
