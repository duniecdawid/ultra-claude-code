# Debug Mode — Stage 4: Write

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-4.md`

The instructions below extend the base rules with debug-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Each fix task in the plan must include, on top of the base task fields:

- **Regression criteria** — what must NOT break alongside the success criteria. Every fix should make the system stronger, not just patched.
- **Failing test first** — the plan must include writing and running a test that proves the bug exists *before* the fix is applied. The team can then verify the bug reproduces and confirm the fix resolves it. This is the first step of the fix task, not an afterthought.

Both fields exist because the most common debug failure mode is a fix that "works" only because the bug couldn't be reproduced in the first place. The failing-test-first rule prevents that.
