---
description: Recovery tool — restarts the layout watcher or triggers a one-shot layout fix. Reads @agent-name labels to identify panes. Use when user says "team grid", "tmux grid", "fix layout", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid (Recovery)

Manages the background layout watcher that automatically arranges panes into the team grid based on `@agent-name` labels.

**Normal operation:** The layout watcher runs automatically during plan execution (started in Phase 1.1b). You should not need this skill unless something went wrong.

## When to Use

- Layout watcher died or wasn't started
- Panes are visually messed up and the watcher isn't fixing them
- You want to check the watcher status

## Instructions

### Check watcher status

```bash
# Is the watcher running?
if [ -f /tmp/layout-watcher.pid ] && kill -0 $(cat /tmp/layout-watcher.pid) 2>/dev/null; then
  echo "Watcher running (PID $(cat /tmp/layout-watcher.pid))"
  tail -5 /tmp/layout-watcher.log
else
  echo "Watcher NOT running"
fi
```

### Restart the watcher

Get the main pane ID and window ID, then start the watcher:

```bash
MAIN_PANE=$(tmux display-message -p '#{pane_id}')
WINDOW=$(tmux display-message -p '#{window_id}')

# Kill old watcher if running
[ -f /tmp/layout-watcher.pid ] && kill $(cat /tmp/layout-watcher.pid) 2>/dev/null

# Start fresh
nohup ${CLAUDE_PLUGIN_ROOT}/scripts/layout-watcher.sh "$WINDOW" "$MAIN_PANE" 2 > /tmp/layout-watcher.log 2>&1 &
echo $! > /tmp/layout-watcher.pid
echo "Watcher started: PID $!"
```

The watcher will immediately scan all `@agent-name` labels and arrange the grid.

### Emergency fallback

If the watcher can't fix the layout, use tmux's built-in tiled layout:

```bash
tmux select-layout tiled
```

This distributes all panes evenly — not the team grid, but at least makes everything visible.
