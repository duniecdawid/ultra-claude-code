---
description: >-
  Install, check, repair, or remove a user-level systemd timer that kills
  tmux sessions detached from any client for more than 24 hours. Designed
  for VSCode Remote SSH workflows where integrated terminals auto-launch
  tmux and leave orphaned sessions behind after the VSCode window closes.
  Uses tmux's `session_last_attached` / `session_created` format vars to
  compute disconnect age; never touches currently-attached sessions.
  Linux/systemd only. Use when tmux sessions are piling up on a remote
  machine after VSCode disconnects, or to verify / reinstall / remove an
  existing install. Triggers on "session cleanup", "clean sessions",
  "tmux sessions", "tmux reaper", "tmux cleanup", "orphaned tmux",
  "kill stale tmux", "reap tmux".
argument-hint: "(no arguments — interactive, detects current state and asks to install/repair/remove)"
user-invocable: true
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
---

# Session Cleanup — Tmux Disconnected-Session Reaper

Installs (or updates, or removes) a user-level systemd timer that periodically kills tmux sessions detached from any client for more than 24 hours. Currently-attached sessions are never touched.

**Scope:** Linux + systemd only. On any other platform (e.g. macOS) the skill exits cleanly with a note.

**Design choices** (why not alternatives):
- `destroy-unattached on` in `.tmux.conf` is rejected — that option kills sessions on *any* detach, including manual `Ctrl-b d`, which destroys long-running work.
- Shell `trap EXIT` hooks are rejected — they don't fire on abrupt SSH disconnects, only on clean shell exits.
- CPU-idle heuristics are rejected — they can't distinguish "user is afk with Claude Code running" from "truly dead session".

Using `session_last_attached` from tmux's format vars gives a precise disconnect timestamp. The reaper script also considers `session_created` as a fallback for sessions that were created detached and never attached (in which case `session_last_attached` is `0`).

## Process

### Step 1: Platform gate

```bash
[ "$(uname -s)" = "Linux" ] || { echo "This skill is Linux/systemd-only. Skipping."; exit 0; }
command -v systemctl >/dev/null 2>&1 || { echo "systemctl not found. Skipping."; exit 0; }
```

### Step 2: Detect current install state

Check for three artifacts and report:

```bash
REAPER_BIN="$HOME/.local/bin/tmux-reap-disconnected.sh"
SERVICE_UNIT="$HOME/.config/systemd/user/tmux-reap.service"
TIMER_UNIT="$HOME/.config/systemd/user/tmux-reap.timer"

reaper_installed=false
timer_enabled=false
timer_active=false
linger_enabled=false

[ -f "$REAPER_BIN" ] && [ -f "$SERVICE_UNIT" ] && [ -f "$TIMER_UNIT" ] && reaper_installed=true
systemctl --user is-enabled tmux-reap.timer >/dev/null 2>&1 && timer_enabled=true
systemctl --user is-active  tmux-reap.timer >/dev/null 2>&1 && timer_active=true
loginctl show-user "$USER" 2>/dev/null | grep -q '^Linger=yes' && linger_enabled=true
```

Also capture the current tmux session inventory so the user sees what would be affected by the reaper if it ran right now:

```bash
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
  tmux list-sessions -F '#{session_name}|#{session_attached}|#{session_last_attached}|#{session_created}'
fi
```

### Step 3: Describe behavior and ask for confirmation

Present this to the user (concrete, no hand-waving):

```
Tmux Disconnected-Session Reaper
================================

Proposed behavior:
  - Every 1 hour, list all tmux sessions.
  - Skip any session that currently has a client attached (session_attached != 0).
  - For detached sessions, compute age = now - max(last_attached, created).
    (last_attached is 0 for sessions created detached; created is used as the fallback.)
  - If age > 24h → tmux kill-session -t <name>.
  - Never touches attached sessions regardless of age.
  - Runs as a systemd --user oneshot timer, so it works even when no one is
    logged in (requires `loginctl enable-linger $USER` — enabled as part of
    install; needs sudo once).

Files installed:
  $HOME/.local/bin/tmux-reap-disconnected.sh          (the reaper script)
  $HOME/.config/systemd/user/tmux-reap.service        (systemd oneshot unit)
  $HOME/.config/systemd/user/tmux-reap.timer          (hourly trigger)

Current state on this machine:
  Reaper script installed:  <yes/no>
  Timer enabled:            <yes/no>
  Timer active:             <yes/no>
  User lingering enabled:   <yes/no>

Tmux sessions that currently exist:
  <rendered from the list-sessions output — name, attached?, age>

Sessions that would be killed if the reaper ran right now:
  <subset of the above with attached=0 and age > 24h>
```

Then `AskUserQuestion` with options appropriate to current state:

- If nothing installed: `[Install] [Cancel]`
- If installed and healthy: `[Reinstall/update] [Remove] [Leave as is]`
- If installed but timer inactive or linger off: `[Repair] [Remove] [Leave as is]`

### Step 4: Implement

Only run this step if the user confirmed install/reinstall/repair. Write the three files exactly as below (use the `Write` tool so the files land atomically; do not `cat <<EOF` via Bash).

**`$HOME/.local/bin/tmux-reap-disconnected.sh`** — make executable with `chmod +x` after writing:

```bash
#!/usr/bin/env bash
# tmux-reap-disconnected.sh
# Installed by Ultra Claude's session-cleanup skill.
# Kills tmux sessions that have been detached from any client for more than
# THRESHOLD_SECONDS. Never touches attached sessions. Safe to run on any cadence.

set -euo pipefail

THRESHOLD_SECONDS="${TMUX_REAP_THRESHOLD:-86400}"   # 24h default

command -v tmux >/dev/null 2>&1 || exit 0
tmux list-sessions >/dev/null 2>&1 || exit 0

now=$(date +%s)

tmux list-sessions -F '#{session_name}|#{session_attached}|#{session_last_attached}|#{session_created}' 2>/dev/null \
| while IFS='|' read -r name attached last_attached created; do
    [ -z "$name" ] && continue
    [ "$attached" != "0" ] && continue

    if [ -z "$last_attached" ] || [ "$last_attached" = "0" ]; then
        ref="$created"
    elif [ "$last_attached" -gt "$created" ]; then
        ref="$last_attached"
    else
        ref="$created"
    fi

    age=$((now - ref))
    if [ "$age" -gt "$THRESHOLD_SECONDS" ]; then
        printf 'tmux-reap: killing session %s (idle %ds)\n' "$name" "$age"
        tmux kill-session -t "$name" || true
    fi
done
```

**`$HOME/.config/systemd/user/tmux-reap.service`**:

```ini
[Unit]
Description=Reap tmux sessions detached from any client for more than 24h

[Service]
Type=oneshot
ExecStart=%h/.local/bin/tmux-reap-disconnected.sh
```

**`$HOME/.config/systemd/user/tmux-reap.timer`**:

```ini
[Unit]
Description=Run tmux disconnected-session reaper hourly

[Timer]
OnBootSec=10min
OnUnitActiveSec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

Then run:

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
chmod +x "$HOME/.local/bin/tmux-reap-disconnected.sh"
systemctl --user daemon-reload
systemctl --user enable --now tmux-reap.timer
```

**Linger** (only if `loginctl show-user "$USER"` reports `Linger=no`): `loginctl enable-linger` usually requires sudo. Run:

```bash
sudo loginctl enable-linger "$USER"
```

If the user doesn't have passwordless sudo, tell them exactly what to paste and wait for them to run it — do not silently proceed.

### Step 5: Verify and report

After install, verify:

```bash
systemctl --user is-enabled tmux-reap.timer
systemctl --user is-active  tmux-reap.timer
systemctl --user list-timers tmux-reap.timer --no-pager
loginctl show-user "$USER" | grep '^Linger='
```

Report to the user:
- Whether timer is enabled + active
- Next scheduled run (from `list-timers`)
- Whether linger is now on
- The threshold (default 24h, via `TMUX_REAP_THRESHOLD` env var in the service unit if the user later wants to tune it without reinstalling)
- Where the three files live

**Remove path** (only if user picked "Remove"):

```bash
systemctl --user disable --now tmux-reap.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/tmux-reap.timer"
rm -f "$HOME/.config/systemd/user/tmux-reap.service"
rm -f "$HOME/.local/bin/tmux-reap-disconnected.sh"
systemctl --user daemon-reload
```

Do **not** disable linger automatically on remove — other user services may rely on it.

## Notes

- This skill installs machine-local systemd units under `$HOME` — nothing is written into any project directory.
- The skill is idempotent: re-running "Install" over an existing install is equivalent to "Reinstall" — the three files are overwritten, the timer is re-enabled, and linger is re-checked. Safe to run as many times as you want.
- To change the threshold without reinstalling, add `Environment=TMUX_REAP_THRESHOLD=<seconds>` under `[Service]` in `tmux-reap.service` and `systemctl --user daemon-reload`.
- This skill does **not** clean up Ultra Claude session state files under `.claude/ultra/sessions/`. An earlier version of this skill attempted that, but the approach was abandoned — the session file schema has no reliable liveness signal and cross-referencing Claude Code transcripts proved unreliable in practice.
