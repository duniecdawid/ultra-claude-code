#!/usr/bin/env bash
# StopFailure hook (matcher: rate_limit) — the limit sentinel's detection channel.
#
# Claude Code invokes this with JSON on stdin when a turn ends on a rate-limit API error
# (payload verified 2026-07-23: session_id, transcript_path, cwd, prompt_id,
# hook_event_name:"StopFailure", error:"rate_limit", last_assistant_message:"You've hit your
# session limit · resets …"). We record one spool event for the sentinel and revive the
# sentinel itself — the one moment it is indispensable is the moment we are guaranteed to run.
#
# Contract: NEVER block, NEVER fail the calling session. Everything is best-effort; exit 0 always.
# StopFailure output/exit codes are ignored by Claude Code, so this hook can only observe.

set +e

SENTINEL_DIR="$HOME/.claude/ultra/sentinel"
EVENTS_DIR="$SENTINEL_DIR/events"
SENTINEL="$HOME/.claude/ultra/limit-sentinel.sh"
LIB="$HOME/.claude/ultra/lib.sh"

payload=$(timeout 2 cat 2>/dev/null)

session_id=$(jq -r '.session_id // empty' <<<"$payload" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)

# Account resolution: the session file written by session-start.sh is authoritative and cheap.
# Fallback to `claude auth status` only if it is missing (slow path, still bounded by timeout).
account_id=""
if [ -n "$cwd" ] && [ -n "$session_id" ] && [ -f "$cwd/.claude/ultra/sessions/$session_id.json" ]; then
  account_id=$(jq -r '.account_id // empty' "$cwd/.claude/ultra/sessions/$session_id.json" 2>/dev/null)
fi
if [ -z "$account_id" ] && [ -f "$LIB" ]; then
  email=$(timeout 4 claude auth status --json 2>/dev/null | jq -r '.email // empty' 2>/dev/null)
  [ -n "$email" ] && account_id=$( (source "$LIB" 2>/dev/null && slugifyEmail "$email") 2>/dev/null )
fi

mkdir -p "$EVENTS_DIR" 2>/dev/null

if [ -n "$session_id" ] || [ -n "$payload" ]; then
  ts_epoch=$(date +%s)
  event_file="$EVENTS_DIR/${ts_epoch}-${session_id:-unknown}.json"
  jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg session_id "$session_id" \
    --arg transcript_path "$(jq -r '.transcript_path // empty' <<<"$payload" 2>/dev/null)" \
    --arg cwd "$cwd" \
    --arg error "$(jq -r '.error // empty' <<<"$payload" 2>/dev/null)" \
    --arg banner "$(jq -r '.last_assistant_message // empty' <<<"$payload" 2>/dev/null)" \
    --arg tmux_pane "${TMUX_PANE:-}" \
    --arg tmux "${TMUX:-}" \
    --arg account_id "$account_id" \
    --arg config_dir "${CLAUDE_CONFIG_DIR:-}" \
    '{ts:$ts, session_id:$session_id, transcript_path:$transcript_path, cwd:$cwd,
      error:$error, banner:$banner, tmux_pane:$tmux_pane, tmux:$tmux,
      account_id:$account_id, config_dir:$config_dir}' \
    > "$event_file.tmp" 2>/dev/null && mv "$event_file.tmp" "$event_file" 2>/dev/null
fi

# Revive the sentinel (self-healing). Backgrounded + disowned: the hook must return immediately.
if [ -x "$SENTINEL" ] || [ -L "$SENTINEL" ]; then
  (bash "$SENTINEL" ensure >/dev/null 2>&1 &) 2>/dev/null
fi

exit 0
