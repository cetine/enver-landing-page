#!/usr/bin/env bash
#
# with_timeout <seconds> <command...>
#
# Runs a command with a deadline. Returns the command's own exit code, or 124 —
# the same code GNU timeout uses — if the deadline was hit, so a caller can tell
# "it broke" from "it hung".
#
# Why this exists at all: this Mac has neither `timeout` nor `gtimeout`, and
# every long step in the pipeline can hang rather than fail. A hung `claude -p`,
# or a `vercel deploy` waiting on a socket that will never answer, holds the
# guard's locks forever — and from then on every Saturday is skipped with
# "a previous run is still going". One hang, and the pipeline is dead for good.
#
# Why not SIGALRM, and why no background sweeper daemon: this MacBook spends most
# of its life with the lid closed. Alarms do not fire while the machine sleeps,
# and a sweeper process sleeps along with everything else. So the deadline is
# enforced by polling from a child that is awake exactly when the command is —
# and the real backstop against a lock held by a hung run lives in guard.sh,
# where the NEXT run evaluates the lock's age. Nothing has to stay awake.
#
# The budget is therefore awake-time, not wall-clock: a command that spans a
# system sleep is not punished for the hours the clock moved while nothing ran.

# shellcheck shell=bash

with_timeout() {
  local secs="$1"; shift
  local poll="${WITH_TIMEOUT_POLL_SEC:-5}"
  local grace="${WITH_TIMEOUT_GRACE_SEC:-10}"

  # A file, not a variable: the killer runs in a subshell and cannot write back.
  local marker
  marker="$(mktemp -t envercetin-with-timeout)" || return 125

  # Job control gives the command its own process group, which is what makes it
  # killable as a tree. `npm run verify` and `claude -p` both spawn children that
  # would otherwise survive the kill and keep holding the thing that hung.
  local had_monitor=0
  case "$-" in *m*) had_monitor=1 ;; esac
  set -m

  "$@" &
  local pid=$!

  # >/dev/null matters more than it looks: the watcher inherits the caller's
  # stdout, and a caller like `X="$(with_timeout 60 claude -p ...)"` or a pipe
  # into sed only ends when EVERY writer has closed that pipe. With the watcher
  # holding it open, the command finishes and the caller hangs anyway — the exact
  # failure this file exists to prevent, reintroduced by the fix for it.
  (
    local waited=0
    while (( waited < secs )); do
      sleep "$poll"
      kill -0 "$pid" 2>/dev/null || exit 0
      waited=$(( waited + poll ))
    done
    printf 'timeout' > "$marker"
    kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    sleep "$grace"
    kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
  ) >/dev/null 2>&1 &
  local killer=$!

  # 2>/dev/null: with job control on, the shell announces the kill as
  # "Terminated: 15" on stderr. The caller's log should carry the pipeline's own
  # account of what happened, not bash's.
  { wait "$pid"; } 2>/dev/null
  local rc=$?

  # Both forms, unconditionally: `set -m` does not always take effect in a
  # subshell — a pipeline element, for instance — and then the watcher is not a
  # process-group leader and the group form quietly hits nothing.
  kill -TERM "-$killer" 2>/dev/null
  kill -TERM "$killer" 2>/dev/null
  { wait "$killer"; } 2>/dev/null

  (( had_monitor )) || set +m

  local timed_out=no
  [[ -s "$marker" ]] && timed_out=yes
  rm -f "$marker"

  [[ "$timed_out" == yes ]] && return 124
  return $rc
}
