---
description: Recovery tool — restarts the Ultra Dashboard if layout is broken. The dashboard handles tmux layout, health monitoring, and web UI. Use when user says "team grid", "tmux grid", "fix layout", "arrange team", or "team layout".
user-invocable: true
allowed-tools: [Bash]
---

# tmux Team Grid (Recovery)

The Ultra Dashboard automatically manages tmux layouts based on `@agent-name` pane labels. This skill is for when the dashboard isn't running or the layout needs a manual fix.

## Check dashboard status

```bash
PID=$(cat ~/.claude/dashboard.pid 2>/dev/null)
if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
  echo "Dashboard running (PID $PID, port 3847)"
  curl -s http://localhost:3847/api/tmux | python3 -m json.tool 2>/dev/null
else
  echo "Dashboard NOT running"
fi
```

## Restart the dashboard

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/ultra-dashboard/index.js --ensure
```

This is idempotent — if the dashboard is already running, it exits immediately. The dashboard auto-discovers all tmux windows with `main-context` labels and arranges them.

## Emergency fallback

If the dashboard can't fix the layout, use tmux's built-in tiled layout:

```bash
tmux select-layout tiled
```
