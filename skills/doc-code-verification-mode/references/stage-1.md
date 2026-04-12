# Doc-Code Verification Mode — Stage 1: Understand

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-1.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Determine what to verify based on `$ARGUMENTS`:

- **If `$ARGUMENTS` specifies a directory** (e.g., `src/auth/`) — scope verification to that directory and its related documentation.
- **If `$ARGUMENTS` is empty or "all"** — verify the entire project.
- **If `$ARGUMENTS` specifies a topic** (e.g., "authentication") — focus on documentation and code related to that topic.

For very large codebases, suggest scoped verification instead of "all" via AskUserQuestion — full-project verification on a monorepo can run for hours and produce noise that drowns out the real findings.

The base "ask 3 questions" rule still applies. Questions in this mode focus on: which areas of the system the user has changed recently (those drift fastest), which docs the user trusts vs distrusts, and whether they have specific concerns to investigate first.

## Stage Transition

When the verification scope is clear and the base Stage 1 rules are satisfied, announce:

> **▶ PROCEED TO STAGE 2: RESEARCH**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/doc-code-verification-mode/references/stage-2.md`
