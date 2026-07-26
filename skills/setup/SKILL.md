---
description: One-time machine setup for Ultra Claude. Checks and configures shell environment (1M context, agent teams, teammate execution mode for tmux-paned plan-execution teams), installs prerequisites (node, optionally tmux), guides tmux mode selection (per-project, per-terminal, none, or custom — see references/tmux-modes.md), configures the statusline for per-account usage tracking, offers the Claude Code fullscreen renderer for flicker-free flat-memory output (opt-out, version-gated), offers recommended client-side VS Code settings for the Claude Code extension when VS Code is detected (opt-in — see references/vscode-settings.md), optionally sets up Tailscale for remote access, and — if the `ultraclaude-agent` npm package is already installed — checks for and offers to update it to the latest published version. Idempotent — safe to re-run. Writes version marker to ~/.claude/ultra/uc-setup.json so other skills can quickly check if setup is current. Use when onboarding a new machine, after Ultra Claude install, when plan-execution reports missing prerequisites, when experiencing screen tearing/flickering in tmux. Triggers on "setup", "machine setup", "environment setup", "configure machine", "setup 1m context", "enable agent teams", "screen tearing", "tmux tearing", "flickering", "fullscreen", "fullscreen renderer", "fullscreen mode", "tui", "flicker-free".
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

### 3.2b Teammate execution mode

Plan execution runs its teammates (Executor/Reviewer/Tester/PM) as **tmux panes**. *How* a named teammate runs is governed by the `teammateMode` key in `~/.claude/settings.json` (`tmux` | `in-process` | `auto`). When it is unset, Claude Code defaults to **`in-process`** — teammates spawn inside the Lead's process with **no tmux panes**, which silently breaks the pane-based coordination plan-execution depends on (the user sees "it didn't run as a team / no panes").

```bash
jq -r '.teammateMode // empty' ~/.claude/settings.json 2>/dev/null
```

PASS if `teammateMode` is `tmux` (the value plan-execution needs). Report `in-process`, `auto`, or empty as NOT configured for pane-based teams. `auto` is reported as a soft-fail: it silently falls back to `in-process` when no pane backend is reachable, so we prefer an explicit `tmux`.

### 3.3 1M Context env vars

Grep shell config for `ANTHROPIC_DEFAULT_OPUS_MODEL` and `ANTHROPIC_DEFAULT_SONNET_MODEL`, and read the value each one currently pins.

**Canonical pins** (single source of truth — keep in sync with §5.3):

| Var | Canonical value |
|-----|-----------------|
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | `claude-opus-5[1m]` |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | `claude-sonnet-5[1m]` |

Classify **each** var independently into one of three states:
- **current** — the export line exists and its value exactly matches the canonical pin.
- **outdated** — the export line exists but pins a different/older model or lacks the `[1m]` suffix (e.g. an existing `claude-sonnet-4-6[1m]` while canonical is `claude-sonnet-5[1m]`). Soft-fail: §5.3 upgrades it in place.
- **missing** — no export line at all.

PASS only if **both** vars are **current**. Report `outdated` distinctly from `missing` so the user sees "will upgrade" rather than "will add" — this is what lets a re-run pick up a model bump instead of silently leaving an old pin in place.

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

PASS if `allow-passthrough on` is found. This lets the classic renderer's DEC 2026 synchronized-output (BSU/ESU) sequences through to batch screen draws, and enables Shift+Enter newlines. Without it, the classic renderer tears badly during streaming output (4,000–6,700 scroll events/sec). Note: the **fullscreen renderer** (§3.13) is the primary tearing fix and doesn't depend on this — these tmux.conf settings remain as classic-renderer fallback and to support fullscreen's mouse/clipboard/extended-key features.

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

### 3.7 Session Hooks + Limit Sentinel

Check if session tracking hooks, the StopFailure hook, and the limit sentinel are configured:

```bash
[ -L ~/.claude/ultra/lib.sh ] && echo "lib exists" || echo "lib missing"
[ -L ~/.claude/ultra/usage-monitor.sh ] && echo "usage-monitor exists" || echo "usage-monitor missing"
[ -L ~/.claude/ultra/limit-sentinel.sh ] && echo "sentinel exists" || echo "sentinel missing"
[ -L ~/.claude/ultra/hooks/session-start.sh ] && echo "start exists" || echo "start missing"
[ -L ~/.claude/ultra/hooks/session-end.sh ] && echo "end exists" || echo "end missing"
[ -L ~/.claude/ultra/hooks/stop-failure.sh ] && echo "stop-failure exists" || echo "stop-failure missing"
jq -r '.hooks.SessionStart // empty' ~/.claude/settings.json 2>/dev/null
jq -r '.hooks.SessionEnd // empty' ~/.claude/settings.json 2>/dev/null
jq -r '.hooks.StopFailure // empty' ~/.claude/settings.json 2>/dev/null
bash ~/.claude/ultra/limit-sentinel.sh status 2>/dev/null | jq -r '.running' 2>/dev/null
```

PASS if:
- All symlinks exist (`lib.sh`, `usage-monitor.sh`, `limit-sentinel.sh`, `hooks/session-start.sh`, `hooks/session-end.sh`, `hooks/stop-failure.sh`)
- `~/.claude/settings.json` has `hooks.SessionStart`, `hooks.SessionEnd`, and `hooks.StopFailure` entries
- `limit-sentinel.sh status` reports `running: true`

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

Record status but don't mark as MISSING — this is optional. The `machine-context` skill holds per-machine values (VM/host topology, dev runtimes, network conventions, warnings) that other Ultra Claude skills read at runtime. Consuming skills fall back to pure runtime detection when it's absent, so the skill is not strictly required, but populating it makes future diagnostics and workflows more targeted.

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

### 3.13 Fullscreen Renderer (recommended, version-gated)

Claude Code's fullscreen renderer draws the UI on the terminal's alternate screen buffer (like `vim`/`htop`), rendering only visible content instead of repainting the whole conversation into scrollback on every update. This eliminates screen tearing/flicker, keeps memory flat on long sessions, stops scroll-position jumping, and adds mouse support. It is the **primary** fix for the tearing this skill otherwise mitigates via tmux.conf — the docs recommend it specifically for tmux / VS Code / SSH setups, where tmux's lack of synchronized-output support makes the classic renderer flicker.

It is configured persistently via the `tui` key in `~/.claude/settings.json` (`"fullscreen"` or `"default"`). Requires Claude Code **v2.1.89+**.

Detect the installed version and the current setting:

```bash
CLAUDE_VERSION=$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
TUI_SETTING=$(jq -r '.tui // empty' ~/.claude/settings.json 2>/dev/null)
# Version gate: PASS the gate if installed >= 2.1.89
REQUIRED="2.1.89"
if [ -n "$CLAUDE_VERSION" ] && [ "$(printf '%s\n' "$REQUIRED" "$CLAUDE_VERSION" | sort -V | head -1)" = "$REQUIRED" ]; then
  echo "version: ok ($CLAUDE_VERSION)"
else
  echo "version: too-old (${CLAUDE_VERSION:-unknown})"
fi
echo "tui: ${TUI_SETTING:-default}"
```

Treat as:

- **PASS** — `tui` is `"fullscreen"`.
- **OPT-OUT AVAILABLE** — version gate passes and `tui` is unset or `"default"`. This is **recommended-on**: surface it in Step 4 and present the enable/keep-classic prompt in Step 5.13 (enable is the recommended choice).
- **SKIP** — `claude --version` is below 2.1.89 or unavailable. Note "needs Claude Code v2.1.89+" and move on; never mark MISSING.

### 3.14 VS Code Client Settings (optional)

Recommended client-side VS Code settings (window behavior, Claude Code extension placement) for users who edit through VS Code. Full reference: `references/vscode-settings.md`. VS Code is never required — this check exists only to offer the settings when VS Code is present.

Detect VS Code and any prior choice:

```bash
[ -d "$HOME/.vscode-server" ] && echo "vscode-remote" || { [ -d "$HOME/.vscode" ] && echo "vscode-local"; } || echo "no-vscode"
jq -r '.checks.vscodeSettings // empty' ~/.claude/ultra/uc-setup.json 2>/dev/null
```

Treat as:

- **SKIP** — no VS Code installation detected. Skip silently; never mark MISSING.
- **PASS** — marker records `vscodeSettings: "applied"` or `"declined"` (the user already made a choice; don't nag on re-runs).
- **OPT-IN AVAILABLE** — VS Code detected and no recorded choice.

## Step 4: Present Status

Display a status table:

```
Ultra Claude Environment Check (plugin v{version})

  tmux mode                 ✓ per-project (recommended)   # or "— none (no tmux)" / "— custom (user-managed)" / "✓ per-terminal (legacy)" / "✗ not configured"
  tmux.conf                 ✓ passthrough enabled          # or "— skipped" if mode is none/custom
  Agent teams env var       ✗ missing
  1M context env vars       ✗ missing                       # or "✓ current" / "⤴ outdated → will upgrade to claude-opus-5[1m]"
  Node.js                   ✓ v22.0.0
  Statusline                ✗ not configured
  Session Hooks             ✗ not configured
  Tailscale (optional)      — not installed
  Agent (optional)          — not installed   # or "✓ 0.0.26 (latest)" / "✗ 0.0.25 → 0.0.26"
  Machine Context (optional) — not configured
  Dashboard (optional)       — skipped       # or "✓ connected" / "✗ not connected" / "— skipped (agent not installed)"
  Fullscreen renderer        ✗ classic (recommended: fullscreen)  # or "✓ fullscreen" / "— skipped (needs Claude Code v2.1.89+)"
  VS Code settings (optional) — available     # or "✓ applied" / "— declined" / "— skipped (no VS Code)"
```

If ALL required checks pass (3.2–3.7 — tmux mode is always valid since all four choices are acceptable):
- **First**, if the fullscreen renderer is OPT-OUT AVAILABLE (3.13) and the marker has no recorded `fullscreen` choice yet, run the Step 5.13 prompt — it's recommended and shouldn't be skipped just because everything else is green.
- Write the marker file (Step 6)
- Print "Environment ready! All prerequisites configured."
- If Tailscale is not set up, mention: "Optional: Run `/uc:tailscale-setup` to enable remote access."
- Stop here.

## Step 5: Fix Missing Prerequisites

If tmux mode is not yet configured (no `tmuxMode` in marker file), present the tmux mode selection prompt from `references/tmux-modes.md` Section "Selection Prompt" FIRST, before the multi-select fix list. The mode choice determines which tmux-related fixes appear.

Then use AskUserQuestion with a multi-select to let the user choose which items to fix. List only MISSING items. Always include Tailscale if not installed (marked as optional in the description). Include VS Code client settings only if check 3.14 reported OPT-IN AVAILABLE (marked as optional: "recommended editor + Claude Code extension settings").

The fullscreen renderer (5.13) is **not** part of this multi-select — because it's recommended-on (opt-out), present it as its own dedicated question per 5.13 whenever check 3.13 reported OPT-OUT AVAILABLE.

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

### 5.2b Fix: Teammate execution mode (tmux panes)

Run when §3.2b did not report `tmux`. This is the setting that makes plan-execution spawn real tmux team members instead of silent in-process ones.

1. **Ask the user** (default/recommended **tmux**), tying the choice to their tmux mode from §3.1 / Step 5:
   - **tmux (recommended)** — teammates spawn as panes; a missing pane backend fails loudly (`no_backend_available`) instead of silently degrading. Requires launching Claude inside a tmux session.
   - **in-process** — teammates run inside the Lead with no panes. Honest choice only if the user's `tmuxMode` is `none` and they don't want pane-based teams; warn that `/uc:plan-execution` will refuse to run in this mode (it requires tmux teammates).
   - Avoid recommending **auto** — it silently falls back to in-process when no pane backend is present, which is exactly the failure we're fixing.
   - If the user's stored `tmuxMode` is `none`, surface that tmux teammates need an actual tmux session and let them decide knowingly.

2. **Merge `teammateMode` into `~/.claude/settings.json`** preserving all other keys (same jq-merge pattern as statusLine/tui):

```bash
settings_file="$HOME/.claude/settings.json"
mode="tmux"   # or the user's chosen value
if [ -f "$settings_file" ]; then
  jq --arg m "$mode" '.teammateMode = $m' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
else
  printf '{"teammateMode":"%s"}\n' "$mode" > "$settings_file"
fi
```

Tell the user: "Teammate mode set to `tmux` — takes effect on your **next Claude Code launch** (it's read at session start, not live). Relaunch inside a tmux session before running `/uc:plan-execution`."

### 5.3 Fix: 1M Context env vars

Act on the state each var was classified into in §3.3. Handle the two vars **independently** — a machine can have a current Opus pin but an outdated Sonnet one.

**missing** → append the canonical export line(s) to the shell config (append only the var(s) actually missing — don't duplicate one that's already present):

```bash
# Ultra Claude: enable 1M context window for all opus/sonnet usage (including subagents)
export ANTHROPIC_DEFAULT_OPUS_MODEL='claude-opus-5[1m]'
export ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-5[1m]'
```

**outdated** → rewrite the existing line **in place** to the canonical value. This is the path that upgrades an already-set-up machine across a model bump (e.g. Opus 4.8 → Opus 5) — a bare append would create a duplicate export and the last one wins unpredictably, so you MUST edit in place. Back up first, replace the whole `export VAR=…` line, then print the before→after so the change is visible (`$SHELL_CONFIG` = the file detected in Step 2, `~/.bashrc` or `~/.zshrc`):

```bash
config="$SHELL_CONFIG"
# Opus — repeat the same substitution for ANTHROPIC_DEFAULT_SONNET_MODEL if it too is outdated:
sed -i.uc-bak -E "s|^([[:space:]]*export[[:space:]]+ANTHROPIC_DEFAULT_OPUS_MODEL=).*|\1'claude-opus-5[1m]'|" "$config"
```

- Upgrading an Ultra-Claude-written default (any `claude-{opus,sonnet,haiku}-…[1m]` Anthropic pin) is the expected non-destructive path — just do it and report before→after; no need to ask.
- **Only** if the existing value is an unexpected custom pin (NOT a `claude-…[1m]` Anthropic model — i.e. the user appears to have deliberately chosen something else) do you warn and ask before overwriting.

**current** → nothing to do.

After any change, remind the user the new pins take effect on the **next shell / Claude Code launch** (env vars are read at process start, not live).

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
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/usage-monitor.sh" ~/.claude/ultra/usage-monitor.sh
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/limit-sentinel.sh" ~/.claude/ultra/limit-sentinel.sh
```

`usage-monitor.sh` and `limit-sentinel.sh` are symlinked here so plan-execution, the hooks, and the sentinel itself can be invoked via stable absolute paths (`~/.claude/ultra/<name>.sh`) that do not depend on `$CLAUDE_PLUGIN_ROOT` being present in the Bash shell.

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
ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/hooks/stop-failure.sh" ~/.claude/ultra/hooks/stop-failure.sh
```

2. **Configure hooks in settings.json** — add `SessionStart`, `SessionEnd`, and `StopFailure` hooks:

```bash
settings_file="$HOME/.claude/settings.json"
jq '
  .hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/ultra/hooks/session-start.sh"}]}] |
  .hooks.SessionEnd = [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/ultra/hooks/session-end.sh"}]}] |
  .hooks.StopFailure = [{"matcher": "rate_limit", "hooks": [{"type": "command", "command": "bash ~/.claude/ultra/hooks/stop-failure.sh", "timeout": 5}]}]
' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
```

Use `jq` to merge into existing settings without overwriting other top-level keys. The `SessionStart`, `SessionEnd`, and `StopFailure` arrays are fully managed by Ultra Claude (replace, not append). The StopFailure hook is the limit sentinel's detection channel: it fires when a turn dies on a rate-limit error and spools an event the sentinel consumes to schedule the post-reset wake.

Tell the user: "Session hooks configured — each Claude Code session will now be tracked with its account identity, and limit hits are detected for automatic post-reset resume."

3. **Clear legacy usage data** — the usage-status.json format changed from email-keyed to account_id-keyed. Remove the old file so it gets recreated cleanly:

```bash
rm -f ~/.claude/ultra/usage-status.json
```

**Important:** Always re-create the symlinks during setup. The hook scripts source `~/.claude/ultra/lib.sh` which must be symlinked first (done in 5.6).

### 5.7b Fix: Limit Sentinel

The limit sentinel (`scripts/limit-sentinel.sh`) is ONE global background process per machine
that handles usage limits reactively: it consumes the StopFailure hook's events, wakes parked
sessions when their window resets, injects 90% soft-band advisories into plan-execution Lead
panes, keeps a 5h window open continuously for mapped accounts via a heartbeat (one tiny headless
prompt every `UC_PREOPEN_INTERVAL`, default 30 min), and notifies on weekly-limit parks. It is a
process, not an agent — plan-execution agents never monitor usage themselves.

1. **Initialize and start it** (the symlink was created in 5.6):

```bash
mkdir -p ~/.claude/ultra/sentinel
bash ~/.claude/ultra/limit-sentinel.sh ensure
sleep 1
bash ~/.claude/ultra/limit-sentinel.sh status
```

PASS when `status` reports `running: true`. The sentinel is self-healing after this: the
SessionStart hook re-runs `ensure` on every new session (lazy reboot survival), and the
StopFailure hook re-runs it the moment a limit hit is detected.

2. **Machine-context topic (optional but recommended)** — the sentinel reads
`~/.claude/skills/machine-context/limit-sentinel.md` for machine-specific values, with runtime
detection as fallback (see the machine-context interview, `references/machine-context-interview.md`):

```markdown
map: <account-slug> = <profile-dir or "default">   # account → CLAUDE_CONFIG_DIR for window pre-open
notify: <shell command>                             # gets the message as $1 (weekly-limit alerts)
standalone-wake: on                                 # wake non-plan sessions after reset (default on)
```

Tell the user: "Limit sentinel running — sessions that hit a usage limit will resume
automatically when the window resets. No usage questions will be asked at plan start."

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

If the user selected Machine Context, run the interview-driven scaffolding procedure defined in `references/machine-context-interview.md`. The procedure creates `~/.claude/skills/machine-context/SKILL.md` plus topic files (`environment.md`, `claude-profiles.md`, `development.md`, `network.md`, `limit-sentinel.md`, `warnings.md`). Each topic file is populated from targeted questions with sensible defaults from runtime detection.

**Detection-first defaults** the interview uses without asking the user:
- OS from `/etc/os-release` (Linux) or `uname -s` (macOS/others)
- Username from `whoami`, home from `$HOME`
- Shell from `$SHELL`
- Node version from `node -v 2>/dev/null`
- Python version from `python3 --version 2>/dev/null`
- Active Claude profile from `cat ~/.claude-profiles/.active 2>/dev/null`
- Available profiles from `ls -1 ~/.claude-profiles/ 2>/dev/null | grep -v '^\.'`
- Plugin-dir entries from `~/.claude/plugin-dirs.txt`

**Rerun-safe behavior**: if `~/.claude/skills/machine-context/` already exists, ask whether to skip, update specific topic files, or regenerate from scratch. **Never clobber user-written content** without an explicit confirmation.

See `references/machine-context-interview.md` for the full question set and file templates.

### 5.12 Fix: Dashboard

Skip if the agent is not installed (Step 3.9 must report the agent on `PATH`). Skip if Step 3.12 already reported PASS.

If the agent is installed but not connected to the dashboard:

Tell the user: "Run `/uc:dashboard` to connect to the Ultra Claude Dashboard and verify agent connectivity."

This fix delegates to the dashboard skill which handles the full setup and debug flow. `/uc:setup` does not duplicate the dashboard connection logic.

### 5.13 Fix: Fullscreen Renderer (recommended, opt-out)

Skip entirely if check 3.13 reported SKIP (Claude Code below v2.1.89). Skip if 3.13 reported PASS (already `"fullscreen"`) unless the user explicitly asks to turn it off.

This is **opt-out**: fullscreen is recommended, but the user must make a deliberate choice because it changes terminal behavior. Present the choice with `AskUserQuestion`, enable listed first:

```
AskUserQuestion({
  questions: [{
    question: "Claude Code's fullscreen renderer draws on the alternate screen (like vim/htop) — it eliminates screen tearing, keeps memory flat on long sessions, and adds mouse support. The tradeoff: the conversation no longer lives in native terminal scrollback, so your terminal's own search (Cmd/Ctrl+F) and tmux copy-mode won't see it. Enable it?",
    header: "Fullscreen renderer",
    multiSelect: false,
    options: [
      {
        label: "Enable fullscreen (Recommended)",
        description: "Flicker-free, flat memory, mouse support. Best for tmux / VS Code / SSH. Search the conversation with Ctrl+o then / (or [ to dump it to native scrollback). Turn off anytime with /tui default."
      },
      {
        label: "Keep classic renderer",
        description: "Conversation stays in native scrollback so Cmd/Ctrl+F and tmux copy-mode work directly. tmux.conf tearing mitigations still apply. You can enable fullscreen later with /tui fullscreen."
      }
    ]
  }]
})
```

If the user chose **Enable fullscreen**, merge `tui: "fullscreen"` into `~/.claude/settings.json` (preserving all other keys):

```bash
settings_file="$HOME/.claude/settings.json"
if [ -f "$settings_file" ]; then
  jq '.tui = "fullscreen"' "$settings_file" > "${settings_file}.tmp" && mv "${settings_file}.tmp" "$settings_file"
else
  echo '{"tui":"fullscreen"}' > "$settings_file"
fi
```

Tell the user: "Fullscreen renderer enabled — it takes effect on your next Claude Code launch (or run `/tui fullscreen` now to switch this session). Disable anytime with `/tui default`. Search the conversation with `Ctrl+o` then `/`."

If the user chose **Keep classic renderer**, do not write the `tui` key. Record the opt-out in the marker so re-runs don't nag.

Record the user's choice in the Step 6 marker `fullscreen` field (`"fullscreen"`, `"classic"`, or `"unsupported"`).

### 5.14 Fix: VS Code Client Settings (opt-in)

Only runs when the user selected it in the Step 5 multi-select (check 3.14 must have reported OPT-IN AVAILABLE). Follow `references/vscode-settings.md`:

1. Present the recommended client-side settings from the reference (the main table; mention the optional extras without pushing them).
2. Client settings can't be edited from the remote machine — ask the user to paste their current client User Settings JSON if they want a merge, then **print the merged JSON** for them to apply on the client (`Cmd+,` / `Ctrl+,` → Open Settings JSON). If they skip pasting, print the recommended block as-is and remind them to merge manually, not overwrite.
3. Do **not** touch terminal profiles here — those are owned by §5.5b / `references/tmux-modes.md`.
4. Briefly explain each setting as the reference table does, and note that with `claudeCode.useTerminal: true` the fullscreen renderer choice from §5.13 governs rendering.

Record the outcome in the Step 6 marker `vscodeSettings` field: `"applied"` if the user took the settings, `"declined"` if they chose not to, `"skipped"` if VS Code wasn't detected.

## Step 6: Write Marker File

After all fixes are applied, write `~/.claude/ultra/uc-setup.json`:

```json
{
  "version": "{plugin version from plugin.json}",
  "timestamp": "{ISO 8601 timestamp}",
  "shell": "{bash or zsh}",
  "shellConfig": "{path to shell config file}",
  "tmuxMode": "per-project" | "none" | "per-terminal" | "custom",
  "teammateMode": "tmux" | "in-process" | "auto",
  "checks": {
    "tmux": true/false,
    "tmuxConf": true/false,
    "agentTeams": true/false,
    "teammateMode": true/false,
    "context1m": true/false,
    "node": true/false,
    "statusline": true/false,
    "sessionHooks": true/false,
    "tailscale": true/false,
    "agent": "{installed version or null if not installed}",
    "machineContext": true/false,
    "dashboard": "connected" | "not-connected" | "skipped",
    "fullscreen": "fullscreen" | "classic" | "unsupported",
    "vscodeSettings": "applied" | "declined" | "skipped"
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
