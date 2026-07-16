# Doc-Code Verification Mode — Stage 2: Research

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-2.md`

The instructions below extend the base rules with verification-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Use the base research skills (code-surveyor + doc-surveyor) to survey code and documentation in scope. Then run three verification dimensions in parallel. All subagents in this stage (surveyors, Checkers) spawn as one-shot fan-out — no `name`, explicit `run_in_background: true` (Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`).

**Tech Stack sweep input for verification mode:** the base framework's mandatory Tech Stack sweep needs an in-scope file set. For verification mode, that's the code files being checked against documentation claims — whatever is in the verification matrix (Dimension 1 below). Sweep those files' imports via `/uc:research --fill-only`. Library research is particularly valuable here because "docs claim X, code does Y" is sometimes actually "docs claim X, library behavior is Z, code correctly implements Z, docs are wrong" — and you need current library docs to tell those cases apart.

### Dimension 1: Code-Documentation Accuracy

1. **Build a verification matrix** — pair documentation sections with the code they describe. Each row is a (doc section, code path) pair to compare.
2. **Spawn Checker agents** for each pair — compare code implementation against documentation claims. Each Checker returns discrepancies with severity and file:line references.
3. **Synthesize results** (only after every Checker's completion notification has been collected):
   - Deduplicate discrepancies found by multiple checkers.
   - Classify severity: **Critical** (phantom docs describing nonexistent code), **Major** (undocumented code, significant drift), **Minor** (naming, formatting).
   - Classify fix type: **Update docs** (code is correct), **Update code** (docs are correct), **Needs decision** (unclear — flag for user).

### Dimension 2: Documentation Structure Adherence

Verify that documentation follows docs-manager's framework. Check:

1. **Routing compliance** — all docs under `documentation/` are in the correct directories per routing rules.
2. **Reference conformance** — each document follows its type's expected structure (has the expected sections per the reference guide).
3. **Cross-references** — documents link to related docs of other types (product description links to architecture, etc.), and every `[...](path#anchor)` resolves to a real heading slug in the target file. A broken anchor (heading renamed or removed out from under an inbound link) is a Major structural issue.
4. **Content separation** — no content duplication across doc types (e.g., market data in product descriptions, implementation details in requirements).

Classify structural issues:

- **Critical** — document in wrong directory (routing violation).
- **Major** — document missing key sections per reference guide, missing cross-references between related docs, broken cross-reference anchors, content duplicated across doc types.
- **Minor** — formatting deviations from reference structure.

### Dimension 3: Documentation Redundancy

Detect the *same substantive content copied across different documents* — distinct from Dimension 2 item 4, which is about the right content sitting in the wrong doc *type*. This dimension is doc-vs-doc: the same fact restated in two or more documents.

1. **Build a topic→docs map from the survey you already have.** Reuse the doc-surveyor output (`### Key Topics Documented`, `### Specifications Defined`) — no new survey pass. Any topic or specification that appears in 2+ documents is a candidate cluster.
2. **Read the candidate sections and classify each cluster:**
   - **True duplication** — the same drift-prone content (schema, config value, count, version, definition, procedure, acceptance criterion, contract shape) is restated in more than one place. This is a finding.
   - **Not a finding** — legitimate distinct-perspective coverage (each doc says something different about the topic from its own perspective), or a brief (1–2 sentence) orienting summary that already links to a canonical source. Do not flag these; the goal is less duplication, not zero.
3. **Recommend the canonical home** for each true-duplication cluster using the docs-manager per-type ownership table, and mark the other copies for replacement with an anchored section-pointer cross-link.
4. **Classify severity by drift risk:**
   - **Critical** — a spec, config value, count, version, or contract shape copied verbatim across docs (will drift, causes bugs).
   - **Major** — substantial overlapping procedures or definitions that should be consolidated.
   - **Minor** — small repeated substantive phrasing.
5. **Fix type:** always **consolidate** — keep the canonical copy, replace the others with a section-pointer cross-link (plus at most a brief orienting summary).

### Early Exit

**If no discrepancies found in any dimension** — report clean verification status to the user and exit. No plan needed. Do not invent work to justify the run.

## Stage Transition

When all three dimensions complete and discrepancies (if any) are synthesized, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/doc-code-verification-mode/references/stage-3.md`
