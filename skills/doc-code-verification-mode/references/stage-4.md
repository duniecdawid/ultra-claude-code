# Doc-Code Verification Mode — Stage 4: Write

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-4.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

**Don't try to fix everything in one go.** The plan should focus on the discrepancies and structural issues the user decided to fix during Stage 3. Skipped items stay skipped — don't smuggle them back in.

Structural fixes include: moving docs to correct directories, adding missing sections, adding cross-references, separating duplicated content. When a task involves a structural fix, the executor must read the relevant docs-manager reference guide before rewriting the document, to ensure the fix conforms to the expected structure. Add this as a task instruction.

### Missing Features List

Separately, create an additional list of **features described in documentation but not implemented at all**. These are NOT part of the fix plan — they represent product gaps, not doc drift. Present them to the user for prioritization in the post-plan summary. Do NOT add them to the backlog automatically — the user decides what to track.
