---
description: >-
  Scan and clean stale Ultra Claude session files across all projects on this
  machine. Walks the filesystem for `.claude/ultra/sessions/*.json`, cross-
  references each session id against Claude Code's own transcript jsonl for
  real liveness, and removes files whose `started_at` is older than the
  threshold AND whose transcript has been silent for the same threshold.
  Use when session files accumulate, disk needs cleaning, or after crashes
  leave orphaned sessions. Triggers on "session cleanup", "clean sessions",
  "stale sessions", "orphaned sessions", "session files".
argument-hint: "(no arguments — interactive, asks for threshold)"
user-invocable: true
allowed-tools:
  - Bash
  - Glob
  - Grep
  - Read
  - AskUserQuestion
---

# Session Cleanup

Scan all Ultra Claude projects for stale session files and clean them up after user confirmation.

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

## Notes

- This skill only removes the Ultra Claude session state files under `.claude/ultra/sessions/`. It never touches Claude Code's own transcripts under `~/.claude/projects/` — those belong to Claude Code, not Ultra Claude.
- Tmux-pane killing is **not supported**: the session file schema carries no tmux reference. If you need to clean up dead panes, that is a separate concern.
- If you're on a machine where projects live outside `$HOME` (e.g. mounted shared folders), extend the Step 3 `find` root list accordingly — but prefer resolving symlinks so duplicate project views are deduped by realpath.
