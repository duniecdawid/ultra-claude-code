# Planning Framework — Stage 1: Understand

Base Stage 1 rules. Modes layer their own questioning style and domain-specific extraction on top via their own `references/stage-1.md`.

**Purpose:** Gather enough context from the user to prepare for research. The active mode drives questions, challenges assumptions, and surfaces edge cases until it has a clear picture of the problem space.

## Tmux Layout (when UC-managed tmux mode is active)

Start the layout daemon and label this pane as the main context. Skipped when `$TMUX_PANE` is unset or tmux mode is `none`/`custom` — agents communicate via signals and SendMessage, not tmux.

```bash
TMUX_MODE=$(jq -r '.tmuxMode // empty' ~/.claude/ultra/uc-setup.json 2>/dev/null)
if [ -n "$TMUX_PANE" ] && [ "$TMUX_MODE" != "none" ] && [ "$TMUX_MODE" != "custom" ]; then
  node "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-daemon.js" --ensure
  tmux set-option -p -t $TMUX_PANE @agent-name "main-context"
  tmux set-option -w pane-border-status top
  tmux set-option -w pane-border-format " #{@agent-name} "
fi
```

## Rules

- No files written.
- No research agents spawned.
- Ask at least 3 questions via AskUserQuestion and receive answers before moving on — even when the user provides a detailed report with clear symptoms, reproduction steps, and a suggested cause. A detailed report makes your questions *better*, not unnecessary. You are probing for what the reporter doesn't know they missed: unstated assumptions, scope boundaries, environmental factors, second-order effects.
- Use AskUserQuestion for every question that needs user input. If the user declines to answer or says "just move on," acknowledge it but still ask your remaining minimum questions — reframe them as shorter yes/no confirmations if needed. You need at least 3 *answered* questions (not just 3 asked) to have confidence in your understanding.
- The active mode decides when it has enough context to move to Stage 2 — no user permission needed for this transition. But "enough context" means you can articulate: (a) the exact scope boundary of what is and isn't being investigated, (b) at least one assumption from the report you verified or challenged, and (c) who/what is affected. If you cannot state all three, you are not ready.

## Stage Transition

When you have gathered sufficient context to direct research effectively, announce:

> **▶ PROCEED TO STAGE 2: RESEARCH**

The active mode's `references/stage-1.md` will instruct you to read its `references/stage-2.md` next. Do not preload it earlier.
