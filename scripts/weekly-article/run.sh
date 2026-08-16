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
#   7. On "Publish" the article is SCHEDULED, not published: a one-shot job goes
#      live the following Friday 19:00-21:00 or Saturday 10:00-13:00, at random
#
# Anything that fails sends a Telegram message and stops. The working tree is
# never touched unless it was clean to begin with.
#
# To run it now instead of waiting for Saturday, just execute it:
#   scripts/weekly-article/run.sh

set -euo pipefail

# --resume <branch> picks up a run that died AFTER the article was written —
# skipping topics and writing, and continuing at the verify gate. On 2026-08-15
# the writer finished the article and then hit the monthly spend limit before it
# could print its SLUG line, so run.sh threw away 24 minutes of finished work.
# Nothing downstream of the writer needs a model, so a resume always can run.
RESUME_BRANCH=""
if [[ "${1:-}" == "--resume" ]]; then
  RESUME_BRANCH="${2:?usage: run.sh --resume <branch>}"
fi

# Derived from this script's own location, never hardcoded: moving the repo must
# not require editing it. scripts/weekly-article/run.sh → ../.. is the root.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

# launchd fires a deferred job the instant the Mac wakes, which is usually before
# Wi-Fi is back. Wait for the network rather than dying on the first git call.
source scripts/weekly-article/lib/net.sh
if ! wait_for_network 60; then
  notify "📴 Weekly article skipped: the Mac had no network for an hour after the job fired. Nothing was written. I'll try again next Saturday."
  exit 0
fi

# A resume expects a dirty tree — the half-finished article is the whole point.
if [[ -z "$RESUME_BRANCH" ]]; then
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    notify "⚠️ Weekly article skipped: the repo has uncommitted changes. I did not touch them."
    exit 0
  fi

  git checkout main --quiet
  git pull --ff-only --quiet
fi

CLAUDE_FLAGS=(--model opus --permission-mode acceptEdits
  --allowed-tools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Task,Workflow,TodoWrite,TaskCreate,TaskUpdate")

if [[ -n "$RESUME_BRANCH" ]]; then
  # --- Resume -------------------------------------------------------------------
  # Steps 1-3 already happened in the run that died. Adopt its branch and read the
  # slug off the draft on disk rather than off the writer's stdout, which is the
  # thing that went missing.
  BRANCH="$RESUME_BRANCH"
  if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git checkout "$BRANCH" --quiet
  else
    git checkout -b "$BRANCH" --quiet
  fi

  SLUG="$(
    {
      git status --porcelain --untracked-files=all -- src/content/writing/en/
      git diff --name-only main...HEAD -- src/content/writing/en/
    } 2>/dev/null | grep -oE '[^/ ]+\.mdx' | sed 's/\.mdx$//' | sort -u | head -1
  )"

  if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
    notify "⚠️ Resume of \`$BRANCH\` found no article to publish. Nothing was done. Log: $LOG"
    exit 1
  fi
  echo "resuming $BRANCH at the verify gate — slug: $SLUG"
else
  # --- 1. Propose topics --------------------------------------------------------
  # What counts as "already covered" is NOT what is in the working tree. Approved
  # articles wait on their own branch for up to a week before merging, so during
  # that week the subject is finished and scheduled while `src/content/writing/en/`
  # still looks empty of it. On 2026-08-15 the proposer offered the exact article
  # that was queued to publish the next morning. Ask git, across every branch.
  COVERED="$(
    {
      git ls-tree -r --name-only main src/content/writing/en/
      for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/article/*'); do
        git ls-tree -r --name-only "$b" src/content/writing/en/
      done
    } 2>/dev/null | sed 's|.*/||; s|\.[^.]*$||' | sort -u
  )"
  echo "already covered: $(printf '%s' "$COVERED" | tr '\n' ' ')"

  echo "--- proposing topics"
  PROPOSE_PROMPT="$(cat scripts/weekly-article/prompts/propose-topics.md)

ALREADY COVERED — published, or written and waiting for its scheduled publish:
$COVERED"
  TOPICS_JSON="$(claude -p "$PROPOSE_PROMPT" "${CLAUDE_FLAGS[@]}" | sed -n '/\[/,/\]/p')"

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

  # The writer prints SLUG last. If it dies after writing the article but before
  # printing — a crash, a spend limit — the article is on disk and only this line
  # is missing. Say so, so the work can be resumed instead of rewritten.
  SLUG="$(printf '%s\n' "$WRITE_OUT" | grep '^SLUG: ' | tail -1 | sed 's/^SLUG: //' | tr -d '[:space:]')"
  if [[ -z "$SLUG" || ! -f "src/content/writing/en/$SLUG.mdx" ]]; then
    DRAFT="$(git status --porcelain --untracked-files=all -- src/content/writing/en/ | grep -c '\.mdx' || true)"
    if [[ "$DRAFT" -gt 0 ]]; then
      notify "⚠️ Weekly article: the writer stopped before naming its article, but a draft IS on \`$BRANCH\`.

Resume it with:
scripts/weekly-article/run.sh --resume $BRANCH

Log: $LOG"
    else
      notify "⚠️ Weekly article: no usable article was produced. Branch $BRANCH kept locally. Log: $LOG"
    fi
    exit 1
  fi
fi

# --- 4. Hard gate -------------------------------------------------------------
echo "--- verifying"
if ! npm run verify > "$LOG_DIR/$STAMP-verify.log" 2>&1; then
  notify "⚠️ Weekly article: \`npm run verify\` failed, so nothing was deployed. Branch $BRANCH is on your Mac. Log: $LOG_DIR/$STAMP-verify.log"
  exit 1
fi

# A writing run creates a throwaway page to look at its own figure. It is not
# part of the article, and `git add -A` would otherwise commit and publish it.
rm -f src/pages/diagram-preview.astro src/pages/preview.astro
git add -A
git commit --quiet -m "feat: article — $SLUG"

# --- 5. Preview (local tree → Vercel; nothing pushed to GitHub) ---------------
echo "--- deploying preview"
PREVIEW="$(vercel deploy --yes 2>/dev/null | grep -Eo 'https://[a-z0-9.-]+\.vercel\.app' | tail -1)"
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

# --- 7. Schedule the publish ---------------------------------------------------
# Approved articles do not go live immediately. They are held and published at a
# randomised time in one of two windows — the following Friday 19:00-21:00 or the
# following Saturday 10:00-13:00 — so the site does not read as cron-driven.
echo "--- scheduling publish"
git checkout main --quiet
SLOT="$(python3 scripts/weekly-article/lib/schedule_publish.py "$BRANCH")"
SLOT_HUMAN="${SLOT#*|}"

notify "🗓 Approved. \"$SLUG\" is scheduled to go live on $SLOT_HUMAN.

Preview stays up: $PREVIEW
To cancel: launchctl bootout gui/\$(id -u)/com.enver.envercetin.publish-${SLOT%%|*}"
echo "scheduled for $SLOT_HUMAN"
echo "=== done $(date +%H:%M:%S) ==="
