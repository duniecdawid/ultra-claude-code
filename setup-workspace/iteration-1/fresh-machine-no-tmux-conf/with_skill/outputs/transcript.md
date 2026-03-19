# Ultra Claude /setup — Transcript (fresh machine, no tmux.conf)

## Simulation Context

- Fresh machine, no prior Claude Code configuration
- tmux installed (v3.4), but no ~/.tmux.conf
- No shell env vars configured (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS, ANTHROPIC_DEFAULT_OPUS_MODEL, ANTHROPIC_DEFAULT_SONNET_MODEL all missing)
- Node.js installed (v22.0.0)
- Tailscale NOT installed
- Shell: bash
- Shell config: ~/.bashrc

---

## Step 1: Read Current State

1. Read `plugin.json` — plugin version is **0.3.3**.
2. Check for `~/.claude/uc-setup.json` — does NOT exist (fresh machine). No previous setup state.
3. Since no marker exists, proceed with full setup.

## Step 2: Detect Shell

Ran `basename "$SHELL"` — result: `bash`.

Per the skill's table, the config file is `~/.bashrc`. Read the shell config file to check for existing entries.

## Step 3: Run Prerequisite Checks

All checks run in parallel:

### 3.1 tmux
- `which tmux` returned `/usr/bin/tmux`
- `tmux -V` returned `tmux 3.4`
- **Result: PASS**

### 3.2 Agent Teams env var
- Grepped `~/.bashrc` for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — NOT found.
- Checked current environment: variable is not set.
- **Result: FAIL (missing)**

### 3.3 1M Context env vars
- Grepped `~/.bashrc` for `ANTHROPIC_DEFAULT_OPUS_MODEL` — NOT found.
- Grepped `~/.bashrc` for `ANTHROPIC_DEFAULT_SONNET_MODEL` — NOT found.
- **Result: FAIL (missing)**

### 3.4 Node.js
- `node --version` returned `v22.0.0`
- **Result: PASS**

### 3.5 tmux.conf (Claude Code optimized)
- tmux IS installed, so this check applies.
- `grep -c 'allow-passthrough' ~/.tmux.conf` — file does NOT exist, grep returns error.
- **Result: FAIL (missing passthrough)**

### 3.6 Tailscale (optional)
- `which tailscale` — not found.
- **Result: not installed (optional, not marked as MISSING)**

## Step 4: Present Status

Displayed the status table:

```
Ultra Claude Environment Check (plugin v0.3.3)

  tmux                  ✓ installed (v3.4)
  tmux.conf             ✗ missing passthrough
  Agent teams env var   ✗ missing
  1M context env vars   ✗ missing
  Node.js               ✓ v22.0.0
  Tailscale (optional)  — not installed
```

Not all required checks pass (3.2, 3.3, 3.5 are failing), so proceed to Step 5.

## Step 5: Fix Missing Prerequisites

Per the skill, use AskUserQuestion with a multi-select listing only MISSING items, plus Tailscale (optional). The items offered:

1. [x] tmux.conf — Write Claude Code optimized config
2. [x] Agent Teams env var — Add export to ~/.bashrc
3. [x] 1M Context env vars — Add exports to ~/.bashrc
4. [ ] Tailscale (optional) — Install and configure

**Simulated user response:** User selected items 1, 2, and 3 (all required fixes). Declined Tailscale.

### 5.5 Fix: tmux.conf (Claude Code optimized)

Since `~/.tmux.conf` does NOT exist, no merge needed — wrote the full optimized config:

```
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

Ran `tmux source-file ~/.tmux.conf 2>/dev/null` to reload if tmux is running.

Told the user: "If tearing persists, detach and reattach your tmux session — some terminal overrides only take effect on new attachments."

### 5.2 Fix: Agent Teams env var

Grepped `~/.bashrc` for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — confirmed NOT present.

Appended to `~/.bashrc`:

```bash
# Ultra Claude: enable agent teams for plan execution
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

### 5.3 Fix: 1M Context env vars

Grepped `~/.bashrc` for `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` — confirmed neither present. No old/partial entries to warn about.

Appended to `~/.bashrc`:

```bash
# Ultra Claude: enable 1M context window for all opus/sonnet usage (including subagents)
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6[1m]'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6[1m]'
```

### 5.6 Tailscale — SKIPPED (user declined)

## Step 6: Write Marker File

Wrote `~/.claude/uc-setup.json`:

```json
{
  "version": "0.3.3",
  "timestamp": "2026-03-19T12:00:00.000Z",
  "shell": "bash",
  "shellConfig": "~/.bashrc",
  "checks": {
    "tmux": true,
    "tmuxConf": true,
    "agentTeams": true,
    "context1m": true,
    "node": true,
    "tailscale": false
  }
}
```

The `checks` values reflect the state AFTER applying fixes. `tailscale` is `false` because it was not installed (user declined).

## Step 7: Summary

Displayed:

```
Ultra Claude setup complete (v0.3.3)

  Configured:
    ✓ tmux.conf (Claude Code optimized)
    ✓ Agent teams env var
    ✓ 1M context env vars

  Already present:
    ✓ tmux (v3.4)
    ✓ Node.js (v22.0.0)

  Skipped:
    — Tailscale (user declined)

  To activate shell changes: run `source ~/.bashrc` or restart your terminal.
```

Optional: Mentioned "Run `/uc:tailscale-setup` to enable remote dashboard access."
