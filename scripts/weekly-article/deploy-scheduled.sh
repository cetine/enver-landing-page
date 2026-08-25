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
#
# The rule this script exists to keep: after it finishes, either the article is
# on GitHub, or the repo looks exactly as it did before it started. Never both,
# never neither, and never a claim that is not checked.

set -euo pipefail

BRANCH="${1:?usage: deploy-scheduled.sh <branch> [launchd-label]}"
LABEL="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ENVERCETIN_REPO and ENVERCETIN_VERIFY_CMD are test seams. The tests drive this
# script against a real bare repo in a temp dir — a publish script whose failure
# paths are only ever exercised in production is how the 2026-08-22 hole happened.
REPO="${ENVERCETIN_REPO:-$(cd "$HERE/../.." && pwd)}"
VERIFY_CMD="${ENVERCETIN_VERIFY_CMD:-npm run verify}"
PERSONAL_OS="/Users/ece/Projects/personal-os"
TG="$PERSONAL_OS/tg.py"
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
LOG="$LOG_DIR/deploy-$(date +%Y-%m-%d-%H%M).log"

# Anything that talks to the network can hang instead of failing, and a hang here
# holds the repo lock until the sweeper's cap expires. Bound them.
NET_TIMEOUT="${ENVERCETIN_NET_TIMEOUT_SEC:-600}"
VERIFY_TIMEOUT="${ENVERCETIN_VERIFY_TIMEOUT_SEC:-2700}"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "=== scheduled deploy of $BRANCH — $(date) ==="

# shellcheck source=lib/with_timeout.sh
source "$HERE/lib/with_timeout.sh"
# shellcheck source=lib/repo_lock.sh
source "$HERE/lib/repo_lock.sh"

# Queues what it cannot send — see scripts/weekly-article/notify.sh.
notify() {
  # First, before anything that could reach Telegram: the tests run this script
  # end to end, and a test suite that messages Enver is a test suite nobody runs.
  if [[ -n "${ENVERCETIN_TEST_SILENT:-}" ]]; then
    echo "[test-silent] would notify: $1"
    return 0
  fi
  if command -v envercetin-notify >/dev/null 2>&1; then
    envercetin-notify "$1" || true
  else
    (cd "$PERSONAL_OS" && python3 "$TG" send "$1") || echo "TELEGRAM FAILED: $1"
  fi
}
trap 'echo "FAILED at line $LINENO"; notify "⚠️ Scheduled deploy of $BRANCH failed at line $LINENO. Nothing was published. Log: $LOG"' ERR

cd "$REPO"

# One job at a time in this working tree. The guard already holds this lock when
# it started us, and repo_lock_hold recognises that; this matters for the hand-run
# path the watchdog recommends, at 20:58 on a Friday with a job due at 21:00.
if ! repo_lock_hold "$REPO" "deploy-scheduled.sh $BRANCH"; then
  echo "repo busy: $REPO_LOCK_BUSY_JOB (pid $REPO_LOCK_BUSY_PID)"
  notify "⚠️ Scheduled deploy of $BRANCH skipped: \`$REPO_LOCK_BUSY_JOB\` is working in the repo right now. Nothing was published — start it again once that has finished."
  exit 1
fi

# No connectivity handling here: the guard waits for the network before starting
# this script, and on timeout re-arms this exact invocation instead of giving up.
# A publish is approved, finished work, so losing it to hotel Wi-Fi is not an
# option — but that guarantee belongs in one place, and the guard is it.
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  notify "⚠️ Scheduled deploy skipped: the repo has uncommitted changes. Nothing was published."
  exit 0
fi

if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  notify "⚠️ Scheduled deploy skipped: branch $BRANCH no longer exists."
  exit 0
fi

git checkout main --quiet
if ! with_timeout "$NET_TIMEOUT" git pull --ff-only --quiet; then
  notify "⚠️ Scheduled deploy of $BRANCH stopped: \`git pull\` failed or hung. Nothing was published, nothing was changed."
  exit 1
fi

# Where to return to if anything below fails. NOT origin/main: main can legitimately
# hold local commits that are not pushed yet, and resetting to origin would throw
# them away while "aborting safely".
MAIN_BEFORE="$(git rev-parse main)"

# Undo everything this run did to main. Called on every path that ends without a
# published article, so the repo is left exactly as it was found — which is also
# what makes the watchdog's alarms tell the truth afterwards.
rollback() {
  git checkout main --quiet 2>/dev/null || true
  git reset --hard "$MAIN_BEFORE" --quiet
}

# The branch was cut days ago and main has probably moved since — another article
# may have published in between. Replay the branch on top instead of demanding a
# fast-forward: an ff-only merge against a moved main cannot succeed, and `verify`
# below is what actually gates the result. (This is why the 2026-08-12 article
# would have failed to publish even once its path problem was fixed.)
if ! git rebase main "$BRANCH" --quiet; then
  git rebase --abort 2>/dev/null || true
  git checkout main --quiet
  notify "⚠️ Scheduled deploy aborted: \`$BRANCH\` conflicts with main and needs a human. Nothing was published."
  exit 1
fi
git checkout main --quiet
git merge --ff-only "$BRANCH" --quiet

# The gate. A branch that was fine days ago can still break against a moved main.
echo "--- verifying"
if ! with_timeout "$VERIFY_TIMEOUT" bash -c "$VERIFY_CMD" > "$LOG_DIR/deploy-verify.log" 2>&1; then
  rollback
  notify "⚠️ Scheduled deploy aborted: \`$VERIFY_CMD\` failed or hung. main is untouched. Log: $LOG_DIR/deploy-verify.log"
  exit 1
fi

SLUG="$(git show --name-only --format= "$BRANCH" | grep -oE 'src/content/writing/en/[^/]+\.mdx$' | head -1 | sed 's|.*/||; s|\.mdx$||')"

echo "--- pushing (this is what deploys production)"
if ! with_timeout "$NET_TIMEOUT" git push --quiet; then
  # Without this rollback the article sat merged into LOCAL main and nowhere else,
  # the branch was deleted, and the watchdog — which reads local main — reported
  # a healthy, freshly published site. A hole in the archive with every alarm green.
  rollback
  notify "⚠️ Scheduled deploy of \`${SLUG:-$BRANCH}\` failed at the push: GitHub did not accept it.

Nothing was published and I put main back exactly as it was. The article is still on \`$BRANCH\`. Try again with:
$REPO/scripts/weekly-article/deploy-scheduled.sh $BRANCH

Log: $LOG"
  exit 1
fi

# `git push` returning 0 is not proof the article is on GitHub — and "✅ Published"
# used to be sent on exactly that assumption. Ask the remote.
if ! with_timeout "$NET_TIMEOUT" git fetch --quiet origin main; then
  notify "⚠️ \`${SLUG:-$BRANCH}\` was pushed, but I could not reach GitHub afterwards to confirm it landed.

I left \`$BRANCH\` in place on purpose. Check https://envercetin.de/writing/${SLUG:-} — if it is there, nothing needs doing; the branch will clean itself up on the next attempt. Log: $LOG"
  exit 1
fi

# Ancestry rather than equality: someone else pushing between our push and this
# check moves origin/main ahead of us, and our commit is still on it.
if ! git merge-base --is-ancestor main origin/main 2>/dev/null; then
  rollback
  notify "⚠️ Scheduled deploy of \`${SLUG:-$BRANCH}\` reported success but GitHub does not have the commit.

Nothing was published and main is back where it was. The article is still on \`$BRANCH\`. Log: $LOG"
  exit 1
fi
echo "confirmed on origin/main: $(git rev-parse --short main)"

git branch -d "$BRANCH" --quiet || true

notify "✅ Published as scheduled: https://envercetin.de/writing/${SLUG:-}

GitHub has it and Vercel is building — give it a minute."
echo "=== done $(date) ==="

# Remove the one-shot schedule so it cannot fire again next year.
if [[ -n "$LABEL" ]]; then
  # Delete the file FIRST. This script runs under $LABEL, via the guard, so
  # `launchctl bootout` on it terminates this very process — on 2026-08-16 it did,
  # swallowing the "removed" line, the guard's exit-code report and its lock
  # cleanup, and it is only luck that the push had already happened. Removing the
  # plist is what actually matters: a one-shot job whose StartCalendarInterval has
  # passed cannot fire again, and with no file it is not reloaded at next login.
  rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
  if [[ "${XPC_SERVICE_NAME:-}" != "$LABEL" ]]; then
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  fi
  echo "one-shot schedule $LABEL removed"
fi
