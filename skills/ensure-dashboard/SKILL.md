---
description: Start the Ultra Dashboard if not already running, expose via Tailscale, and print the URL. Idempotent — safe to run anytime. Pass "reset" to force-restart. Use when user says "ensure dashboard", "start dashboard", "dashboard url", "open dashboard", "launch dashboard", or "restart dashboard".
user-invocable: true
argument-hint: "reset (optional — force restart)"
allowed-tools: [Bash]
---

# Ensure Dashboard

**Arguments:** $ARGUMENTS

## If `$ARGUMENTS` contains "reset"

Kill the existing dashboard process and remove the PID file before proceeding:

```bash
DASHBOARD_PID_FILE="$HOME/.claude/ultra/dashboard.pid"
if [ -f "$DASHBOARD_PID_FILE" ]; then
  DASH_PID=$(cat "$DASHBOARD_PID_FILE")
  kill "$DASH_PID" 2>/dev/null
  rm -f "$DASHBOARD_PID_FILE"
  sleep 1
  echo "Dashboard stopped"
fi
```

Then fall through to the ensure step below.

## Ensure running

Read and execute `${CLAUDE_PLUGIN_ROOT}/references/ensure-dashboard.md`.

Print the resulting `$DASHBOARD_URL` to the user.
