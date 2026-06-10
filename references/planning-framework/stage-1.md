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

- No files written until the **Scaffold Skeleton** step below (the final action of this stage). Everything before it — questions, challenges, scope shaping — stays in conversation context.
- No research agents spawned.
- Ask at least 3 questions via AskUserQuestion and receive answers before moving on — even when the user provides a detailed report with clear symptoms, reproduction steps, and a suggested cause. A detailed report makes your questions *better*, not unnecessary. You are probing for what the reporter doesn't know they missed: unstated assumptions, scope boundaries, environmental factors, second-order effects.
- Use AskUserQuestion for every question that needs user input. If the user declines to answer or says "just move on," acknowledge it but still ask your remaining minimum questions — reframe them as shorter yes/no confirmations if needed. You need at least 3 *answered* questions (not just 3 asked) to have confidence in your understanding.
- The active mode decides when it has enough context to move to Stage 2 — no user permission needed for this transition. But "enough context" means you can articulate: (a) the exact scope boundary of what is and isn't being investigated, (b) at least one assumption from the report you verified or challenged, and (c) who/what is affected. If you cannot state all three, you are not ready.

## Scaffold Skeleton

This is the **final action of Stage 1**, performed once you can articulate the scope boundary (the prerequisite for the transition below). It makes the plan visible on the dashboard from the moment its scope is settled, instead of only at the end of planning. This is the one write permitted before Stage 4 (see `framework.md` Constraints).

1. **Existing plan first.** Apply `framework.md` Existing Plan Handling. If a directory matching `*-{name}` already exists, **adopt or resurrect it** — do NOT allocate a new number or re-create the directory. Handle per existing `plan.json` `status`:
   - **`planning`** (an interrupted/resumed self-scaffolded skeleton): adopt as-is — `status` and `stage` are already correct.
   - **`stub`** (a `/uc:roadmap` stub): upgrade in place — set `plan.json` `"status"` → `"planning"` and `"stage"` → `"research"`. No user announcement (this upgrade is expected, unlike a cancelled resurrect). The roadmap stub's README Objective/Scope are already filled, so no skeleton README write is needed.
   - **`cancelled`**: resurrect per `framework.md` (announce, reset `status` → `planning`/`stage` → `research`, README `Cancelled` → `Stub`).

   Once the adopted `plan.json` reads `status: planning`, `stage: research`, skip to the Stage Transition.

2. **Allocate the number** (only when no matching directory exists). Scan `documentation/plans/` for directories matching `[0-9][0-9][0-9]-*`, take the highest, increment by 1, and **always zero-pad to 3 digits** (`001`, `012`, …). If none exist, start at `001`. Derive a short hyphenated `{name}` from the feature/problem (2–4 words, no special characters).

3. **Create the directory:**

   ```bash
   mkdir -p documentation/plans/{NNN}-{name}/{shared,tasks}
   ```

4. **Write the stub README** to `documentation/plans/{NNN}-{name}/README.md` from `${CLAUDE_PLUGIN_ROOT}/templates/plan.md`:
   - `Status: Stub`, `Source: {active mode name}` (e.g. `Feature Mode`), and the `Execute: /uc:plan-execution {NNN}` header.
   - **Fill** the Objective and Scope (In/Out) sections from your Stage 1 understanding — this is the settled scope boundary.
   - Leave every other section — Context, Tech Stack, Success Criteria, Task List, Documentation Changes, Risk Assessment — as a literal `<!-- STUB -->` placeholder. They are populated in Stage 4.

5. **Write `plan.json`** at the plan root following `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md`: `"status": "planning"`, `"stage": "research"`, `"started_at"` set, `"ended_at": null`, all counts `0`, and `"tasks": []`. The dashboard renders this as a planning plan whose stage indicator reads "Stage 2 of 4 — Research".

The skeleton's Objective/Scope are the only plan content written now; research findings and discussion stay in conversation until Stage 4. The Stage 4 Write flow upgrades this same skeleton in place (no re-numbering).

## Stage Transition

When you have gathered sufficient context to direct research effectively and have scaffolded the skeleton above, announce:

> **▶ PROCEED TO STAGE 2: RESEARCH**

The active mode's `references/stage-1.md` will instruct you to read its `references/stage-2.md` next. Do not preload it earlier.
