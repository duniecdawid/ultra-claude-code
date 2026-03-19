# Environment Setup Check — Without Skill

**User request:** `/setup` to check environment. Has existing `~/.tmux.conf` with custom settings. Uses tmux 3.3a, VS Code Remote SSH, and Claude Code CLI.

**Note:** No `/setup` skill is loaded. Performing a manual environment check instead.

---

## Environment Scan Results

### System
| Component | Value |
|-----------|-------|
| OS | Ubuntu 24.04.4 LTS (Noble Numbat) |
| Kernel | Linux 6.17.0-19-generic aarch64 |
| CPU | 24 cores |
| Memory | 78 GB total, ~70 GB available |
| Disk | 62 GB total, 21 GB free (65% used) |

### Development Tools
| Tool | Version | Status |
|------|---------|--------|
| tmux | 3.4 | Installed |
| Git | 2.43.0 | Installed |
| Node.js | 22.22.1 | Installed |
| npm | 10.9.4 | Installed |
| Python | 3.12.3 | Installed |
| Docker | 29.3.0 | Installed |
| Claude Code | 2.1.79 | Installed |
| Bash | 5.2.21 | Default shell |

### Environment Context
- **Connected via:** VS Code Remote SSH (from 10.10.21.174)
- **TERM:** `tmux-256color`
- **Active tmux sessions:** 18 sessions running (multiple VS Code-managed sessions)

---

## Tmux Configuration Analysis

### Current `~/.tmux.conf`

The existing config on disk has already been modified beyond the user's described custom settings. The current file includes Claude Code optimizations (passthrough, escape-time 0, history-limit 250000, extended-keys, clipboard, focus-events). Below is the analysis against the user's **original** custom config:

### User's Original Settings

```
set -g mouse on                          # GOOD — keep
set -g base-index 1                      # GOOD — keep (quality-of-life)
set -g status-bg colour235               # GOOD — keep (custom styling)
set -g status-fg colour136               # GOOD — keep (custom styling)
set -g default-terminal "screen-256color" # NEEDS UPDATE
bind r source-file ~/.tmux.conf \; display "Reloaded!"  # GOOD — keep
set -g history-limit 50000               # NEEDS UPDATE
set -sg escape-time 50                   # NEEDS UPDATE
```

### Recommended Changes for Claude Code + VS Code Remote SSH

#### 1. `default-terminal` — Change from `screen-256color` to `tmux-256color`

**Why:** `screen-256color` lacks support for extended keys and synchronized output that Claude Code relies on. `tmux-256color` is the correct terminfo for tmux 3.x and enables features like DEC synchronized output (which prevents screen tearing from Claude's high-throughput output).

```
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
```

#### 2. `escape-time` — Reduce from 50 to 0

**Why:** The escape-time delay causes noticeable input lag, especially when Claude Code is streaming output. With modern terminals and VS Code's terminal, there is no need for an escape delay.

```
set -sg escape-time 0
```

#### 3. `history-limit` — Increase from 50000 to 250000

**Why:** Claude Code generates massive scroll output (4,000-6,700 events/sec during tool use). 50,000 lines can be exhausted in a single long operation, losing context. 250,000 provides sufficient buffer.

```
set -g history-limit 250000
```

#### 4. Add `allow-passthrough` — NEW

**Why:** Claude Code uses DEC synchronized output to prevent screen tearing. This requires passthrough sequences to reach the outer terminal through tmux.

```
set -g allow-passthrough on
```

#### 5. Add `extended-keys` — NEW

**Why:** Enables xterm-style extended key sequences, allowing Claude Code and VS Code to correctly handle modifier key combinations (Ctrl+Shift+*, etc.).

```
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'
```

#### 6. Add `set-clipboard` — NEW

**Why:** Enables OSC 52 clipboard integration, allowing copy/paste to work correctly through the SSH tunnel between your local machine and the remote tmux session.

```
set -g set-clipboard on
```

#### 7. Add `focus-events` — NEW

**Why:** Allows tmux to pass focus events to applications inside it. VS Code and Claude Code use focus events to detect when the terminal pane is active.

```
set -g focus-events on
```

### Recommended Full Config

Merging user's custom settings with Claude Code / VS Code Remote SSH optimizations:

```
# Custom settings (preserved)
set -g mouse on
set -g base-index 1
set -g status-bg colour235
set -g status-fg colour136
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# Claude Code + VS Code Remote SSH optimizations
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -sg escape-time 0
set -g history-limit 250000
set -g allow-passthrough on
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -g set-clipboard on
set -g focus-events on
```

---

## Session Hygiene Warning

There are **18 active tmux sessions**, most created by VS Code. Many appear to be stale (e.g., multiple `vscode_Discovery_*` sessions from the same day). Consider cleaning up with:

```bash
# List all sessions
tmux list-sessions

# Kill specific stale sessions
tmux kill-session -t <session-name>

# Or kill all non-attached sessions
tmux list-sessions | grep -v attached | cut -d: -f1 | xargs -I{} tmux kill-session -t {}
```

---

## Disk Usage Note

Disk is at 65% capacity (21 GB free). Not critical, but worth monitoring — Docker images and VS Code server caches can consume space quickly.

---

## Summary

| Area | Status | Action |
|------|--------|--------|
| System resources | Good | 24 cores, 78 GB RAM — well provisioned |
| Dev tools | Good | All key tools installed and recent |
| tmux config | Needs update | 3 settings to change, 4 new settings to add |
| tmux sessions | Warning | 18 sessions running, many likely stale |
| Disk space | OK | 65% used, monitor going forward |
| Claude Code | Good | v2.1.79 installed and functional |
| VS Code Remote | Good | Connected and operational |
