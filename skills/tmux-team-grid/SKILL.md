---
name: tmux-team-grid
description: Organize existing tmux panes into a team grid layout for plan-execution teams. Left column stacks main context + shared agents (tech-knowledge, project-manager). Right side shows task grid (executor/tester/reviewer rows × task columns). Reads pane titles to identify agents. NEVER creates new panes. Use when user says "team grid", "tmux grid", "organize panes", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid

Scans existing tmux panes by title and rearranges them into a structured grid. **Never creates new panes.**

## The Layout

```
│ main         │ executor-1   │ executor-2   │ executor-3   │
│ context      │──────────────┼──────────────┼──────────────│
│──────────────│ tester-1     │ tester-2     │ tester-3     │
│ tech-        │──────────────┼──────────────┼──────────────│
│ knowledge    │ reviewer-1   │ reviewer-2   │ reviewer-3   │
│──────────────│              │              │              │
│ project-     │              │              │              │
│ manager      │              │              │              │
```

- **Left column (fixed 70 cols, full height):**
  - Main context (top, ~50% height) — never moves
  - Tech-knowledge (middle, ~25%) — shared, plan-wide
  - Project-manager (bottom, ~25%) — shared, plan-wide
- **Task grid (remaining width):**
  - Rows = roles: executor → tester → reviewer
  - Columns = task numbers: 1, 2, 3, ...
  - Equal space distribution

If only some shared agents exist (e.g., knowledge but no PM), the left column adjusts — main gets ~60%, the single shared agent gets ~40%.

### Adaptive Layouts

The grid adapts to the current execution phase:

**Startup (no task teams yet):** Only main + knowledge + PM. Left column stacked vertically (50%/25%/25%).
```
│ main context      │
│───────────────────│
│ tech-knowledge    │
│───────────────────│
│ project-manager   │
```

**Full execution:** Left column + task grid (the default layout above).

**Final gate (all tasks done):** Only main + final-gate tester (+ possibly knowledge/PM still alive).
```
│ main         │ final-gate   │
│ context      │              │
│──────────────│              │
│ (knowledge)  │              │
│──────────────│              │
│ (pm)         │              │
```

## Pane Identification

Panes are matched by their tmux pane title (`#{pane_title}`). Plan-execution is responsible for setting these titles after spawning each agent.

**Title patterns recognized:**
- Task agents: `executor-N`, `tester-N`, `reviewer-N` (N = task number)
- Final gate: title starts with `final-gate`
- Tech-knowledge: title starts with `knowledge` (e.g., `knowledge-user-auth`)
- Project-manager: title starts with `pm` (e.g., `pm-user-auth`)

If a manifest file exists at `/tmp/team-grid-manifest.json`, pane titles are applied from it before scanning. This is a fallback for cases where titles weren't set at spawn time.

## Instructions

### Step 1: Write and run the grid builder script

Get the main pane ID with `tmux display-message -p '#{pane_id}'`, then write the script to `/tmp/tmux-team-grid.sh` **using Bash** (e.g., `cat > /tmp/tmux-team-grid.sh << 'EOF' ... EOF`). Replace `__MAIN_PANE__` with the actual ID. Then execute with `bash /tmp/tmux-team-grid.sh`.

**Important:** Only the `Bash` tool is available — do NOT use the Write tool. Write the file via `cat` heredoc in Bash.

```bash
#!/usr/bin/env bash
# NO set -e — individual join failures must not kill the script

MAIN_PANE="__MAIN_PANE__"
MAIN_WIDTH=70
WINDOW=$(tmux display-message -t "$MAIN_PANE" -p '#{window_id}')

# ── 0. Apply manifest titles if available ────────────────────────
MANIFEST="/tmp/team-grid-manifest.json"
if [ -f "$MANIFEST" ] && command -v python3 &>/dev/null; then
  echo "Applying pane titles from manifest..."
  python3 -c "
import json, subprocess
with open('$MANIFEST') as f:
    data = json.load(f)
for pane_id, info in data.get('agents', {}).items():
    role = info['role']
    task = info.get('task')
    title = f'{role}-{task}' if task else role
    subprocess.run(['tmux', 'select-pane', '-t', pane_id, '-T', title],
                   capture_output=True)
"
  sleep 0.1
fi

# ── 1. Scan panes, classify ─────────────────────────────────────
declare -A TASK_MAP          # TASK_MAP[role,number] = pane_id
declare -A SHARED_MAP        # SHARED_MAP[knowledge|pm] = pane_id
TASK_ROLES_RAW=()
TASK_NUMS_RAW=()

task_role_priority() {
  case "$1" in
    executor) echo 1 ;; tester) echo 2 ;; reviewer) echo 3 ;; *) echo 4 ;;
  esac
}

TOTAL_PANES=0
MATCHED_PANES=0
UNMATCHED=()

while IFS=' ' read -r pane_id pane_title; do
  [ "$pane_id" = "$MAIN_PANE" ] && continue
  ((TOTAL_PANES++))

  # Task agent: executor-N, tester-N, reviewer-N
  if [[ "$pane_title" =~ ^(executor|tester|reviewer)-([0-9]+)$ ]]; then
    role="${BASH_REMATCH[1]}"
    num="${BASH_REMATCH[2]}"
    TASK_MAP["$role,$num"]="$pane_id"
    TASK_ROLES_RAW+=("$role")
    TASK_NUMS_RAW+=("$num")
    ((MATCHED_PANES++))
  # Final gate tester
  elif [[ "$pane_title" =~ ^final-gate ]]; then
    SHARED_MAP["final-gate"]="$pane_id"
    ((MATCHED_PANES++))
  # Shared: knowledge-* or just "knowledge"
  elif [[ "$pane_title" =~ ^knowledge ]]; then
    SHARED_MAP["knowledge"]="$pane_id"
    ((MATCHED_PANES++))
  # Shared: pm-* or just "pm"
  elif [[ "$pane_title" =~ ^pm ]]; then
    SHARED_MAP["pm"]="$pane_id"
    ((MATCHED_PANES++))
  else
    UNMATCHED+=("$pane_id:$pane_title")
  fi
done < <(tmux list-panes -t "$WINDOW" -F '#{pane_id} #{pane_title}')

# ── Safety checks ───────────────────────────────────────────────
if [ "$TOTAL_PANES" -eq 0 ]; then
  echo "ABORT: No panes found besides main."
  exit 0
fi

if [ "$MATCHED_PANES" -lt 1 ]; then
  echo "ABORT: No panes matched."
  echo "  Expected titles: executor-1, tester-1, reviewer-1, knowledge-*, pm-*, final-gate"
  echo "  Actual titles:"
  tmux list-panes -t "$WINDOW" -F '  #{pane_id}  #{pane_title}' | grep -v "^  $MAIN_PANE"
  echo ""
  echo "If titles aren't set, check that plan-execution is setting them at spawn time."
  exit 1
fi

MATCH_PCT=$(( MATCHED_PANES * 100 / TOTAL_PANES ))
if [ "$MATCH_PCT" -lt 40 ]; then
  echo "ABORT: Only $MATCHED_PANES/$TOTAL_PANES (${MATCH_PCT}%) matched."
  echo "  Unmatched:"
  for u in "${UNMATCHED[@]}"; do echo "    ${u%%:*} — '${u#*:}'"; done
  exit 1
fi

# Deduplicate and sort
ROLES=($(printf '%s\n' "${TASK_ROLES_RAW[@]}" | sort -u | while read r; do
  echo "$(task_role_priority "$r") $r"
done | sort -n | awk '{print $2}'))

NUMS=($(printf '%s\n' "${TASK_NUMS_RAW[@]}" | sort -un))

NUM_ROLES=${#ROLES[@]}
NUM_COLS=${#NUMS[@]}
KNOW_PANE="${SHARED_MAP[knowledge]:-}"
PM_PANE="${SHARED_MAP[pm]:-}"
GATE_PANE="${SHARED_MAP[final-gate]:-}"
# Left-column shared agents (stacked below main)
LEFT_SHARED=0
[ -n "$KNOW_PANE" ] && ((LEFT_SHARED++))
[ -n "$PM_PANE" ] && ((LEFT_SHARED++))
# Total right-side columns = task columns + final-gate (if present)
TOTAL_RIGHT_COLS=$NUM_COLS
[ -n "$GATE_PANE" ] && ((TOTAL_RIGHT_COLS++))

echo "Layout: ${NUM_COLS} tasks × ${NUM_ROLES} roles + ${LEFT_SHARED} shared + $([ -n "$GATE_PANE" ] && echo "final-gate" || echo "no gate")"
[ "$NUM_COLS" -gt 0 ] && echo "  Roles: ${ROLES[*]}  Tasks: ${NUMS[*]}"
[ -n "$KNOW_PANE" ] && echo "  Left: tech-knowledge ($KNOW_PANE)"
[ -n "$PM_PANE" ] && echo "  Left: project-manager ($PM_PANE)"
[ -n "$GATE_PANE" ] && echo "  Right: final-gate ($GATE_PANE)"
[ "${#UNMATCHED[@]}" -gt 0 ] && echo "  Skipping ${#UNMATCHED[@]} unrecognized pane(s)"

# ── 1b. Save layout snapshot for restore ────────────────────────
RESTORE_SCRIPT="/tmp/tmux-restore-layout.sh"
{
  echo '#!/usr/bin/env bash'
  echo "WINDOW=\"$WINDOW\""
  echo "MAIN_PANE=\"$MAIN_PANE\""
  echo ''
  echo '# Remove resize hooks from the grid window'
  echo "tmux set-hook -t \"\$WINDOW\" -u window-layout-changed 2>/dev/null || true"
  echo "tmux set-hook -t \"\$WINDOW\" -u client-resized 2>/dev/null || true"
  echo ''
  echo '# Break all non-main panes to hidden windows'
  echo 'ALL_PANES=($(tmux list-panes -t "$WINDOW" -F "#{pane_id}" | grep -v "^${MAIN_PANE}$"))'
  echo 'for pid in "${ALL_PANES[@]}"; do'
  echo '  tmux break-pane -d -s "$pid" 2>/dev/null || true'
  echo 'done'
  echo 'sleep 0.3'
  echo ''
  echo '# Rejoin all broken panes — apply tiled layout after each join'
  echo '# to prevent running out of space on horizontal/vertical splits'
  echo 'for pid in "${ALL_PANES[@]}"; do'
  echo '  tmux join-pane -v -t "$MAIN_PANE" -s "$pid" 2>/dev/null || true'
  echo '  tmux select-layout -t "$WINDOW" tiled 2>/dev/null || true'
  echo '  sleep 0.05'
  echo 'done'
  echo ''
  echo '# Remove border labels'
  echo 'tmux set-option -wu pane-border-status 2>/dev/null || true'
  echo 'tmux select-pane -t "$MAIN_PANE"'
  echo 'echo "Layout restored to tiled. Resize hooks removed."'
} > "$RESTORE_SCRIPT"
chmod +x "$RESTORE_SCRIPT"
echo "Restore script saved: $RESTORE_SCRIPT"

# ── 2. Break all non-main panes to hidden windows ───────────────
ERRORS=0

for role in knowledge pm final-gate; do
  pid="${SHARED_MAP[$role]:-}"; [ -z "$pid" ] && continue
  tmux break-pane -d -s "$pid" 2>/dev/null || { echo "  WARN: break failed $role ($pid)"; ((ERRORS++)); }
done

for role in "${ROLES[@]}"; do
  for num in "${NUMS[@]}"; do
    pid="${TASK_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
    tmux break-pane -d -s "$pid" 2>/dev/null || { echo "  WARN: break failed $role-$num ($pid)"; ((ERRORS++)); }
  done
done
sleep 0.3

# ── 3. Rebuild: two-phase binary-tree approach ──────────────────
# Phase 1: horizontal joins → establish columns (first task row)
# Phase 2a: vertical joins → left column (shared agents below main)
# Phase 2b: vertical joins → task rows within each column
#
# Horizontal first is mandatory. Building column-by-column causes
# tmux's binary split tree to nest incorrectly.

FIRST_COL_PANE=()
JOIN_TARGET="$MAIN_PANE"
FIRST_ROLE="${ROLES[0]:-}"

# Phase 1: horizontal joins — task columns and/or final-gate
if [ -n "$FIRST_ROLE" ] && [ "$NUM_COLS" -gt 0 ]; then
  for col_idx in "${!NUMS[@]}"; do
    num="${NUMS[$col_idx]}"
    pid="${TASK_MAP[$FIRST_ROLE,$num]:-}"; [ -z "$pid" ] && continue
    if tmux join-pane -h -t "$JOIN_TARGET" -s "$pid" 2>/dev/null; then
      FIRST_COL_PANE+=("$pid")
      JOIN_TARGET="$pid"
    else
      echo "  ERROR: H-join failed $FIRST_ROLE-$num ($pid)"
      ((ERRORS++))
    fi
    sleep 0.05
  done
fi

# Final gate gets its own column (full height, to the right)
if [ -n "$GATE_PANE" ]; then
  if tmux join-pane -h -t "$JOIN_TARGET" -s "$GATE_PANE" 2>/dev/null; then
    FIRST_COL_PANE+=("$GATE_PANE")
  else
    echo "  ERROR: H-join failed final-gate ($GATE_PANE)"
    ((ERRORS++))
  fi
  sleep 0.05
fi

# Phase 2a: left column — shared agents below main
LEFT_PREV="$MAIN_PANE"
if [ -n "$KNOW_PANE" ]; then
  if tmux join-pane -v -t "$LEFT_PREV" -s "$KNOW_PANE" 2>/dev/null; then
    LEFT_PREV="$KNOW_PANE"
  else
    echo "  ERROR: V-join failed knowledge ($KNOW_PANE)"
    ((ERRORS++))
  fi
  sleep 0.05
fi
if [ -n "$PM_PANE" ]; then
  if tmux join-pane -v -t "$LEFT_PREV" -s "$PM_PANE" 2>/dev/null; then
    LEFT_PREV="$PM_PANE"
  else
    echo "  ERROR: V-join failed pm ($PM_PANE)"
    ((ERRORS++))
  fi
  sleep 0.05
fi

# Phase 2b: task grid rows
for col_idx in "${!NUMS[@]}"; do
  num="${NUMS[$col_idx]}"
  prev_pid="${TASK_MAP[$FIRST_ROLE,$num]:-}"; [ -z "$prev_pid" ] && continue
  for (( row_idx=1; row_idx < NUM_ROLES; row_idx++ )); do
    role="${ROLES[$row_idx]}"
    pid="${TASK_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
    if tmux join-pane -v -t "$prev_pid" -s "$pid" 2>/dev/null; then
      prev_pid="$pid"
    else
      echo "  ERROR: V-join failed $role-$num ($pid)"
      ((ERRORS++))
    fi
    sleep 0.05
  done
done

# ── 4. Resize ───────────────────────────────────────────────────
sleep 0.3
tmux resize-pane -t "$MAIN_PANE" -x "$MAIN_WIDTH" 2>/dev/null

TOTAL_W=$(tmux display-message -t "$MAIN_PANE" -p '#{window_width}')
TOTAL_H=$(tmux display-message -t "$MAIN_PANE" -p '#{window_height}')

# Left column heights: main ~50%, shared split the rest
if [ "$LEFT_SHARED" -eq 2 ]; then
  MAIN_H=$(( TOTAL_H * 50 / 100 ))
  SHARED_H=$(( (TOTAL_H - MAIN_H) / 2 ))
  tmux resize-pane -t "$MAIN_PANE" -y "$MAIN_H" 2>/dev/null || true
  [ -n "$KNOW_PANE" ] && tmux resize-pane -t "$KNOW_PANE" -y "$SHARED_H" 2>/dev/null || true
elif [ "$LEFT_SHARED" -eq 1 ]; then
  MAIN_H=$(( TOTAL_H * 60 / 100 ))
  tmux resize-pane -t "$MAIN_PANE" -y "$MAIN_H" 2>/dev/null || true
fi

# Right-side columns: equal width (skip last — gets remainder)
RIGHT_COLS=${#FIRST_COL_PANE[@]}
if [ "$RIGHT_COLS" -gt 1 ]; then
  GRID_W=$(( TOTAL_W - MAIN_WIDTH - 1 ))
  COL_W=$(( GRID_W / RIGHT_COLS ))
  for (( i=0; i < RIGHT_COLS - 1; i++ )); do
    tmux resize-pane -t "${FIRST_COL_PANE[$i]}" -x "$COL_W" 2>/dev/null || true
  done
fi

# Task grid: equal rows
if [ "$NUM_ROLES" -gt 1 ]; then
  ROW_H=$(( TOTAL_H / NUM_ROLES ))
  for role in "${ROLES[@]}"; do
    for num in "${NUMS[@]}"; do
      pid="${TASK_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
      tmux resize-pane -t "$pid" -y "$ROW_H" 2>/dev/null || true
    done
  done
fi

# ── 5. Resize hook ──────────────────────────────────────────────
RESIZE_SCRIPT="/tmp/tmux-resize-grid.sh"
{
  cat <<'HOOK_HEAD'
#!/usr/bin/env bash
HOOK_HEAD
  echo "WINDOW=\"$WINDOW\""
  echo "MAIN_PANE=\"$MAIN_PANE\""
  echo "MAIN_WIDTH=$MAIN_WIDTH"
  echo "NUM_COLS=$NUM_COLS"
  echo "NUM_ROLES=$NUM_ROLES"
  echo "LEFT_SHARED=$LEFT_SHARED"
  [ -n "$KNOW_PANE" ] && echo "KNOW_PANE=\"$KNOW_PANE\""
  [ -n "$PM_PANE" ] && echo "PM_PANE=\"$PM_PANE\""
  echo ''
  echo '# Verify main pane still exists, skip if window was destroyed'
  echo 'tmux display-message -t "$MAIN_PANE" -p "" 2>/dev/null || exit 0'
  echo ''
  echo 'tmux resize-pane -t "$MAIN_PANE" -x "$MAIN_WIDTH" 2>/dev/null || exit 0'
  echo ''
  echo 'TOTAL_W=$(tmux display-message -t "$MAIN_PANE" -p "#{window_width}")'
  echo 'TOTAL_H=$(tmux display-message -t "$MAIN_PANE" -p "#{window_height}")'
  echo ''
  # Left column
  echo 'if [ "$LEFT_SHARED" -eq 2 ]; then'
  echo '  MAIN_H=$(( TOTAL_H * 50 / 100 ))'
  echo '  SHARED_H=$(( (TOTAL_H - MAIN_H) / 2 ))'
  echo '  tmux resize-pane -t "$MAIN_PANE" -y "$MAIN_H" 2>/dev/null || true'
  [ -n "$KNOW_PANE" ] && echo "  tmux resize-pane -t \"$KNOW_PANE\" -y \$SHARED_H 2>/dev/null || true"
  echo 'elif [ "$LEFT_SHARED" -eq 1 ]; then'
  echo '  MAIN_H=$(( TOTAL_H * 60 / 100 ))'
  echo '  tmux resize-pane -t "$MAIN_PANE" -y "$MAIN_H" 2>/dev/null || true'
  echo 'fi'
  echo ''
  # Right-side columns
  if [ "${#FIRST_COL_PANE[@]}" -gt 1 ]; then
    echo "RIGHT_COLS=${#FIRST_COL_PANE[@]}"
    echo 'GRID_W=$(( TOTAL_W - MAIN_WIDTH - 1 ))'
    echo 'COL_W=$(( GRID_W / RIGHT_COLS ))'
    for (( i=0; i < ${#FIRST_COL_PANE[@]} - 1; i++ )); do
      echo "tmux resize-pane -t \"${FIRST_COL_PANE[$i]}\" -x \$COL_W 2>/dev/null || true"
    done
  fi
  echo ''
  # Task rows
  if [ "$NUM_ROLES" -gt 1 ]; then
    echo 'ROW_H=$(( TOTAL_H / NUM_ROLES ))'
    for role in "${ROLES[@]}"; do
      for num in "${NUMS[@]}"; do
        pid="${TASK_MAP[$role,$num]:-}"; [ -z "$pid" ] && continue
        echo "tmux resize-pane -t \"$pid\" -y \$ROW_H 2>/dev/null || true"
      done
    done
  fi
} > "$RESIZE_SCRIPT"
chmod +x "$RESIZE_SCRIPT"

tmux set-hook -t "$WINDOW" window-layout-changed "run-shell '$RESIZE_SCRIPT'"
tmux set-hook -t "$WINDOW" client-resized "run-shell '$RESIZE_SCRIPT'"

# ── 6. Labels and borders ──────────────────────────────────────
tmux set-option -w pane-border-status top
tmux set-option -w pane-border-format " #{pane_title} "
tmux select-pane -t "$MAIN_PANE"

# ── 7. Report ──────────────────────────────────────────────────
[ "$ERRORS" -gt 0 ] && echo "" && echo "WARNING: $ERRORS errors during arrangement"

echo ""
DESC="${NUM_COLS} tasks × ${NUM_ROLES} roles"
[ "$LEFT_SHARED" -gt 0 ] && DESC="$DESC + ${LEFT_SHARED} shared"
[ -n "$GATE_PANE" ] && DESC="$DESC + final-gate"
echo "Grid arranged: $DESC (resize hook installed)"
echo ""

# Visual grid
printf "│ %-12s │" "main"
for num in "${NUMS[@]}"; do printf " task %-3s │" "$num"; done
[ -n "$GATE_PANE" ] && printf " gate     │"
echo ""
[ -n "$KNOW_PANE" ] && { printf "│ %-12s │" "knowledge"
  for num in "${NUMS[@]}"; do printf " %-8s │" ""; done
  [ -n "$GATE_PANE" ] && printf " %-8s │" ""
  echo ""; }
[ -n "$PM_PANE" ] && { printf "│ %-12s │" "pm"
  for num in "${NUMS[@]}"; do printf " %-8s │" ""; done
  [ -n "$GATE_PANE" ] && printf " %-8s │" ""
  echo ""; }
if [ "$NUM_COLS" -gt 0 ]; then
  printf "│ %-12s │" ""
  for num in "${NUMS[@]}"; do printf "──────────│"; done
  [ -n "$GATE_PANE" ] && printf " final-   │"
  echo ""
  for role in "${ROLES[@]}"; do
    printf "│ %-12s │" "$role"
    for num in "${NUMS[@]}"; do
      pid="${TASK_MAP[$role,$num]:-}"
      [ -n "$pid" ] && printf " %-8s │" "$role-$num" || printf " %-8s │" "(empty)"
    done
    [ -n "$GATE_PANE" ] && printf " gate     │"
    echo ""
  done
fi
```

### Step 2: Report

The script handles everything — building, resizing, hooks, and reporting. Print the grid diagram output to the user.

## Manifest File (Optional)

If plan-execution writes `/tmp/team-grid-manifest.json`, the script applies pane titles from it before scanning. Format:

```json
{
  "plan": "user-auth",
  "agents": {
    "%142": {"role": "executor", "task": 1},
    "%143": {"role": "reviewer", "task": 1},
    "%144": {"role": "tester", "task": 1},
    "%150": {"role": "knowledge", "task": null},
    "%151": {"role": "pm", "task": null}
  }
}
```

This is a fallback — the primary mechanism is plan-execution setting pane titles directly after each spawn.

## Restore Original Layout

If the grid goes wrong, restore the saved layout snapshot:

```bash
bash /tmp/tmux-restore-layout.sh
```

The grid builder script saves a snapshot before rearranging. This restore script breaks all panes back to hidden windows and rejoins them in the original order, returning to tmux's default tiled layout. It also removes the resize hooks.

## Critical Rules

- **NEVER use `split-window` or `new-window`** — only rearrange existing panes
- **NEVER use `set -e`** — individual join failures must not kill the script
- **Always use `%`-prefixed pane IDs** (e.g., `%142`) — never named targets
- **Two-phase build is mandatory** — horizontal first (columns), then vertical (rows). Building column-by-column causes the binary tree to nest incorrectly.
- **`break-pane -d`** detaches without destroying — pane moves to a hidden window
- **`join-pane`** moves it back into the target window at the specified position
- **Main pane never moves** — all joins target relative to it
- **Unrecognized panes** (title doesn't match any pattern) are left untouched
- Set hooks on **window** level (`-w`) not global (`-g`)
