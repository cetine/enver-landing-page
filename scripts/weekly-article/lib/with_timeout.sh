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

  # Read the group NOW, while the child is alive: after it exits there is nothing
  # left to ask. Compared against our own group before any group-wide signal,
  # because `set -m` does not always take effect — in a pipeline element, for one
  # — and then `-$pid` is not the child's group but OURS, and the cleanup below
  # would kill the caller.
  local child_pgid own_pgid
  child_pgid="$(ps -o pgid= -p "$pid" 2>/dev/null | tr -d ' ')"
  own_pgid="$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')"

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

  # Whatever the command left behind in its own process group goes with it.
  #
  # This is not tidiness. A caller writes `OUT="$(with_timeout 1800 model_run ...)"`,
  # and a command substitution ends when the PIPE closes, not when the child
  # exits — so one grandchild holding the write end blocks the caller forever,
  # deadline or no deadline. On 2026-09-18 `claude -p` was still running seven and
  # a half hours into a thirty-minute step, reparented to pid 1, with run.sh
  # waiting on it: the watcher had seen its direct child go, exited, and reported
  # nothing wrong. Nobody was told, because nothing had failed.
  if [[ -n "$child_pgid" && "$child_pgid" != "$own_pgid" ]] \
     && pgrep -g "$child_pgid" >/dev/null 2>&1; then
    kill -TERM "-$child_pgid" 2>/dev/null
    local settle=0
    while (( settle < grace )) && pgrep -g "$child_pgid" >/dev/null 2>&1; do
      sleep 1
      settle=$(( settle + 1 ))
    done
    pgrep -g "$child_pgid" >/dev/null 2>&1 && kill -KILL "-$child_pgid" 2>/dev/null
  fi

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
