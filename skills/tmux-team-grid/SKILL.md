---
name: tmux-team-grid
description: Organize existing tmux panes into a team grid layout. Scans pane titles for role-N patterns (executor-1, tester-2, reviewer-3, etc.), then rearranges them into rows by role, columns by number. Main context pane stays on the left (full height, fixed width). NEVER creates new panes. Use when user says "team grid", "tmux grid", "organize panes", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid

Scans existing tmux panes and rearranges them into a structured grid. **Never creates new panes.**

## The Layout Idea

You have a tmux window with multiple panes — one main context (this Claude session) and several team agent panes named like `executor-1`, `tester-2`, `reviewer-3`.

The goal: arrange them so you can **visually scan a task group top-to-bottom** in one column.

**Task group = same number.** Executor-1, tester-1, reviewer-1 all work on task 1 — they belong in column 1, stacked vertically. This way you glance down a column to see the full pipeline for one task.

**Role = same row.** All executors across tasks sit in the same horizontal row. This lets you compare the same role across tasks by scanning left-to-right.

```
│            │ task 1       │ task 2       │ task 3       │
│            │──────────────┼──────────────┼──────────────│
│   main     │ executor-1   │ executor-2   │ executor-3   │  ← executor row
│  context   │──────────────┼──────────────┼──────────────│
│            │ tester-1     │ tester-2     │ tester-3     │  ← tester row
│  (fixed    │──────────────┼──────────────┼──────────────│
│   width,   │ reviewer-1   │ reviewer-2   │ reviewer-3   │  ← reviewer row
│  full h)   │              │              │              │
```

**Main pane:** always leftmost, full window height, fixed width (default 70 columns). It never moves, never resizes vertically. Only the grid to its right reflows.

**Grid panes:** share all remaining horizontal space equally across columns. Rows share vertical space equally. On window resize, main stays fixed and grid columns re-equalize dynamically.

## Core Rules

1. **NEVER create new panes** (`split-window`, `new-window` are forbidden) — only scan, identify, and rearrange existing ones
2. **Main pane** = the pane running this Claude Code session. Always full height, fixed width, pinned left
3. **Scan pane titles** for `{role}-{number}` patterns (any string-dash-integer)
4. **Row order:** executor → tester → reviewer → researcher → then alphabetical for any others
5. **Column order:** sorted ascending by number (1, 2, 3, ...)
6. **Unrecognized panes** (title doesn't match `role-N`) are left untouched

## Instructions

### Step 1: Identify Main Pane and Scan All Panes

```bash
MAIN_PANE=$(tmux display-message -p '#{pane_id}')
tmux list-panes -F '#{pane_id} #{pane_title}'
```

- `MAIN_PANE` = this session's pane — skip during grid arrangement
- For every other pane, match title against `{role}-{number}`
- Build: `ROLES` (unique roles, ordered), `GROUPS` (unique numbers, sorted), pane ID map

### Step 2: Determine Grid Dimensions

- `NUM_ROWS` = number of unique roles
- `NUM_COLS` = number of unique task numbers
- Total grid panes = `NUM_ROWS × NUM_COLS` (some cells may be empty if sparse)

### Step 3: Rearrange Panes

Use `tmux swap-pane -s $SOURCE -t $TARGET` to move panes into correct grid positions. Do NOT use `split-window`.

Target positions (row-major order within the grid area):
- Column 1, top to bottom: `role1-1`, `role2-1`, `role3-1`
- Column 2, top to bottom: `role1-2`, `role2-2`, `role3-2`
- etc.

If panes are already roughly positioned, just resize — skip unnecessary swaps.

### Step 4: Label Panes

```bash
tmux select-pane -t $MAIN_PANE -T "main-context"
tmux set-option pane-border-status top
tmux set-option pane-border-format " #{pane_title} "
```

### Step 5: Create Dynamic Resize Script

Write `/tmp/tmux-resize.sh` with the actual `%`-prefixed pane IDs:

```bash
#!/bin/bash
MAIN_WIDTH=70
MAIN_PANE="<actual_main_id>"
NUM_COLS=<actual>

tmux resize-pane -t $MAIN_PANE -x $MAIN_WIDTH

TOTAL=$(tmux display-message -p '#{window_width}')
GRID_WIDTH=$(( TOTAL - MAIN_WIDTH - 4 ))
COL=$(( GRID_WIDTH / NUM_COLS ))

# Resize columns 1 through NUM_COLS-1 (last column gets remainder)
for pane in <col1_pane_ids>; do
  tmux resize-pane -t "$pane" -x $COL
done
for pane in <col2_pane_ids>; do
  tmux resize-pane -t "$pane" -x $COL
done
# ... repeat through NUM_COLS-1
```

### Step 6: Set Resize Hooks

```bash
tmux set-hook -g client-resized "run-shell '/tmp/tmux-resize.sh'"
tmux set-hook -g window-layout-changed "run-shell '/tmp/tmux-resize.sh'"
```

### Step 7: Finalize

```bash
tmux select-pane -t $MAIN_PANE
/tmp/tmux-resize.sh
```

Report the final layout to the user with a grid diagram showing pane assignments.

## Important Notes

- **NEVER `split-window` or `new-window`** — only rearrange existing panes
- Always use `%`-prefixed pane IDs (e.g. `%142`) — named targets break with spaces in session names
- Resize script must be dynamic: calculate column width from `#{window_width}` at runtime
- Both `client-resized` and `window-layout-changed` hooks are needed — VS Code terminal may not fire one reliably
- Main pane is always full height, fixed width — grid gets all remaining space
- Unrecognized panes are left untouched
