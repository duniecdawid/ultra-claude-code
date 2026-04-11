---
description: >-
  Scan and clean stale Claude Code session files across all projects.
  Discovers sessions via ~/.claude/projects/, classifies as active/stale/legacy,
  prompts for cleanup criteria, removes matching session files and optionally
  kills dead tmux panes. Use when session files accumulate, disk needs cleaning,
  or after crashes leave orphaned sessions. Triggers on "session cleanup",
  "clean sessions", "stale sessions", "orphaned sessions", "session files".
argument-hint: "(no arguments — interactive)"
user-invocable: true
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
  - AskUserQuestion
---

# Session Cleanup

Scan all Ultra Claude projects for stale session files and clean them up after user confirmation.

## Process

### Step 1: Discover Projects

Find all projects by scanning `~/.claude/projects/` — each subdirectory contains a symlink to the project's `.claude` directory. Resolve each symlink to get the project root path:

```bash
projects=()
for entry in ~/.claude/projects/*/; do
  # Each entry is a directory named after the project path (with dashes replacing slashes)
  # Inside it are files that Claude Code manages — the parent of .claude is the project root
  # Resolve by reading the actual path stored in the directory
  if [ -d "$entry" ]; then
    # The project path is encoded in the directory name: leading dash removed, dashes-that-were-slashes restored
    dir_name=$(basename "$entry")
    # Convert the encoded name back to a path
    project_path="/${dir_name//-//}"
    # Verify it has Ultra Claude sessions
    if [ -d "${project_path}/.claude/ultra/sessions" ]; then
      projects+=("$project_path")
    fi
  fi
done
echo "Found ${#projects[@]} projects with session directories"
```

If the symlink-based discovery doesn't yield results, fall back to listing the directory names and trying common path patterns.

### Step 2: Collect and Classify Sessions

For each project, read all `*.json` files in `.claude/ultra/sessions/`:

```bash
for project in "${projects[@]}"; do
  sessions_dir="${project}/.claude/ultra/sessions"
  for session_file in "$sessions_dir"/*.json; do
    [ -f "$session_file" ] || continue
    # Read session data
    data=$(cat "$session_file")
    active=$(echo "$data" | jq -r '.active // false')
    pid=$(echo "$data" | jq -r '.pid // empty')
    last_activity=$(echo "$data" | jq -r '.last_activity // empty')
    tmux_pane=$(echo "$data" | jq -r '.tmux_pane // empty')
    # Classify...
  done
done
```

**Classification rules:**

| Classification | Criteria |
|---|---|
| **Active** | `active: true` AND `pid` exists AND `kill -0 $pid 2>/dev/null` succeeds (process alive) |
| **Stale** | `pid` exists but process dead (`kill -0` fails), OR `last_activity` older than threshold |
| **Legacy** | No `last_activity` field (old session format, before enrichment) |
| **Ended** | `active: false` (session ended normally) — stale if older than threshold |

Note: A session with `active: true` but a dead PID is **stale** (crashed session).

### Step 3: Present Summary and Options

Use `AskUserQuestion` to present findings and get cleanup preferences. Include:

```
Session Scan Results
====================
Projects scanned: N
Total sessions found: N

  Active (PID alive):  N  — will be kept
  Stale (PID dead):    N
  Ended (normal):      N
  Legacy (no activity): N

Options:
1. Stale threshold in days [default: 7] — ended sessions older than this are cleaned
2. Include legacy sessions without last_activity? [default: yes]
3. Kill tmux panes for dead sessions? [default: no]

Enter options as: threshold_days,include_legacy(y/n),kill_panes(y/n)
Example: 7,y,n (defaults)
```

### Step 4: Execute Cleanup

Based on user's choices:

1. **Remove stale session files** — sessions where PID is dead
2. **Remove old ended sessions** — `active: false` with `ended_at` older than threshold
3. **Remove legacy sessions** (if user opted in) — sessions without `last_activity`
4. **Kill tmux panes** (if user opted in) — for stale sessions that have a `tmux_pane` value:
   ```bash
   tmux kill-pane -t "$tmux_pane" 2>/dev/null
   ```

### Step 5: Report Results

```
Cleanup Complete
================
Sessions removed: N
  - Stale (dead PID): N
  - Old ended: N
  - Legacy: N
Tmux panes killed: N
Sessions kept: N (active)
```
