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

LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
HUNG_LOCK="$LOCK_ROOT/watchdog-selftest-hung.lock"

cleanup() {
  git -C "$REPO" branch -D "$BRANCH" --quiet 2>/dev/null
  [[ -n "${HOLDER:-}" ]] && kill -KILL "$HOLDER" 2>/dev/null
  rm -rf "$TMP" "$HUNG_LOCK" "$UNPUSHED_REPO"
}
trap cleanup EXIT

# A LaunchAgents directory and an install directory of our own, populated to look
# healthy. Individual cases break exactly one thing.
mkdir -p "$TMP/agents" "$TMP/bin" "$TMP/logs"
cp "$REPO/scripts/weekly-article/guard.sh"  "$TMP/bin/envercetin-guard"
cp "$REPO/scripts/weekly-article/notify.sh" "$TMP/bin/envercetin-notify"
chmod +x "$TMP/bin/envercetin-notify"
chmod +x "$TMP/bin/"*

run_wd() {
  ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" \
  ENVERCETIN_LABEL="${WD_LABEL:-com.enver.envercetin.weekly-article}" \
  ENVERCETIN_MAX_DAYS="${WD_MAX_DAYS:-10}" \
  ENVERCETIN_LOG_DIR="${WD_LOG_DIR:-$TMP/logs}" \
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
# WD_MAX_DAYS is pinned high here and in case 8. These two cases assert that the
# fixture-controlled checks are quiet; the age check reads the REAL repo, so
# leaving it at its default made both of them fail the moment the site actually
# went quiet — the test went red for the one condition the watchdog exists to
# report, and stayed red until the site was fixed. Cases 6a and 6b pin their own
# thresholds and are where the age check is actually tested.
OUT="$(WD_MAX_DAYS=99999 run_wd)"; RC=$?
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
# Against a fixture with a backdated commit, not against the real repo's history:
# the previous version of this case asserted that `main~1` still pointed at an
# old article, which stopped being true the moment another article was committed.
# A test that decays into a pass is the failure mode the watchdog itself exists
# to prevent.
QUIET_REPO="$TMP/quiet"
git init --quiet "$QUIET_REPO"
git -C "$QUIET_REPO" config user.email "test@example.com"
git -C "$QUIET_REPO" config user.name "Test"
git -C "$QUIET_REPO" config commit.gpgsign false
git -C "$QUIET_REPO" symbolic-ref HEAD refs/heads/main
mkdir -p "$QUIET_REPO/src/content/writing/en"
echo old > "$QUIET_REPO/src/content/writing/en/an-old-one.mdx"
git -C "$QUIET_REPO" add -A
OLD_DATE="$(date -v-30d '+%Y-%m-%dT%H:%M:%S')"
GIT_AUTHOR_DATE="$OLD_DATE" GIT_COMMITTER_DATE="$OLD_DATE" \
  git -C "$QUIET_REPO" commit --quiet -m "feat: article — an-old-one"

OUT="$(ENVERCETIN_REPO="$QUIET_REPO" ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" ENVERCETIN_MAX_DAYS=10 "$WD" --check 2>&1)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "30 days ago" <<<"$OUT"; then
  ok "catches a site that has gone quiet"
else
  bad "catches a site that has gone quiet" "$OUT"
fi

OUT="$(ENVERCETIN_REPO="$QUIET_REPO" ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" ENVERCETIN_MAX_DAYS=40 "$WD" --check 2>&1)"
if grep -q "days ago" <<<"$OUT"; then
  bad "stays quiet while the site is still within its rhythm" "$OUT"
else
  ok "stays quiet while the site is still within its rhythm"
fi

# --- 7b. A run that has been holding a lock since who knows when ---------------
# One hang used to mean every later week was skipped with "a previous run is
# still going" — silently, because nothing looks at the locks.
# >/dev/null so the holder does not keep the command substitution's pipe open.
set -m
sleep 600 >/dev/null 2>&1 &
HOLDER=$!
set +m
rm -rf "$HUNG_LOCK"; mkdir -p "$HUNG_LOCK"
echo "$HOLDER" > "$HUNG_LOCK/pid"
printf 'weekly-article' > "$HUNG_LOCK/job"

# Within the cap: still working, and no business of the watchdog's.
date +%s > "$HUNG_LOCK/since"
OUT="$(run_wd)"; RC=$?
if grep -q "has been running for" <<<"$OUT"; then
  bad "leaves a run that is merely slow alone" "$OUT"
else
  ok "leaves a run that is merely slow alone"
fi

# Past the cap: hung, and everything behind it is stuck.
echo $(( $(date +%s) - 40 * 3600 )) > "$HUNG_LOCK/since"
OUT="$(run_wd)"; RC=$?
if [[ $RC -ne 0 ]] && grep -q "has been running for 40 hours" <<<"$OUT"; then
  ok "catches a run that has hung and is blocking every other job"
else
  bad "catches a run that has hung and is blocking every other job" "$OUT"
fi
kill -KILL "$HOLDER" 2>/dev/null
HOLDER=""
rm -rf "$HUNG_LOCK"

# --- 7c. An article that never left this Mac ----------------------------------
# The 2026-08-22 push failure, reconstructed: main carries an article the remote
# has never seen. Every other check reads local main and calls that healthy.
UNPUSHED_REPO="$TMP/unpushed"
git init --bare --quiet "$TMP/unpushed-origin.git"
git init --quiet "$UNPUSHED_REPO"
git -C "$UNPUSHED_REPO" config user.email "test@example.com"
git -C "$UNPUSHED_REPO" config user.name "Test"
git -C "$UNPUSHED_REPO" config commit.gpgsign false
git -C "$UNPUSHED_REPO" symbolic-ref HEAD refs/heads/main
mkdir -p "$UNPUSHED_REPO/src/content/writing/en"
echo old > "$UNPUSHED_REPO/src/content/writing/en/already-there.mdx"
git -C "$UNPUSHED_REPO" add -A
git -C "$UNPUSHED_REPO" commit --quiet -m "chore: base"
git -C "$UNPUSHED_REPO" remote add origin "$TMP/unpushed-origin.git"
git -C "$UNPUSHED_REPO" push --quiet -u origin main

OUT="$(ENVERCETIN_REPO="$UNPUSHED_REPO" ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" ENVERCETIN_MAX_DAYS=99999 "$WD" --check 2>&1)"
if grep -q "NOT on GitHub" <<<"$OUT"; then
  bad "a repo in step with its remote raises no push alarm" "$OUT"
else
  ok "a repo in step with its remote raises no push alarm"
fi

# Now commit an article locally and do not push it.
echo new > "$UNPUSHED_REPO/src/content/writing/en/never-pushed.mdx"
git -C "$UNPUSHED_REPO" add -A
git -C "$UNPUSHED_REPO" commit --quiet -m "feat: article — never-pushed"

# Fresh, so the grace period must hold its tongue. On 2026-08-25 an article was
# committed by hand at 09:13 and pushed at 11:37, and the 10:00 watchdog fired in
# the gap telling Enver a push had failed when none had been attempted.
OUT="$(ENVERCETIN_REPO="$UNPUSHED_REPO" ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" ENVERCETIN_MAX_DAYS=99999 "$WD" --check 2>&1)"
if grep -q "not on GitHub" <<<"$OUT"; then
  bad "gives a just-made commit time to be pushed before crying about it" "$OUT"
else
  ok "gives a just-made commit time to be pushed before crying about it"
fi

# Past the grace period, it is a real problem and must be reported.
OUT="$(ENVERCETIN_REPO="$UNPUSHED_REPO" ENVERCETIN_AGENTS_DIR="$TMP/agents" \
  ENVERCETIN_BIN_DIR="$TMP/bin" ENVERCETIN_MAX_DAYS=99999 \
  ENVERCETIN_UNPUSHED_GRACE_SEC=0 "$WD" --check 2>&1)"
if grep -q "not on GitHub" <<<"$OUT"; then
  ok "catches an article that is committed locally but never reached the site"
else
  bad "catches an article that is committed locally but never reached the site" "$OUT"
fi

# --- 8. Back to healthy --------------------------------------------------------
# The alarms above are only worth anything if the watchdog can still be quiet.
OUT="$(WD_MAX_DAYS=99999 run_wd)"; RC=$?
if [[ $RC -eq 0 ]] && [[ "$OUT" == watchdog:\ healthy* ]]; then
  ok "returns to silence once each fault is repaired"
else
  bad "returns to silence once each fault is repaired" "$OUT"
fi

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
