---
description: Connect to Ultra Claude Dashboard for real-time project visibility. Guides agent installation and setup, verifies connectivity, manages multiple dashboard accounts and per-project account routing, transfers project ownership between accounts (agent `move` or the dashboard's Incoming-transfers inbox), and runs self-contained debug checks for common sync issues. Use when setting up the dashboard, troubleshooting agent connectivity, checking sync status, managing accounts, transferring/moving a project to another account, or after "dashboard not updating", "agent not syncing", "connect to dashboard", "dashboard setup", "agent status", "which account", "wrong account", "sync to a different account", "switch account", "multiple accounts", "transfer project", "move project to another account", "incoming transfers", "accept transfer", "transferred away", "project moved".
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

## Accounts & project mapping

The agent supports **multiple dashboard accounts** and routes each project's sync to a chosen account. Per-project mapping is **optional** — projects with no explicit mapping sync to the **default account**. Requires `ultraclaude-agent` **≥ 0.0.28** (every command below works non-interactively from the CLI as well as in the interactive REPL).

### The model

- **Multiple accounts** — log into more than one dashboard account; each is stored under the server's `accounts/` directory, keyed by user id.
- **Default account** — new/unmapped projects sync here.
- **Per-project mapping** *(optional)* — bind a specific project to a specific account, overriding the default. `assign` is guarded: the account must already **own** the project (same workspace). To move a project to a *different* account, use an ownership **transfer** (see "Transferring a project to another account" below), not `assign`.
- **Auto-assign** — when on, newly discovered projects are auto-mapped to the default account; when off, they show as `unassigned` until you `assign` them.

### Commands (CLI form shown — same verbs work in the REPL)

```bash
# Add another account (opens browser, log in as that account).
# Installs auto-start + starts the daemon if needed.
ultraclaude-agent login

# Read current state
ultraclaude-agent accounts                     # accounts + per-account project counts; [default] marked
ultraclaude-agent projects                     # projects with their mapped account + sync status
ultraclaude-agent status                       # full status incl. account per project

# Set routing
ultraclaude-agent default <account>            # set the default account (email prefix or full email)
ultraclaude-agent assign <project> <account>   # bind a project to an account (guarded: must already own it, else use `move`)
ultraclaude-agent move <project> --to <account>  # TRANSFER ownership to another account (see section below)
ultraclaude-agent auto-assign on|off           # toggle auto-mapping of newly discovered projects
ultraclaude-agent remove <account>             # remove an account (warns about orphaned projects)

# Force a full re-sync after switching an account (see rule below — always run this)
ultraclaude-agent push <project> --account <account>   # one-shot full sync into the target account
```

### Always force a push after switching an account

> This applies to routing among accounts that **already own** the project (the same workspace). To move a project to a *different* account, use an ownership **transfer** (next section) — that moves the data and the daemon reconciles for you; no manual push.

Switching a project's account with `assign` (or changing the `default`) only **rewrites
routing config** — it moves no data. The background daemon re-syncs only on the *next* file
change, so until then the newly-targeted account's dashboard stays empty. **Immediately
follow any account switch with a one-shot push** so the new account is back-filled with the
project's current state:

```bash
ultraclaude-agent push <project> --account <account>
```

Pass `--account` explicitly: a bare `ultraclaude-agent push <project>` resolves to the
**default** account, not the project's newly-assigned one, so it would push to the wrong
place. `push` runs standalone — it needs login and a project ID, not a running daemon.

`<project>` matches by directory name (partial, case-insensitive); `<account>` matches by email prefix or full email. The same commands are available inside the interactive REPL (run `ultraclaude-agent` with no subcommand, then e.g. `assign my-app alice`).

### Routing a project to a specific account (via Bash)

```bash
ultraclaude-agent login                                      # ensure the target account exists (opens browser; log in as that account)
ultraclaude-agent assign my-app work@example.com             # route this project to it (config only — moves no data)
ultraclaude-agent push   my-app --account work@example.com   # force a full re-sync into the new account
ultraclaude-agent projects                                   # confirm the mapping + sync status
```

### config.json

Mappings live in a per-server config file:

```
~/.claude/ultra/agent/{server-host}/config.json
```

`{server-host}` is the dashboard host (e.g. `dashboard.ultra-claude.dev`). Shape:

```json
{
  "defaultAccount": "user_abc123",
  "projectAccounts": {
    "/home/you/Projects/my-app": "user_abc123"
  },
  "autoAssignNewProjects": true
}
```

`projectAccounts` is keyed by local project path → account user id and is **optional** — omit a project and it follows `defaultAccount`. Prefer the commands above over hand-editing this file (they validate accounts and handle orphan cleanup).

## Transferring a project to another account (ownership transfer)

`assign` only rewrites **local routing** and is guarded — it refuses an account that does not already **own** the project on the server (e.g. a different workspace) and points you here. To move a project to a *different* account, use an **ownership transfer**: it preserves the project's id, URL, history, and snapshots (nothing is orphaned, no new URL).

Two ways to transfer:

**From the agent** (both accounts logged in on this machine):

```bash
ultraclaude-agent move <project> --to <account>          # e.g. move my-app work@example.com
ultraclaude-agent move <project> --to <account> --to-org <org>   # if the target account has >1 workspace
```

`move` runs the whole handshake: it opens the transfer as the current owner, accepts it as the target account, and re-points local routing — the project id is unchanged. Add `--yes` to skip confirmation. If the target account isn't logged in on this machine, `move` stops with an actionable message — use the dashboard flow instead.

**From the dashboard** (works across machines, or when the other account isn't local):

1. As the current owner, open the project and choose **"Transfer project…"**, then enter the recipient's email.
2. The recipient sees it in their **"Incoming transfers"** inbox and **Accepts** (choosing the destination workspace if they have more than one) or **Rejects** it. Discovery is entirely in-app — no email is sent.

### After a transfer, the daemon reconciles automatically

You do **not** need to `push` after a transfer. On its next reconcile the local daemon converges to the new server-side ownership:

- If the new owner is **another account on this machine**, the daemon re-routes sync to it automatically.
- If **no local account** owns it anymore, the daemon marks the project **"transferred away"**, stops syncing it from this machine, and shows that in `ultraclaude-agent status`.

The daemon also watches `config.json`, so routing changes are picked up without a restart. Run `ultraclaude-agent status` to see each project's current owner/route and any "transferred away" projects.

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
| Project synced to the wrong account | No / stale per-project mapping | `ultraclaude-agent assign <project> <account>`, then `ultraclaude-agent push <project> --account <account>` to back-fill the new account |
| New account's dashboard empty after a switch | `assign`/`default` only rewrite routing — they move no data | `ultraclaude-agent push <project> --account <account>` (force a one-shot full sync) |
| New projects not syncing automatically | Auto-assign is off | `ultraclaude-agent auto-assign on` (or `assign` each) |
| `assign` refuses — "account doesn't own this project" | You're routing to a different-workspace account; `assign` only rewrites routing | Use an ownership transfer instead: `ultraclaude-agent move <project> --to <account>` (or the dashboard "Transfer project…" flow) |
| `push --account X` errors "project not registered under X" | That account doesn't own the project (routing points at the wrong account) | Transfer it (`move` / dashboard), or `push`/`assign` under the account that actually owns it |
| Project shows "transferred away" in `status` / stopped syncing here | It was transferred to an account not present on this machine | Expected — it now syncs from the owning account. If you own it under a local account, the daemon re-routes automatically; otherwise log in as the owner or transfer it back |
