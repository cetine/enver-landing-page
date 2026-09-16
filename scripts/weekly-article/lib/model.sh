# How the pipeline reaches its model. Sourced by run.sh; expects CLAUDE_BIN.
#
# Fable runs the whole job and delegates research, drafting and review to
# subagents. It runs in the local Claude Code CLI on the subscription login —
# never on an API key, and never on a local backend that happens to be exported
# in some shell (~/.zshrc defines one for LM Studio).

MODEL_NAME="${ENVERCETIN_CLAUDE_MODEL:-fable}"

# `Agent` is the subagent tool; `Task` is its older name, kept so an older CLI
# can still delegate.
MODEL_FLAGS=(--model "$MODEL_NAME" --permission-mode acceptEdits
  --allowed-tools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,Agent,Task,TodoWrite,TaskCreate,TaskUpdate")

# `env -u` removes anything that would route the CLI past the subscription. The
# rest: on 2026-09-05 `claude -p` hung for thirty fully awake minutes before its
# first model turn, and startup is where the CLI refreshes plugin marketplaces
# and checks for updates — network calls this pipeline gains nothing from.
MODEL_ENV=(env
  -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL
  -u ANTHROPIC_MODEL -u ANTHROPIC_SMALL_FAST_MODEL
  -u ANTHROPIC_DEFAULT_OPUS_MODEL -u ANTHROPIC_DEFAULT_SONNET_MODEL
  -u ANTHROPIC_DEFAULT_HAIKU_MODEL -u CLAUDE_CODE_SUBAGENT_MODEL
  -u CLAUDE_CODE_USE_BEDROCK -u CLAUDE_CODE_USE_VERTEX
  CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
  DISABLE_AUTOUPDATER=1
  DISABLE_TELEMETRY=1
  DISABLE_ERROR_REPORTING=1)

MODEL_LOGIN_FIX="Open a terminal, run \`claude\`, type /login and sign in with the Claude subscription"

# model_run <prompt> — one headless model call, output on stdout.
model_run() {
  "${MODEL_ENV[@]}" "$CLAUDE_BIN" -p "$1" "${MODEL_FLAGS[@]}" < /dev/null
}

# model_login_problem — prints why the CLI cannot run on the subscription and
# returns 0; returns 1 when the login is fine. No model call, so it costs nothing
# and can run before anyone is asked for a topic. Needs lib/with_timeout.sh.
model_login_problem() {
  local status
  status="$(with_timeout 60 "${MODEL_ENV[@]}" "$CLAUDE_BIN" auth status 2>&1)" || true
  if python3 -c '
import json, sys
try:
    s = json.loads(sys.argv[1])
except ValueError:
    sys.exit(1)
method = str(s.get("authMethod", "")).lower()
sys.exit(0 if s.get("loggedIn") is True and "api" not in method and "console" not in method else 1)
' "$status"; then
    return 1
  fi
  if printf '%s' "$status" | grep -q '"loggedIn": *true'; then
    echo "Claude Code is logged in with an API key instead of the subscription"
  else
    echo "Claude Code is not logged in"
  fi
  return 0
}

# model_failure_kind <output> — auth | limit | other. Read from what the CLI
# said, never from the exit code alone: both of these exit 1. Only the last
# lines count — the CLI reports these as a one-liner, and a writer that failed
# for another reason may well have written prose about OAuth.
model_failure_kind() {
  local tail_said
  tail_said="$(printf '%s\n' "$1" | tail -3)"
  if printf '%s' "$tail_said" | grep -qiE 'failed to authenticate|oauth|not logged in|/login|authentication_error|invalid api key'; then
    echo auth
  elif printf '%s' "$tail_said" | grep -qiE 'session limit|usage limit|weekly limit|hit your .*limit|limit reached|rate_limit'; then
    echo limit
  else
    echo other
  fi
}

# model_failure_line <kind> <output> — one sentence for a notification.
model_failure_line() {
  local said
  said="$(printf '%s' "$2" | grep -v '^[[:space:]]*$' | tail -1)"
  case "$1" in
    auth)  echo "Claude's login has expired (it said: ${said}). $MODEL_LOGIN_FIX" ;;
    limit) echo "the Claude subscription hit its usage limit (it said: ${said}). Nothing is wrong with the pipeline; it needs the limit to reset" ;;
    *)     echo "it said: ${said:-nothing at all}" ;;
  esac
}
