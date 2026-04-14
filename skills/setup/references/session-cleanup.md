# Session Cleanup — Tmux Disconnected-Session Reaper

Install, verify, repair, or remove a user-level systemd timer that hourly kills tmux sessions detached from any client for more than 24 hours. Currently-attached sessions are never touched.

**Scope:** Linux + systemd only. On macOS or any other platform this reference is a no-op — the setup check should report "skipped" and move on.

## Tradeoff — read before installing

This reaper solves a specific problem: tmux sessions pile up on a remote machine because VSCode Remote SSH integrated terminals auto-launch tmux, and closing the VSCode window leaves those sessions orphaned and detached forever. After weeks of use you end up with dozens of dead `tmux attach` candidates.

**The cost:** any tmux session you detach and leave alone for more than 24 hours (including Ctrl-b d on purpose to "come back tomorrow") will be killed. That means:

- Background shell work in detached sessions (long-running builds, interactive REPLs, scratch work, `claude` sessions left running) will be terminated on the next reaper tick after the 24h mark.
- Scrollback buffers for those sessions are lost.
- Anything relying on the session staying alive across multi-day gaps — e.g. "I'll resume this workflow on Monday" — will not survive.

If you deliberately rely on long-lived detached tmux sessions to resume work across days, **do not install this**. It is designed for the opposite pattern: short-lived sessions that should have been garbage-collected when the client went away.

The skill must present this tradeoff to the user before asking whether to install.

## Design choices (why not alternatives)

- `destroy-unattached on` in `.tmux.conf` is rejected — that option kills sessions on *any* detach, including manual `Ctrl-b d`, which destroys long-running work immediately instead of after 24h.
- Shell `trap EXIT` hooks are rejected — they don't fire on abrupt SSH disconnects, only on clean shell exits.
- CPU-idle heuristics are rejected — they can't distinguish "user is afk with Claude Code running" from "truly dead session".

Using `session_last_attached` from tmux's format vars gives a precise disconnect timestamp. The reaper script also considers `session_created` as a fallback for sessions that were created detached and never attached (in which case `session_last_attached` is `0`).

## Detection

Three artifacts plus linger state plus the timer's runtime state:

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

For the setup flow's status table this reference returns a single PASS/FAIL/SKIP signal:

- **PASS** — all three files present AND `tmux-reap.timer` is enabled and active AND linger is enabled.
- **SKIP** — not Linux, or systemctl unavailable, or user opted out on a previous setup run.
- **MISSING** — anything else. (Partial installs count as MISSING; the fix path overwrites them atomically.)

## Opt-in prompt

Because this reference is invoked from `/uc:setup`, it **must** present the tradeoff explicitly and ask for confirmation before installing anything. Use `AskUserQuestion` with a body that includes:

```
Tmux Disconnected-Session Reaper — opt-in
=========================================

What it does:
  - Every 1 hour, list all tmux sessions.
  - Skip any session with a client attached (session_attached != 0).
  - For detached sessions, compute age = now - max(last_attached, created).
  - If age > 24h → tmux kill-session -t <name>.
  - Never touches attached sessions regardless of age.
  - Runs as a systemd --user oneshot timer, so it works even when no one
    is logged in (requires `loginctl enable-linger $USER`).

Why you might want it:
  Solves VSCode Remote SSH tmux pile-up — orphaned sessions from closed
  VSCode windows get reaped automatically instead of accumulating forever.

Why you might NOT want it:
  If you rely on long-lived detached tmux sessions to resume work across
  days, this will kill them. Any detached session older than 24h is gone,
  along with its scrollback and any running processes.

  This skill CLEANS UP stale sessions but REMOVES your ability to resume
  any tmux session that has been detached for more than 24 hours. If you
  regularly "come back tomorrow" to a detached session, skip this.

Files installed (all under $HOME — nothing touches project directories):
  $HOME/.local/bin/tmux-reap-disconnected.sh
  $HOME/.config/systemd/user/tmux-reap.service
  $HOME/.config/systemd/user/tmux-reap.timer

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

Options depend on current state:

- Nothing installed → `[Install] [Skip]`
- Installed and healthy → `[Reinstall/update] [Remove] [Leave as is]`
- Installed but timer inactive or linger off → `[Repair] [Remove] [Leave as is]`

`[Skip]` and `[Leave as is]` should both result in no changes and no error.

## Install / repair implementation

Only run this step if the user confirmed install/reinstall/repair. Write the three files exactly as below using the `Write` tool (do not `cat <<EOF` via Bash — atomic writes only).

### `$HOME/.local/bin/tmux-reap-disconnected.sh`

Make executable with `chmod +x` after writing.

```bash
#!/usr/bin/env bash
# tmux-reap-disconnected.sh
# Installed by Ultra Claude's /uc:setup session-cleanup reference.
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

### `$HOME/.config/systemd/user/tmux-reap.service`

```ini
[Unit]
Description=Reap tmux sessions detached from any client for more than 24h

[Service]
Type=oneshot
ExecStart=%h/.local/bin/tmux-reap-disconnected.sh
```

### `$HOME/.config/systemd/user/tmux-reap.timer`

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

### Enable

```bash
mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
chmod +x "$HOME/.local/bin/tmux-reap-disconnected.sh"
systemctl --user daemon-reload
systemctl --user enable --now tmux-reap.timer
```

### Linger

Only if `loginctl show-user "$USER"` reports `Linger=no`. `loginctl enable-linger` usually requires sudo:

```bash
sudo loginctl enable-linger "$USER"
```

If the user doesn't have passwordless sudo, print the exact command and wait for them to run it — do not silently proceed.

## Verify

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
- The threshold (default 24h, tunable via `TMUX_REAP_THRESHOLD` env var in the service unit)
- Where the three files live

## Remove

Only if the user explicitly picked "Remove":

```bash
systemctl --user disable --now tmux-reap.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/tmux-reap.timer"
rm -f "$HOME/.config/systemd/user/tmux-reap.service"
rm -f "$HOME/.local/bin/tmux-reap-disconnected.sh"
systemctl --user daemon-reload
```

Do **not** disable linger automatically on remove — other user services may rely on it.

## Notes

- All writes land under `$HOME`. Nothing touches project directories.
- Install is idempotent: re-running "Install" over an existing install is equivalent to "Reinstall" — the three files are overwritten, the timer is re-enabled, and linger is re-checked.
- To change the threshold without reinstalling, add `Environment=TMUX_REAP_THRESHOLD=<seconds>` under `[Service]` in `tmux-reap.service` and `systemctl --user daemon-reload`.
- This reference does **not** clean up Ultra Claude session state files under `.claude/ultra/sessions/`. A previous attempt at that was abandoned — the session file schema has no reliable liveness signal and cross-referencing Claude Code transcripts proved unreliable in practice.
