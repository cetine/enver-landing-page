#!/usr/bin/env bash
#
# Installs (or re-installs) the weekly article schedule.
#
# Idempotent — safe to run any time. Run it after moving the repo, after editing
# guard.sh, or if you are ever unsure whether the schedule is actually live:
#
#   scripts/weekly-article/install.sh
#   scripts/weekly-article/install.sh --check    # report only, change nothing
#
# It writes the guard to ~/.local/bin (outside the repo, on purpose — see
# guard.sh) and the launchd plist to ~/Library/LaunchAgents, then loads the job.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL="com.enver.envercetin.weekly-article"
GUARD="$HOME/.local/bin/envercetin-guard"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"
CHECK_ONLY=no
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=yes

# Two independent fences can lock this repo out of its own pipeline, and both
# did so on 2026-08-15. Check them here rather than discovering them at 14:00 on
# a Saturday.

# 1. macOS TCC. A LaunchAgent gets no Documents/Desktop/Downloads access, so
#    launchd cannot even start a script living there.
case "$REPO/" in
  "$HOME/Documents/"* | "$HOME/Desktop/"* | "$HOME/Downloads/"* | */Library/CloudStorage/*)
    echo "REFUSING: the repo is at $REPO" >&2
    echo "launchd jobs cannot read that location (macOS TCC). Move the repo somewhere" >&2
    echo "like ~/Sites/envercetin and run this again." >&2
    exit 1
    ;;
esac

# 2. This repo's own sandbox. `.claude/settings.json` denies whole trees to keep
#    the unattended writer out of unrelated work. Deny beats allow and a broad
#    pattern cannot carve out an exception, so a repo sitting inside one of its
#    own denied trees fences itself out: the writer can run, but cannot read the
#    style guide or write the article. Costly to diagnose, trivial to detect.
DENIED_BY_OWN_RULES="$(python3 - "$REPO" <<'PY'
import json, os, sys

repo = os.path.realpath(sys.argv[1])
settings = os.path.join(repo, ".claude", "settings.json")
if not os.path.exists(settings):
    sys.exit(0)

with open(settings, encoding="utf-8") as fh:
    rules = json.load(fh).get("permissions", {}).get("deny", [])

for rule in rules:
    if not rule.startswith(("Read(//", "Edit(//")):
        continue
    # "Read(//Users/x/Projects/**)" -> "/Users/x/Projects"
    tree = rule[rule.index("(") + 2:rule.rindex(")")].rstrip("*").rstrip("/")
    if repo == tree or repo.startswith(tree + "/"):
        print(rule)
        break
PY
)"
if [[ -n "$DENIED_BY_OWN_RULES" ]]; then
  echo "REFUSING: the repo is at $REPO" >&2
  echo "which its own .claude/settings.json denies via: $DENIED_BY_OWN_RULES" >&2
  echo "The writer would be unable to read or edit its own repository. Move the repo" >&2
  echo "outside that tree, or narrow the rule, and run this again." >&2
  exit 1
fi

if [[ "$CHECK_ONLY" == yes ]]; then
  echo "repo:  $REPO (not TCC-protected — ok)"
  echo -n "guard: "; [[ -x "$GUARD" ]] && { cmp -s "$REPO/scripts/weekly-article/guard.sh" "$GUARD" \
    && echo "$GUARD (up to date)" || echo "$GUARD (STALE — re-run without --check)"; } || echo "MISSING"
  echo -n "plist: "; [[ -f "$PLIST" ]] && echo "$PLIST" || echo "MISSING"
  echo -n "job:   "; launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 \
    && launchctl list | grep "$LABEL" || echo "NOT LOADED"
  exit 0
fi

mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" \
         "$HOME/Library/Logs/envercetin-weekly-article"

install -m 755 "$REPO/scripts/weekly-article/guard.sh" "$GUARD"
echo "guard installed: $GUARD"

cat > "$PLIST" <<PLIST_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <!-- launchd starts the guard, never the pipeline directly. If run.sh is
       unreachable the guard is what tells you so; pointing launchd at run.sh
       itself means an unreachable script fails before any code can report it. -->
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$GUARD</string>
    <string>weekly-article</string>
    <string>$REPO/scripts/weekly-article/run.sh</string>
  </array>

  <!-- Saturdays at 14:00 local time. If the Mac is asleep, shut down or logged
       out at that moment, launchd runs the job once at the next wake or login
       rather than skipping the week. -->
  <key>StartCalendarInterval</key>
  <dict>
    <key>Weekday</key><integer>6</integer>
    <key>Hour</key><integer>14</integer>
    <key>Minute</key><integer>0</integer>
  </dict>

  <!-- Deliberately no WorkingDirectory: launchd fails a job outright, and
       silently, when it cannot chdir there. The guard cds and reports instead. -->
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key>
    <string>$HOME</string>
  </dict>

  <!-- The guard and run.sh both tee their own dated logs; these catch anything
       that escapes them, including launchd's own refusals. -->
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/envercetin-weekly-article/launchd.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/envercetin-weekly-article/launchd.err.log</string>

  <key>RunAtLoad</key>
  <false/>
  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
PLIST_END
echo "plist written: $PLIST"

plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "job loaded. Next run:"
launchctl print "gui/$UID_NUM/$LABEL" | grep -A3 "next fire" || true
