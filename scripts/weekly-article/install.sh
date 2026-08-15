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

# The repo must not live under a folder macOS protects with TCC. A LaunchAgent
# gets no Documents/Desktop/Downloads access, so a repo there cannot be started
# by launchd at all — that is exactly how the 2026-08-15 run was lost.
case "$REPO/" in
  "$HOME/Documents/"* | "$HOME/Desktop/"* | "$HOME/Downloads/"* | */Library/CloudStorage/*)
    echo "REFUSING: the repo is at $REPO" >&2
    echo "launchd jobs cannot read that location (macOS TCC). Move the repo somewhere" >&2
    echo "like ~/Projects/envercetin and run this again." >&2
    exit 1
    ;;
esac

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
