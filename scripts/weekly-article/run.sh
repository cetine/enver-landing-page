#!/usr/bin/env bash
#
# Weekly article pipeline — fires Saturdays 14:00 via launchd.
#
#   1. Claude proposes 4 topics (web-researched, checked against what is already published)
#   2. Telegram asks Enver: tap a proposal, or type a topic of his own
#   3. Claude researches and writes the article on a local branch, in ultracode
#   4. `npm run verify` is a hard gate
#   5. `vercel deploy` publishes a PREVIEW from the local tree — nothing reaches
#      GitHub, and nothing reaches production, before Enver has seen it
#   6. Telegram asks for approval, with the preview link
#   7. Only on "Publish" does the branch merge to main, push, and go to production
#
# Anything that fails sends a Telegram message and stops. The working tree is
# never touched unless it was clean to begin with.
#
# To run it now instead of waiting for Saturday, just execute it:
#   scripts/weekly-article/run.sh

set -euo pipefail

REPO="/Users/ece/Documents/Documents - MB-928749/EnverLandingPage"
TG="/Users/ece/Projects/personal-os/tg.py"
PERSONAL_OS="/Users/ece/Projects/personal-os"
LOG_DIR="$HOME/Library/Logs/envercetin-weekly-article"
STAMP="$(date +%Y-%m-%d)"
LOG="$LOG_DIR/$STAMP.log"

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG") 2>&1
echo "=== weekly-article $STAMP $(date +%H:%M:%S) ==="

notify() { (cd "$PERSONAL_OS" && python3 "$TG" send "$1") || echo "TELEGRAM SEND FAILED: $1"; }

on_error() {
  local line=$1
  echo "FAILED at line $line"
  notify "⚠️ Weekly article failed at line $line. Log: $LOG"
}
trap 'on_error $LINENO' ERR

# --- Preconditions ------------------------------------------------------------
cd "$REPO"

if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  notify "⚠️ Weekly article skipped: the repo has uncommitted changes. I did not touch them."
  exit 0
fi

git checkout main --quiet
git pull --ff-only --quiet

CLAUDE_FLAGS=(--model opus --permission-mode acceptEdits
  --allowed-tools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,Workflow,TodoWrite,TaskCreate,TaskUpdate")

# --- 1. Propose topics --------------------------------------------------------
echo "--- proposing topics"
TOPICS_JSON="$(claude -p "$(cat scripts/weekly-article/prompts/propose-topics.md)" \
  "${CLAUDE_FLAGS[@]}" | sed -n '/\[/,/\]/p')"

if [[ -z "$TOPICS_JSON" ]]; then
  notify "⚠️ Weekly article: topic proposal returned nothing. Log: $LOG"
  exit 1
fi
echo "$TOPICS_JSON" > "$LOG_DIR/$STAMP-topics.json"

LIB="scripts/weekly-article/lib/topics.py"
QUESTION="$(python3 "$LIB" question "$LOG_DIR/$STAMP-topics.json")"
OPTIONS="$(python3 "$LIB" options "$LOG_DIR/$STAMP-topics.json")"

# --- 2. Ask Enver -------------------------------------------------------------
echo "--- asking for the topic"
set +e
ASK_OUT="$(cd "$PERSONAL_OS" && python3 "$TG" ask "$QUESTION" --options "$OPTIONS" --timeout-min 240)"
ASK_RC=$?
set -e

if [[ $ASK_RC -eq 2 ]]; then
  notify "No reply in 4 h — skipping this week's article. Nothing was written."
  exit 0
elif [[ $ASK_RC -ne 0 ]]; then
  notify "⚠️ Weekly article: Telegram ask failed (rc=$ASK_RC). Log: $LOG"
  exit 1
fi

TOPIC="$(printf '%s\n' "$ASK_OUT" | grep '^REPLY: ' | tail -1 | sed 's/^REPLY: //')"
if [[ -z "$TOPIC" ]]; then
  notify "⚠️ Weekly article: could not read your reply. Log: $LOG"
  exit 1
fi
echo "topic: $TOPIC"

# If Enver tapped a button, hand the full proposal to the writer, not just the label.
TOPIC_BRIEF="$(python3 "$LIB" brief "$LOG_DIR/$STAMP-topics.json" "$TOPIC")"

# --- 3. Write -----------------------------------------------------------------
BRANCH="article/$STAMP"
git checkout -b "$BRANCH" --quiet
notify "✍️ Writing this week's article: $TOPIC — I'll send a preview link when it's ready."

echo "--- writing"
PROMPT="$(sed "s|{{TOPIC}}|$TOPIC_BRIEF|" scripts/weekly-article/prompts/write-article.md)"
WRITE_OUT="$(claude -p "$PROMPT" "${CLAUDE_FLAGS[@]}")"
echo "$WRITE_OUT" | tail -40

SLUG="$(printf '%s\n' "$WRITE_OUT" | grep '^SLUG: ' | tail -1 | sed 's/^SLUG: //' | tr -d '[:space:]')"
if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
  notify "⚠️ Weekly article: no usable article was produced. Branch $BRANCH kept locally. Log: $LOG"
  exit 1
fi

# --- 4. Hard gate -------------------------------------------------------------
echo "--- verifying"
if ! npm run verify > "$LOG_DIR/$STAMP-verify.log" 2>&1; then
  notify "⚠️ Weekly article: \`npm run verify\` failed, so nothing was deployed. Branch $BRANCH is on your Mac. Log: $LOG_DIR/$STAMP-verify.log"
  exit 1
fi

git add -A
git commit --quiet -m "feat: article — $SLUG"

# --- 5. Preview (local tree → Vercel; nothing pushed to GitHub) ---------------
echo "--- deploying preview"
PREVIEW="$(vercel deploy --yes 2>/dev/null | grep -Eo 'https://[^[:space:]]+' | tail -1)"
if [[ -z "$PREVIEW" ]]; then
  notify "⚠️ Weekly article: preview deploy produced no URL. Branch $BRANCH is committed locally. Log: $LOG"
  exit 1
fi
echo "preview: $PREVIEW"

# --- 6. Approval --------------------------------------------------------------
set +e
APPROVE_OUT="$(cd "$PERSONAL_OS" && python3 "$TG" ask \
  "📄 This week's article is ready.

$PREVIEW/writing/$SLUG

Publish it to envercetin.de?" \
  --options "Publish,Keep as draft" --timeout-min 720)"
APPROVE_RC=$?
set -e

APPROVAL="$(printf '%s\n' "$APPROVE_OUT" | grep '^REPLY: ' | tail -1 | sed 's/^REPLY: //')"

if [[ $APPROVE_RC -ne 0 || "$APPROVAL" != "Publish" ]]; then
  git checkout main --quiet
  notify "Article kept as a draft on branch \`$BRANCH\`. Nothing was published. Preview stays at $PREVIEW"
  exit 0
fi

# --- 7. Publish ---------------------------------------------------------------
echo "--- publishing"
git checkout main --quiet
git merge --ff-only "$BRANCH" --quiet
git push --quiet
# Explicit production promotion, so this works whether or not the GitHub
# integration is connected. A duplicate build is harmless; drop this line if the
# Git integration already deploys main.
PROD="$(vercel deploy --prod --yes 2>/dev/null | grep -Eo 'https://[^[:space:]]+' | tail -1)"
git branch -d "$BRANCH" --quiet || true

notify "✅ Published: https://envercetin.de/writing/$SLUG"
echo "=== done $(date +%H:%M:%S) ==="
