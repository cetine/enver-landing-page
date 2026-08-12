#!/usr/bin/env bash
#
# One-shot scheduled publish of an already-written article branch.
#
#   deploy-scheduled.sh <branch> [launchd-label]
#
# Merges the branch into main, re-runs the full verify suite as a hard gate, and
# pushes. Pushing main is what deploys production — the Vercel GitHub
# integration builds from it. Nothing here talks to Vercel directly.
#
# If a launchd label is given, the job unloads and deletes itself afterwards, so
# a date-pinned schedule cannot fire again a year later.

set -euo pipefail

BRANCH="${1:?usage: deploy-scheduled.sh <branch> [launchd-label]}"
LABEL="${2:-}"
REPO="/Users/ece/Documents/Documents - MB-928749/EnverLandingPage"
PERSONAL_OS="/Users/ece/Projects/personal-os"
TG="$PERSONAL_OS/tg.py"
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
LOG="$LOG_DIR/deploy-$(date +%Y-%m-%d-%H%M).log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "=== scheduled deploy of $BRANCH — $(date) ==="

notify() { (cd "$PERSONAL_OS" && python3 "$TG" send "$1") || echo "TELEGRAM FAILED: $1"; }
trap 'echo "FAILED at line $LINENO"; notify "⚠️ Scheduled deploy of $BRANCH failed at line $LINENO. Nothing was published. Log: $LOG"' ERR

cd "$REPO"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  notify "⚠️ Scheduled deploy skipped: the repo has uncommitted changes. Nothing was published."
  exit 0
fi

if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  notify "⚠️ Scheduled deploy skipped: branch $BRANCH no longer exists."
  exit 0
fi

git checkout main --quiet
git pull --ff-only --quiet
git merge --ff-only "$BRANCH" --quiet

# The gate. A branch that was fine days ago can still break against a moved main.
echo "--- verifying"
if ! npm run verify > "$LOG_DIR/deploy-verify.log" 2>&1; then
  git reset --hard origin/main --quiet
  notify "⚠️ Scheduled deploy aborted: \`npm run verify\` failed. main is untouched. Log: $LOG_DIR/deploy-verify.log"
  exit 1
fi

SLUG="$(git show --name-only --format= "$BRANCH" | grep -oE 'src/content/writing/en/[^/]+\.mdx$' | head -1 | sed 's|.*/||; s|\.mdx$||')"

echo "--- pushing (this is what deploys production)"
git push --quiet
git branch -d "$BRANCH" --quiet || true

notify "✅ Published as scheduled: https://envercetin.de/writing/${SLUG:-}"
echo "=== done $(date) ==="

# Remove the one-shot schedule so it cannot fire again next year.
if [[ -n "$LABEL" ]]; then
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
  echo "one-shot schedule $LABEL removed"
fi
