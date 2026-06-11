# tmux Modes — Setup Reference

tmux is a terminal multiplexer: it lets you run multiple terminal sessions inside a single window and keeps them alive even when you disconnect. Ultra Claude uses tmux for two things: (1) visual pane layout during plan execution — agents get arranged in a grid so you can see what each one is doing, and (2) terminal persistence so your dev servers and processes survive VS Code reloads and SSH disconnects. Neither is required — agent teams communicate via SendMessage and file-based signals, not tmux — so tmux is entirely optional.

## Modes

| Mode | Marker value | Description | Session Reaper? | tmux Required? | UC touches tmux config? |
|------|-------------|-------------|-----------------|----------------|------------------------|
| Per-project session | `per-project` | One tmux session per project directory. Created on first terminal open, reattached on subsequent ones. Processes survive VS Code reloads, SSH disconnects, lid closes. No orphan sessions. | No | Yes | Yes |
| No tmux | `none` | Plain shell. Terminals are regular shells. Closing VS Code kills running processes. Agent teams still work — communication is tmux-independent. | N/A | No | No |
| Per-terminal session | `per-terminal` | Each terminal spawns its own tmux session. Processes survive but sessions accumulate over time. A systemd reaper can be installed to clean up old ones (see `session-cleanup.md`). | Yes (opt-in) | Yes | Yes |
| Don't touch it | `custom` | User manages their own tmux setup. Ultra Claude won't install tmux, modify tmux.conf, write terminal profiles, or offer the session reaper. Agent pane labeling still works at runtime if `$TMUX_PANE` is set. | User's choice | User's choice | No |

## Selection Prompt

Present this when tmux mode is not yet configured (no `tmuxMode` in `~/.claude/ultra/uc-setup.json`):

```
AskUserQuestion({
  questions: [{
    question: "tmux is a terminal multiplexer that keeps your processes running even when VS Code disconnects. How would you like to use it?",
    header: "Terminal session mode",
    multiSelect: false,
    options: [
      {
        label: "Per-project session (Recommended)",
        description: "One persistent session per project. Closing VS Code or losing SSH doesn't kill your processes. Reopening reattaches automatically. No cleanup needed."
      },
      {
        label: "No tmux — plain shell",
        description: "Simple terminals with no persistence. Closing VS Code kills running processes. Good if you don't run long dev servers. Agent teams still work fine."
      },
      {
        label: "Per-terminal session (Legacy)",
        description: "Each terminal gets its own tmux session. Processes survive but sessions pile up over time. A cleanup timer can be optionally installed."
      },
      {
        label: "Don't touch it — I manage tmux myself",
        description: "You already have your own tmux setup. Ultra Claude won't install tmux, modify tmux.conf, or configure terminal profiles. Agent pane labeling still works automatically if you're inside a tmux session."
      }
    ]
  }]
})
```

Map the user's selection to the marker value:
- "Per-project session" → `per-project`
- "No tmux" → `none`
- "Per-terminal session" → `per-terminal`
- "Don't touch it" → `custom`

## Per-Project Mode

One tmux session per project, auto-created on first terminal open and reattached on all subsequent ones. This is the cleanest option — no orphan sessions, processes survive disconnects, and switching projects gives you a different session automatically.

### How it works

A single shared script (`scripts/tmux-session.sh`, symlinked to `~/.claude/ultra/tmux-session.sh`) runs every time VS Code opens a terminal. VS Code passes `${workspaceFolder}` as an argument:
1. Derives a session name from the workspace folder: `${USER}_${PROJECT_NAME}`
2. If that session doesn't exist, creates it
3. Attaches to it with `exec tmux attach` (replaces the shell process — clean detach on panel close)

The script lives in the plugin source and is symlinked during setup — no per-project files needed.

### Script

Ships at `scripts/tmux-session.sh` in the plugin. Setup symlinks it to `~/.claude/ultra/tmux-session.sh`:

```bash
ln -sf "<plugin-source>/scripts/tmux-session.sh" ~/.claude/ultra/tmux-session.sh
```

The script accepts an optional directory argument (defaults to `pwd`):

```bash
#!/usr/bin/env bash
# Auto-create or attach to a tmux session named after the working directory.

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not found, falling back to plain shell"
  exec "${SHELL:-bash}"
fi

if [ -n "$TMUX" ]; then
  exec "${SHELL:-bash}"
fi

PROJECT_DIR="${1:-$(pwd)}"
PROJECT_NAME="$(basename "$PROJECT_DIR" | tr -c '[:alnum:]_-' '_')"
SESSION="${USER}_${PROJECT_NAME}"

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR" -n editor
fi

exec tmux attach -t "$SESSION"
```

### VS Code terminal profile

Write to `~/.vscode-server/data/Machine/settings.json` (merge, don't overwrite):

```json
{
  "terminal.integrated.defaultProfile.linux": "project-tmux",
  "terminal.integrated.profiles.linux": {
    "project-tmux": {
      "path": "bash",
      "args": ["-c", "bash ~/.claude/ultra/tmux-session.sh ${workspaceFolder}"],
      "icon": "terminal-tmux"
    },
    "bash": {
      "path": "bash",
      "icon": "terminal-bash"
    }
  }
}
```

Only touch `terminal.integrated.profiles.*` and `terminal.integrated.defaultProfile.*`. Never modify other VS Code settings here — client-side editor settings are covered by `references/vscode-settings.md` (setup §5.14).

### Fallbacks

The script handles two edge cases:
- **tmux not installed** — falls back to a plain shell with a warning
- **Already inside tmux** — opens a plain shell instead of nesting

A `bash` profile is always added so the user can pick a non-tmux shell from the terminal dropdown.

### Daily usage

| Key | Action |
|-----|--------|
| `` Ctrl+` `` | Open terminal (auto-attaches to project session) |
| `Ctrl+b c` | New window inside tmux |
| `Ctrl+b ,` | Rename current window |
| `Ctrl+b n` / `Ctrl+b p` | Next / previous window |
| `Ctrl+b d` | Detach (session keeps running) |
| `Ctrl+b %` | Split pane vertically |
| `Ctrl+b "` | Split pane horizontally |
| `Ctrl+b z` | Zoom pane to fullscreen (toggle) |
| `Ctrl+b [` | Copy/scroll mode (`q` to exit) |

### Multiple terminal panels

If you open two VS Code terminal panels, both attach to the same tmux session and mirror each other. The intended workflow is one VS Code terminal panel, navigating between windows inside tmux. For independent views, use tmux panes (`Ctrl+b %` / `Ctrl+b "`).

## Per-Terminal Mode

Each VS Code terminal spawns its own tmux session. Simple but generates orphan sessions over time.

### VS Code terminal profile

```json
{
  "terminal.integrated.profiles.linux": {
    "tmux-session": {
      "path": "bash",
      "args": ["-c", "tmux new-session -s \"vscode:${workspaceFolderBasename}:$$\""]
    }
  },
  "terminal.integrated.defaultProfile.linux": "tmux-session"
}
```

### Session cleanup

Sessions pile up because each terminal creates a new one and closing VS Code doesn't kill them. A systemd-based reaper can be installed to kill sessions detached for more than 24 hours. See `session-cleanup.md` for the full procedure and tradeoffs.

The reaper is only relevant for this mode — per-project mode reuses sessions so there's nothing to clean up.

## No-tmux Mode

No tmux configuration. Terminals are plain shells. Agent teams work normally — communication uses SendMessage and file-based signals, not tmux. The visual pane layout grid during plan execution is disabled (agents still run, you just don't get the organized grid view).

No VS Code terminal profile changes are made.

## Custom Mode

Ultra Claude skips ALL tmux-related setup: no tmux installation, no tmux.conf changes, no VS Code terminal profile changes, no session reaper.

Agent pane labeling still works at runtime — every agent checks `$TMUX_PANE` before running tmux commands. If you happen to run Claude Code inside your own tmux session, panes get labeled and the layout daemon arranges them automatically. If you're not in tmux, the labeling is silently skipped.

## tmux.conf Template

Applied for `per-project` and `per-terminal` modes. Skipped for `none` and `custom`.

Write or merge into `~/.tmux.conf`. If the file already exists, read it first and only add settings that are missing — don't duplicate lines. If conflicting values exist (e.g., `allow-passthrough off`), warn the user and ask before changing.

**Primary fix is the fullscreen renderer.** Claude Code's fullscreen renderer (`/uc:setup` §3.13/§5.13, enabled via `"tui": "fullscreen"` in `~/.claude/settings.json`, or `/tui fullscreen`) is the real fix for screen tearing — it draws on the alternate screen and only repaints visible content, so it sidesteps tmux's lack of synchronized-output support entirely. These tmux.conf settings remain valuable because: (a) they support the fullscreen renderer itself (`mouse on` for wheel scrolling, `set-clipboard on` / OSC 52 for mouse-copy over SSH, extended keys for Shift+Enter newlines), and (b) they keep the **classic** renderer bearable for anyone who runs `/tui default`. Without them the classic renderer flickers badly during streaming output, and even with them tmux can't fully synchronize draws — which is exactly why fullscreen is recommended.

```bash
# ~/.tmux.conf — Claude Code optimized

# Wheel scrolling inside Claude Code (required by the fullscreen renderer)
set -g mouse on

# Let extended-key + synchronized-output (BSU/ESU) escape sequences through.
# Needed for Shift+Enter newlines, and lets the CLASSIC renderer batch screen
# draws to reduce tearing. The fullscreen renderer doesn't depend on this, but
# it's free insurance for anyone who runs /tui default.
set -g allow-passthrough on

# Remove 500ms escape delay (causes input lag in Claude Code)
set -sg escape-time 0

# Generous scrollback for shell output and Ctrl+o -> [ transcript dumps.
# (The classic renderer also floods scrollback at 4k-6.7k events/sec; the
# fullscreen renderer keeps the conversation in the alt-screen buffer instead.)
set -g history-limit 250000

# Extended keys (Shift+Enter newlines) and clipboard (OSC 52 mouse-copy over SSH)
set -s extended-keys on
set -as terminal-features 'xterm*:extkeys'
set -g set-clipboard on

# Color and focus
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g focus-events on
```

After writing, reload if tmux is running:

```bash
tmux source-file ~/.tmux.conf 2>/dev/null
```

If tearing persists, the user should detach and reattach their tmux session — some terminal overrides only take effect on new attachments.

## VS Code Detection

Before writing any terminal profiles, detect whether the user uses VS Code:

```bash
[ -d "$HOME/.vscode-server" ] && echo "vscode-remote" || [ -d "$HOME/.vscode" ] && echo "vscode-local" || echo "no-vscode"
```

- If neither directory exists, skip all VS Code terminal profile configuration and note: "No VS Code installation detected — skipping terminal profile setup."
- If detected, proceed with mode-appropriate terminal profile changes
- Only touch `terminal.integrated.profiles.*` and `terminal.integrated.defaultProfile.*`. Never modify other VS Code settings as part of tmux mode setup — client-side editor settings are covered by `references/vscode-settings.md` (setup §5.14).

## Tips

Print after mode selection (informational only — the setup skill does not configure these):

> **Tip:** For best performance with agent teams, run Claude Code directly inside the VM terminal (not through VS Code's integrated terminal) with bypass permissions enabled. This eliminates SSH latency and permission prompts during plan execution.

## Detection Logic

How to detect the current tmux mode at runtime:

1. Read `~/.claude/ultra/uc-setup.json` → `tmuxMode` field
2. If marker doesn't exist or field is missing, fall back:
   - `$TMUX_PANE` is set → tmux is active (mode is either `per-project` or `per-terminal`, but the distinction doesn't matter at runtime — agent labeling works the same)
   - `which tmux` succeeds but `$TMUX_PANE` is unset → tmux is installed but user is not in a session
   - Neither → effectively `none`

The `tmuxMode` marker records the user's setup-time preference. `$TMUX_PANE` is the runtime signal used by agents and the plan execution skill to decide whether to run tmux commands.
