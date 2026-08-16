#!/usr/bin/env bash
#
# Telegram notification with an offline spool.
#
#   envercetin-notify "<message>"
#   envercetin-notify --flush
#
# The scheduled jobs report every failure to Telegram — but Telegram needs the
# network, and the most likely reason a job fails is that there is no network.
# So the alert about a lost week was itself lost, and `tg.py` does not buffer:
# it catches NotConnected and drops the message. A skipped Saturday was silent.
#
# This queues what it cannot send and delivers it the next time anything gets
# through, so an outage delays the message instead of destroying it.
#
# Never fails: a notifier that breaks its caller is worse than a late message.
#
# Canonical source: scripts/weekly-article/notify.sh in the envercetin repo.
# Installed to ~/.local/bin/envercetin-notify by scripts/weekly-article/install.sh.
# It lives outside the repo for the same reason the guard does — it has to work
# when the repo does not.

set -uo pipefail

PERSONAL_OS="$HOME/Projects/personal-os"
TG="$PERSONAL_OS/tg.py"
SPOOL="$HOME/Library/Application Support/envercetin/pending-notifications"

mkdir -p "$SPOOL" 2>/dev/null || true

# One message per file, content verbatim — no escaping to get wrong, and a
# partially written file can never corrupt the ones already queued.
# Name is <epoch>_<pid>_<rand>; epoch stays 10 digits until 2286, so a plain
# lexicographic sort is chronological.
spool() {
  printf '%s' "$1" > "$SPOOL/$(date +%s)_$$_${RANDOM}" 2>/dev/null || true
}

send() {
  [[ -f "$TG" ]] || return 1
  (cd "$PERSONAL_OS" && python3 "$TG" send "$1") >/dev/null 2>&1
}

# Deliver the backlog oldest-first. Stops at the first failure and leaves the
# rest queued, so order is never scrambled by a flaky connection.
flush() {
  local name path body when
  for name in $(ls -1 "$SPOOL" 2>/dev/null | sort); do
    path="$SPOOL/$name"
    [[ -f "$path" ]] || continue
    body="$(cat "$path")"
    when="$(date -r "${name%%_*}" '+%d.%m. um %H:%M' 2>/dev/null || echo 'früher')"
    if send "🕗 Nachgereicht — das hier fiel am $when an, als der Mac offline war:

$body"; then
      rm -f "$path"
    else
      return 1
    fi
  done
  return 0
}

if [[ "${1:-}" == "--flush" ]]; then
  flush || true
  exit 0
fi

MSG="${1:-}"
if [[ -z "$MSG" ]]; then
  echo "usage: envercetin-notify <message> | --flush" >&2
  exit 64
fi

# Backlog first, so messages arrive in the order they happened.
flush || true

if ! send "$MSG"; then
  spool "$MSG"
  echo "TELEGRAM UNREACHABLE — queued for delivery when the network is back: $MSG"
  osascript -e 'display notification "envercetin: alert queued — no network" with title "Weekly article"' 2>/dev/null || true
fi

exit 0
