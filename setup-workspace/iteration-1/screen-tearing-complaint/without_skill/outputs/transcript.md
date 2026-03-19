# Screen Tearing Fix: Claude Code in tmux over VS Code Remote SSH

## Diagnosis

The screen tearing and flickering you are seeing is caused by a well-known interaction between tmux and fast-updating terminal applications like Claude Code. There are several contributing factors:

1. **Missing synchronized output passthrough.** Claude Code uses DEC synchronized output (escape sequences `\e[?2026h` / `\e[?2026l`) to batch screen updates atomically. By default, tmux blocks these passthrough sequences, so the terminal renders partial frames -- causing visible tearing.

2. **Escape-time delay.** tmux defaults `escape-time` to 500ms. This means every escape sequence Claude Code emits gets delayed by half a second before tmux processes it. With Claude Code producing thousands of escape sequences per second during streaming output, this creates a massive rendering bottleneck that manifests as flickering and visual corruption.

3. **Insufficient scroll buffer.** Claude Code can produce very high volumes of output (4,000-6,700+ events/sec during streaming). The default tmux `history-limit` of 2,000 lines is inadequate and can contribute to display glitches when the buffer overflows.

4. **Terminal capability mismatches.** VS Code's integrated terminal supports 24-bit color (RGB) and extended keys, but tmux needs to be explicitly told about these capabilities. Without proper configuration, you get rendering artifacts from incorrect color handling.

## The Fix

Add the following to your `~/.tmux.conf`:

```tmux
# --- Claude Code screen tearing fix ---

# Allow passthrough of synchronized output escape sequences.
# This is the single most important setting for eliminating tearing.
# Claude Code uses DEC 2026 synchronized output to batch screen
# updates atomically. Without this, tmux strips those sequences
# and the terminal renders partial frames.
set -g allow-passthrough on

# Remove the 500ms escape-sequence delay. The default causes
# massive input lag and rendering stutter with fast-updating
# TUI applications like Claude Code.
set -sg escape-time 0

# Increase scroll buffer for Claude's high-volume streaming output.
set -g history-limit 250000

# Tell tmux to advertise 256-color + true-color (RGB) support.
# Prevents color-related rendering artifacts in VS Code's terminal.
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"

# Extended keys support (modifier key combinations).
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'

# Enable OSC 52 clipboard passthrough (copy/paste from remote).
set -g set-clipboard on

# Let tmux forward focus events to applications.
set -g focus-events on
```

Your full `~/.tmux.conf` should look like this after the change:

```tmux
set -g mouse on

# Allow passthrough of synchronized output escape sequences
set -g allow-passthrough on

# Remove the 500ms escape-sequence delay
set -sg escape-time 0

# Increase scroll buffer for Claude's high-volume output
set -g history-limit 250000

# Terminal color and capability settings
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -g set-clipboard on
set -g focus-events on
```

## Applying the Changes

After saving the file, reload from within your existing tmux session:

```bash
tmux source-file ~/.tmux.conf
```

If the tearing persists after reloading, fully kill the tmux server and start a new session:

```bash
tmux kill-server
tmux new -s main
```

This is sometimes necessary because certain terminal capability settings (`default-terminal`, `terminal-overrides`) only take effect on new sessions.

## Why This Works

The root cause is `allow-passthrough on`. Synchronized output (DEC private mode 2026) is a protocol where an application tells the terminal "hold all rendering until I say I am done." Claude Code wraps every screen update in these sequences. When tmux strips them (the default), the terminal renders each individual write call as it arrives, producing torn frames where the top half of the screen shows the new content and the bottom half still shows old content.

Setting `escape-time` to 0 eliminates the additional half-second of latency per escape sequence, which is especially punishing over SSH where network latency already adds delay.

## Summary of Settings

| Setting | Default | New Value | Purpose |
|---------|---------|-----------|---------|
| `allow-passthrough` | `off` | `on` | Let synchronized output sequences reach the terminal |
| `escape-time` | `500` (ms) | `0` | Eliminate escape-sequence processing delay |
| `history-limit` | `2000` | `250000` | Handle Claude's high-volume output |
| `default-terminal` | `screen` | `tmux-256color` | Correct color capability advertising |
| `terminal-overrides` | (none) | `xterm-256color:RGB` | Enable 24-bit true color |
| `extended-keys` | `off` | `on` | Support modifier key combinations |
| `set-clipboard` | `external` | `on` | Enable OSC 52 clipboard passthrough |
| `focus-events` | `off` | `on` | Forward focus in/out events to apps |
