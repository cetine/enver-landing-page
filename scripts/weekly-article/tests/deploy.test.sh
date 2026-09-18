#!/usr/bin/env bash
#
# Tests for deploy-scheduled.sh — the one script that can put something wrong on
# envercetin.de, and the one whose failures used to be reported as successes.
#
# Two defects are pinned here:
#
#   1. A failed `git push` left main locally merged and the branch deleted. The
#      article existed on this Mac and nowhere else, the watchdog read LOCAL main
#      and concluded an article had been published, and the site stayed unchanged.
#      A silent hole in the archive, with every alarm reporting healthy.
#
#   2. "✅ Published as scheduled" was printed after `git push` returned, not
#      after anything confirmed the push had landed.
#
# Everything runs against a real bare repo in a temp dir. Nothing here can reach
# GitHub, Vercel, or Telegram.

set -uo pipefail

# run.sh only asks between 09:00 and 21:00, and a suite whose result depends on
# the hour it is run is not a test. Pinned here rather than in run-all.sh so a
# single suite run by hand behaves the same. Cases that test the window itself
# override these per case.
: "${ENVERCETIN_ASK_FROM_HOUR:=0}"
: "${ENVERCETIN_ASK_UNTIL_HOUR:=24}"
export ENVERCETIN_ASK_FROM_HOUR ENVERCETIN_ASK_UNTIL_HOUR

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DEPLOY="$REPO/scripts/weekly-article/deploy-scheduled.sh"
TMP="$(mktemp -d -t envercetin-deploy)"
ORIGIN="$TMP/origin.git"
CLONE="$TMP/clone"
BRANCH="article/2026-08-25"

PASS=0
FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   — %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL — %s\n' "$1"; [[ -n "${2:-}" ]] && printf '         %s\n' "$2"; return 0; }

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# A fixture repo with a published article on main and an approved one on a branch,
# rebuilt from scratch for every case so no test can inherit another's state.
build_fixture() {
  rm -rf "$ORIGIN" "$CLONE"
  git init --bare --quiet "$ORIGIN"
  git init --quiet "$CLONE"
  git -C "$CLONE" config user.email "test@example.com"
  git -C "$CLONE" config user.name "Test"
  git -C "$CLONE" config commit.gpgsign false
  git -C "$CLONE" symbolic-ref HEAD refs/heads/main
  mkdir -p "$CLONE/src/content/writing/en"
  echo "old" > "$CLONE/src/content/writing/en/already-published.mdx"
  git -C "$CLONE" add -A
  git -C "$CLONE" commit --quiet -m "chore: base"
  git -C "$CLONE" remote add origin "$ORIGIN"
  git -C "$CLONE" push --quiet -u origin main

  git -C "$CLONE" checkout -b "$BRANCH" --quiet
  echo "new" > "$CLONE/src/content/writing/en/the-new-one.mdx"
  git -C "$CLONE" add -A
  git -C "$CLONE" commit --quiet -m "feat: article — the-new-one"
  git -C "$CLONE" checkout main --quiet
}

reject_pushes() {
  cat > "$ORIGIN/hooks/pre-receive" <<'HOOK'
#!/bin/sh
echo "remote: refusing (test)" >&2
exit 1
HOOK
  chmod +x "$ORIGIN/hooks/pre-receive"
}

run_deploy() {
  env ENVERCETIN_TEST_SILENT=1 \
      ENVERCETIN_REPO="$CLONE" \
      ENVERCETIN_VERIFY_CMD="${VERIFY:-true}" \
      /bin/bash "$DEPLOY" "$BRANCH" > "$TMP/deploy.log" 2>&1
  DEPLOY_RC=$?
}

echo "deploy-scheduled.sh"

# --- 1. The happy path ---------------------------------------------------------
build_fixture
BEFORE="$(git -C "$CLONE" rev-parse main)"
run_deploy

[[ $DEPLOY_RC -eq 0 ]] && ok "a clean publish succeeds" \
  || bad "a clean publish succeeds" "rc=$DEPLOY_RC, last line: $(tail -1 "$TMP/deploy.log")"
[[ "$(git -C "$CLONE" rev-parse main)" == "$(git -C "$ORIGIN" rev-parse main)" ]] \
  && ok "main and the remote agree afterwards" \
  || bad "main and the remote agree afterwards" "local and origin diverged"
git -C "$CLONE" show main:src/content/writing/en/the-new-one.mdx >/dev/null 2>&1 \
  && ok "the article is on main" || bad "the article is on main" "not found"
grep -q "would notify: ✅" "$TMP/deploy.log" \
  && ok "success is reported" || bad "success is reported" "no ✅ notification"
grep -q "the-new-one" "$TMP/deploy.log" \
  && ok "the message names the article" || bad "the message names the article" "slug missing"
git -C "$CLONE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && bad "the branch is cleaned up after a real publish" "$BRANCH survived" \
  || ok "the branch is cleaned up after a real publish"

# --- 2. A rejected push must leave NOTHING behind ------------------------------
# The defect: main kept the merge, the branch was deleted, and Telegram said ✅.
build_fixture
reject_pushes
BEFORE="$(git -C "$CLONE" rev-parse main)"
run_deploy

[[ $DEPLOY_RC -ne 0 ]] && ok "a rejected push fails the run" \
  || bad "a rejected push fails the run" "rc=0 — the failure was swallowed"
[[ "$(git -C "$CLONE" rev-parse main)" == "$BEFORE" ]] \
  && ok "a rejected push rolls main back to where it was" \
  || bad "a rejected push rolls main back to where it was" \
         "main is at $(git -C "$CLONE" rev-parse --short main), was ${BEFORE:0:7} — the article exists only on this Mac"
git -C "$CLONE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && ok "a rejected push keeps the branch, so the work is not lost" \
  || bad "a rejected push keeps the branch, so the work is not lost" "$BRANCH was deleted"
grep -q "would notify: ✅" "$TMP/deploy.log" \
  && bad "a rejected push is never reported as published" "it claimed ✅ anyway" \
  || ok "a rejected push is never reported as published"
grep -q "would notify: ⚠️" "$TMP/deploy.log" \
  && ok "a rejected push is reported as a failure" \
  || bad "a rejected push is reported as a failure" "no ⚠️ notification: $(tail -2 "$TMP/deploy.log")"
[[ -z "$(git -C "$CLONE" status --porcelain)" ]] \
  && ok "a rejected push leaves a clean working tree" \
  || bad "a rejected push leaves a clean working tree" "the next run would refuse to start"

# --- 3. A failing verify still gates, and still rolls back ---------------------
build_fixture
BEFORE="$(git -C "$CLONE" rev-parse main)"
VERIFY=false run_deploy
[[ $DEPLOY_RC -ne 0 ]] && ok "a failing verify fails the run" \
  || bad "a failing verify fails the run" "rc=0"
[[ "$(git -C "$CLONE" rev-parse main)" == "$BEFORE" ]] \
  && ok "a failing verify leaves main untouched" \
  || bad "a failing verify leaves main untouched" "main moved"
[[ "$(git -C "$ORIGIN" rev-parse main)" == "$BEFORE" ]] \
  && ok "a failing verify publishes nothing" \
  || bad "a failing verify publishes nothing" "the remote moved"
git -C "$CLONE" rev-parse --verify "$BRANCH" >/dev/null 2>&1 \
  && ok "a failing verify keeps the branch" || bad "a failing verify keeps the branch" "branch gone"

# --- 4. A busy working tree is not entered ------------------------------------
# Same rule as the guard's, for the hand-run path the watchdog itself recommends.
build_fixture
LOCK="$HOME/Library/Caches/envercetin-guard/repo-$(printf '%s' "$(cd "$CLONE" && pwd -P)" | shasum | cut -c1-12).lock"
rm -rf "$LOCK"; mkdir -p "$LOCK"
echo $$ > "$LOCK/pid"; date +%s > "$LOCK/since"; printf 'weekly-article' > "$LOCK/job"
BEFORE="$(git -C "$CLONE" rev-parse main)"
run_deploy
rm -rf "$LOCK"
[[ $DEPLOY_RC -ne 0 ]] && ok "a hand-run deploy refuses a repo another job is in" \
  || bad "a hand-run deploy refuses a repo another job is in" "it went ahead anyway"
[[ "$(git -C "$CLONE" rev-parse main)" == "$BEFORE" ]] \
  && ok "the busy repo is left exactly as it was" \
  || bad "the busy repo is left exactly as it was" "main moved"

echo
echo "$PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
