# Ensure Ultra Dashboard

Shared reference — read and execute these steps to ensure the Ultra Dashboard is running and obtain a dashboard URL. Idempotent: safe to run every time.

## 1. Check if dashboard is running

```bash
DASHBOARD_PID_FILE="$HOME/.claude/dashboard.pid"
DASHBOARD_RUNNING=false
if [ -f "$DASHBOARD_PID_FILE" ]; then
  DASH_PID=$(cat "$DASHBOARD_PID_FILE")
  if kill -0 "$DASH_PID" 2>/dev/null && \
     curl -sf http://localhost:3847/api/plans > /dev/null 2>&1; then
    DASHBOARD_RUNNING=true
  fi
fi
echo "Dashboard running: $DASHBOARD_RUNNING"
```

## 2. Start if not running

```bash
if [ "$DASHBOARD_RUNNING" = "false" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/scripts/ultra-dashboard/index.js" --ensure
  sleep 1
fi
```

## 3. Expose via Tailscale (best-effort)

```bash
tailscale serve --bg 3847 2>/dev/null
```

This is idempotent — no-op if already serving. Fails silently if Tailscale is not installed or not configured.

## 4. Construct dashboard URL

```bash
DASHBOARD_URL=""
TS_HOSTNAME=$(tailscale status --self --json 2>/dev/null | jq -r '.Self.DNSName // empty' | sed 's/\.$//')
if [ -n "$TS_HOSTNAME" ]; then
  DASHBOARD_URL="https://${TS_HOSTNAME}"
fi
if [ -z "$DASHBOARD_URL" ]; then
  DASHBOARD_URL="http://localhost:3847"
fi
echo "Dashboard URL: $DASHBOARD_URL"
```

After executing these steps, `$DASHBOARD_URL` contains the base URL for the dashboard. Append paths as needed:
- Project plans page: `$DASHBOARD_URL/project/{PROJECT_NAME}`
- Specific plan: `$DASHBOARD_URL/plan/{PROJECT_NAME}/{PLAN_NAME}`
- Home: `$DASHBOARD_URL`

Where `PROJECT_NAME` is `basename` of the project root directory.
