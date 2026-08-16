#!/usr/bin/env bash
#
# Connectivity precondition for the scheduled jobs. Sourced, not executed.
#
# Every step of the pipeline needs the network — git, the model, Telegram,
# Vercel — and every script runs under `set -e`, so without this the first
# network call is also the last thing that happens.
#
# The case this exists for is not a broken router, it is a laptop: launchd fires
# a deferred job the moment the Mac wakes, which is regularly BEFORE Wi-Fi has
# re-associated. Failing there would make the "we run at the next wake" promise
# false most of the time it mattered.

# wait_for_network <minutes>
#
# Returns 0 as soon as the git remote answers, 1 if it never does within the
# budget. `git ls-remote` is the probe on purpose: it exercises DNS, TCP, TLS and
# the credential that `git pull`/`git push` will need moments later. A captive
# portal that returns 200 to everything still fails it, which is the point —
# hotel Wi-Fi that has not been clicked through is "online" to a ping and useless
# to this pipeline.
#
# Must be called from inside the repo.
wait_for_network() {
  local budget_min="${1:-60}"
  local waited=0 interval=30

  if git ls-remote --exit-code -q origin HEAD >/dev/null 2>&1; then
    return 0
  fi

  echo "no network yet — waiting up to ${budget_min} min for the git remote"
  while (( waited < budget_min * 60 )); do
    sleep "$interval"
    waited=$(( waited + interval ))
    if git ls-remote --exit-code -q origin HEAD >/dev/null 2>&1; then
      echo "network came up after ${waited}s"
      return 0
    fi
  done

  echo "still offline after ${budget_min} min"
  return 1
}
