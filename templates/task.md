# Task {N}: {Title}

**Description:** What needs to be done. One paragraph.

**Product context:** Relevant files from `documentation/product/` (description or requirements).

**Files:** Expected files to create or modify.
- `path/to/file.ts`
- `path/to/other.ts`

**Patterns:** Architecture/standards files the executor must follow (populated by Standards Review in Stage 4). Optional section hints like `documentation/technology/standards/error-handling.md (API Error Responses section)`. If none apply: `None identified`.
- `documentation/technology/standards/{file}.md`
- `documentation/technology/architecture/{file}.md`

**Research:** Pointers to durable research files this task depends on. Each entry is `file-path — one-line what-matters-for-this-task`. Populated by the planning mode during Stage 4 from research collected in Stage 2 via `/uc:research`. Lead may append during mid-execution ADVICE handling.
- `documentation/technology/research/libraries/{lib}.md` — {why this matters for this task}
- `documentation/technology/research/patterns/{pattern}.md` — {why this matters for this task}
- (or `None applicable` if the task has no external-research dependencies)

**Success criteria:**
1. {criterion 1}
2. {criterion 2}
3. {criterion 3}

**Dependencies:** `task-{M}`, `task-{K}` (or `none`).

<!--
Pipeline mode block — Lead appends this when pre-spawning the task team early while the predecessor is still in review/test. Omit entirely for non-pipeline spawns.

**Pipeline mode:** This task was pre-spawned while predecessor task {P} is in review/test. You MUST NOT begin implementing (step 4 in your agent workflow) until Lead sends "Implementation approved". Follow steps 1 through 3 (context, explore, plan) normally. After plan.md passes the deviation self-check, park at the pipeline wait gate by sending "Task {N} planning complete — awaiting implementation approval" to Lead, then wait silently for "Implementation approved — predecessor task {P} passed all stages. Proceed to implement."
-->
