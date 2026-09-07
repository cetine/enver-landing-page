#!/usr/bin/env bash
#
# arm_job <label> <MM> <DD> <HH> <MM> <program-args...>
#
# Writes a one-shot LaunchAgent that runs `/bin/bash <program-args...>` at the
# given date and time, and loads it. Date-pinned, so it fires once and then sits
# inert until something overwrites or removes it.
#
# Why this is not shared with guard.sh, which has the same shape: the guard is
# installed to ~/.local/bin deliberately outside the repo, so that it still
# reports when the repo is unreachable — the whole reason it exists. A guard that
# sourced a repo lib would fail in exactly the case it was written for. The
# duplication is the price of that, and it is a price worth paying.
#
# The caller decides the label. Everything under com.enver.envercetin.* is ours.

# shellcheck shell=bash

arm_job() {
  local label="$1" month="$2" day="$3" hour="$4" minute="$5"
  shift 5

  # Seam, so a test can arm a job without writing into the real LaunchAgents
  # directory — and so ENVERCETIN_TEST_NO_LAUNCHCTL below never loads one.
  local agents="${ENVERCETIN_AGENTS_DIR:-$HOME/Library/LaunchAgents}"
  local plist="$agents/$label.plist"
  local args=""
  local a
  for a in "$@"; do
    args="$args    <string>$a</string>
"
  done

  mkdir -p "$agents"
  cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
$args  </array>
  <!-- Date-pinned and one-shot. If the Mac is asleep at that minute launchd
       runs it at the next wake rather than skipping it. -->
  <key>StartCalendarInterval</key>
  <dict>
    <key>Month</key><integer>$month</integer>
    <key>Day</key><integer>$day</integer>
    <key>Hour</key><integer>$hour</integer>
    <key>Minute</key><integer>$minute</integer>
  </dict>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key><string>$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <key>HOME</key><string>$HOME</string>
  </dict>
  <!-- No WorkingDirectory: launchd fails a job outright, and silently, when it
       cannot chdir there. -->
  <key>StandardOutPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/$label.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/envercetin-weekly-article/$label.err.log</string>
  <key>RunAtLoad</key><false/>
</dict>
</plist>
PLIST

  # A plist that fails to load is worse than no plist: the caller believes the
  # work is scheduled and nothing ever runs it. Say so instead.
  if [[ -n "${ENVERCETIN_TEST_NO_LAUNCHCTL:-}" ]]; then
    return 0
  fi
  launchctl bootout "gui/$(id -u)/$label" 2>/dev/null
  launchctl bootstrap "gui/$(id -u)" "$plist" 2>/dev/null || {
    launchctl load -w "$plist" 2>/dev/null || return 1
  }
  launchctl print "gui/$(id -u)/$label" >/dev/null 2>&1
}
