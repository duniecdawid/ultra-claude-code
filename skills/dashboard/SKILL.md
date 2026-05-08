---
description: Connect to Ultra Claude Dashboard for real-time project visibility. Guides agent installation and setup, verifies connectivity, and runs self-contained debug checks for common sync issues. Use when setting up the dashboard, troubleshooting agent connectivity, checking sync status, or after "dashboard not updating", "agent not syncing", "connect to dashboard", "dashboard setup", "agent status".
user-invocable: true
---

# Dashboard — Ultra Claude Dashboard Connection

The Ultra Claude Dashboard at `dashboard.ultra-claude.dev` provides real-time visibility into your Ultra Claude projects — plans, backlog, documentation, and execution history — accessible from any browser without a local dev environment.

This skill guides you through connecting your local Ultra Claude projects to the dashboard and diagnosing connectivity issues.

## Step 1: Connect

### 1.1 Install the sync agent

The dashboard sync agent is a global npm package. Requires Node.js (see `/uc:setup` for version requirements).

```bash
npm i -g ultraclaude-agent
```

### 1.2 Run setup

From your project directory:

```bash
ultraclaude-agent setup
```

The setup wizard handles the entire onboarding flow:
1. **Login** — opens browser for authentication
2. **Project discovery** — detects Ultra Claude project in the current directory
3. **Sync confirmation** — asks whether to sync this project
4. **Start daemon** — launches the background sync daemon

Re-running `ultraclaude-agent setup` is safe — it detects existing configuration and offers to reconfigure if needed.

### 1.3 Verify connection

After setup, confirm the agent is running and syncing:

```bash
ultraclaude-agent status
```

You should see the daemon status, connected projects, and last sync timestamp. Once syncing, your project appears at `dashboard.ultra-claude.dev`.

## Step 2: Verify & Debug

Run these checks if the dashboard is not updating or the agent appears disconnected.

### 2.1 Agent installed?

```bash
command -v ultraclaude-agent && ultraclaude-agent --version || echo "NOT INSTALLED — run: npm i -g ultraclaude-agent"
```

### 2.2 Daemon running?

```bash
ultraclaude-agent status 2>/dev/null || echo "DAEMON NOT RUNNING — run: ultraclaude-agent start"
```

If the daemon is not running, start it:

```bash
ultraclaude-agent start
```

### 2.3 Project registered?

Check that the current project has a server-side project ID:

```bash
PROJECT_ID_FILE=".claude/ultra/project-id"
if [ -f "$PROJECT_ID_FILE" ]; then
  echo "Project ID found:"
  cat "$PROJECT_ID_FILE"
else
  echo "NO PROJECT ID — run 'ultraclaude-agent setup' from this directory"
fi
```

### 2.4 State files being written?

The agent syncs execution state files from your plan directories. Verify they exist:

```bash
# Check for any plan with state files
find documentation/plans -name "plan.json" -o -name "events.json" 2>/dev/null | head -5
if [ $? -eq 0 ]; then
  echo "State files found"
else
  echo "No state files — run a plan execution first (/uc:plan-execution)"
fi
```

### 2.5 Agent errors?

Check the agent's status output for error counts or sync failures:

```bash
ultraclaude-agent status 2>/dev/null | grep -i -E "error|fail|disconnect" || echo "No errors detected"
```

If errors persist, check the agent logs:

```bash
ls ~/.claude/ultra/agent/*/logs/daemon.log 2>/dev/null && echo "Log file found — tail it for details" || echo "No log file found"
```

## Common Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Dashboard shows no projects | Agent not set up or not running | Run `ultraclaude-agent setup` |
| Dashboard not updating | Daemon stopped or crashed | Run `ultraclaude-agent start` |
| "Project not found" in agent | No project-id mapping | Run `ultraclaude-agent setup` from the project directory |
| State files missing | No plan has been executed yet | Run `/uc:plan-execution` to create execution state |
| Agent installed but old version | Outdated agent package | Run `npm update -g ultraclaude-agent` |
