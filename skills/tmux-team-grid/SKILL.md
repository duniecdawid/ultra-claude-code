---
name: tmux-team-grid
description: Organize existing tmux panes into a team grid layout. Scans pane titles for role-N patterns (executor-1, tester-2, reviewer-3, etc.), then rearranges them into rows by role, columns by number. Main context pane stays on the left (full height, fixed width). NEVER creates new panes. Use when user says "team grid", "tmux grid", "organize panes", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid

Scans existing tmux panes and rearranges them into a structured grid. **Never creates new panes.**

## The Layout

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

- **Main pane:** leftmost, full height, fixed width (70 cols). Never moves.
- **Grid:** rows = roles, columns = task numbers. Equal space distribution.
- **Row order:** executor → tester → reviewer → researcher → alphabetical for others
- **Column order:** ascending by number (1, 2, 3, ...)

## Instructions

### Step 1: Write and run the grid builder script

Get the main pane ID with `tmux display-message -p '#{pane_id}'`, then write `/tmp/tmux-team-grid.sh` with this content (replacing `__MAIN_PANE__` with the actual ID) and execute it.

```bash
#!/usr/bin/env bash
# NO set -e — handle errors explicitly so one failed join doesn't kill everything

MAIN_PANE="__MAIN_PANE__"
MAIN_WIDTH=70
WINDOW=$(tmux display-message -p '#{window_id}')

# ── 1. Scan panes, classify by role-N pattern ──────────────────────
declare -A PANE_MAP        # PANE_MAP[role,number] = pane_id
declare -A ROLE_ORDER_MAP  # for sorting
ROLE_LIST=()
NUM_LIST=()

role_priority() {
  case "$1" in
    executor)   echo 1 ;;
    tester)     echo 2 ;;
    reviewer)   echo 3 ;;
    researcher) echo 4 ;;
    *)          echo 5 ;;
  esac
}

TOTAL_PANES=0
MATCHED_PANES=0
UNMATCHED_PANES=()

while IFS=' ' read -r pane_id pane_title; do
  [ "$pane_id" = "$MAIN_PANE" ] && continue
  ((TOTAL_PANES++))
  if [[ "$pane_title" =~ ^([a-zA-Z_-]+)-([0-9]+)$ ]]; then
    role="${BASH_REMATCH[1]}"
    num="${BASH_REMATCH[2]}"
    PANE_MAP["$role,$num"]="$pane_id"
    ROLE_ORDER_MAP["$role"]=$(role_priority "$role")
    ROLE_LIST+=("$role")
    NUM_LIST+=("$num")
    ((MATCHED_PANES++))
  else
    UNMATCHED_PANES+=("$pane_id:$pane_title")
  fi
done < <(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{pane_title}')

# ── Safety check: abort if naming structure is not recognized ──────
# Require at least 2 matched panes AND >50% of non-main panes must match.
# This prevents destroying a layout the script doesn't understand.

if [ "$TOTAL_PANES" -eq 0 ]; then
  echo "ABORT: No panes found besides main. Nothing to arrange."
  exit 0
fi

if [ "$MATCHED_PANES" -lt 2 ]; then
  echo "ABORT: Only $MATCHED_PANES pane(s) match the role-N naming pattern (need at least 2)."
  echo "  Expected names like: executor-1, tester-2, reviewer-3"
  echo "  Found: $(tmux list-panes -t "$WINDOW" -F '#{pane_title}' | grep -v '^$' | tr '\n' ', ')"
  echo "Leaving layout untouched."
  exit 1
fi

MATCH_PCT=$(( MATCHED_PANES * 100 / TOTAL_PANES ))
if [ "$MATCH_PCT" -lt 50 ]; then
  echo "ABORT: Only $MATCHED_PANES/$TOTAL_PANES panes (${MATCH_PCT}%) match role-N pattern."
  echo "  Matched: ${ROLE_LIST[*]/%/-}${NUM_LIST[*]}"
  echo "  Unmatched:"
  for u in "${UNMATCHED_PANES[@]}"; do
    echo "    ${u%%:*} — '${u#*:}'"
  done
  echo "Leaving layout untouched. Rename panes to role-N format first."
  exit 1
fi

# Deduplicate and sort
ROLES=($(printf '%s\n' "${ROLE_LIST[@]}" | sort -u | while read r; do
  echo "${ROLE_ORDER_MAP[$r]} $r"
done | sort -n | awk '{print $2}'))

NUMS=($(printf '%s\n' "${NUM_LIST[@]}" | sort -un))

NUM_ROLES=${#ROLES[@]}
NUM_COLS=${#NUMS[@]}

if [ "$NUM_ROLES" -eq 0 ] || [ "$NUM_COLS" -eq 0 ]; then
  echo "ABORT: No valid grid structure found."
  exit 0
fi

echo "Grid: $NUM_ROLES roles × $NUM_COLS tasks ($MATCHED_PANES/$TOTAL_PANES panes matched)"
echo "  Roles: ${ROLES[*]}"
echo "  Tasks: ${NUMS[*]}"
if [ "${#UNMATCHED_PANES[@]}" -gt 0 ]; then
  echo "  Skipping ${#UNMATCHED_PANES[@]} unrecognized pane(s) (will not be moved)"
fi

# ── 2. Break all grid panes to hidden windows ──────────────────────
ERRORS=0
for role in "${ROLES[@]}"; do
  for num in "${NUMS[@]}"; do
    pid="${PANE_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
    if ! tmux break-pane -d -s "$pid" 2>/dev/null; then
      echo "  WARN: break-pane failed for $role-$num ($pid)"
      ((ERRORS++))
    fi
  done
done
sleep 0.3

# ── 3. Rebuild grid ────────────────────────────────────────────────
# IMPORTANT: tmux panes form a binary tree. If we build each column
# fully (all vertical splits) before the next, join-pane -h only
# splits ONE cell, not the whole column. So we MUST build in two phases:
#   Phase 1: first row across all columns (horizontal splits → columns)
#   Phase 2: remaining rows within each column (vertical splits → rows)

FIRST_COL_PANE=()
JOIN_TARGET="$MAIN_PANE"
FIRST_ROLE="${ROLES[0]}"

# Phase 1: horizontal structure — one pane per column
for col_idx in "${!NUMS[@]}"; do
  num="${NUMS[$col_idx]}"
  pid="${PANE_MAP[$FIRST_ROLE,$num]:-}"; [ -z "$pid" ] && continue
  if tmux join-pane -h -t "$JOIN_TARGET" -s "$pid" 2>/dev/null; then
    FIRST_COL_PANE+=("$pid")
    JOIN_TARGET="$pid"
  else
    echo "  ERROR: Phase 1 join failed for $FIRST_ROLE-$num ($pid)"
    ((ERRORS++))
  fi
  sleep 0.05
done

# Phase 2: vertical structure — remaining rows per column
for col_idx in "${!NUMS[@]}"; do
  num="${NUMS[$col_idx]}"
  prev_pid="${PANE_MAP[$FIRST_ROLE,$num]:-}"; [ -z "$prev_pid" ] && continue
  for (( row_idx=1; row_idx < NUM_ROLES; row_idx++ )); do
    role="${ROLES[$row_idx]}"
    pid="${PANE_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
    if tmux join-pane -v -t "$prev_pid" -s "$pid" 2>/dev/null; then
      prev_pid="$pid"
    else
      echo "  ERROR: Phase 2 join failed for $role-$num ($pid)"
      ((ERRORS++))
    fi
    sleep 0.05
  done
done

# ── 4. Resize: main fixed, columns equal, rows equal ──────────────
sleep 0.3
tmux resize-pane -t "$MAIN_PANE" -x "$MAIN_WIDTH" 2>/dev/null

TOTAL_W=$(tmux display-message -p '#{window_width}')
GRID_W=$(( TOTAL_W - MAIN_WIDTH - 1 ))
COL_W=$(( GRID_W / NUM_COLS ))

# Resize columns (skip last — gets remainder)
for (( i=0; i < ${#FIRST_COL_PANE[@]} - 1; i++ )); do
  tmux resize-pane -t "${FIRST_COL_PANE[$i]}" -x "$COL_W" 2>/dev/null || true
done

# Equalize rows
TOTAL_H=$(tmux display-message -p '#{window_height}')
ROW_H=$(( TOTAL_H / NUM_ROLES ))
for role in "${ROLES[@]}"; do
  for num in "${NUMS[@]}"; do
    pid="${PANE_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
    tmux resize-pane -t "$pid" -y "$ROW_H" 2>/dev/null || true
  done
done

# ── 5. Generate and install resize hook ────────────────────────────
# This script runs on every window resize to keep main width constant
# and redistribute grid space evenly.
RESIZE_SCRIPT="/tmp/tmux-resize-grid.sh"
{
  echo '#!/usr/bin/env bash'
  echo "WINDOW=\"$WINDOW\""
  echo "MAIN_PANE=\"$MAIN_PANE\""
  echo "MAIN_WIDTH=$MAIN_WIDTH"
  echo "NUM_COLS=$NUM_COLS"
  echo "NUM_ROLES=$NUM_ROLES"
  echo ''
  echo '# Only run if we are in the grid window (client-resized fires for all windows)'
  echo 'CURRENT=$(tmux display-message -p "#{window_id}" 2>/dev/null) || exit 0'
  echo '[ "$CURRENT" != "$WINDOW" ] && exit 0'
  echo ''
  echo 'tmux resize-pane -t "$MAIN_PANE" -x "$MAIN_WIDTH" 2>/dev/null || exit 0'
  echo ''
  echo 'TOTAL_W=$(tmux display-message -p "#{window_width}")'
  echo 'GRID_W=$(( TOTAL_W - MAIN_WIDTH - 1 ))'
  echo 'COL_W=$(( GRID_W / NUM_COLS ))'
  echo 'TOTAL_H=$(tmux display-message -p "#{window_height}")'
  echo 'ROW_H=$(( TOTAL_H / NUM_ROLES ))'
  echo ''
  # Column width resizes (skip last column — gets remainder)
  for (( i=0; i < ${#FIRST_COL_PANE[@]} - 1; i++ )); do
    echo "tmux resize-pane -t \"${FIRST_COL_PANE[$i]}\" -x \$COL_W 2>/dev/null || true"
  done
  echo ''
  # Row height resizes
  for role in "${ROLES[@]}"; do
    for num in "${NUMS[@]}"; do
      pid="${PANE_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
      echo "tmux resize-pane -t \"$pid\" -y \$ROW_H 2>/dev/null || true"
    done
  done
} > "$RESIZE_SCRIPT"
chmod +x "$RESIZE_SCRIPT"

# Install hooks:
# - window-layout-changed (window-level) — fires on pane split/close within window
# - client-resized (session-level) — fires on terminal resize; script guards by window ID
tmux set-hook -w window-layout-changed "run-shell '$RESIZE_SCRIPT'"
tmux set-hook client-resized "run-shell '$RESIZE_SCRIPT'"

# ── 6. Labels and borders ─────────────────────────────────────────
tmux set-option -w pane-border-status top
tmux set-option -w pane-border-format " #{pane_title} "
tmux select-pane -t "$MAIN_PANE"

# ── 7. Report ─────────────────────────────────────────────────────
if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "WARNING: $ERRORS errors occurred during arrangement"
fi

echo ""
echo "Grid arranged: ${NUM_COLS} tasks × ${NUM_ROLES} roles (resize hook installed)"
echo ""
printf "│ %-12s │" "main"
for num in "${NUMS[@]}"; do printf " task %-3s │" "$num"; done
echo ""
for role in "${ROLES[@]}"; do
  printf "│ %-12s │" "$role"
  for num in "${NUMS[@]}"; do
    pid="${PANE_MAP[$role,$num]:-}"
    if [ -n "$pid" ]; then
      printf " %-8s │" "$role-$num"
    else
      printf " %-8s │" "(empty)"
    fi
  done
  echo ""
done
```

### Step 2: Report

The resize hook (`/tmp/tmux-resize-grid.sh`) is auto-generated and installed by the main script — no separate step needed. Print the final grid diagram to the user.

## Critical Rules

- **NEVER use `split-window` or `new-window`** — only rearrange existing panes
- **NEVER use `set -e`** — individual join failures must not kill the script
- **Always use `%`-prefixed pane IDs** (e.g. `%142`) — never named targets
- **Two-phase build is mandatory** — horizontal first (columns), then vertical (rows). Building column-by-column causes the binary tree to nest incorrectly.
- **`break-pane -d`** detaches without destroying — the pane moves to a hidden window
- **`join-pane`** moves it back into the target window at the specified position
- **Main pane never moves** — all joins target relative to it or to other grid panes
- **Unrecognized panes** (title doesn't match `role-N`) are left untouched
- Set hooks on **window** level (`-w`) not global (`-g`) to avoid affecting other windows
