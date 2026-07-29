# Stage 1 — Structural

Scope: stage 1 of the build workflow — settling the structural shape of every target artifact, inside native plan mode. Procedure only; the catalogue itself lives in `structural-optimization.md`.

## Prepare

1. Check every target artifact against the **full catalogue** in `structural-optimization.md` — duplication patterns, altitude cuts, form rewrites. Cross-file patterns require Grep over the plugin tree for the artifact's distinctive phrases and taxonomies — an artifact can be clean in isolation and still be the second copy of something.
2. **Payload zones:** declare the known ones and auto-detect the rest — fenced template blocks, table columns whose cells are emitted into user documents, quoted fallback strings. Off-limits for every change in every stage. Record the inventory; stage 3 passes it to the compression agent.
3. For a **new** artifact: draft its structure (sections, routing, frontmatter shape) per the matching knowledge references (`description-writing.md` for descriptions, `agent-building.md` for agents).
4. Write the structural proposal into the plan file — one entry per finding or decision (pattern name, location, proposed fix, estimated saving), largest impact first.

## Discuss — exit gate

Present the proposal and discuss. "ok" / "looks good" / "makes sense" are conversational, not exit signals. Move to stage 2 only when the user explicitly confirms structure is settled ("structure settled", "go to lexical", "next stage").
