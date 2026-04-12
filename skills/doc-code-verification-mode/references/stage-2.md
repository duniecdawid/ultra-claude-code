# Doc-Code Verification Mode — Stage 2: Research

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-2.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Use the base research skills (code-surveyor + doc-surveyor) to survey code and documentation in scope. Then run two verification dimensions in parallel.

### Dimension 1: Code-Documentation Accuracy

1. **Build a verification matrix** — pair documentation sections with the code they describe. Each row is a (doc section, code path) pair to compare.
2. **Spawn Checker agents** for each pair — compare code implementation against documentation claims. Each Checker returns discrepancies with severity and file:line references.
3. **Synthesize results:**
   - Deduplicate discrepancies found by multiple checkers.
   - Classify severity: **Critical** (phantom docs describing nonexistent code), **Major** (undocumented code, significant drift), **Minor** (naming, formatting).
   - Classify fix type: **Update docs** (code is correct), **Update code** (docs are correct), **Needs decision** (unclear — flag for user).

### Dimension 2: Documentation Structure Adherence

Verify that documentation follows docs-manager's framework. Check:

1. **Routing compliance** — all docs under `documentation/` are in the correct directories per routing rules.
2. **Reference conformance** — each document follows its type's expected structure (has the expected sections per the reference guide).
3. **Cross-references** — documents link to related docs of other types (product description links to architecture, etc.).
4. **Content separation** — no content duplication across doc types (e.g., market data in product descriptions, implementation details in requirements).

Classify structural issues:

- **Critical** — document in wrong directory (routing violation).
- **Major** — document missing key sections per reference guide, missing cross-references between related docs, content duplicated across doc types.
- **Minor** — formatting deviations from reference structure.

### Early Exit

**If no discrepancies found in either dimension** — report clean verification status to the user and exit. No plan needed. Do not invent work to justify the run.

## Stage Transition

When both dimensions complete and discrepancies (if any) are synthesized, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/doc-code-verification-mode/references/stage-3.md`
