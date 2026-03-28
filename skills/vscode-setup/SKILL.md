---
description: Configure VS Code settings for optimal Claude Code experience. Manages both remote (vscode-server) and client-side settings. Use when setting up VS Code, tweaking editor behavior, or optimizing the Claude Code workflow. Triggers on "vscode setup", "vscode settings", "configure vscode", "optimize vscode", "vs code config".
user-invocable: true
argument-hint: "what to configure (optional)"
---

# VS Code Setup

Configure VS Code for an optimal Claude Code development experience. Handles both remote server settings and client-side settings, guiding the user on where each belongs.

## Settings Locations

VS Code Remote (vscode-server) has two distinct settings locations:

| Location | Path | Scope |
|----------|------|-------|
| **Remote machine** | `~/.vscode-server/data/Machine/settings.json` | Terminal profiles, Linux-specific settings |
| **Client (Mac/Windows)** | User Settings JSON on host machine | Window behavior, UI, extensions, Claude Code settings |

**Rule:** Settings that control the VS Code window, UI, or extensions go on the **client**. Settings that control terminal, shell, or Linux behavior go on the **remote machine**.

## Process

### Step 1: Understand the Request

From `$ARGUMENTS`, identify what the user wants to configure:
- **Clean startup** — no restored tabs, Claude Code auto-open
- **Claude Code optimization** — panel location, permissions, terminal mode
- **Terminal setup** — profiles, default shell, tmux integration
- **General editor** — tab behavior, git settings, UI preferences
- **Full setup** — all of the above

If no arguments provided, offer a menu of the above options.

### Step 2: Read Current Settings

Read the remote machine settings:
```
Read: ~/.vscode-server/data/Machine/settings.json
```

Ask the user to share their current client settings if needed (we cannot access them directly).

### Step 3: Apply Changes

**For remote machine settings** — edit directly:
- Terminal profiles and default shell
- Any Linux-specific configuration

**For client settings** — print the merged JSON for the user to paste:
- Window restore behavior
- Startup editor
- Claude Code extension settings
- UI and editor preferences
- Extension-specific settings (Parallels, git, etc.)

Always merge with existing settings — never overwrite.

### Step 4: Explain What Changed

For each setting added or modified, briefly explain what it does and why.

## Recommended Settings

### Client-Side (Mac/Windows)

```json
{
    "window.restoreWindows": "none",
    "workbench.startupEditor": "none",
    "workbench.editor.restoreViewState": false,
    "workbench.editor.revealIfOpen": true,
    "chat.disableAIFeatures": true,
    "git.autofetch": true,
    "claudeCode.preferredLocation": "panel",
    "claudeCode.useTerminal": true
}
```

| Setting | Purpose |
|---------|---------|
| `window.restoreWindows: none` | Start fresh — no restored windows or tabs |
| `workbench.startupEditor: none` | No welcome tab or previous files on startup |
| `workbench.editor.restoreViewState: false` | Don't restore scroll position or cursor in editors |
| `workbench.editor.revealIfOpen: true` | Switch to existing tab instead of opening duplicates |
| `chat.disableAIFeatures: true` | Disable built-in AI features (using Claude Code instead) |
| `git.autofetch: true` | Auto-fetch remote changes in background |
| `claudeCode.preferredLocation: panel` | Show Claude Code in the bottom panel |
| `claudeCode.useTerminal: true` | Run Claude Code in integrated terminal |

### Remote Machine (vscode-server)

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

| Setting | Purpose |
|---------|---------|
| `terminal.integrated.profiles.linux` | Define tmux-wrapped terminal profile |
| `terminal.integrated.defaultProfile.linux` | Use tmux session as default terminal |

## Guidelines

- **Never blindly overwrite** — always read existing settings first and merge
- **Separate client vs remote** — explain which file each setting belongs in
- **Print client JSON** — we can't edit client files directly, so output merged JSON for the user
- **Edit remote directly** — use Edit tool for `~/.vscode-server/data/Machine/settings.json`
- **Explain each setting** — users should understand what they're enabling
- **Warn about security** — note when settings like `allowDangerouslySkipPermissions` are used
