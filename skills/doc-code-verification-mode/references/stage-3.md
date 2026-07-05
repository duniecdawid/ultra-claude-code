# Doc-Code Verification Mode — Stage 3: Discuss

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-3.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Walk through all findings — code-documentation discrepancies, structural adherence issues, and duplicate-content clusters — with the user. For each one:

1. Present the evidence: what the docs say vs what the code does (with file:line references), what's wrong structurally, or which documents duplicate the same content (with the recommended canonical home).
2. Ask for a decision via AskUserQuestion: **update docs** / **update code** / **fix structure** / **consolidate** (for duplicate content — merge into the recommended canonical home and replace the copies with cross-links) / **skip**.
3. Allow discussion between items — the user may want to debate, ask questions, or change their mind on a previous decision before moving to the next.

Do not auto-resolve ambiguous discrepancies. When it's unclear which source of truth is correct, the human decides.

## Stage Transition

When all findings have a decision (or have been explicitly skipped), and the user picks "Proceed to plan" via the base exit gate, announce:

> **▶ PROCEED TO STAGE 4: WRITE**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/doc-code-verification-mode/references/stage-4.md`
