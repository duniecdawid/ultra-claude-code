---
description: One-time machine setup for Ultra Claude. Checks and configures shell environment (1M context, agent teams), installs prerequisites (node, optionally tmux), guides tmux mode selection (per-project, per-terminal, none, or custom — see references/tmux-modes.md), configures the statusline for per-account usage tracking, optionally sets up Tailscale for remote access, optionally installs a tmux disconnected-session reaper for per-terminal mode users whose tmux sessions pile up, and — if the `ultraclaude-agent` npm package is already installed — checks for and offers to update it to the latest published version. Idempotent — safe to re-run. Writes version marker to ~/.claude/ultra/uc-setup.json so other skills can quickly check if setup is current. Use when onboarding a new machine, after Ultra Claude install, when plan-execution reports missing prerequisites, when experiencing screen tearing/flickering in tmux, or when stale tmux sessions are accumulating on a remote machine. Triggers on "setup", "machine setup", "environment setup", "configure machine", "setup 1m context", "enable agent teams", "screen tearing", "tmux tearing", "flickering", "session cleanup", "tmux reaper", "reap tmux", "orphaned tmux", "stale tmux sessions".
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

### 3.1 tmux mode

Check tmux installation and current mode preference:

```bash
which tmux 2>/dev/null && tmux -V
jq -r '.tmuxMode // empty' ~/.claude/ultra/uc-setup.json 2>/dev/null
```

Report:
- If `tmuxMode` is set in marker: show the stored mode (`per-project`, `none`, `per-terminal`, or `custom`)
- If no stored mode: show "not configured" — will be prompted in Step 5
- tmux installed: yes/no (informational — not a hard requirement)

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

SKIP if tmux is not installed, or if tmux mode is `none` or `custom`.

### 3.6 Statusline (usage data for execution tracking)

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
- The statusLine has `"type": "command"`, `"command": "bash ~/.claude/ultra/statusline.sh"`, and `"refreshInterval": 1`

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

### 3.9 Agent (optional — only if installed)

If the `ultraclaude-agent` npm package is installed, check whether a newer version is published. The agent is an independent package (not part of this plugin) that some users install to sync project state to external consumers — do **not** offer to install it from this skill. Only flag it as OUTDATED when it is already present.

```bash
if command -v ultraclaude-agent >/dev/null 2>&1; then
  INSTALLED=$(ultraclaude-agent --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  # Short timeout so setup never hangs on a slow/offline npm registry
  LATEST=$(timeout 5 npm view ultraclaude-agent version 2>/dev/null)
  echo "agent installed: ${INSTALLED:-unknown}"
  echo "agent latest:    ${LATEST:-unavailable}"
fi
```

Status:
- SKIP (treat as `— not installed`) if `ultraclaude-agent` is not on `PATH`.
- PASS if installed AND (a) latest cannot be fetched (offline) OR (b) installed == latest.
- OUTDATED if installed and latest differ — surface in Step 4 and offer the update in Step 5.10.

Never auto-install the agent from `/uc:setup`. Installation is the user's choice.

### 3.10 Machine Context (optional)

Check whether the user's local `~/.claude/skills/machine-context/` skill exists:

```bash
test -f ~/.claude/skills/machine-context/SKILL.md && echo present || echo missing
```

Record status but don't mark as MISSING — this is optional. The `machine-context` skill holds per-machine values (Chrome install, VM/host topology, dev runtimes, network conventions, warnings) that other Ultra Claude skills read at runtime. Skills like `/uc:chrome-debug` fall back to pure runtime detection when it's absent, so the skill is not strictly required, but populating it makes future diagnostics and workflows more targeted.

### 3.11 Session Cleanup (optional, Linux/systemd only)

Optional opt-in tmux disconnected-session reaper for users whose tmux sessions accumulate on a remote machine (typically VSCode Remote SSH workflows). Full procedure — including the tradeoff prompt, file templates, and systemd unit definitions — lives in `references/session-cleanup.md`.

SKIP if tmux mode is `none`, `per-project`, or `custom`. The reaper is only relevant for `per-terminal` mode where sessions accumulate.

Platform gate first:

```bash
[ "$(uname -s)" = "Linux" ] || echo "skip: not linux"
command -v systemctl >/dev/null 2>&1 || echo "skip: no systemctl"
```

If the gate fails, record SKIP and move on — never mark as MISSING on non-Linux platforms.

Otherwise detect current state per the reference's "Detection" section:

```bash
REAPER_BIN="$HOME/.local/bin/tmux-reap-disconnected.sh"
SERVICE_UNIT="$HOME/.config/systemd/user/tmux-reap.service"
TIMER_UNIT="$HOME/.config/systemd/user/tmux-reap.timer"
[ -f "$REAPER_BIN" ] && [ -f "$SERVICE_UNIT" ] && [ -f "$TIMER_UNIT" ] && echo "files: yes" || echo "files: no"
systemctl --user is-enabled tmux-reap.timer >/dev/null 2>&1 && echo "enabled: yes" || echo "enabled: no"
systemctl --user is-active  tmux-reap.timer >/dev/null 2>&1 && echo "active: yes"  || echo "active: no"
loginctl show-user "$USER" 2>/dev/null | grep -q '^Linger=yes' && echo "linger: yes" || echo "linger: no"
```

Record status but don't mark as MISSING — this is **strictly opt-in**. Treat as:

- **PASS** — all three files exist AND timer is enabled AND active AND linger is on.
- **OPT-IN AVAILABLE** — platform gate passed but files are absent or partial. Surface in Step 4 with the optional label; the fix in Step 5.11 must explicitly ask the user to opt in before touching anything.
- **SKIP** — non-Linux or systemctl unavailable.

### 3.12 Dashboard (optional)

Check whether the sync agent is connected to the Ultra Claude Dashboard. This check only runs if Step 3.9 detected the agent as installed — skip entirely if the agent is not on `PATH`.

```bash
if command -v ultraclaude-agent >/dev/null 2>&1; then
  ultraclaude-agent status 2>/dev/null | head -5
fi
```

Record status but don't mark as MISSING — this is optional. Treat as:

- **SKIP** — agent is not installed (3.9 already handles installation status)
- **PASS** — agent is installed and `ultraclaude-agent status` reports a running daemon with connected projects
- **OPT-IN AVAILABLE** — agent is installed but status shows not connected, no projects, or daemon not running

## Step 4: Present Status

Display a status table:

```
Ultra Claude Environment Check (plugin v{version})

  tmux mode                 ✓ per-project (recommended)   # or "— none (no tmux)" / "— custom (user-managed)" / "✓ per-terminal (legacy)" / "✗ not configured"
  tmux.conf                 ✓ passthrough enabled          # or "— skipped" if mode is none/custom
  Agent teams env var       ✗ missing
  1M context env vars       ✗ missing
  Node.js                   ✓ v22.0.0
  Statusline                ✗ not configured
  Session Hooks             ✗ not configured
  Tailscale (optional)      — not installed
  Agent (optional)          — not installed   # or "✓ 0.0.26 (latest)" / "✗ 0.0.25 → 0.0.26"
  Machine Context (optional) — not configured
  Session Cleanup (optional) — not installed  # or "✓ reaper active (24h)" / "— skipped (not linux)" / "— skipped (not per-terminal)"
  Dashboard (optional)       — skipped       # or "✓ connected" / "✗ not connected" / "— skipped (agent not installed)"
```

If ALL required checks pass (3.2–3.7 — tmux mode is always valid since all four choices are acceptable):
- Write the marker file (Step 6)
- Print "Environment ready! All prerequisites configured."
- If Tailscale is not set up, mention: "Optional: Run `/uc:tailscale-setup` to enable remote access."
- Stop here.

## Step 5: Fix Missing Prerequisites

If tmux mode is not yet configured (no `tmuxMode` in marker file), present the tmux mode selection prompt from `references/tmux-modes.md` Section "Selection Prompt" FIRST, before the multi-select fix list. The mode choice determines which tmux-related fixes appear.

Then use AskUserQuestion with a multi-select to let the user choose which items to fix. List only MISSING items. Always include Tailscale if not installed (marked as optional in the description). On Linux, include Session Cleanup only if tmux mode is `per-terminal` (marked as optional, with a short one-liner about the tradeoff — the full warning lives in the fix step's own prompt).

After mode selection (or after presenting fixes), print the tip from `references/tmux-modes.md` Section "Tips".

### 5.1 Fix: tmux

Skip if tmux mode is `none` or `custom`.

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
Node.js is required for Ultra Claude scripts (including the tmux layout daemon when tmux is available).

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

Skip if tmux mode is `none` or `custom`.

Write the tmux.conf template from `references/tmux-modes.md` Section "tmux.conf Template". If the file already exists, read it first and only add settings that are missing — don't duplicate lines. If conflicting values exist (e.g., `allow-passthrough off`), warn the user and ask before changing.

After writing, reload the config if tmux is currently running:

```bash
tmux source-file ~/.tmux.conf 2>/dev/null
```

Tell the user: "If tearing persists, detach and reattach your tmux session — some terminal overrides only take effect on new attachments."

### 5.5b Fix: VS Code terminal profile (tmux mode dependent)

Skip if tmux mode is `none` or `custom`.

Detect VS Code installation:

```bash
[ -d "$HOME/.vscode-server" ] && echo "vscode-remote" || [ -d "$HOME/.vscode" ] && echo "vscode-local" || echo "no-vscode"
```

If no VS Code installation detected, skip and note: "No VS Code installation detected — skipping terminal profile setup."

If VS Code is detected, apply mode-appropriate terminal profile from `references/tmux-modes.md`:

- `per-project`: Symlink the shared tmux session script, then configure VS Code:

  ```bash
  ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-session.sh" ~/.claude/ultra/tmux-session.sh
  ```

  Then merge the `project-tmux` profile into VS Code settings (the profile calls `bash ~/.claude/ultra/tmux-session.sh ${workspaceFolder}`). No per-project files needed. Only touch `terminal.integrated.profiles.*` and `terminal.integrated.defaultProfile.*` — never modify other VS Code settings.

- `per-terminal`: Write the per-terminal profile from reference Section "Per-Terminal Mode".

Always add a `bash` fallback profile alongside the tmux profile.

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
    "command": "bash ~/.claude/ultra/statusline.sh",
    "refreshInterval": 1
  }
}
```

The `refreshInterval: 1` re-runs the script every second, enabling the live cache countdown timer.

Use `jq` to merge into existing settings without overwriting other keys:

```bash
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  jq '.statusLine = {"type": "command", "command": "bash ~/.claude/ultra/statusline.sh", "refreshInterval": 1}' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
else
  echo '{"statusLine":{"type":"command","command":"bash ~/.claude/ultra/statusline.sh","refreshInterval":1}}' > "$settings_file"
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

### 5.9 Fix: Update Agent

Only run this fix if check 3.9 flagged the agent as OUTDATED (installed and newer version available on npm). Never run it when the agent is not installed — `/uc:setup` does not install the agent from scratch.

```bash
# Preserve the original install mechanism. `npm update -g` works whether the
# agent was installed via plain npm, nvm, or Homebrew's npm. Homebrew users
# who manage node via brew may see a "symlinks" notice — that's expected.
npm update -g ultraclaude-agent
```

After updating, verify the new version is installed and offer to restart the daemon if it was running:

```bash
NEW=$(ultraclaude-agent --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "ultraclaude-agent now at v$NEW"

# If a daemon is running, the upgrade-check mechanism in the agent itself
# triggers a restart. Print a status line for the user's benefit.
ultraclaude-agent status 2>/dev/null | head -5 || true
```

If `npm update` fails (permission errors, registry unreachable), print the exact command the user would run themselves (`npm update -g ultraclaude-agent`) and move on — a failed agent update must not block the rest of setup.

### 5.10 Fix: Machine Context

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

### 5.11 Fix: Session Cleanup (opt-in, Linux/systemd only)

Skip this fix entirely if the platform gate in 3.11 failed (not Linux, or no systemctl). Skip it also if check 3.11 already reported PASS — the user has a working reaper, leave it alone unless they explicitly picked "Reinstall" or "Repair".

This is **strictly opt-in**. Before writing any files, present the user with the tradeoff prompt from `references/session-cleanup.md` (section "Opt-in prompt"). The prompt must make clear that:

1. The reaper **cleans up** stale tmux sessions — great for VSCode Remote SSH users whose integrated terminals leave orphaned sessions behind.
2. The reaper **disrupts your ability to resume work** in any detached tmux session older than 24 hours — including sessions you deliberately detached with `Ctrl-b d` intending to come back later. Scrollback and running processes inside those sessions are lost.
3. If the user relies on long-lived detached sessions to pick up work across days, they should pick `[Skip]`.

Use `AskUserQuestion` with the options described in the reference — at minimum `[Install]` and `[Skip]`, adding `[Reinstall]`, `[Repair]`, `[Remove]`, or `[Leave as is]` when the current install state calls for them. Default to the non-destructive option.

Only if the user explicitly chose Install / Reinstall / Repair, follow the "Install / repair implementation" section of `references/session-cleanup.md`:

1. Write `$HOME/.local/bin/tmux-reap-disconnected.sh` with the `Write` tool (the exact content is in the reference). `chmod +x` it afterwards.
2. Write `$HOME/.config/systemd/user/tmux-reap.service`.
3. Write `$HOME/.config/systemd/user/tmux-reap.timer`.
4. Run `systemctl --user daemon-reload` and `systemctl --user enable --now tmux-reap.timer`.
5. If `loginctl show-user "$USER"` reports `Linger=no`, run `sudo loginctl enable-linger "$USER"`. If the user doesn't have passwordless sudo, print the exact command and wait for them to run it — do **not** silently proceed.

If the user picked `[Remove]`, follow the "Remove" section of the reference and stop.

After any install/reinstall/repair, run the "Verify" block from the reference and report: timer enabled/active, next scheduled run, linger state, threshold (default 24h, tunable via `TMUX_REAP_THRESHOLD` in the service unit), and the three file paths.

All writes land under `$HOME`. Nothing touches project directories.

### 5.12 Fix: Dashboard

Skip if the agent is not installed (Step 3.9 must report the agent on `PATH`). Skip if Step 3.12 already reported PASS.

If the agent is installed but not connected to the dashboard:

Tell the user: "Run `/uc:dashboard` to connect to the Ultra Claude Dashboard and verify agent connectivity."

This fix delegates to the dashboard skill which handles the full setup and debug flow. `/uc:setup` does not duplicate the dashboard connection logic.

## Step 6: Write Marker File

After all fixes are applied, write `~/.claude/ultra/uc-setup.json`:

```json
{
  "version": "{plugin version from plugin.json}",
  "timestamp": "{ISO 8601 timestamp}",
  "shell": "{bash or zsh}",
  "shellConfig": "{path to shell config file}",
  "tmuxMode": "per-project" | "none" | "per-terminal" | "custom",
  "checks": {
    "tmux": true/false,
    "tmuxConf": true/false,
    "agentTeams": true/false,
    "context1m": true/false,
    "node": true/false,
    "statusline": true/false,
    "sessionHooks": true/false,
    "tailscale": true/false,
    "agent": "{installed version or null if not installed}",
    "machineContext": true/false,
    "sessionCleanup": "installed" | "skipped" | "not-linux" | "opted-out",
    "dashboard": "connected" | "not-connected" | "skipped"
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
