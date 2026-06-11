# VS Code Client Settings — Setup Reference

Optional, detection-gated guidance for users who edit through VS Code (local or Remote SSH). Setup offers this only when a VS Code installation is detected — never require VS Code, never nag when it's absent.

## Settings Locations

VS Code Remote (vscode-server) has two distinct settings locations:

| Location | Path | Scope |
|----------|------|-------|
| **Remote machine** | `~/.vscode-server/data/Machine/settings.json` | Terminal profiles, Linux-specific settings |
| **Client (Mac/Windows)** | User Settings JSON on the host machine | Window behavior, UI, extensions, Claude Code extension settings |

**Rule:** Settings that control the VS Code window, UI, or extensions go on the **client**. Settings that control terminal, shell, or Linux behavior go on the **remote machine**.

The remote file is directly editable from setup. Client settings cannot be reached from the remote — print the merged JSON for the user to paste into their client User Settings (`Cmd+,` / `Ctrl+,` → Open Settings JSON).

## Terminal Profiles — Not Here

Terminal profiles (tmux-wrapped or plain) are owned entirely by `references/tmux-modes.md` and applied in setup §5.5b based on the user's tmux mode. Do not duplicate or modify them from this reference.

## Recommended Client-Side Settings

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
| `chat.disableAIFeatures: true` | Disable built-in Copilot/AI chat in one setting (VS Code 1.104+; using Claude Code instead) |
| `git.autofetch: true` | Auto-fetch remote changes in background |
| `claudeCode.preferredLocation: panel` | Show Claude Code in the bottom panel instead of the sidebar |
| `claudeCode.useTerminal: true` | Run Claude Code as the CLI in the integrated terminal rather than the graphical panel |

With `claudeCode.useTerminal: true`, rendering is governed by the CLI's TUI setting — the fullscreen renderer from setup §3.13/§5.13 (`"tui": "fullscreen"` in `~/.claude/settings.json`) is the primary fix for tearing/flicker in that terminal; these client settings are comfort settings, not the tearing fix.

### Optional extras (mention, don't push)

| Setting | Purpose |
|---------|---------|
| `claudeCode.initialPermissionMode` | Default permission mode for new extension sessions (`default`, `plan`, `acceptEdits`, `bypassPermissions`) |
| `claudeCode.autosave` | Auto-save files before Claude reads/writes (default `true`; keep on for Remote SSH to avoid stale state) |
| `claudeCode.respectGitIgnore` | Exclude `.gitignore` patterns from Claude's file search (default `true`) |
| `claudeCode.disableLoginPrompt` | Suppress browser sign-in prompt (for Bedrock/Vertex/headless setups) |

## Guidelines

- **Never blindly overwrite** — read the user's existing settings first (ask them to paste client settings if relevant) and merge
- **Separate client vs remote** — say which file each setting belongs in
- **Print client JSON** — output the merged JSON for the user to paste; only the remote machine file is editable directly
- **Explain each setting** — users should understand what they're enabling
- **Warn about security** — call out permission-bypassing settings (e.g. `initialPermissionMode: bypassPermissions`) explicitly
