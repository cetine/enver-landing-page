#!/usr/bin/env bash
#
# Tests for cancel-publish.sh.
#
# The defect it exists to fix is mine, introduced on 2026-08-24. run.sh told Enver
# to cancel a scheduled publish with:
#
#   launchctl bootout gui/$(id -u)/com.enver.envercetin.publish-...
#
# which unloads the job and leaves the plist on disk. At the next login launchd
# loads it again, and an article that was deliberately withdrawn goes live. The
# second half is quieter: cancelling a publish without doing anything about the
# branch leaves an `article/*` branch with no schedule, which is exactly the
# shape the watchdog reports as broken — every Tuesday and Saturday, forever.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CANCEL="$REPO/scripts/weekly-article/cancel-publish.sh"
WATCHDOG="$REPO/scripts/weekly-article/watchdog.sh"
TMP="$(mktemp -d -t envercetin-cancel)"
FIXTURE="$TMP/repo"
AGENTS="$TMP/agents"
LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
BRANCH="article/2026-08-22"
LABEL="com.enver.envercetin.publish-2026-08-28-1930"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }
cleanup() { rm -rf "$TMP" "$LOCK_ROOT/$LABEL.lock"; }
trap cleanup EXIT

mkdir -p "$AGENTS"

build_fixture() {
  rm -rf "$FIXTURE"
  mkdir -p "$FIXTURE/src/content/writing/en"
  git init --quiet "$FIXTURE"
  git -C "$FIXTURE" config user.email "test@example.com"
  git -C "$FIXTURE" config user.name "Test"
  git -C "$FIXTURE" config commit.gpgsign false
  git -C "$FIXTURE" symbolic-ref HEAD refs/heads/main
  echo old > "$FIXTURE/src/content/writing/en/already-there.mdx"
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit --quiet -m "chore: base"
  git -C "$FIXTURE" checkout -b "$BRANCH" --quiet
  echo new > "$FIXTURE/src/content/writing/en/the-new-one.mdx"
  git -C "$FIXTURE" add -A
  git -C "$FIXTURE" commit --quiet -m "feat: article — the-new-one"
  git -C "$FIXTURE" checkout main --quiet

  rm -f "$AGENTS"/*.plist
  cat > "$AGENTS/$LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$HOME/.local/bin/envercetin-guard</string>
    <string>$LABEL</string>
    <string>$REPO/scripts/weekly-article/deploy-scheduled.sh</string>
    <string>$BRANCH</string>
    <string>$LABEL</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Month</key><integer>8</integer><key>Day</key><integer>28</integer><key>Hour</key><integer>19</integer><key>Minute</key><integer>30</integer></dict>
</dict>
</plist>
PLIST
}

run_cancel() {
  env ENVERCETIN_TEST_SILENT=1 ENVERCETIN_REPO="$FIXTURE" ENVERCETIN_AGENTS_DIR="$AGENTS" \
      /bin/bash "$CANCEL" "$@" > "$TMP/cancel.log" 2>&1
  CANCEL_RC=$?
}

echo "cancel-publish.sh"

# --- 1. The plist must be GONE, not just unloaded -----------------------------
build_fixture
run_cancel "$BRANCH"
[[ $CANCEL_RC -eq 0 ]] && ok "cancelling a scheduled publish succeeds" \
  || bad "cancelling a scheduled publish succeeds" "rc=$CANCEL_RC: $(tail -2 "$TMP/cancel.log")"
[[ ! -f "$AGENTS/$LABEL.plist" ]] \
  && ok "the plist is deleted, so it cannot come back at the next login" \
  || bad "the plist is deleted, so it cannot come back at the next login" "$AGENTS/$LABEL.plist survived"

# --- 2. The branch must stop looking broken to the watchdog -------------------
git -C "$FIXTURE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && bad "the cancelled branch leaves article/*" "$BRANCH is still an article branch — the watchdog will report it every Tue and Sat" \
  || ok "the cancelled branch leaves article/*"
git -C "$FIXTURE" rev-parse --verify "draft/2026-08-22" >/dev/null 2>&1 \
  && ok "the work is kept, under draft/" \
  || bad "the work is kept, under draft/" "the article was thrown away instead of renamed"
git -C "$FIXTURE" show "draft/2026-08-22:src/content/writing/en/the-new-one.mdx" >/dev/null 2>&1 \
  && ok "the article itself is untouched" || bad "the article itself is untouched" "content lost"

# The point of the rename, checked against the real watchdog rather than assumed.
WD_OUT="$(env ENVERCETIN_REPO="$FIXTURE" ENVERCETIN_AGENTS_DIR="$AGENTS" ENVERCETIN_BIN_DIR="$TMP/bin" \
  ENVERCETIN_LABEL=nonexistent.test ENVERCETIN_MAX_DAYS=99999 "$WATCHDOG" --check 2>&1)"
printf '%s' "$WD_OUT" | grep -q "2026-08-22" \
  && bad "the watchdog stops nagging about a cancelled article" "it still reports the branch: $(printf '%s' "$WD_OUT" | grep 2026-08-22 | head -1)" \
  || ok "the watchdog stops nagging about a cancelled article"

# --- 3. Cancelling by label works too ------------------------------------------
build_fixture
run_cancel "$LABEL"
[[ ! -f "$AGENTS/$LABEL.plist" ]] && ok "a job can be cancelled by its launchd label" \
  || bad "a job can be cancelled by its launchd label" "plist survived"

# --- 4. Throwing the article away has to be asked for --------------------------
build_fixture
run_cancel "$BRANCH" --delete-branch
git -C "$FIXTURE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && bad "--delete-branch really deletes it" "branch survived" \
  || ok "--delete-branch really deletes it"
git -C "$FIXTURE" rev-parse --verify "draft/2026-08-22" >/dev/null 2>&1 \
  && bad "--delete-branch does not leave a draft behind" "draft/2026-08-22 exists" \
  || ok "--delete-branch does not leave a draft behind"

build_fixture
run_cancel "$BRANCH" --keep-branch
git -C "$FIXTURE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && ok "--keep-branch leaves the branch exactly where it was" \
  || bad "--keep-branch leaves the branch exactly where it was" "it was renamed anyway"

# --- 5. Never cancel a publish that is already running -------------------------
# Deleting the plist under a running deploy would strip the job of the label it
# cleans up with, mid-push.
build_fixture
mkdir -p "$LOCK_ROOT/$LABEL.lock"
echo $$ > "$LOCK_ROOT/$LABEL.lock/pid"
date +%s > "$LOCK_ROOT/$LABEL.lock/since"
run_cancel "$BRANCH"
rm -rf "$LOCK_ROOT/$LABEL.lock"
[[ $CANCEL_RC -ne 0 ]] && ok "a publish that is running right now is not cancelled" \
  || bad "a publish that is running right now is not cancelled" "it cancelled mid-publish"
[[ -f "$AGENTS/$LABEL.plist" ]] && ok "a running publish keeps its plist" \
  || bad "a running publish keeps its plist" "the plist was deleted under a live job"

# --- 6. Nothing to cancel is said plainly --------------------------------------
build_fixture
run_cancel "article/1999-01-01"
[[ $CANCEL_RC -ne 0 ]] && ok "an unknown branch is an error, not a silent success" \
  || bad "an unknown branch is an error, not a silent success" "rc=0"
grep -qi "no scheduled publish\|not found\|nothing" "$TMP/cancel.log" \
  && ok "an unknown branch says so" || bad "an unknown branch says so" "$(tail -1 "$TMP/cancel.log")"

# --- 7. Listing what is pending ------------------------------------------------
build_fixture
run_cancel --list
grep -q "$LABEL" "$TMP/cancel.log" && ok "--list shows what is scheduled" \
  || bad "--list shows what is scheduled" "$(cat "$TMP/cancel.log")"
[[ -f "$AGENTS/$LABEL.plist" ]] && ok "--list changes nothing" \
  || bad "--list changes nothing" "listing cancelled something"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
