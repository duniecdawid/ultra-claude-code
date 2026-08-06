# Doc-Code Verification Mode — Stage 4: Write

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-4.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

**Don't try to fix everything in one go.** The plan should focus on the discrepancies and structural issues the user decided to fix during Stage 3. Skipped items stay skipped — don't smuggle them back in.

Structural fixes include: moving docs to correct directories, adding missing sections, adding cross-references, fixing broken cross-reference anchors, consolidating duplicate content into its canonical home and replacing the copies with standard anchored section-pointer cross-links, and relocating decision residue into RFCs. When a task involves a structural fix, the executor must read the relevant docs-manager reference guide before rewriting the document, to ensure the fix conforms to the expected structure.

Add a `**Docs-manager reference:**` field to any such task's `tasks/task-N/task.md`, after `**Patterns:**` and before `**Research:**`:

```markdown
**Docs-manager reference:** `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/{doc-type}.md`

The executor must read this reference file before rewriting the document.
```

### Missing Features List

Separately, create an additional list of **features described in documentation but not implemented at all**. These are NOT part of the fix plan — they represent product gaps, not doc drift. Present them to the user in the post-plan summary, then triage each with the user per `${CLAUDE_PLUGIN_ROOT}/references/backlog-triage.md` (plan-context variant).
