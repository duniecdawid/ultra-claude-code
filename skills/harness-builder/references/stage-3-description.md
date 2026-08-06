# Stage 3 — Description & name

Scope: stage 3 of the build workflow — writing the artifact's description (and, for new artifacts, its name) once the body is confirmed. The only stage that touches descriptions; deriving them from the settled body is the point — never draft them in parallel with it.

## Prepare

1. **Descriptions (skill and agent):** write against `description-writing.md` — budgets (skill 1–3 sentences ~20–50 words; agent 1 sentence ~10–25 words), key-term precedence (key terms win over budget on conflict; an overshoot is stated, never hidden), sibling distinguishability.
2. **Name/slug** for a new artifact: per `description-writing.md` and, for agents, `agent-building.md`.
3. Descriptions **never reach the engine**: it splits YAML frontmatter off and re-prepends it verbatim ([MEASURED 2026-07-27]), and forced through as prose it trades routing key terms for a few percent.
4. Any description change ⇒ before/after trigger test (`testing-refactors.md`), recorded as an execution step for stage 5.
5. Apply the edits directly to the files.

## Discuss — exit gate

Explicit confirmation only ("description settled"); conversational acknowledgements don't advance the stage. On confirmation, read `references/stage-4-compression.md` and enter stage 4.
