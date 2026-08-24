#!/usr/bin/env bash
#
# Deadline watchdog for the weekly article pipeline.
#
#   watchdog.sh [--check]     # --check prints the report and sends nothing
#
# Runs Saturdays and Tuesdays at 10:00, independently of the pipeline it watches.
# That independence is the whole point: on 2026-08-22 every part of the pipeline
# that could have raised the alarm was itself the part that broke, and two weeks
# went by in silence — one article written and never published, one never written.
#
# It never reports success. Silence means healthy; a message means something needs
# a human. Saturday is the pre-flight (today is a writing day — is last week's
# work actually out?), Tuesday is the post-mortem (Saturday has been and gone —
# did anything come of it?).
#
# Everything it checks is local state. It needs the network only to deliver, and
# envercetin-notify spools what it cannot send.

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Seams, so the tests can build each broken state without touching the real
# schedule. A watchdog you cannot safely test is one you find out about the same
# way you found out about everything else: too late.
LABEL="${ENVERCETIN_LABEL:-com.enver.envercetin.weekly-article}"
AGENTS="${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
BIN_DIR="${ENVERCETIN_BIN_DIR:-$HOME/.local/bin}"
UID_NUM="$(id -u)"
MAX_DAYS="${ENVERCETIN_MAX_DAYS:-10}"
# Which ref counts as published. Only the tests ever override it, so the quiet-site
# alarm can be driven from real history rather than a fabricated timestamp.
MAIN_REF="${ENVERCETIN_MAIN_REF:-main}"
CHECK_ONLY=no
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=yes

cd "$REPO" || { echo "cannot reach $REPO" >&2; exit 66; }

PROBLEMS=()
add() { PROBLEMS+=("$1"); }

# --- 1. Is the schedule even there? -------------------------------------------
# A job that has been booted out, or whose plist was lost, fails by doing nothing
# at all — the quietest failure of the lot.
if ! launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  add "• The weekly job is not loaded in launchd. Nothing will run on Saturday.
  Fix: $REPO/scripts/weekly-article/install.sh"
fi

# --- 2. Is the installed guard the one in the repo? ---------------------------
# The guard runs from ~/.local/bin so it survives the repo moving. The cost of
# that is drift: editing guard.sh in the repo changes nothing until it is
# installed, so a fix can look done and not be.
for pair in "guard.sh:$BIN_DIR/envercetin-guard" "notify.sh:$BIN_DIR/envercetin-notify"; do
  src="$REPO/scripts/weekly-article/${pair%%:*}"
  dst="${pair#*:}"
  if [[ ! -x "$dst" ]]; then
    add "• $dst is missing. Fix: $REPO/scripts/weekly-article/install.sh"
  elif ! cmp -s "$src" "$dst"; then
    add "• $dst is out of date — the repo has a newer ${pair%%:*}.
  Fix: $REPO/scripts/weekly-article/install.sh"
  fi
done

# --- 3. An approved article that never went out -------------------------------
# This is the 2026-08-22 shape exactly: run.sh wrote the article, Enver approved
# it, schedule_publish.py armed a one-shot job — and the job died. The branch sits
# there, the plist sits there pinned to a date that has passed, and nothing ever
# says so. A pending publish is only healthy while its job is still in the future.
NOW_EPOCH="$(date +%s)"
for branch in $(git for-each-ref --format='%(refname:short)' 'refs/heads/article/*' 2>/dev/null); do
  pending=no
  for plist in "$AGENTS"/com.enver.envercetin.publish-*.plist; do
    [[ -f "$plist" ]] || continue
    grep -q "<string>$branch</string>" "$plist" 2>/dev/null || continue
    # Read the date the job is pinned to and compare it with now.
    fire="$(python3 - "$plist" <<'PY' 2>/dev/null
import plistlib, sys, datetime as dt
with open(sys.argv[1], "rb") as fh:
    cal = plistlib.load(fh).get("StartCalendarInterval", {})
if not cal:
    sys.exit(1)
now = dt.datetime.now()
print(int(dt.datetime(now.year, cal.get("Month", now.month), cal.get("Day", now.day),
                      cal.get("Hour", 0), cal.get("Minute", 0)).timestamp()))
PY
)"
    if [[ -n "$fire" ]] && (( fire > NOW_EPOCH )); then
      pending=yes
    else
      add "• \`$branch\` was approved and scheduled, but its publish job was due $(date -r "${fire:-$NOW_EPOCH}" '+%d.%m. um %H:%M') and never ran.
  The article is written and sitting on your Mac, unpublished.
  Fix: $REPO/scripts/weekly-article/deploy-scheduled.sh $branch"
      pending=yes   # reported; do not also report it as an orphan below
    fi
  done
  if [[ "$pending" == no ]]; then
    add "• \`$branch\` exists but nothing is scheduled to publish it. It is written and stuck.
  Fix: $REPO/scripts/weekly-article/deploy-scheduled.sh $branch"
  fi
done

# --- 4. How long since anything actually reached the site? --------------------
# The end-to-end question, and the only one that catches a failure mode nobody
# has thought of yet: whatever went wrong, did an article come out or not?
LAST_ADD="$(git log -1 --format=%ct --diff-filter=A "$MAIN_REF" -- src/content/writing/en/ 2>/dev/null)"
if [[ -z "$LAST_ADD" ]]; then
  add "• No published article found in git history at all. Something is very wrong with $REPO."
else
  DAYS=$(( (NOW_EPOCH - LAST_ADD) / 86400 ))
  if (( DAYS > MAX_DAYS )); then
    add "• The last article went live $DAYS days ago ($(date -r "$LAST_ADD" '+%d.%m.')). Expected roughly weekly.
  Nothing is queued either — the pipeline has produced nothing for two cycles."
  fi
fi

# --- Report -------------------------------------------------------------------
if [[ ${#PROBLEMS[@]} -eq 0 ]]; then
  echo "watchdog: healthy — last article $(date -r "${LAST_ADD:-$NOW_EPOCH}" '+%d.%m.'), schedule loaded, guard current"
  exit 0
fi

# Command substitution eats trailing newlines, so a single finding used to run
# straight into the closing sentence. Join the findings explicitly instead.
BODY=""
for problem in "${PROBLEMS[@]}"; do
  BODY="$BODY$problem

"
done
REPORT="🔎 Der Artikel-Wächter meldet sich — irgendwas hängt:

${BODY}Wenn nichts davon stimmt, sag mir Bescheid; dann liegt der Fehler im Wächter."

if [[ "$CHECK_ONLY" == yes ]]; then
  echo "$REPORT"
  exit 1
fi

if command -v envercetin-notify >/dev/null 2>&1; then
  envercetin-notify "$REPORT"
else
  (cd "$HOME/Projects/personal-os" && python3 tg.py send "$REPORT") \
    || osascript -e 'display notification "envercetin: the article watchdog found a problem" with title "Weekly article"' 2>/dev/null
fi
echo "$REPORT"
exit 1
