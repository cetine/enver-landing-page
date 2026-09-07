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
NOTIFY="$HOME/.local/bin/envercetin-notify"
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
  echo -n "notify:"; [[ -x "$NOTIFY" ]] && { cmp -s "$REPO/scripts/weekly-article/notify.sh" "$NOTIFY" \
    && echo " $NOTIFY (up to date)" || echo " $NOTIFY (STALE — re-run without --check)"; } || echo " MISSING"
  echo -n "queued:"; SPOOL="$HOME/Library/Application Support/envercetin/pending-notifications"
  echo " $(ls -1 "$SPOOL" 2>/dev/null | wc -l | tr -d ' ') undelivered message(s)"
  echo -n "plist: "; [[ -f "$PLIST" ]] && echo "$PLIST" || echo "MISSING"
  echo -n "watch: "; launchctl print "gui/$UID_NUM/com.enver.envercetin.watchdog" >/dev/null 2>&1 \
    && echo "loaded (Sat + Tue 10:00)" || echo "NOT LOADED"
  echo -n "flush: "; launchctl print "gui/$UID_NUM/com.enver.envercetin.notify-flush" >/dev/null 2>&1 \
    && echo "loaded (every 30 min)" || echo "NOT LOADED"
  # The last exit status, interpreted rather than printed raw. This line read
  # `-	124	com.enver.envercetin.weekly-article` for two days after the run of
  # 2026-09-05 was killed at its ceiling, and looked like every other green row.
  echo -n "job:   "
  if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
    LAST_RC="$(launchctl list | awk -v l="$LABEL" '$3 == l { print $2 }')"
    if [[ -z "$LAST_RC" || "$LAST_RC" == "0" || "$LAST_RC" == "-" ]]; then
      echo "loaded (Sat 14:00)"
    else
      echo "loaded (Sat 14:00) — LAST RUN FAILED, exit $LAST_RC"
    fi
  else
    echo "NOT LOADED"
  fi
  # What actually happened last, which no other line here reports.
  LAST_LOG="$(ls -1t "$HOME/Library/Logs/envercetin-weekly-article"/????-??-??.log 2>/dev/null | head -1)"
  if [[ -n "$LAST_LOG" ]]; then
    echo "last:  $(basename "$LAST_LOG" .log) — $(tail -1 "$LAST_LOG")"
  fi
  # A question still waiting on an answer is the state that silently lost
  # 2026-08-29, so say so here as well as in the watchdog.
  for MARKER in "$HOME/Library/Logs/envercetin-weekly-article"/*-deferrals; do
    [[ -f "$MARKER" ]] || continue
    STAMP_D="$(basename "$MARKER")"; STAMP_D="${STAMP_D%-deferrals}"
    echo "open:  topics from $STAMP_D are still waiting for you to pick one"
    echo "       $REPO/scripts/weekly-article/run.sh --topics $HOME/Library/Logs/envercetin-weekly-article/$STAMP_D-topics.json"
  done
  exit 0
fi

# The guard's launchd behaviour is not reachable by the site's unit tests, and it
# is where the expensive bugs live: on 2026-08-22 it boot-ed out its own label and
# every offline retry killed itself in silence. This is the moment that regression
# would be introduced, so this is where the gate belongs.
if [[ "${ENVERCETIN_SKIP_GUARD_TESTS:-}" != "1" ]]; then
  echo "running the pipeline's tests..."
  if ! "$REPO/scripts/weekly-article/tests/run-all.sh"; then
    echo >&2
    echo "REFUSING: the pipeline fails its own tests. Nothing was installed." >&2
    echo "Set ENVERCETIN_SKIP_GUARD_TESTS=1 to override, but read the failures first." >&2
    exit 1
  fi
  echo
fi

mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" \
         "$HOME/Library/Logs/envercetin-weekly-article"

install -m 755 "$REPO/scripts/weekly-article/guard.sh" "$GUARD"
echo "guard installed: $GUARD"

install -m 755 "$REPO/scripts/weekly-article/notify.sh" "$NOTIFY"
echo "notifier installed: $NOTIFY"

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

# A queued alert used to wait for the next weekly run to deliver it — and the
# weekly run is exactly what fails when there is no network to deliver on. The
# backlog could therefore sit unseen for a week, or forever. This drains it on its
# own schedule, so bad news arrives when the connection does.
FLUSH_LABEL="com.enver.envercetin.notify-flush"
FLUSH_PLIST="$HOME/Library/LaunchAgents/$FLUSH_LABEL.plist"
cat > "$FLUSH_PLIST" <<FLUSH_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$FLUSH_LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$NOTIFY</string><string>--flush</string></array>
  <key>StartInterval</key><integer>1800</integer>
  <key>RunAtLoad</key><true/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/notify-flush.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/notify-flush.log</string>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
FLUSH_END
plutil -lint "$FLUSH_PLIST" >/dev/null
launchctl bootout "gui/$UID_NUM/$FLUSH_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$FLUSH_PLIST"
echo "notification flusher loaded: $FLUSH_LABEL (every 30 min)"

# The deadline watchdog. Saturdays 10:00 is the pre-flight — today is a writing
# day, so is last week's article actually out? Tuesdays 10:00 is the post-mortem:
# Saturday has been and gone, did anything come of it? It reports only problems,
# so silence means healthy, and it runs from the repo rather than ~/.local/bin
# because unlike the guard it has no job if the repo is gone.
WATCH_LABEL="com.enver.envercetin.watchdog"
WATCH_PLIST="$HOME/Library/LaunchAgents/$WATCH_LABEL.plist"
cat > "$WATCH_PLIST" <<WATCH_END
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$WATCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$REPO/scripts/weekly-article/watchdog.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Weekday</key><integer>6</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Weekday</key><integer>2</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/watchdog.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/watchdog.log</string>
  <key>RunAtLoad</key><false/>
  <key>ProcessType</key><string>Background</string>
</dict>
</plist>
WATCH_END
plutil -lint "$WATCH_PLIST" >/dev/null
launchctl bootout "gui/$UID_NUM/$WATCH_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$WATCH_PLIST"
echo "watchdog loaded: $WATCH_LABEL (Sat + Tue, 10:00)"

plutil -lint "$PLIST" >/dev/null
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "job loaded. Next run:"
launchctl print "gui/$UID_NUM/$LABEL" | grep -A3 "next fire" || true
