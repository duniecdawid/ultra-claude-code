---
description: Start the Ultra Dashboard if not already running, expose via Tailscale, and print the URL. Idempotent — safe to run anytime. Use when user says "ensure dashboard", "start dashboard", "dashboard url", "open dashboard", or "launch dashboard".
user-invocable: true
allowed-tools: [Bash]
---

# Ensure Dashboard

Read and execute `${CLAUDE_PLUGIN_ROOT}/references/ensure-dashboard.md`.

Print the resulting `$DASHBOARD_URL` to the user.
