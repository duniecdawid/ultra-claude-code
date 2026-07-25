# Machine Context Interview

Reference for `/uc:setup` Step 5.9 — scaffolding the user's `~/.claude/skills/machine-context/` skill interactively.

## Goal

Create (or update) a user-level skill at `~/.claude/skills/machine-context/` that holds per-machine values other Ultra Claude skills read at runtime. The skill is a collection of topic-scoped markdown files; each file is concrete configuration, not procedural knowledge.

## Before you start — runtime detection

Gather default values without asking the user:

```bash
OS_ID=$(. /etc/os-release 2>/dev/null && echo "$NAME $VERSION" || uname -s)
USER_NAME=$(whoami)
HOSTNAME=$(hostname)
HOME_DIR=$HOME
SHELL_NAME=$(basename "$SHELL")
BASH_VERSION_STR=$(bash --version 2>/dev/null | head -1 | grep -oE 'version [0-9.]+' | awk '{print $2}')
NODE_VERSION=$(node -v 2>/dev/null)
PYTHON_VERSION=$(python3 --version 2>/dev/null | awk '{print $2}')
GIT_VERSION=$(git --version 2>/dev/null | awk '{print $3}')
TMUX_VERSION=$(tmux -V 2>/dev/null | awk '{print $2}')

ACTIVE_PROFILE=$(cat "$HOME/.claude-profiles/.active" 2>/dev/null)
AVAILABLE_PROFILES=$(ls -1 "$HOME/.claude-profiles/" 2>/dev/null | grep -v '^\.' | tr '\n' ',' | sed 's/,$//')

PLUGIN_DIRS=$(cat "$HOME/.claude/plugin-dirs.txt" 2>/dev/null | grep -v '^#' | grep -v '^$')
```

Most defaults should be accepted without user confirmation. Only prompt when a value genuinely requires judgment (is this machine a VM? is there a "never use localhost" rule?).

## Existing skill — rerun behavior

If `~/.claude/skills/machine-context/SKILL.md` already exists, ask the user:

1. **Skip** — don't touch the skill at all. Useful when the user has hand-edited it and just wants setup to check other prerequisites.
2. **Update specific topic files** — list the topic files (environment, claude-profiles, development, network, limit-sentinel, warnings) and let the user pick which to regenerate. Unpicked files are left untouched.
3. **Regenerate from scratch** — delete all existing topic files and re-run the full interview. Warn the user that hand-written content will be lost. Require a second explicit confirmation.

Default behavior: **skip**. Never clobber without explicit user confirmation.

## Interview questions

### 1. Machine topology

- **Is this a VM, a host, or a standalone machine?**
  - Options: `vm` (Parallels / VMware / Hyper-V), `wsl` (Windows WSL), `standalone` (a plain laptop or desktop), `server` (headless Linux server).
  - If VM or WSL: ask for the host OS (macOS, Windows, Linux) and the VM's reachable IP from the host.
  - Default: inferred from `systemd-detect-virt` if available, otherwise `standalone`.

- **Hostname, primary user, home directory** — use detected defaults without asking.

### 2. Claude Code profile management

- **Is `~/.claude-profiles/` in use?** Check for the directory.
- If yes: list detected profiles, show the active one, ask if the user wants extra context in `claude-profiles.md` (e.g., a note about which account each profile maps to).
- If no: ask if the user wants multi-account profile isolation set up. If yes, point them at the `profiled-claude` pattern (reference: https://github.com/duniecdawid/ClaudeProfileSwitcher or wherever the canonical reference lives at the time). Do NOT install it automatically — that's out of scope for `/uc:setup`.

### 3. Development environment

- **Editor** — VS Code (remote or local) / JetBrains / vim / emacs / other. Ask.
- **Shell** — detected. Confirm.
- **Runtimes** — Node, Python, Go, Rust versions are already detected. Ask only if the user wants to override or add info about version managers (nvm, pyenv, mise, asdf).
- **Claude Code plugin configuration** — auto-populate from `~/.claude/plugin-dirs.txt`. If the file is empty or missing, note that Ultra Claude is loaded from the default marketplace cache (not via `--plugin-dir`) and that `/uc:update` is the update path. If `ultra-claude` is in plugin-dirs, note that `/uc:update` should NOT be run on this machine because the plugin is loaded from a local source clone.

### 4. Network conventions

- **VM-to-host routing** (only if machine topology is `vm` or `wsl`) — ask for the dev server port convention. Typically "dev servers bind `0.0.0.0`, reach them via `{VM_HOST}:PORT`, never `localhost`".
- **Default network reachability** — `localhost` works (standalone), or `localhost` is a host loopback and dev servers need an external IP (VM/WSL with dev servers reachable from host browser).
- **Tailscale** — installed? If yes, capture the tailnet domain and any `tailscale serve` / `funnel` setups.

### 5. Warnings

Start empty. The user accumulates warnings over time as they hit gotchas. The interview doesn't try to populate this file — it creates it with a header and the user extends it later.

### 6. Limit sentinel

Inputs for the machine-global limit sentinel (`~/.claude/ultra/limit-sentinel.sh`). Detection-first:

- **Account → profile map** — scan `~/.claude-profiles/*/.claude.json` and `~/.claude/.claude.json` for `.oauthAccount.emailAddress`, slugify each (lib.sh `slugifyEmail`), and PROPOSE the detected map for confirmation rather than asking cold. The map tells the sentinel which `CLAUDE_CONFIG_DIR` to use when pre-opening a fresh usage window for an account. Default-profile accounts map to the literal word `default`.
- **Notify command** — an optional shell command for weekly-limit alerts (gets the message as `$1`). Examples: a personal push script, `notify-send`, `osascript -e ...`. Skip if the user has none — the sentinel logs instead.
- **Standalone wake** — should non-plan Claude sessions parked at a limit be auto-woken at reset? Default `on`; the cautious answer is `off` (only plan-execution fleets get woken).

## File templates

Each topic file gets a consistent structure. Below are the skeletons the interview should write.

### `SKILL.md`

```markdown
---
name: machine-context
description: >
  Machine-local context describing this specific machine's setup — OS, VM/host topology,
  Claude Code profile management, development environment, network conventions, and
  accumulated warnings. Other skills
  read the topic files in this directory at runtime for per-machine values.
  Triggers on questions about this machine's environment.
---

# Machine Context

This skill describes **this specific machine** — the one you're running on right now. Other skills read the topic files for concrete per-machine values.

## Topic files

- [environment.md](environment.md) — OS, hardware, usernames, hostname, VM/host topology
- [claude-profiles.md](claude-profiles.md) — Multi-account Claude Code profile management
- [development.md](development.md) — Shell, editor, runtimes, Claude Code plugin configuration
- [network.md](network.md) — VM IPs, port conventions, reachability rules
- [limit-sentinel.md](limit-sentinel.md) — Account→profile map, notify command, standalone-wake toggle for the limit sentinel
- [warnings.md](warnings.md) — Machine-specific gotchas and hard-learned lessons

## How other skills use this

Lazy read with runtime fallback:

1. Check if the relevant `{topic}.md` file exists
2. If yes: read it, use its values
3. If no: fall back to `$HOME`, `whoami`, `jq`-based runtime detection

Files are the API. `/machine-context` invocation is optional.
```

### `environment.md`

```markdown
# Environment

| Detail | Value |
|--------|-------|
| Hostname | {HOSTNAME} |
| OS | {OS_ID} |
| User | {USER_NAME} |
| Home | {HOME_DIR} |
| Shell | {SHELL_NAME} {BASH_VERSION_STR or equivalent} |
| Topology | {vm/wsl/standalone/server} |

{if VM or WSL}
## Host relationship

Host OS: {asked}
Reachable VM IP from host: {asked}
{endif}
```

### `limit-sentinel.md`

Grep-able line format — the sentinel parses these lines directly (files are the API):

```markdown
# Limit Sentinel

map: {account-slug} = {profile-dir or default}
map: {account-slug-2} = {profile-dir-2}
notify: {shell command receiving the message as $1}
standalone-wake: on
```

Omit `notify:` if the user has no notify command. Omit `map:` lines that could not be confirmed —
the sentinel falls back to runtime profile detection and skips pre-open for unmapped accounts.

### `claude-profiles.md`

```markdown
# Claude Code Profile Management

{if ~/.claude-profiles/ detected}
Active profile: **{ACTIVE_PROFILE}**
Available: {AVAILABLE_PROFILES}

Managed via `profiled-claude`. See {canonical reference URL or path} for full details.
{else}
Profile management not configured on this machine. Single-account Claude Code setup.
{endif}
```

### `development.md`

```markdown
# Development Environment

| Tool | Version |
|------|---------|
| {shell} | {version} |
| Node.js | {NODE_VERSION} |
| Python | {PYTHON_VERSION} |
| Git | {GIT_VERSION} |
| tmux | {TMUX_VERSION} |

## Editor
{asked}

## Claude Code plugin configuration
{from PLUGIN_DIRS — if ultra-claude is in plugin-dirs, note that /uc:update should NOT be run on this machine}
```

### `network.md`

```markdown
# Network

{if VM/WSL with external reachability rule}
## Dev server port convention

Dev servers must bind `0.0.0.0`, not `localhost`. Reach them from the host browser via `{VM_IP}:{PORT}`.

If connection refused, check binding:
```bash
ss -tlnp | grep :PORT
```
{endif}

{if Tailscale installed}
## Tailscale
Tailnet: {domain}
Known serves/funnels: {list}
{endif}
```

### `warnings.md`

```markdown
# Warnings & Gotchas

Hard-learned lessons and machine-specific pitfalls. Add to this file when you hit a non-obvious failure mode you wish you'd known about before.

{empty initially}
```

## After writing the files

Print a summary:

```
Machine context scaffolded at ~/.claude/skills/machine-context/

  SKILL.md                  created
  environment.md            {N} fields populated
  claude-profiles.md        {populated/empty — no profiles detected}
  development.md            {N} fields populated
  network.md                {populated/empty}
  warnings.md               empty (extend as you hit gotchas)

Edit any of these files directly at any time. Other Ultra Claude skills read them at runtime —
improvements take effect on the next invocation, no rebuild needed.
```

Mark `checks.machineContext = true` in `~/.claude/ultra/uc-setup.json`.
