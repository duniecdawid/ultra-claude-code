---
description: >-
  Clean up stale sessions on this machine. Two independent sub-flows, chosen
  at invocation: (a) Ultra Claude session files — walks the filesystem for
  `.claude/ultra/sessions/*.json`, cross-references each session id against
  Claude Code's own transcript jsonl for real liveness, and removes files
  whose `started_at` is older than the threshold AND whose transcript has
  been silent for the same threshold; (b) Tmux disconnected-session reaper
  (Linux/systemd only) — installs a user-level systemd timer that kills
  tmux sessions detached from any client for more than 24 hours, designed
  for VSCode Remote SSH workflows where integrated terminals leave orphaned
  tmux sessions behind. Use when session files accumulate, disk needs
  cleaning, tmux sessions are piling up after closing a VSCode window,
  or after crashes leave orphaned sessions. Triggers on "session cleanup",
  "clean sessions", "stale sessions", "orphaned sessions", "session files",
  "tmux sessions", "tmux reaper", "tmux cleanup".
argument-hint: "(no arguments — interactive, asks which sub-flow to run)"
user-invocable: true
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
  - Write
  - AskUserQuestion
---

# Session Cleanup

Two sub-flows, picked at the start via `AskUserQuestion`:

1. **Ultra Claude session files** — scan all projects for stale `.claude/ultra/sessions/*.json` and delete the ones whose transcripts have been silent past the threshold. Original behavior of this skill.
2. **Tmux disconnected-session reaper** — install/check/remove a user-level systemd timer that kills tmux sessions detached from any client for more than 24 hours. Solves the common "VSCode Remote SSH closes, tmux keeps piling up on the VM" problem.

The two flows share nothing except the name. The user picks one per invocation (or both in sequence).

## Background — session file schema

Ultra Claude session files are written by two hooks and nothing else:

- `SessionStart` hook creates `<cwd>/.claude/ultra/sessions/<session_id>.json` with exactly:
  ```json
  { "account_id": "...", "started_at": "<ISO8601>", "active": true }
  ```
- `SessionEnd` hook (on clean exits only) flips `active` to `false` and adds `ended_at`.

**Important:** the session file is written once at start and optionally once at end. It contains no `pid`, no `last_activity`, no `tmux_pane`, no mid-session heartbeat. The `active` flag is **not** a liveness signal — it is "was started and never got a clean goodbye." Every session killed abruptly (terminal closed, tmux pane killed, crash, VM shutdown) leaves `active: true` forever.

The only reliable liveness signal comes from **outside** the session file: Claude Code's own transcript at `~/.claude/projects/<encoded-cwd>/<session_id>.jsonl` is appended on every turn, so its mtime tracks real activity.

## Process

### Step 0: Pick the sub-flow

Use `AskUserQuestion` to ask which cleanup to run. Options:

- **Ultra session files** — proceed to sub-flow A (Steps 1–7).
- **Tmux reaper** — proceed to sub-flow B (Steps 8–11).
- **Both** — run sub-flow A to completion, then sub-flow B.

If the user picks a flow that includes sub-flow B and `uname -s` is not `Linux` or `command -v systemctl` fails, tell the user the tmux reaper is Linux/systemd-only and skip sub-flow B cleanly. Sub-flow A still runs if they picked "Both".

## Sub-flow A — Ultra session file cleanup

### Step 1: Ask for threshold

Use `AskUserQuestion` to get the cleanup threshold in days. Default is **1 day**. This single value drives both rules — session-start age and transcript silence — so one knob is enough.

### Step 2: Build the transcript index

Before scanning sessions, index Claude Code's transcripts so each session id can be looked up in O(1):

```bash
tidx=$(mktemp)
find "$HOME/.claude/projects" -maxdepth 2 -name '*.jsonl' -type f 2>/dev/null \
  -printf '%f\t%T@\n' \
  | awk -F'\t' '{gsub(/\.jsonl$/,"",$1); print $1"\t"int($2)}' \
  | sort -t$'\t' -k1,1 -k2,2nr \
  | awk -F'\t' '!seen[$1]++' > "$tidx"
```

The result is a tab-separated `session_id\tmtime_epoch` map, with the freshest transcript per id kept when duplicates exist (the same session can appear under multiple encoded-cwd directories on machines with bind mounts).

### Step 3: Walk projects for session files

Discover session directories by walking the filesystem directly — **do not** decode `~/.claude/projects/` directory names into paths, because project names with hyphens collide with the dash-as-slash encoding and get dropped silently.

```bash
find "$HOME" -maxdepth 6 -type d -name sessions -path '*/.claude/ultra/sessions' 2>/dev/null
```

Tune `maxdepth` up if some of your projects live deeper than six levels under `$HOME`.

### Step 4: Classify each session file

For every `.json` in each sessions directory:

1. Parse `started_at` from the JSON.
2. Look up the session id in the transcript index → `transcript_mtime` (may be empty).
3. Apply these rules with threshold `T` seconds:

| Case | started_at | Transcript mtime | Action |
|---|---|---|---|
| Young | ≤ T ago | — | **Keep** (session is recent, regardless of transcript) |
| Legacy | missing / unparseable | — | Check transcript — kill unless `now - transcript_mtime ≤ T` |
| Old | > T ago | missing or > T ago | **Kill** |
| Old but active | > T ago | ≤ T ago | **Keep** (real recent activity) |

Write the kill list to a temp file (one absolute path per line) so the subsequent delete step is a simple stream over it.

### Step 5: Present summary via AskUserQuestion

Show counts before deleting:

```
Session Cleanup Plan
====================
Threshold: N day(s)

Total session files found:       N
  Young (started within N days): N  — keep
  Kept due to recent transcript: N  — keep
  Legacy (no started_at):        N  — in kill list
  Old + transcript silent:       N  — in kill list

Kill list total: N

Per project (kill counts):
  <path>  N
  ...
```

Ask the user to confirm, cancel, or adjust the threshold and rerun.

### Step 6: Execute deletion

Stream the kill list into `rm` and track success/failure counts:

```bash
deleted=0; failed=0
while IFS= read -r f; do
  if rm -f "$f" 2>/dev/null; then deleted=$((deleted+1))
  else failed=$((failed+1)); fi
done < "$kill_list"
```

### Step 7: Report

Print the deletion counts, remaining session-file count by project, and note any kept-by-transcript sessions so the user knows which stuck-active files were spared.

## Sub-flow B — Tmux disconnected-session reaper

This sub-flow installs (or updates, or removes) a user-level systemd timer that periodically kills tmux sessions detached from any client for more than 24 hours. Currently-attached sessions are never touched. The threshold and cadence are configured at install time and baked into the units — re-run the skill to change them.

**Scope:** Linux + systemd only. macOS has no systemd; on macOS the sub-flow exits cleanly with a note.

**Design choices** (why not alternatives):
- `destroy-unattached on` in `.tmux.conf` is rejected — that option kills sessions on *any* detach, including manual `Ctrl-b d`, which destroys long-running work.
- Shell `trap EXIT` hooks are rejected — they don't fire on abrupt SSH disconnects, only on clean shell exits.
- CPU-idle heuristics are rejected — they can't distinguish "user is afk with Claude Code running" from "truly dead session".

Using `session_last_attached` from tmux's format vars gives a precise disconnect timestamp. The reaper script also considers `session_created` as a fallback for sessions that were created detached and never attached (in which case `session_last_attached` is `0`).

### Step 8: Detect current install state

Check for three artifacts:

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

Also capture the current tmux session inventory so the user sees what would be affected by the reaper if it were run right now:

```bash
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
  tmux list-sessions -F '#{session_name}|#{session_attached}|#{session_last_attached}|#{session_created}'
fi
```

### Step 9: Describe behavior and ask for confirmation

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

### Step 10: Implement

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

### Step 11: Verify and report

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

- Sub-flow A only removes the Ultra Claude session state files under `.claude/ultra/sessions/`. It never touches Claude Code's own transcripts under `~/.claude/projects/` — those belong to Claude Code, not Ultra Claude.
- Sub-flow A does not kill tmux panes or sessions — that is sub-flow B's job, and it operates by disconnect time, not by any linkage to Ultra Claude session files.
- If you're on a machine where projects live outside `$HOME` (e.g. mounted shared folders), extend the Step 3 `find` root list accordingly — but prefer resolving symlinks so duplicate project views are deduped by realpath.
- Sub-flow B is idempotent: re-running "Install" over an existing install is equivalent to "Reinstall" — the three files are overwritten, the timer is re-enabled, and linger is re-checked. Safe to run as many times as you want.
