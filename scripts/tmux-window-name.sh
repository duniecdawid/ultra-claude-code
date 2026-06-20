#!/usr/bin/env bash
# tmux-window-name.sh — rename the current tmux WINDOW (Ultra Claude).
#
# The dumb mechanical primitive behind the /uc:rename-window skill and the
# standardized window naming that planning/execution flows apply. The CALLER
# builds the name string (e.g. "UC::P-007::Add login"); this script only
# applies it. It is the window-name analogue of tmux-layout-setup.sh, which
# manages PANE labels — the two are orthogonal (the layout daemon never touches
# window names, so there is no conflict).
#
# Usage:  tmux-window-name.sh "<window name>"
#
# Runtime gate: $TMUX_PANE. Per skills/setup/references/tmux-modes.md, $TMUX_PANE
# is THE runtime signal for whether to run tmux commands; outside tmux we no-op.
#
# Effects (idempotent — safe to run repeatedly):
#   1. sanitize the requested name (collapse whitespace, strip control chars,
#      keep the "::" delimiter unambiguous) and truncate for the status bar
#   2. rename the current window
#   3. disable automatic-rename / allow-rename so the shell prompt or programs
#      do not immediately overwrite the name
#
# Every action and skip is logged to ~/.claude/ultra/tmux-window-name.log.
# Always exits 0 — a naming step must never break its caller.

set -u

LOG_FILE="$HOME/.claude/ultra/tmux-window-name.log"
LOG_MAX_BYTES=$((1024 * 1024)) # 1 MB
MAX_LEN=40                     # cap total window-name length for the status bar

log() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
  if [ -f "$LOG_FILE" ]; then
    local size
    size=$(wc -c <"$LOG_FILE" 2>/dev/null || echo 0)
    [ "${size:-0}" -gt "$LOG_MAX_BYTES" ] && : >"$LOG_FILE"
  fi
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$LOG_FILE" 2>/dev/null
}

# --- Single runtime gate: are we inside tmux? ---
if [ -z "${TMUX_PANE:-}" ]; then
  log "SKIP: \$TMUX_PANE unset — not in tmux, nothing to rename"
  exit 0
fi

RAW="${1:-}"
if [ -z "$RAW" ]; then
  log "SKIP: no name argument given"
  exit 0
fi

# 1. Sanitize.
#    - drop control chars
#    - collapse any run of whitespace to a single space, trim ends
#    - protect the "::" delimiter: turn a single ":" (not part of "::") into "-"
NAME=$(printf '%s' "$RAW" | tr -d '\000-\037')
NAME=$(printf '%s' "$NAME" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')
# collapse 3+ colons to 2, then any lone colon -> '-', then restore '::'
NAME=$(printf '%s' "$NAME" | sed -E 's/:{3,}/::/g; s/::/\x01/g; s/:/-/g; s/\x01/::/g')

# 2. Truncate (keep it readable in the status bar).
if [ "${#NAME}" -gt "$MAX_LEN" ]; then
  NAME="${NAME:0:$((MAX_LEN - 1))}…"
fi

# 3. Rename the current window and make the name stick.
WINDOW=$(tmux display-message -p -t "$TMUX_PANE" '#{window_id}' 2>>"$LOG_FILE")
if [ -z "$WINDOW" ]; then
  log "SKIP: could not resolve window for pane $TMUX_PANE"
  exit 0
fi

if tmux rename-window -t "$WINDOW" "$NAME" 2>>"$LOG_FILE"; then
  log "RENAME: window $WINDOW -> '$NAME'"
else
  log "RENAME: FAILED for window $WINDOW"
  exit 0
fi

# Stop the shell/programs from overwriting the name we just set.
tmux set-window-option -t "$WINDOW" automatic-rename off 2>>"$LOG_FILE" \
  || log "OPT: automatic-rename off failed"
tmux set-window-option -t "$WINDOW" allow-rename off 2>>"$LOG_FILE" \
  || log "OPT: allow-rename off failed"

log "DONE: window $WINDOW named '$NAME'"
exit 0
