---
description: One-time machine setup for Ultra Claude. Checks and configures shell environment (1M context, agent teams), installs prerequisites (tmux, node), and optionally sets up Tailscale for remote dashboard access. Idempotent — safe to re-run. Writes version marker to ~/.claude/uc-setup.json so other skills can quickly check if setup is current. Use when onboarding a new machine, after Ultra Claude install, or when plan-execution reports missing prerequisites. Triggers on "setup", "machine setup", "environment setup", "configure machine", "setup 1m context", "enable agent teams".
user-invocable: true
---

# Ultra Claude Setup

One-time machine setup that configures your environment for Ultra Claude features — especially agent teams and 1M context windows. Idempotent: safe to re-run after updates.

## Step 1: Read Current State

1. Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` to get the current plugin version
2. Read `~/.claude/uc-setup.json` (if exists) to check previous setup state
3. If marker exists and version matches current plugin version, tell the user: "Setup is current (v{version}, last run {timestamp}). Re-running to verify."

## Step 2: Detect Shell

```bash
# Detect shell and config file
basename "$SHELL"
```

| Shell | Config file |
|-------|-------------|
| `bash` | `~/.bashrc` |
| `zsh` | `~/.zshrc` |

Read the detected shell config file.

## Step 3: Run Prerequisite Checks

Run all checks in parallel:

### 3.1 tmux

```bash
which tmux 2>/dev/null && tmux -V
```

PASS if `tmux` is found.

### 3.2 Agent Teams env var

Grep shell config for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Also check current environment:

```bash
echo $CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
```

PASS if the export line exists in shell config.

### 3.3 1M Context env vars

Grep shell config for `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL`.

PASS if **both** export lines exist in shell config with `[1m]` suffix.

### 3.4 Node.js

```bash
node --version 2>/dev/null
```

PASS if `node` is found (v18+ recommended for PM dashboard).

### 3.5 Tailscale (optional)

```bash
which tailscale 2>/dev/null && tailscale status --self --json 2>/dev/null
```

Record status but don't mark as MISSING — this is optional.

## Step 4: Present Status

Display a status table:

```
Ultra Claude Environment Check (plugin v{version})

  tmux                  ✓ installed (v3.4)
  Agent teams env var   ✗ missing
  1M context env vars   ✗ missing
  Node.js               ✓ v22.0.0
  Tailscale (optional)  — not installed
```

If ALL required checks pass (1-4):
- Write the marker file (Step 6)
- Print "Environment ready! All prerequisites configured."
- If Tailscale is not set up, mention: "Optional: Run `/uc:tailscale-setup` to enable remote dashboard access."
- Stop here.

## Step 5: Fix Missing Prerequisites

Use AskUserQuestion with a multi-select to let the user choose which items to fix. List only MISSING items. Always include Tailscale if not installed (marked as optional in the description).

### 5.1 Fix: tmux

Detect OS and install:

```bash
# Linux (Debian/Ubuntu)
sudo apt update && sudo apt install -y tmux

# macOS
brew install tmux
```

If `sudo` or `brew` is not available, print manual install instructions.

### 5.2 Fix: Agent Teams env var

Only if NOT already present in shell config (grep first):

Append to shell config file:

```bash
# Ultra Claude: enable agent teams for plan execution
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### 5.3 Fix: 1M Context env vars

Only if NOT already present in shell config (grep first):

Append to shell config file:

```bash
# Ultra Claude: enable 1M context window for all opus/sonnet usage (including subagents)
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6[1m]'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6[1m]'
```

**Important:** If old/partial entries exist (e.g., the vars are set but without `[1m]`), warn the user and ask before modifying.

### 5.4 Fix: Node.js

Do NOT auto-install Node.js — too many ways to manage it. Instead, print guidance:

```
Node.js is required for the PM status dashboard.

Recommended install methods:
  - nvm (recommended): https://github.com/nvm-sh/nvm
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
    nvm install --lts

  - System package (Debian/Ubuntu):
    sudo apt install -y nodejs npm

  - Homebrew (macOS):
    brew install node
```

### 5.5 Fix: Tailscale

If the user selected Tailscale, invoke the existing skill:

```
/uc:tailscale-setup
```

This delegates all Tailscale configuration to the dedicated skill.

## Step 6: Write Marker File

After all fixes are applied, write `~/.claude/uc-setup.json`:

```json
{
  "version": "{plugin version from plugin.json}",
  "timestamp": "{ISO 8601 timestamp}",
  "shell": "{bash or zsh}",
  "shellConfig": "{path to shell config file}",
  "checks": {
    "tmux": true/false,
    "agentTeams": true/false,
    "context1m": true/false,
    "node": true/false,
    "tailscale": true/false
  }
}
```

The `checks` values reflect the state AFTER applying fixes.

## Step 7: Summary

Print:

```
Ultra Claude setup complete (v{version})

  Configured:
    ✓ {list of items that were fixed this run}

  Already present:
    ✓ {list of items that were already passing}

  Skipped:
    — {list of items user chose not to fix}

  To activate shell changes: run `source ~/{shellConfig}` or restart your terminal.
```
