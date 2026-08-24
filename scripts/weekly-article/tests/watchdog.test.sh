#!/usr/bin/env bash
#
# Tests for watchdog.sh.
#
#   scripts/weekly-article/tests/watchdog.test.sh
#
# The watchdog exists because on 2026-08-22 nothing told anyone the week was lost.
# Its own failure mode is the same one: a watchdog that quietly reports "healthy"
# through a broken week is worse than none, because it is trusted. So each case
# below RECONSTRUCTS one of the states that actually occurred and asserts the
# watchdog speaks — and the last case asserts it stays quiet when all is well, so
# the alarms cannot be passing merely because it always complains.
#
# Nothing here touches the real schedule: the watchdog takes its launchd label,
# LaunchAgents directory and install directory from the environment.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
WD="$REPO/scripts/weekly-article/watchdog.sh"
TMP="$(mktemp -d)"
BRANCH="article/watchdog-selftest"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         got: %s\n' "$(printf '%s' "${2:-}" | head -4 | tr '\n' ' ')"; return 0; }

cleanup() {
  git -C "$REPO" branch -D "$BRANCH" --quiet 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

# A LaunchAgents directory and an install directory of our own, populated to look
# healthy. Individual cases break exactly one thing.
mkdir -p "$TMP/agents" "$TMP/bin"
cp "$REPO/scripts/weekly-article/guard.sh"  "$TMP/bin/envercetin-guard"
cp "$REPO/scripts/weekly-article/notify.sh" "$TMP/bin/envercetin-notify"
chmod +x "$TMP/bin/envercetin-notify"
chmod +x "$TMP/bin/"*

run_wd() {
  ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" \
  ENVERCETIN_LABEL="${WD_LABEL:-com.enver.envercetin.weekly-article}" \
  ENVERCETIN_MAX_DAYS="${WD_MAX_DAYS:-10}" \
  ENVERCETIN_MAIN_REF="${WD_REF:-main}" \
  "$WD" --check 2>&1
}

# A publish plist for $BRANCH, pinned to the given month/day/hour.
write_publish_plist() {
  cat > "$TMP/agents/com.enver.envercetin.publish-selftest.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.enver.envercetin.publish-selftest</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>guard</string><string>x</string><string>deploy</string><string>$BRANCH</string></array>
  <key>StartCalendarInterval</key>
  <dict><key>Month</key><integer>$1</integer><key>Day</key><integer>$2</integer><key>Hour</key><integer>$3</integer><key>Minute</key><integer>0</integer></dict>
</dict>
</plist>
EOF
}

echo "watchdog.sh"

# --- 0. Healthy is silent ------------------------------------------------------
OUT="$(run_wd)"; RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == watchdog:\ healthy* ]]; then
  ok "says nothing when the pipeline is healthy"
else
  bad "says nothing when the pipeline is healthy" "$OUT"
fi

# --- 1. An approved article with nothing scheduled to publish it ---------------
git -C "$REPO" branch "$BRANCH" main --quiet 2>/dev/null
OUT="$(run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "nothing is scheduled to publish it" <<<"$OUT"; then
  ok "catches an approved article that was never scheduled"
else
  bad "catches an approved article that was never scheduled" "$OUT"
fi

# --- 2. The 2026-08-22 state: scheduled, due in the past, never ran ------------
# The publish job for article/2026-08-15 was armed for 22.08. 10:47, died, and
# left its plist pinned to a date that had passed. Everything looked scheduled.
write_publish_plist 1 2 3
OUT="$(run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "never ran" <<<"$OUT"; then
  ok "catches a publish job that was due and never ran (the 22.08. state)"
else
  bad "catches a publish job that was due and never ran (the 22.08. state)" "$OUT"
fi

# --- 3. A publish still in the future is NOT an alarm --------------------------
# Otherwise every approved article would page Enver for a week while it waits.
write_publish_plist 12 31 23
OUT="$(run_wd)"; RC=$?
if grep -q "never ran" <<<"$OUT" || grep -q "nothing is scheduled" <<<"$OUT"; then
  bad "stays quiet about a publish that is still in the future" "$OUT"
else
  ok "stays quiet about a publish that is still in the future"
fi
rm -f "$TMP/agents/com.enver.envercetin.publish-selftest.plist"
git -C "$REPO" branch -D "$BRANCH" --quiet 2>/dev/null

# --- 4. The schedule itself is gone --------------------------------------------
# The prefix must sit on the command inside the substitution, not on the OUT=
# assignment — a variable assignment preceding an assignment is not a prefix, it
# is permanent, and it leaked into every case after this one.
OUT="$(WD_LABEL=com.enver.envercetin.does-not-exist run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "not loaded in launchd" <<<"$OUT"; then
  ok "catches a schedule that is no longer loaded"
else
  bad "catches a schedule that is no longer loaded" "$OUT"
fi

# --- 5. The installed guard has drifted from the repo --------------------------
# Editing guard.sh changes nothing until install.sh copies it. A fix can look
# done and not be — which is exactly how a known bug survives a week.
printf '\n# drift\n' >> "$TMP/bin/envercetin-guard"
OUT="$(run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "out of date" <<<"$OUT"; then
  ok "catches an installed guard that no longer matches the repo"
else
  bad "catches an installed guard that no longer matches the repo" "$OUT"
fi
cp "$REPO/scripts/weekly-article/guard.sh" "$TMP/bin/envercetin-guard"
chmod +x "$TMP/bin/envercetin-guard"

# --- 6. The guard is missing entirely ------------------------------------------
rm -f "$TMP/bin/envercetin-notify"
OUT="$(run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "is missing" <<<"$OUT"; then
  ok "catches a missing notifier"
else
  bad "catches a missing notifier" "$OUT"
fi
cp "$REPO/scripts/weekly-article/notify.sh" "$TMP/bin/envercetin-notify"
chmod +x "$TMP/bin/envercetin-notify"

# --- 7. Nothing has been published for too long --------------------------------
# Driven from real history rather than a fabricated clock: one commit back, the
# newest article is the one from mid-August, which is genuinely more than three
# days old — and gets older, never younger, so this cannot rot into a pass.
OUT="$(WD_REF=main~1 WD_MAX_DAYS=3 run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "days ago" <<<"$OUT"; then
  ok "catches a site that has gone quiet"
else
  bad "catches a site that has gone quiet" "$OUT"
fi

# --- 8. Back to healthy --------------------------------------------------------
# The alarms above are only worth anything if the watchdog can still be quiet.
OUT="$(run_wd)"; RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == watchdog:\ healthy* ]]; then
  ok "returns to silence once each fault is repaired"
else
  bad "returns to silence once each fault is repaired" "$OUT"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
