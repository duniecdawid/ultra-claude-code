# Debug Mode — Stage 3: Discuss

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-3.md`

The instructions below extend the base rules with debug-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Your Stage 3 opening message must include all four of these:

1. **Root cause summary** — your current best understanding, grounded in Stage 2 evidence.
2. **Confidence level** — how certain you are and what would change your mind.
3. **Fix approach** — your proposed direction, including blast radius and regression risk.
4. **Open questions** — anything you are still uncertain about.

Present this, then enter the base discussion loop. Do not skip to Stage 4 even if the root cause seems obvious — the discussion exists to catch fix approaches that seem right but have hidden costs (a rushed patch that breaks something else is worse than the original bug).

## Stage Transition

When the discussion converges and the user picks "Proceed to plan" via the base exit gate, announce:

> **▶ PROCEED TO STAGE 4: WRITE**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/debug-mode/references/stage-4.md`
