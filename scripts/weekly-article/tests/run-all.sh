#!/usr/bin/env bash
#
# Every test for the weekly-article pipeline, in one command.
#
#   scripts/weekly-article/tests/run-all.sh
#
# install.sh runs this before it installs anything, because installing is the
# moment a regression in the guard or the watchdog would go live — and both of
# them fail by staying silent, which is the one failure nobody notices.
#
# New test files are picked up automatically: anything named *.test.sh here runs.

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()

for suite in "$DIR"/*.test.sh; do
  [[ -f "$suite" ]] || continue
  name="$(basename "$suite")"
  echo "── $name"
  if ! /bin/bash "$suite"; then
    FAILED+=("$name")
  fi
  echo
done

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo "FAILED: ${FAILED[*]}"
  exit 1
fi
echo "all suites passed"
