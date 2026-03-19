# Ultra Claude Setup — Transcript

**User complaint:** "I'm getting really bad screen tearing and flickering when using Claude Code inside tmux over VS Code Remote SSH. Can you fix this?"

---

## Step 1: Read Current State

- Read `plugin.json` — current plugin version is **0.3.3**.
- Checked for `~/.claude/uc-setup.json` — does not exist (first run).

## Step 2: Detect Shell

- Detected shell: **bash**
- Config file: **~/.bashrc**
- Read `~/.bashrc` — contains the agent teams and 1M context env vars already.

## Step 3: Run Prerequisite Checks

### 3.1 tmux
```
$ which tmux && tmux -V
/usr/bin/tmux
tmux 3.5a
```
**Result: PASS** — tmux is installed (v3.5a).

### 3.2 Agent Teams env var
Grepped `~/.bashrc` for `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` — found.
```
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```
**Result: PASS** — already configured in shell config.

### 3.3 1M Context env vars
Grepped `~/.bashrc` for `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL` — both found with `[1m]` suffix.
```
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-4-6[1m]'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-6[1m]'
```
**Result: PASS** — both env vars are configured correctly.

### 3.4 Node.js
```
$ node --version
v20.11.0
```
**Result: PASS** — Node.js v20.11.0 installed (v18+ recommended).

### 3.5 tmux.conf (Claude Code optimized)
```
$ grep -c 'allow-passthrough' ~/.tmux.conf
0
```
**Result: FAIL** — `~/.tmux.conf` exists but does NOT contain `allow-passthrough`. The file only contains `set -g mouse on`.

### 3.6 Tailscale (optional)
```
$ which tailscale && tailscale status --self --json
/usr/bin/tailscale
{"Self":{"Online":true,...}}
```
**Result: PASS** — Tailscale is installed and connected.

## Step 4: Present Status

```
Ultra Claude Environment Check (plugin v0.3.3)

  tmux                  ✓ installed (v3.5a)
  tmux.conf             ✗ missing passthrough
  Agent teams env var   ✓ configured
  1M context env vars   ✓ configured
  Node.js               ✓ v20.11.0
  Tailscale (optional)  ✓ installed & connected
```

Only one required check failed: **tmux.conf passthrough**. This is the direct cause of the screen tearing.

## Root Cause Explanation (presented to user)

Here is exactly what is causing your screen tearing:

Claude Code's terminal UI uses **DEC 2026 synchronized output** — a protocol where the terminal batches all screen draws between a Begin Synchronized Update (BSU) and End Synchronized Update (ESU) escape sequence pair. Instead of painting the screen line-by-line as data arrives (which you would see as tearing/flickering), the terminal holds all the partial updates in a buffer and then flips the entire frame at once.

When you run Claude Code inside **tmux**, there is a critical problem: **tmux intercepts and swallows escape sequences it does not recognize by default**. The BSU/ESU passthrough sequences never reach your actual terminal (VS Code's integrated terminal, in your case). So every streaming response — which can generate **4,000 to 6,700 scroll events per second** — gets painted to the screen one fragment at a time, causing the severe tearing and flickering you are seeing.

The fix is a single tmux setting: `set -g allow-passthrough on`. This tells tmux to forward unrecognized escape sequences (including DEC 2026 BSU/ESU) directly to the outer terminal, restoring synchronized output.

The problem is especially bad in your setup (VS Code Remote SSH) because there is an additional layer of latency — each unsynchronized partial draw has to travel over the SSH connection and then get rendered by VS Code's terminal emulator, amplifying the visual tearing.

## Step 5: Fix Missing Prerequisites

Since only tmux.conf is missing, proceeded directly to fix 5.5.

### 5.5 Fix: tmux.conf (Claude Code optimized)

Read existing `~/.tmux.conf`:
```
set -g mouse on
```

The file already contains `set -g mouse on`, so that line is preserved. Merged the remaining Claude Code settings (passthrough, escape-time, history-limit, extended-keys, clipboard, color, focus) into the file **without duplicating** the existing `set -g mouse on` line.

**Wrote merged `~/.tmux.conf`:**

```
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

**Key merge decisions:**
- `set -g mouse on` — already present, kept in place, not duplicated
- All other settings — added (none were present in the original file)
- No conflicting values found (no `allow-passthrough off` etc.)

Reloaded tmux config:
```
$ tmux source-file ~/.tmux.conf
```

**Note to user:** If tearing persists, detach and reattach your tmux session — some terminal overrides only take effect on new attachments.

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
    "tailscale": true
  }
}
```

All checks now pass (tmuxConf was fixed this run).

## Step 7: Summary

```
Ultra Claude setup complete (v0.3.3)

  Configured:
    ✓ tmux.conf — added passthrough + Claude Code optimizations

  Already present:
    ✓ tmux (v3.5a)
    ✓ Agent teams env var
    ✓ 1M context env vars
    ✓ Node.js (v20.11.0)
    ✓ Tailscale (connected)

  Skipped:
    — (none)

  Note: No shell config changes were made, so no `source ~/.bashrc` needed.
  If tearing persists after the tmux.conf reload, detach and reattach your tmux session.
```
