# Structural optimization — the catalogue

Scope: structural and form-level optimisation of harness text — duplication patterns, altitude cuts, and payload-zone rules. This is **stage 1** of the review protocol (SKILL.md § "Mandatory gate"): it runs before any lexical pass, because structure is where the tokens actually are.

All patterns [MEASURED 2026-07-29, docs-manager overhaul, commit f28833f]: the lexical engine yielded 5–12.5% whole-file on 16 harness artifacts, while the structural pass took the skill's SKILL.md from 23.2KB to 7.4KB (−68%) and the directory −32%. Each entry: the smell → the fix → the measured instance.

## Duplication patterns

1. **Parallel tables sharing a taxonomy** → merge into one table; one row per subject, one column per concern. Duplicated tables don't just cost tokens — they drift (the two docs-manager tables already disagreed on the backlog location). *(3 tables — routing, doc-type references, category descriptions — became one Directory Table.)*

2. **Derivable columns** → replace the column with its derivation rule. *(Display Name column = directory name capitalized, `rfcs/` → RFCs — one rule line replaced 15 cells.)*

3. **Prose restating embedded template comments/placeholders** → delete the prose; the template's own copy arrives at the point of use, inside the document being filled in. *(architecture.md's runtime/observability paragraph duplicated the template's `<!-- Service-level only. -->` comments; standard.md's principle paragraph duplicated its `{placeholder}`.)*

4. **Pitfall/checklist bullets restating adjacent prose or an upstream rule** → keep only bullets carrying information stated nowhere else. A pitfall that negates the instruction three lines above it is noise; worse, compressed pitfall lists flip into imperatives. *(11 bullets deleted across 6 doc-type guides.)*

5. **Same invariant stated N times** → state it once at the governing level, keep only genuine exceptions locally. *(index-generation.md stated "empty ⇒ omit" six times; now once, in the format preamble.)*

6. **Cross-file near-verbatim paragraphs** → hoist to the canonical owner; each former site keeps a one-line pointer plus its own local example. Copies drift — the two docs-manager copies already differed. *(The description-vs-requirements relationship paragraph lived in product-description.md and requirement.md; now in docs-manager SKILL.md § One Canonical Home.)*

7. **Format vs behaviour ownership** → the doc-format guide defines how the artifact *looks* (fields, naming, structure); the agent that acts defines *policy* (when, which value, defaults). Never both. *(TTL/freeze policy was stated in 4 files; now only in `agents/researcher.md` — the guide keeps the field semantics and a pointer.)*

## Altitude cuts

8. **Delete what an Opus-class model already knows or does unprompted**: process narration ("Classify → Route → Apply → Reject"), standard definitions (MoSCoW, what a README is), obvious steps ("create parent directories", "if ambiguous, ask"). The test: would the model behave differently without this sentence? *(docs-manager's Routing Process and Structure Enforcement sections deleted entirely; their few non-obvious survivors moved into the sections they governed.)*

9. **Form rewrites** — a paragraph run that is really a list becomes one thesis line + bullets; guidance sections keep only judgment rules and discriminating examples, not restated mechanics. *(Every "How to Write One": 3–4 paragraphs → 1 line + 2–3 bullets; requirement.md's MoSCoW paragraph → "Be honest about priorities — if everything is 'Must,' nothing is prioritized.")*

## Payload zones

10. **Text emitted verbatim into user output is never compressed or reworded** — template code blocks, table columns whose cells become generated README/document content, quoted fallback strings. Identify these zones before any review and declare them in the reviewer spawn prompt (`Payload zones:` field). The engine's validator protects code blocks but has no concept of payload table cells — that protection is the parent's job.

## Using the catalogue

- Authoring new harness text: check patterns 1–2 and 8–10 before writing (prevention beats review).
- Stage-1 review: the `uc:caveman-reviewer` agent checks the artifact against every pattern, including cross-file duplication via Grep; findings name the pattern number, locations, fix, and estimated saving.
- The catalogue grows: a new structural pattern found during any harness work lands here as a numbered entry with its measured instance.
