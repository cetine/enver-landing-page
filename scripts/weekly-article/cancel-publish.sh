#!/usr/bin/env bash
#
# Call off a scheduled publish.
#
#   cancel-publish.sh <branch>              cancel it, keep the work as draft/<name>
#   cancel-publish.sh <launchd-label>       same, addressed by the job's label
#   cancel-publish.sh <branch> --delete-branch   throw the article away as well
#   cancel-publish.sh <branch> --keep-branch     leave the branch as article/<name>
#   cancel-publish.sh --list                show what is scheduled, change nothing
#
# Why this exists: run.sh used to tell you to cancel with
#
#   launchctl bootout gui/$(id -u)/com.enver.envercetin.publish-...
#
# which unloads the job and leaves the plist sitting in ~/Library/LaunchAgents.
# At the next login launchd reads that directory again, and the article you had
# withdrawn goes live on a date you have long forgotten. Deleting the file is
# what actually cancels a one-shot job; unloading it is the optional half.
#
# The branch matters just as much. An `article/*` branch with no publish job is
# precisely the shape watchdog.sh reports as "written and stuck" — so cancelling
# without moving it turns one decision into a reminder every Tuesday and
# Saturday for the rest of the year. Renaming to `draft/*` keeps the work, keeps
# it findable, and stops the alarm. It is reversible in one command:
#
#   git branch -m draft/<name> article/<name>

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${ENVERCETIN_REPO:-$(cd "$HERE/../.." && pwd)}"
AGENTS="${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
PERSONAL_OS="${ENVERCETIN_PERSONAL_OS:-/Users/ece/Projects/personal-os}"
UID_NUM="$(id -u)"

notify() {
  if [[ -n "${ENVERCETIN_TEST_SILENT:-}" ]]; then
    echo "[test-silent] would notify: $1"
    return 0
  fi
  if command -v envercetin-notify >/dev/null 2>&1; then
    envercetin-notify "$1" || true
  else
    (cd "$PERSONAL_OS" && python3 tg.py send "$1") >/dev/null 2>&1 || true
  fi
}

usage() {
  sed -n '3,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# Every pending publish job, as "<label>\t<branch>".
pending() {
  local plist label branch
  for plist in "$AGENTS"/com.enver.envercetin.publish-*.plist; do
    [[ -f "$plist" ]] || continue
    label="$(basename "$plist" .plist)"
    # The branch is the ProgramArguments entry that looks like one.
    branch="$(grep -oE '<string>(article|draft)/[^<]+</string>' "$plist" 2>/dev/null \
      | head -1 | sed 's|<string>||; s|</string>||')"
    printf '%s\t%s\n' "$label" "${branch:-unknown}"
  done
}

TARGET="${1:-}"
MODE="${2:-}"

if [[ -z "$TARGET" ]]; then
  usage >&2
  exit 64
fi

if [[ "$TARGET" == "--list" ]]; then
  if [[ -z "$(pending)" ]]; then
    echo "nothing is scheduled to publish."
  else
    echo "scheduled publishes:"
    pending | while IFS=$'\t' read -r label branch; do
      printf '  %s  →  %s\n' "$label" "$branch"
    done
  fi
  exit 0
fi

cd "$REPO" || { echo "cannot reach $REPO" >&2; exit 66; }

# --- Resolve the target -------------------------------------------------------
LABELS=()
BRANCH=""
if [[ "$TARGET" == com.enver.envercetin.publish-* ]]; then
  [[ -f "$AGENTS/$TARGET.plist" ]] || { echo "no scheduled publish with label $TARGET" >&2; exit 1; }
  LABELS=("$TARGET")
  BRANCH="$(pending | awk -F'\t' -v l="$TARGET" '$1 == l {print $2}' | head -1)"
else
  BRANCH="$TARGET"
  while IFS=$'\t' read -r label branch; do
    [[ "$branch" == "$BRANCH" ]] && LABELS+=("$label")
  done < <(pending)
  if [[ ${#LABELS[@]} -eq 0 ]]; then
    echo "no scheduled publish found for $BRANCH" >&2
    echo >&2
    echo "What is scheduled:" >&2
    pending >&2 || true
    exit 1
  fi
fi

# --- Never interrupt a publish that is already under way ----------------------
# Deleting the plist out from under a running deploy takes away the label it
# cleans itself up with, in the middle of a push.
for label in "${LABELS[@]}"; do
  lock="$LOCK_ROOT/$label.lock"
  [[ -d "$lock" ]] || continue
  pid="$(cat "$lock/pid" 2>/dev/null || echo "")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "$label is publishing right now (pid $pid) — refusing to cancel it mid-flight." >&2
    echo "Wait for it to finish; if it published, there is nothing left to cancel." >&2
    exit 1
  fi
done

# --- Cancel -------------------------------------------------------------------
# File first, then unload: the file is what makes the job come back at the next
# login, and `launchctl bootout` can terminate the caller when the label happens
# to be its own.
for label in "${LABELS[@]}"; do
  rm -f "$AGENTS/$label.plist"
  launchctl bootout "gui/$UID_NUM/$label" 2>/dev/null
  echo "cancelled $label"
done

# --- What happens to the article ----------------------------------------------
ACTION="kept"
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
  case "$MODE" in
    --delete-branch)
      CURRENT="$(git rev-parse --abbrev-ref HEAD)"
      [[ "$CURRENT" == "$BRANCH" ]] && git checkout main --quiet
      git branch -D "$BRANCH" --quiet
      ACTION="deleted"
      echo "deleted branch $BRANCH"
      ;;
    --keep-branch)
      echo "branch $BRANCH left as it is — the watchdog will keep reminding you about it,"
      echo "which is what you want if you mean to reschedule it."
      ;;
    *)
      DRAFT="draft/${BRANCH#article/}"
      if git rev-parse --verify "$DRAFT" >/dev/null 2>&1; then
        echo "branch $DRAFT already exists — leaving $BRANCH alone" >&2
      else
        CURRENT="$(git rev-parse --abbrev-ref HEAD)"
        [[ "$CURRENT" == "$BRANCH" ]] && git checkout main --quiet
        git branch -m "$BRANCH" "$DRAFT"
        ACTION="renamed to $DRAFT"
        echo "renamed $BRANCH → $DRAFT (undo with: git branch -m $DRAFT $BRANCH)"
      fi
      ;;
  esac
else
  echo "branch $BRANCH does not exist locally — cancelled the schedule only"
fi

notify "🚫 Publish cancelled: \`$BRANCH\` will not go live. The article was $ACTION."
