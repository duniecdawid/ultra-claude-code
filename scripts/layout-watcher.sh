#!/usr/bin/env bash
# Layout Watcher — monitors tmux pane @agent-name labels and arranges the grid
#
# Usage: ./layout-watcher.sh <window-id> <main-pane-id> [poll-interval-seconds]
# Example: ./layout-watcher.sh @8 %155 2
#
# What it does:
#   - Polls pane labels every N seconds (default: 2)
#   - When labels change, rearranges panes into the team grid layout
#   - Only touches panes in the specified window — other windows/sessions untouched
#   - Stage-adaptive: builds only what labels exist (startup → execution → final gate)
#   - Self-healing: if layout gets corrupted, next poll fixes it
#
# The Lead starts this at the beginning of execution and kills it at the end.

set -uo pipefail
# No set -e — individual tmux commands may fail (dead panes, etc.)

WINDOW="${1:?Usage: layout-watcher.sh <window-id> <main-pane-id> [poll-interval]}"
MAIN_PANE="${2:?Usage: layout-watcher.sh <window-id> <main-pane-id> [poll-interval]}"
POLL_INTERVAL="${3:-2}"
LEFT_WIDTH=70

LAST_SNAPSHOT=""
LAST_WIDTH=""

log() {
  echo "[$(date -Iseconds)] $*"
}

# Graceful shutdown
cleanup() {
  log "Layout watcher stopped"
  exit 0
}
trap cleanup SIGTERM SIGINT

arrange_layout() {
  # ── 1. Scan labels ────────────────────────────────────────────
  local pm_pane="" tk_pane="" gate_pane=""
  local -A task_panes  # task_panes[N]="pane1 pane2 pane3"
  local task_nums=()

  while IFS=' ' read -r pane_id label; do
    [ "$pane_id" = "$MAIN_PANE" ] && continue
    [ -z "$label" ] && continue

    if [[ "$label" =~ ^task-([0-9]+)$ ]]; then
      local num="${BASH_REMATCH[1]}"
      task_panes["$num"]="${task_panes[$num]:+${task_panes[$num]} }$pane_id"
      if ! printf '%s\n' "${task_nums[@]}" 2>/dev/null | grep -qx "$num"; then
        task_nums+=("$num")
      fi
    elif [[ "$label" =~ ^pm ]]; then
      pm_pane="$pane_id"
    elif [[ "$label" =~ ^knowledge ]]; then
      tk_pane="$pane_id"
    elif [[ "$label" =~ ^final-gate ]]; then
      gate_pane="$pane_id"
    fi
  done < <(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{@agent-name}' 2>/dev/null)

  task_nums=($(printf '%s\n' "${task_nums[@]}" 2>/dev/null | sort -n))

  local num_tasks=${#task_nums[@]}
  log "Arranging: ${num_tasks} tasks, pm=${pm_pane:--}, tk=${tk_pane:--}, gate=${gate_pane:--}"

  # ── 2. Break only LABELED non-main panes to hidden windows ────
  # Unlabeled panes are left untouched — they haven't been claimed yet.
  # Once an agent labels a pane, the watcher will pick it up on the next poll.
  local labeled_panes=""
  [ -n "$pm_pane" ] && labeled_panes="$labeled_panes $pm_pane"
  [ -n "$tk_pane" ] && labeled_panes="$labeled_panes $tk_pane"
  [ -n "$gate_pane" ] && labeled_panes="$labeled_panes $gate_pane"
  for num in "${task_nums[@]}"; do
    labeled_panes="$labeled_panes ${task_panes[$num]}"
  done
  for pid in $labeled_panes; do
    tmux break-pane -d -s "$pid" 2>/dev/null || true
  done
  sleep 0.2

  # ── 3. Rebuild left column ───────────────────────────────────
  if [ -n "$pm_pane" ]; then
    tmux join-pane -v -s "$pm_pane" -t "$MAIN_PANE" -l 50% 2>/dev/null || true
  fi
  if [ -n "$tk_pane" ]; then
    local tk_target="${pm_pane:-$MAIN_PANE}"
    tmux join-pane -v -s "$tk_pane" -t "$tk_target" -l 50% 2>/dev/null || true
  fi

  # ── 4. Rebuild task columns ──────────────────────────────────
  local column_heads="" num_cols=0

  for num in "${task_nums[@]}"; do
    local panes=(${task_panes[$num]})
    [ ${#panes[@]} -eq 0 ] && continue

    # First pane → column head (full-height)
    local head="${panes[0]}"
    if [ $num_cols -eq 0 ]; then
      tmux join-pane -fh -s "$head" -t "$MAIN_PANE" 2>/dev/null || true
    else
      local last_col=$(echo $column_heads | awk '{print $NF}')
      tmux join-pane -fh -s "$head" -t "$last_col" 2>/dev/null || true
    fi
    column_heads="$column_heads $head"
    num_cols=$((num_cols + 1))

    # Remaining panes → stack below
    local prev="$head"
    local remaining=$((${#panes[@]} - 1))
    for (( i=1; i<${#panes[@]}; i++ )); do
      local pct=$(( 100 * remaining / (remaining + 1) ))
      tmux join-pane -v -s "${panes[$i]}" -t "$prev" -l ${pct}% 2>/dev/null || true
      prev="${panes[$i]}"
      remaining=$((remaining - 1))
    done
  done

  # ── 5. Final gate column ─────────────────────────────────────
  if [ -n "$gate_pane" ]; then
    if [ $num_cols -eq 0 ]; then
      tmux join-pane -fh -s "$gate_pane" -t "$MAIN_PANE" 2>/dev/null || true
    else
      local last_col=$(echo $column_heads | awk '{print $NF}')
      tmux join-pane -fh -s "$gate_pane" -t "$last_col" 2>/dev/null || true
    fi
    column_heads="$column_heads $gate_pane"
    num_cols=$((num_cols + 1))
  fi

  # ── 6. Equalize columns (two-pass) ──────────────────────────
  if [ $num_cols -gt 0 ]; then
    local win_width
    win_width=$(tmux display-message -t "$MAIN_PANE" -p '#{window_width}' 2>/dev/null) || return
    local right_width=$((win_width - LEFT_WIDTH - 1))
    local col_width=$(( (right_width - (num_cols - 1)) / num_cols ))

    for pass in 1 2; do
      for head in $column_heads; do
        tmux resize-pane -t "$head" -x $col_width 2>/dev/null || true
      done
      # Pin ALL left-column panes
      for lp in "$MAIN_PANE" "$pm_pane" "$tk_pane"; do
        [ -n "$lp" ] && tmux resize-pane -t "$lp" -x $LEFT_WIDTH 2>/dev/null || true
      done
    done
  fi

  # ── 7. Ensure borders show labels ───────────────────────────
  tmux set-option -w -t "$WINDOW" pane-border-status top 2>/dev/null || true
  tmux set-option -w -t "$WINDOW" pane-border-format " #{@agent-name} " 2>/dev/null || true
  tmux select-pane -t "$MAIN_PANE" 2>/dev/null || true

  log "Layout done: $num_cols columns"
}

# ── Main loop ──────────────────────────────────────────────────
log "Layout watcher started — window=$WINDOW main=$MAIN_PANE poll=${POLL_INTERVAL}s"

# Set initial label and borders
tmux set-option -p -t "$MAIN_PANE" @agent-name "main-context" 2>/dev/null || true
tmux set-option -w -t "$WINDOW" pane-border-status top 2>/dev/null || true
tmux set-option -w -t "$WINDOW" pane-border-format " #{@agent-name} " 2>/dev/null || true

while true; do
  # Check if window still exists
  if ! tmux display-message -t "$WINDOW" -p "" 2>/dev/null; then
    log "Window $WINDOW no longer exists — exiting"
    exit 0
  fi

  # Snapshot current labels (only labeled panes)
  CURRENT=$(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{@agent-name}' 2>/dev/null | grep -v ' $' | sort)
  CURRENT_WIDTH=$(tmux display-message -t "$WINDOW" -p '#{window_width}' 2>/dev/null)

  if [ "$CURRENT" != "$LAST_SNAPSHOT" ]; then
    arrange_layout
    # Re-snapshot after arrangement
    LAST_SNAPSHOT=$(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{@agent-name}' 2>/dev/null | grep -v ' $' | sort)
    LAST_WIDTH="$CURRENT_WIDTH"
  elif [ "$CURRENT_WIDTH" != "$LAST_WIDTH" ]; then
    # Window resized — re-equalize without full rearrange
    log "Window resized to ${CURRENT_WIDTH} — re-equalizing"
    arrange_layout
    LAST_SNAPSHOT=$(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{@agent-name}' 2>/dev/null | grep -v ' $' | sort)
    LAST_WIDTH="$CURRENT_WIDTH"
  fi

  sleep "$POLL_INTERVAL"
done
