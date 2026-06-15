#!/usr/bin/env bash
# tmux-layout-setup.sh — idempotent setup of the Ultra Claude tmux layout system
# for the current (Lead / main) pane.
#
# Invoked UNCONDITIONALLY by plan-execution (phase-1 §1.1b and phase-2 §2.6).
# The script — not the caller — owns the single runtime gate, so the model's
# instruction is simply "run this script" and the conditions live in one place.
#
# Runtime gate: $TMUX_PANE. Per skills/setup/references/tmux-modes.md, $TMUX_PANE
# is THE runtime signal for whether to run tmux commands; the setup-time
# `tmuxMode` preference does NOT gate runtime behaviour. If we are inside tmux we
# name the pane and ensure the layout daemon; otherwise we no-op.
#
# Effects (idempotent — safe to run repeatedly and from any pane):
#   1. ensure the layout daemon is running
#   2. label the current pane @agent-name=main-context (the daemon keys window
#      management on this label)
#   3. enable the pane-border label display
#
# Every action and skip is logged to ~/.claude/ultra/tmux-layout-setup.log so
# this step can be debugged after the fact.

set -u

LOG_FILE="$HOME/.claude/ultra/tmux-layout-setup.log"
LOG_MAX_BYTES=$((1024 * 1024)) # 1 MB

log() {
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
  # Truncate if the log has grown past the cap (keep it small and tail-able).
  if [ -f "$LOG_FILE" ]; then
    local size
    size=$(wc -c <"$LOG_FILE" 2>/dev/null || echo 0)
    [ "${size:-0}" -gt "$LOG_MAX_BYTES" ] && : >"$LOG_FILE"
  fi
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$LOG_FILE" 2>/dev/null
}

# --- Single runtime gate: are we inside tmux? ---
if [ -z "${TMUX_PANE:-}" ]; then
  log "SKIP: \$TMUX_PANE unset — not in tmux, nothing to set up"
  exit 0
fi

TMUX_MODE=$(jq -r '.tmuxMode // "unknown"' "$HOME/.claude/ultra/uc-setup.json" 2>/dev/null || echo "unknown")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log "START: pane=$TMUX_PANE tmuxMode=$TMUX_MODE script_dir=$SCRIPT_DIR"

# 1. Ensure the layout daemon is running (non-fatal if node is unavailable).
if command -v node >/dev/null 2>&1; then
  if node "$SCRIPT_DIR/tmux-layout-daemon.js" --ensure >>"$LOG_FILE" 2>&1; then
    log "DAEMON: ensured"
  else
    log "DAEMON: --ensure failed (non-fatal)"
  fi
else
  log "DAEMON: node not found — skipping daemon start (label still set)"
fi

# 2. Name this pane as the Lead/main context.
if tmux set-option -p -t "$TMUX_PANE" @agent-name "main-context" 2>>"$LOG_FILE"; then
  log "LABEL: set @agent-name=main-context on $TMUX_PANE"
else
  log "LABEL: FAILED to set @agent-name on $TMUX_PANE"
fi

# 3. Show pane labels on the border.
tmux set-option -w pane-border-status top 2>>"$LOG_FILE" || log "BORDER: pane-border-status failed"
tmux set-option -w pane-border-format " #{@agent-name} " 2>>"$LOG_FILE" || log "BORDER: pane-border-format failed"

log "DONE: pane=$TMUX_PANE labelled main-context"
exit 0
