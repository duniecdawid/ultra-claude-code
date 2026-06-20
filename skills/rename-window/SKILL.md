---
description: Rename the current tmux window. Use to label a window by what it is working on, or to apply Ultra Claude's standardized `UC::…` window-naming convention by hand. Produces a renamed tmux window that survives shell-prompt redraws (automatic-rename is disabled).
user-invocable: true
argument-hint: "new window name (optional)"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
---

# Rename Window

Rename the current **tmux window**. This is a thin wrapper over the rename primitive
`${CLAUDE_PLUGIN_ROOT}/scripts/tmux-window-name.sh`, which is the same script Ultra Claude's
planning and execution flows use to name their windows automatically. Outside tmux it is a silent
no-op (the script is gated on `$TMUX_PANE`).

## Naming convention

Ultra Claude windows use `::`-delimited names so the tmux status bar shows what each window is doing:

- **`UC::P-NNN::<short name>`** — a window tied to a plan. **This form takes priority** — whenever a
  plan number exists, prefer it over the mode form. `<short name>` is the plan README title.
- **`UC::<Mode>::<subject>`** — a window in a mode with no plan yet, e.g. `UC::Discovery::payments`,
  `UC::Feature::add login`, `UC::Debug::login 500`, `UC::Roadmap::billing`.

The script sanitizes the name (collapses whitespace, keeps `::` unambiguous) and truncates it for the
status bar, so you can pass a natural string.

## Process

1. **If `$ARGUMENTS` is given**, use it verbatim as the window name:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-window-name.sh" "$ARGUMENTS"
   ```

2. **If no argument and a plan is active in this session** (you know the resolved `NNN-name`), build
   the standardized plan form and apply it:

   ```bash
   TITLE=$(sed -n 's/^# Plan: //p' "documentation/plans/<NNN-name>/README.md" | head -1)
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-window-name.sh" "UC::P-<NNN>::${TITLE}"
   ```

3. **If no argument and no context**, ask the user for a short window name (or suggest the
   convention above), then apply it with the script.

After running, briefly confirm the new name to the user. If the script logged a `SKIP` (not inside
tmux), tell the user window renaming only works inside a tmux session.

## Constraints

- Do NOT rename panes or touch the layout — that is the layout daemon's job (`@agent-name` labels).
  This skill only sets the **window** name.
- Do NOT re-implement the rename in inline bash — always call the shared script so behavior (gate,
  sanitize, truncate, automatic-rename off, logging) stays in one place.
