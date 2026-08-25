#!/usr/bin/env bash
#
# classify_approval <exit-code-of-tg-ask> <reply-text>
#
# Prints exactly one of:
#
#   publish    — he said publish it
#   draft      — he said keep it as a draft
#   undecided  — the question got no usable answer (timeout, or something the
#                pipeline cannot act on). Nobody rejected anything. Ask again.
#   error      — the question never reached him at all
#
# The distinction is the whole point. run.sh used to collapse every non-zero exit
# into "Keep as draft", so an expired Telegram token answered on Enver's behalf:
# the finished article became a permanent draft, its topic stayed marked COVERED
# on the branch so it could never be proposed again, and the message he received
# told him he had chosen that.
#
# tg.py's codes: 0 answered, 2 timed out, 1 config/network/API error, anything
# else a crash. On a timeout or an error the REPLY line on stdout is stale or
# absent, so the code decides and the text is only consulted when rc is 0.

# shellcheck shell=bash

classify_approval() {
  local rc="${1:-1}" reply="${2:-}"

  if [[ "$rc" != "0" ]]; then
    [[ "$rc" == "2" ]] && { echo undecided; return 0; }
    echo error
    return 0
  fi

  # Typed rather than tapped is normal — he answers from a phone. Accept the
  # option labels in any casing, and nothing else: a reply the pipeline cannot
  # act on is undecided, never a silent No.
  local normalised
  normalised="$(printf '%s' "$reply" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

  case "$normalised" in
    publish)        echo publish ;;
    "keep as draft") echo draft ;;
    *)              echo undecided ;;
  esac
}
