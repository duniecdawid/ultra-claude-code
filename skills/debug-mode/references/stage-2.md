# Debug Mode — Stage 2: Research

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-2.md`

The instructions below extend the base rules with debug-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Use the base research skills (code-surveyor, doc-surveyor, research) to understand the affected code and expected system behavior. Also check **recent `git log`** — most bugs are regressions, and the diff that introduced the bug is often the diff that explains it.

**Tech Stack sweep input for debug mode:** the base framework's mandatory Tech Stack sweep needs an in-scope file set. For debug mode, that's the files under investigation for the bug — the file(s) containing the symptom plus the file(s) containing the suspected cause per your initial hypotheses. Not the whole repo, not even the whole subsystem. Pass the resulting research file paths to any per-hypothesis Explore agents you spawn so they can read them directly for library-specific context — many bugs are caused by subtly wrong use of an external library (deprecated options, changed defaults, version-specific behavior), and fresh library docs often reveal the cause faster than codebase investigation.

### Hypothesis Gate — MANDATORY

After the initial survey, generate **2-5 hypotheses** ranked by likelihood and present them to the user via AskUserQuestion. Ask: "Here are my hypotheses — do you want to confirm, reject, or add any before I investigate?"

This is **not optional**. The hypothesis list is the contract that defines what you will investigate. Skipping it means your investigation has no scope, and you will waste effort exploring the wrong paths. **Do not spawn Explore or System Tester agents until the user has responded to the hypothesis list.**

### Parallel Investigation

Once the user has confirmed/refined the hypothesis list, investigate in parallel — spawn every agent below as one-shot fan-out (no `name`, explicit `run_in_background: true`; Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`):

- **Per-hypothesis Explore agents** — one per hypothesis, scoped to the relevant code paths. Each should return evidence supporting or refuting the hypothesis with file:line references.
- **System Tester** — attempt to reproduce the bug. Try the exact steps first, then variations to understand boundary conditions. Read all files from `documentation/technology/testing/` for project-specific test instructions.

### Synthesis

After **every** agent's completion notification has been collected (not before — completion order is not guaranteed), synthesize evidence:

- Rank hypotheses by evidence strength.
- Cross-reference — does evidence from multiple hypotheses point to the same root cause?
- Assess reproduction results.
- Identify root cause and fix scope.

If the bug cannot be reproduced, ask for more context. If still not reproducible, suggest monitoring/logging additions.

## Stage Transition

Before transitioning, verify the base gates pass AND your hypothesis list was presented to the user and investigated. Then announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/debug-mode/references/stage-3.md`
