---
description: One-time machine setup for Ultra Claude. Checks and configures shell environment (1M context, agent teams), installs prerequisites (tmux, node), configures tmux for Claude Code (fixes screen tearing via DEC 2026 synchronized output passthrough), and optionally sets up Tailscale for remote dashboard access. Idempotent — safe to re-run. Writes version marker to ~/.claude/uc-setup.json so other skills can quickly check if setup is current. Use when onboarding a new machine, after Ultra Claude install, when plan-execution reports missing prerequisites, or when experiencing screen tearing/flickering in tmux. Triggers on "setup", "machine setup", "environment setup", "configure machine", "setup 1m context", "enable agent teams", "screen tearing", "tmux tearing", "flickering".
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

### 3.5 tmux.conf (Claude Code optimized)

If tmux is installed, check `~/.tmux.conf` for the critical `allow-passthrough` setting:

```bash
grep -c 'allow-passthrough' ~/.tmux.conf 2>/dev/null
```

PASS if `allow-passthrough on` is found. This setting is essential because Claude Code's terminal UI relies on DEC 2026 synchronized output (BSU/ESU escape sequences) to batch screen draws. Without passthrough, tmux swallows these sequences, causing severe screen tearing — especially during streaming output which generates 4,000–6,700 scroll events per second.

SKIP if tmux is not installed.

### 3.6 Tailscale (optional)

```bash
which tailscale 2>/dev/null && tailscale status --self --json 2>/dev/null
```

Record status but don't mark as MISSING — this is optional.

## Step 4: Present Status

Display a status table:

```
Ultra Claude Environment Check (plugin v{version})

  tmux                  ✓ installed (v3.4)
  tmux.conf             ✗ missing passthrough
  Agent teams env var   ✗ missing
  1M context env vars   ✗ missing
  Node.js               ✓ v22.0.0
  Tailscale (optional)  — not installed
```

If ALL required checks pass (3.1–3.5):
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

### 5.5 Fix: tmux.conf (Claude Code optimized)

Write or merge the following into `~/.tmux.conf`. If the file already exists, read it first and only add settings that are missing — don't duplicate lines. If conflicting values exist (e.g., `allow-passthrough off`), warn the user and ask before changing.

Claude Code's terminal UI uses DEC 2026 synchronized output to batch screen draws and prevent tearing. Without these settings, tmux intercepts the escape sequences and the result is severe flickering during streaming output.

```bash
# ~/.tmux.conf — Claude Code optimized

set -g mouse on

# Fix Claude Code screen tearing (DEC 2026 synchronized output)
# tmux defaults to blocking passthrough, which swallows the BSU/ESU
# sequences Claude Code uses to batch screen draws
set -g allow-passthrough on

# Remove 500ms escape delay (causes input lag in Claude Code)
set -sg escape-time 0

# Handle Claude's massive scroll output (4k-6.7k events/sec)
set -g history-limit 250000

# Extended keys and clipboard
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -g set-clipboard on

# Color and focus
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g focus-events on
```

After writing, reload the config if tmux is currently running:

```bash
tmux source-file ~/.tmux.conf 2>/dev/null
```

Tell the user: "If tearing persists, detach and reattach your tmux session — some terminal overrides only take effect on new attachments."

### 5.6 Fix: Tailscale

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
    "tmuxConf": true/false,
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
