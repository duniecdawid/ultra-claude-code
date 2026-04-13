---
description: One-time machine setup for Ultra Claude. Checks and configures shell environment (1M context, agent teams), installs prerequisites (tmux, node), configures tmux for Claude Code (fixes screen tearing via DEC 2026 synchronized output passthrough), configures the statusline for per-account usage tracking, and optionally sets up Tailscale for remote access. Idempotent — safe to re-run. Writes version marker to ~/.claude/ultra/uc-setup.json so other skills can quickly check if setup is current. Use when onboarding a new machine, after Ultra Claude install, when plan-execution reports missing prerequisites, or when experiencing screen tearing/flickering in tmux. Triggers on "setup", "machine setup", "environment setup", "configure machine", "setup 1m context", "enable agent teams", "screen tearing", "tmux tearing", "flickering".
user-invocable: true
---

# Ultra Claude Setup

One-time machine setup that configures your environment for Ultra Claude features — especially agent teams and 1M context windows. Idempotent: safe to re-run after updates.

## Step 1: Read Current State

1. Read `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` to get the current plugin version
2. Read `~/.claude/ultra/uc-setup.json` (if exists) to check previous setup state
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

PASS if `node` is found (v18+ recommended).

### 3.5 tmux.conf (Claude Code optimized)

If tmux is installed, check `~/.tmux.conf` for the critical `allow-passthrough` setting:

```bash
grep -c 'allow-passthrough' ~/.tmux.conf 2>/dev/null
```

PASS if `allow-passthrough on` is found. This setting is essential because Claude Code's terminal UI relies on DEC 2026 synchronized output (BSU/ESU escape sequences) to batch screen draws. Without passthrough, tmux swallows these sequences, causing severe screen tearing — especially during streaming output which generates 4,000–6,700 scroll events per second.

SKIP if tmux is not installed.

### 3.6 Statusline (usage data for dashboard)

Check if `~/.claude/settings.json` has a `statusLine` command pointing to the Ultra Claude statusline script and that `jq` is available. All Ultra Claude runtime files live under `~/.claude/ultra/`:

```bash
jq --version 2>/dev/null
```

Then check settings.json for the statusLine configuration:

```bash
jq -r '.statusLine.command // empty' ~/.claude/settings.json 2>/dev/null
```

PASS if:
- `jq` is installed
- The statusLine has `"type": "command"` and `"command": "bash ~/.claude/ultra/statusline.sh"`

### 3.7 Session Hooks

Check if session tracking hooks are configured and symlinked:

```bash
[ -L ~/.claude/ultra/lib.sh ] && echo "lib exists" || echo "lib missing"
[ -L ~/.claude/ultra/hooks/session-start.sh ] && echo "start exists" || echo "start missing"
[ -L ~/.claude/ultra/hooks/session-end.sh ] && echo "end exists" || echo "end missing"
jq -r '.hooks.SessionStart // empty' ~/.claude/settings.json 2>/dev/null
jq -r '.hooks.SessionEnd // empty' ~/.claude/settings.json 2>/dev/null
```

PASS if:
- All three symlinks exist (`lib.sh`, `hooks/session-start.sh`, `hooks/session-end.sh`)
- `~/.claude/settings.json` has `hooks.SessionStart` and `hooks.SessionEnd` entries

### 3.8 Tailscale (optional)

```bash
which tailscale 2>/dev/null && tailscale status --self --json 2>/dev/null
```

Record status but don't mark as MISSING — this is optional.

### 3.9 Machine Context (optional)

Check whether the user's local `~/.claude/skills/machine-context/` skill exists:

```bash
test -f ~/.claude/skills/machine-context/SKILL.md && echo present || echo missing
```

Record status but don't mark as MISSING — this is optional. The `machine-context` skill holds per-machine values (Chrome install, VM/host topology, dev runtimes, network conventions, warnings) that other Ultra Claude skills read at runtime. Skills like `/uc:chrome-debug` fall back to pure runtime detection when it's absent, so the skill is not strictly required, but populating it makes future diagnostics and workflows more targeted.

## Step 4: Present Status

Display a status table:

```
Ultra Claude Environment Check (plugin v{version})

  tmux                      ✓ installed (v3.4)
  tmux.conf                 ✗ missing passthrough
  Agent teams env var       ✗ missing
  1M context env vars       ✗ missing
  Node.js                   ✓ v22.0.0
  Statusline                ✗ not configured
  Session Hooks             ✗ not configured
  Tailscale (optional)      — not installed
  Machine Context (optional) — not configured
```

If ALL required checks pass (3.1–3.7):
- Write the marker file (Step 6)
- Print "Environment ready! All prerequisites configured."
- If Tailscale is not set up, mention: "Optional: Run `/uc:tailscale-setup` to enable remote access."
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
Node.js is required for the tmux layout daemon and other Ultra Claude scripts.

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

### 5.6 Fix: Statusline

The statusline script ships with Ultra Claude at `${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh`. Setup needs to:

1. **Install jq** if missing:

```bash
# Linux (Debian/Ubuntu)
sudo apt update && sudo apt install -y jq

# macOS
brew install jq
```

2. **Symlink the script and shared library** to `~/.claude/ultra/` (so fixes propagate automatically from the plugin source):

```bash
mkdir -p ~/.claude/ultra
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/statusline.sh" ~/.claude/ultra/statusline.sh
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/lib.sh" ~/.claude/ultra/lib.sh
```

3. **Configure settings.json** — read `~/.claude/settings.json`, add or update the `statusLine` key:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/ultra/statusline.sh"
  }
}
```

Use `jq` to merge into existing settings without overwriting other keys:

```bash
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  jq '.statusLine = {"type": "command", "command": "bash ~/.claude/ultra/statusline.sh"}' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
else
  echo '{"statusLine":{"type":"command","command":"bash ~/.claude/ultra/statusline.sh"}}' > "$settings_file"
fi
```

Tell the user: "Statusline configured — usage data will appear after your next Claude Code interaction. Rate limits are tracked per account with overwrite protection."

**Important:** Always re-create the symlinks during setup, even if already configured. The source paths may have changed. The symlink steps are idempotent.

### 5.7 Fix: Session Hooks

Session hooks establish per-session account identity at session boundaries, eliminating the race condition when multiple accounts run simultaneously.

1. **Symlink hook scripts** to `~/.claude/ultra/hooks/`:

```bash
mkdir -p ~/.claude/ultra/hooks
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-start.sh" ~/.claude/ultra/hooks/session-start.sh
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/session-end.sh" ~/.claude/ultra/hooks/session-end.sh
```

2. **Configure hooks in settings.json** — add `SessionStart` and `SessionEnd` hooks:

```bash
settings_file="$HOME/.claude/settings.json"
jq '
  .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/ultra/hooks/session-start.sh"}]}] |
  .hooks.SessionEnd = [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/ultra/hooks/session-end.sh"}]}]
' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
```

Use `jq` to merge into existing settings without overwriting other top-level keys. The `SessionStart` and `SessionEnd` arrays are fully managed by Ultra Claude.

Tell the user: "Session hooks configured — each Claude Code session will now be tracked with its account identity. This eliminates the multi-account race condition."

3. **Clear legacy usage data** — the usage-status.json format changed from email-keyed to account_id-keyed. Remove the old file so it gets recreated cleanly:

```bash
rm -f ~/.claude/ultra/usage-status.json
```

**Important:** Always re-create the symlinks during setup. The hook scripts source `~/.claude/ultra/lib.sh` which must be symlinked first (done in 5.6).

### 5.8 Fix: Tailscale

If the user selected Tailscale, invoke `/uc:tailscale-setup` which handles all Tailscale configuration.

### 5.9 Fix: Machine Context

If the user selected Machine Context, run the interview-driven scaffolding procedure defined in `references/machine-context-interview.md`. The procedure creates `~/.claude/skills/machine-context/SKILL.md` plus topic files (`environment.md`, `chrome-debug.md`, `claude-profiles.md`, `development.md`, `network.md`, `warnings.md`). Each topic file is populated from targeted questions with sensible defaults from runtime detection.

**Detection-first defaults** the interview uses without asking the user:
- OS from `/etc/os-release` (Linux) or `uname -s` (macOS/others)
- Username from `whoami`, home from `$HOME`
- Shell from `$SHELL`
- Node version from `node -v 2>/dev/null`
- Python version from `python3 --version 2>/dev/null`
- Active Claude profile from `cat ~/.claude-profiles/.active 2>/dev/null`
- Available profiles from `ls -1 ~/.claude-profiles/ 2>/dev/null | grep -v '^\.'`
- Chrome extension ID from `jq -r '.allowed_origins[0]' ~/.config/chromium/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json 2>/dev/null`
- Plugin-dir entries from `~/.claude/plugin-dirs.txt`

**Rerun-safe behavior**: if `~/.claude/skills/machine-context/` already exists, ask whether to skip, update specific topic files, or regenerate from scratch. **Never clobber user-written content** without an explicit confirmation.

See `references/machine-context-interview.md` for the full question set and file templates.

## Step 6: Write Marker File

After all fixes are applied, write `~/.claude/ultra/uc-setup.json`:

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
    "statusline": true/false,
    "sessionHooks": true/false,
    "tailscale": true/false,
    "machineContext": true/false
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
