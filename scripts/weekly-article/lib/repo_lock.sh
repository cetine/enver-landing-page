#!/usr/bin/env bash
#
# One article job at a time per working tree — for scripts started by hand.
#
#   source lib/repo_lock.sh
#   repo_lock_hold "$REPO" "run.sh" || exit 1
#
# guard.sh carries its own copy of this rule, because it is installed OUTSIDE the
# repo on purpose and cannot source anything from inside it. What the two share is
# the convention, and it has to stay identical in both places:
#
#   ~/Library/Caches/envercetin-guard/repo-<12 hex of sha1 of the physical path>.lock
#   containing  pid  (the holder),  since  (epoch it was taken),  job  (who)
#
# The reason this exists on the hand-run side at all: the watchdog's own advice is
# "run deploy-scheduled.sh <branch>", and a human following it at 20:58 on a
# Friday would otherwise land in the same working tree as the job scheduled for
# 21:00 — two `git checkout`s, one article.

# shellcheck shell=bash

REPO_LOCK_ROOT="$HOME/Library/Caches/envercetin-guard"
REPO_LOCK_DIR=""
REPO_LOCK_BUSY_JOB=""
REPO_LOCK_BUSY_PID=""

repo_lock_path() {
  printf '%s/repo-%s.lock' "$REPO_LOCK_ROOT" \
    "$(printf '%s' "$(cd "$1" && pwd -P)" | shasum | cut -c1-12)"
}

repo_lock_free() {
  [[ -n "$REPO_LOCK_DIR" ]] && rm -rf "$REPO_LOCK_DIR"
  REPO_LOCK_DIR=""
}

# 0 = go ahead, 1 = someone else is working in there.
repo_lock_hold() {
  local repo="$1" who="${2:-manual}" dir attempt
  dir="$(repo_lock_path "$repo")"

  # Started BY the guard, which already took this exact lock on our behalf. It
  # holds it for the whole run and releases it when the run ends, so taking it
  # again here would deadlock the pipeline against itself.
  if [[ -n "${ENVERCETIN_REPO_LOCK:-}" && "$ENVERCETIN_REPO_LOCK" == "$dir" && -d "$dir" ]]; then
    return 0
  fi

  mkdir -p "$REPO_LOCK_ROOT" 2>/dev/null

  # Two attempts: the second one is for the case where the first found a lock
  # whose holder no longer exists and cleared it.
  for attempt in 1 2; do
    if mkdir "$dir" 2>/dev/null; then
      echo $$ > "$dir/pid"
      date +%s > "$dir/since"
      printf '%s' "$who" > "$dir/job"
      REPO_LOCK_DIR="$dir"
      trap repo_lock_free EXIT
      return 0
    fi

    REPO_LOCK_BUSY_PID="$(cat "$dir/pid" 2>/dev/null || echo "")"
    REPO_LOCK_BUSY_JOB="$(cat "$dir/job" 2>/dev/null || echo unknown)"
    if [[ -n "$REPO_LOCK_BUSY_PID" ]] && kill -0 "$REPO_LOCK_BUSY_PID" 2>/dev/null; then
      return 1
    fi
    # The holder is gone. Clearing a dead lock is safe; killing a live one is not,
    # and that judgement deliberately lives only in guard.sh, where a run that
    # has hung past its cap can be reported as it is killed.
    rm -rf "$dir"
  done
  return 1
}
