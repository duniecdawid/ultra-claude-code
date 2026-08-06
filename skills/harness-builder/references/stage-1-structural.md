# Stage 1 — Structural

Scope: stage 1 of the build workflow — settling the structural shape of every target artifact. Procedure only; the catalogue itself lives in `structural-optimization.md`.

## Prepare

1. Check every target artifact against the **full catalogue** in `structural-optimization.md` — duplication patterns, altitude cuts, form rewrites. Cross-file patterns require Grep over the plugin tree for the artifact's distinctive phrases and taxonomies — an artifact can be clean in isolation and still be the second copy of something.
2. **Payload zones:** declare the known ones and auto-detect the rest — fenced template blocks, table columns whose cells are emitted into user documents, quoted fallback strings. Off-limits for every change in every stage. Record the inventory; stage 4 passes it to the compression agent.
3. For a **new** artifact: draft its structure (sections, routing, frontmatter shape) per the matching knowledge references (`agent-building.md` for agents; description and name come at stage 3).
4. Present the structural proposal — one entry per finding or decision (pattern name, location, proposed fix, estimated saving), largest impact first. Apply settled structural edits directly to the files; the working tree is the draft.

## Discuss — exit gate

Present the proposal and discuss. "ok" / "looks good" / "makes sense" are conversational, not exit signals. Move on only when the user explicitly confirms structure is settled ("structure settled", "go to lexical", "next stage"). On confirmation, read `references/stage-2-lexical.md` and enter stage 2.
