---
description: Recovery tool — re-layouts panes if incremental placement produces a corrupted layout. Reads @agent-name labels to identify panes, then rebuilds the grid using break+join. Use when user says "team grid", "tmux grid", "fix layout", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid (Recovery)

Re-layouts existing panes when incremental placement has gone wrong. Reads `@agent-name` custom options (set by the Lead during spawning) to identify and classify panes, then rebuilds the grid.

**Normal operation does NOT use this skill.** The Lead places panes incrementally during spawning (see `plan-execution/references/phase-2-spawn-prompts.md`). This skill is only for recovery.

## The Layout

```
┌──────────┬──────────┬──────────┬─────────────┐
│          │ exec-1   │ exec-2   │             │
│  main    ├──────────┼──────────┤ final-gate  │
│ context  │ review-1 │ review-2 │             │
│          ├──────────┼──────────┤             │
├──────────┤ test-1   │ test-2   │             │
│ pm       ├──────────┴──────────┤             │
├──────────┤                     │             │
│ tech-kb  │                     │             │
└──────────┴─────────────────────┴─────────────┘
```

- **Left column (fixed 70 cols):** main-context (50%), pm (25%), knowledge (25%)
- **Task columns (equal width):** executor / reviewer / tester — one column per task
- **Final gate:** own full-height column on the right

## Instructions

Get the main pane ID with `tmux display-message -p '#{pane_id}'`, then write the recovery script to `/tmp/tmux-team-grid-recovery.sh` **using Bash** (`cat > ... << 'EOF'`). Replace `__MAIN_PANE__` with the actual ID. Then execute with `bash /tmp/tmux-team-grid-recovery.sh`.

**Important:** Only the `Bash` tool is available — do NOT use the Write tool.

```bash
#!/usr/bin/env bash
MAIN_PANE="__MAIN_PANE__"
LEFT_WIDTH=70

# ── 1. Scan panes by @agent-name label ─────────────────────────
# Labels: "task-N" (3 panes per task), "pm-*", "knowledge-*", "final-gate"
declare -A TASK_PANES  # TASK_PANES[N]="pane1 pane2 pane3"
PM_PANE=""
TK_PANE=""
GATE_PANE=""
TASK_NUMS=()
COLUMN_HEADS=""
NUM_COLS=0

while IFS=' ' read -r pane_id label; do
  [ "$pane_id" = "$MAIN_PANE" ] && continue
  [ -z "$label" ] && continue

  if [[ "$label" =~ ^task-([0-9]+)$ ]]; then
    num="${BASH_REMATCH[1]}"
    TASK_PANES["$num"]="${TASK_PANES[$num]:+${TASK_PANES[$num]} }$pane_id"
    if ! printf '%s\n' "${TASK_NUMS[@]}" | grep -qx "$num" 2>/dev/null; then
      TASK_NUMS+=("$num")
    fi
  elif [[ "$label" =~ ^pm ]]; then
    PM_PANE="$pane_id"
  elif [[ "$label" =~ ^knowledge ]]; then
    TK_PANE="$pane_id"
  elif [[ "$label" =~ ^final-gate ]]; then
    GATE_PANE="$pane_id"
  fi
done < <(tmux list-panes -F '#{pane_id} #{@agent-name}')

# Sort task numbers
TASK_NUMS=($(printf '%s\n' "${TASK_NUMS[@]}" | sort -n))

echo "Found: ${#TASK_NUMS[@]} tasks, pm=${PM_PANE:-(none)}, knowledge=${TK_PANE:-(none)}, gate=${GATE_PANE:-(none)}"

if [ ${#TASK_NUMS[@]} -eq 0 ] && [ -z "$PM_PANE" ] && [ -z "$TK_PANE" ] && [ -z "$GATE_PANE" ]; then
  echo "No labeled panes found. Nothing to recover."
  echo "Hint: panes need @agent-name labels set by the Lead during spawning."
  exit 0
fi

# ── 2. Break all non-main panes to hidden windows ──────────────
ALL_PANES=($(tmux list-panes -F '#{pane_id}' | grep -v "^${MAIN_PANE}$"))
for pid in "${ALL_PANES[@]}"; do
  tmux break-pane -d -s "$pid" 2>/dev/null || true
done
sleep 0.3

# ── 3. Rebuild left column ─────────────────────────────────────
if [ -n "$PM_PANE" ]; then
  tmux join-pane -v -s "$PM_PANE" -t "$MAIN_PANE" -l 50% 2>/dev/null
fi
if [ -n "$TK_PANE" ]; then
  target="${PM_PANE:-$MAIN_PANE}"
  tmux join-pane -v -s "$TK_PANE" -t "$target" -l 50% 2>/dev/null
fi

# ── 4. Rebuild task columns ────────────────────────────────────
for num in "${TASK_NUMS[@]}"; do
  panes=(${TASK_PANES[$num]})
  [ ${#panes[@]} -eq 0 ] && continue

  # First pane → column head (full-height)
  HEAD="${panes[0]}"
  if [ $NUM_COLS -eq 0 ]; then
    tmux join-pane -fh -s "$HEAD" -t "$MAIN_PANE" 2>/dev/null
  else
    LAST_COL=$(echo $COLUMN_HEADS | awk '{print $NF}')
    tmux join-pane -fh -s "$HEAD" -t "$LAST_COL" 2>/dev/null
  fi
  COLUMN_HEADS="$COLUMN_HEADS $HEAD"
  NUM_COLS=$((NUM_COLS + 1))

  # Remaining panes → stack below
  prev="$HEAD"
  remaining=$((${#panes[@]} - 1))
  for (( i=1; i<${#panes[@]}; i++ )); do
    pct=$(( 100 * remaining / (remaining + 1) ))
    tmux join-pane -v -s "${panes[$i]}" -t "$prev" -l ${pct}% 2>/dev/null
    prev="${panes[$i]}"
    remaining=$((remaining - 1))
  done
done

# ── 5. Final gate column ──────────────────────────────────────
if [ -n "$GATE_PANE" ]; then
  if [ $NUM_COLS -eq 0 ]; then
    tmux join-pane -fh -s "$GATE_PANE" -t "$MAIN_PANE" 2>/dev/null
  else
    LAST_COL=$(echo $COLUMN_HEADS | awk '{print $NF}')
    tmux join-pane -fh -s "$GATE_PANE" -t "$LAST_COL" 2>/dev/null
  fi
  COLUMN_HEADS="$COLUMN_HEADS $GATE_PANE"
  NUM_COLS=$((NUM_COLS + 1))
fi

# ── 6. Equalize columns (two-pass) ────────────────────────────
if [ $NUM_COLS -gt 0 ]; then
  win_width=$(tmux display-message -p '#{window_width}')
  right_width=$((win_width - LEFT_WIDTH - 1))
  col_width=$(( (right_width - (NUM_COLS - 1)) / NUM_COLS ))
  for pass in 1 2; do
    for head in $COLUMN_HEADS; do
      tmux resize-pane -t "$head" -x $col_width 2>/dev/null || true
    done
    # Pin ALL left-column panes to LEFT_WIDTH
    for lp in "$MAIN_PANE" "$PM_PANE" "$TK_PANE"; do
      [ -n "$lp" ] && tmux resize-pane -t "$lp" -x $LEFT_WIDTH 2>/dev/null || true
    done
  done
fi

# ── 7. Ensure borders show labels ─────────────────────────────
tmux set-option -w pane-border-status top
tmux set-option -w pane-border-format " #{@agent-name} "
tmux select-pane -t "$MAIN_PANE"

echo ""
echo "Grid recovered: ${#TASK_NUMS[@]} tasks, $NUM_COLS columns"
tmux list-panes -F '#{pane_id} #{@agent-name} #{pane_width}x#{pane_height}'
```

## Emergency Fallback

If recovery fails or panes are too corrupted, use tmux's built-in tiled layout:

```bash
tmux select-layout tiled
```

This distributes all panes evenly with no column/row structure — a quick escape hatch to see all panes again.
