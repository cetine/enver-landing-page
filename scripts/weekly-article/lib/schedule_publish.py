#!/usr/bin/env python3
"""Schedule an approved article branch to publish later, at a randomised time.

An article written on Saturday goes live either on the FOLLOWING Friday evening
(19:00–21:00) or the following Saturday midday (10:00–13:00), picked at random —
so the site does not look like it publishes on a cron, which it does.

Writes a one-shot launchd plist and loads it. `deploy-scheduled.sh` deletes the
job after it runs, so a date-pinned schedule cannot fire again next year.

Usage:  schedule_publish.py <branch> [--dry-run]
Prints the scheduled time as "YYYY-MM-DD HH:MM|<human readable>".
"""
import datetime as dt
import os
import random
import subprocess
import sys
from pathlib import Path

# lib/schedule_publish.py → parents[3] is the repo root. Derived, never hardcoded,
# so moving the repo does not silently break next week's publish.
REPO = str(Path(__file__).resolve().parents[3])
AGENTS = os.path.expanduser("~/Library/LaunchAgents")
LOGS = os.path.expanduser("~/Library/Logs/envercetin-weekly-article")
# The guard lives outside the repo on purpose: it is what still runs, and still
# reaches Telegram, when the repo itself has moved or become unreadable.
GUARD = os.path.expanduser("~/.local/bin/envercetin-guard")

# (weekday, earliest hour, latest hour exclusive). Monday=0 … Friday=4, Saturday=5.
WINDOWS = [(4, 19, 21), (5, 10, 13)]

PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>{label}</string>
  <!-- Everything runs through the guard, which reports a failure to Telegram even
       when the real script cannot be reached at all. -->
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>{guard}</string>
    <string>{label}</string>
    <string>{repo}/scripts/weekly-article/deploy-scheduled.sh</string>
    <string>{branch}</string>
    <string>{label}</string>
  </array>
  <!-- If the Mac is asleep or off at this moment, launchd runs the job once at
       the next wake instead of skipping it. -->
  <key>StartCalendarInterval</key>
  <dict>
    <key>Month</key><integer>{month}</integer>
    <key>Day</key><integer>{day}</integer>
    <key>Hour</key><integer>{hour}</integer>
    <key>Minute</key><integer>{minute}</integer>
  </dict>
  <!-- Deliberately no WorkingDirectory: launchd fails a job outright when it
       cannot chdir there, which is silent. The guard cds and reports instead. -->
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>{home}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>{home}</string>
  </dict>
  <key>StandardOutPath</key><string>{logs}/deploy-launchd.out.log</string>
  <key>StandardErrorPath</key><string>{logs}/deploy-launchd.err.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
"""


def next_weekday(today: dt.date, weekday: int) -> dt.date:
    """The next given weekday strictly after `today`."""
    ahead = (weekday - today.weekday()) % 7
    return today + dt.timedelta(days=ahead or 7)


def pick_slot(today: dt.date, rng: random.Random) -> dt.datetime:
    weekday, lo, hi = rng.choice(WINDOWS)
    day = next_weekday(today, weekday)
    minutes = rng.randrange(0, (hi - lo) * 60)
    return dt.datetime.combine(day, dt.time(lo)) + dt.timedelta(minutes=minutes)


def main(argv: list) -> int:
    if len(argv) < 2:
        print(__doc__, file=sys.stderr)
        return 1
    branch = argv[1]
    dry = "--dry-run" in argv

    when = pick_slot(dt.date.today(), random.Random())
    label = f"com.enver.envercetin.publish-{when:%Y-%m-%d-%H%M}"
    plist_path = os.path.join(AGENTS, f"{label}.plist")

    body = PLIST.format(label=label, repo=REPO, branch=branch, home=os.path.expanduser("~"),
                        guard=GUARD, logs=LOGS, month=when.month, day=when.day,
                        hour=when.hour, minute=when.minute)

    if not dry:
        os.makedirs(LOGS, exist_ok=True)
        with open(plist_path, "w", encoding="utf-8") as fh:
            fh.write(body)
        uid = os.getuid()
        # bootout first so re-running for the same slot cannot fail on a duplicate.
        subprocess.run(["launchctl", "bootout", f"gui/{uid}/{label}"],
                       capture_output=True, check=False)
        result = subprocess.run(["launchctl", "bootstrap", f"gui/{uid}", plist_path],
                                capture_output=True, text=True, check=False)
        if result.returncode != 0:
            print(f"launchctl bootstrap failed: {result.stderr.strip()}", file=sys.stderr)
            return 1

    days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    print(f"{when:%Y-%m-%d %H:%M}|{days[when.weekday()]} {when:%d %B} at {when:%H:%M}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
