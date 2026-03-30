# Stage 1: Understand

The active planning mode defines this stage. Plan Enhancer does not participate.

**Purpose:** Gather enough context from the user to prepare for research. The mode drives questions, challenges assumptions, and surfaces edge cases until it has a clear picture of the problem space.

## Ultra Dashboard

Ensure the Ultra Dashboard is running at the start of Stage 1 (idempotent — safe if already alive):

```bash
node ${CLAUDE_PLUGIN_ROOT}/scripts/ultra-dashboard/index.js --ensure
tmux set-option -p -t $TMUX_PANE @agent-name "main-context"
tmux set-option -w pane-border-status top
tmux set-option -w pane-border-format " #{@agent-name} "
```

## Rules

- No files written
- No research agents spawned
- Ask at least 3 questions via AskUserQuestion and receive answers before moving on — even when the user provides a detailed report with clear symptoms, reproduction steps, and a suggested cause. A detailed report makes your questions *better*, not unnecessary. You are probing for what the reporter doesn't know they missed: unstated assumptions, scope boundaries, environmental factors, and second-order effects.
- Use AskUserQuestion for every question that needs user input. If the user declines to answer or says "just move on," acknowledge it but still ask your remaining minimum questions — reframe them as shorter yes/no confirmations if needed. You need at least 3 answered questions (not just 3 asked) to have confidence in your understanding.
- AI decides when it has enough context to move to Stage 2 — no user permission needed for this transition. But "enough context" means you can articulate: (a) the exact scope boundary of what is and isn't being investigated, (b) at least one assumption from the report you verified or challenged, and (c) who/what is affected. If you cannot state all three, you are not ready.

## Stage Transition

When the AI has gathered sufficient context to direct research effectively:

> **▶ PROCEED TO STAGE 2: RESEARCH**
