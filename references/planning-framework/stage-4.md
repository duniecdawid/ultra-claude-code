# Planning Framework — Stage 4: Write

Mandatory for ALL planning modes — no exceptions.

**Purpose:** All file writing happens here — documentation updates, plan scaffolding, plan README, and per-task `task.md` files. Then approval gate. Then post-approval (commit + print execution command + hard stop).

## Stage Entry Check

Before beginning any Stage 4 work, verify you actually completed the prior stages. If any of these are false, go back — do not proceed:

- **Stage 1 happened:** You asked the user questions via AskUserQuestion and received answers. (If you cannot point to at least one AskUserQuestion call and response in this conversation, Stage 1 was skipped.)
- **Stage 2 happened:** You spawned research agents or surveyors and synthesized their results. (If there are no agent results in context, Stage 2 was skipped.)
- **Stage 3 happened:** You presented your synthesis, the user engaged in discussion, and you used the Stage 3 exit gate (AskUserQuestion with Proceed/Keep discussing/Abandon). (If there was no exit gate interaction, Stage 3 was skipped.)

This check exists because the most common failure mode is jumping from a detailed user request straight to writing a plan. A detailed request makes Stages 1-3 faster, not unnecessary — fast research still catches things the user missed, and fast discussion still validates your approach.

## Rules

- This is the ONLY stage where files are created or modified.
- Product docs are updated in Step 2, architecture/standards in Step 3 — do it now, not as plan tasks.
- After plan file is written: approval gate via AskUserQuestion (Step 6).
- After approval: commit, print execution command, STOP (Step 7).

## Prerequisites

Before writing any docs in Steps 2-3, ensure you have read:
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md` — the authority on document structure, references, routing, naming, and cross-referencing. All documentation written in Steps 2-3 must follow docs-manager rules.

Before writing the plan in Step 4, read both templates:
- `${CLAUDE_PLUGIN_ROOT}/templates/plan.md` — the plan README (plan-level content + flat task heading index)
- `${CLAUDE_PLUGIN_ROOT}/templates/task.md` — the per-task file (description, files, patterns, research pointers, success criteria, dependencies)

---

## Step 1: Scaffold Plan Directory

**Derive the plan name and number:**

1. **Semantic name** — from the feature description or `$ARGUMENTS`:
   - Lowercase, hyphenated: "Add user authentication" → `user-auth`
   - Short but descriptive: 2-4 words max
   - No special characters

2. **Sequential number** — scan `documentation/plans/` for directories matching `[0-9][0-9][0-9]-*`:
   - Extract the highest number, increment by 1, **always zero-pad to 3 digits**
   - If no numbered plans exist, start at `001`
   - Example: existing `001-user-auth`, `002-api-keys` → next is `003-whatever`
   - **Wrong:** `1-user-auth` (bare number) — **Right:** `001-user-auth` (3-digit zero-padded)

3. **Final folder name**: `{NNN}-{semantic-name}` (e.g., `001-user-auth`, `012-billing`)

4. **Check for existing plan** — if `documentation/plans/*-{name}/` exists (suffix match), read it for revision context.

5. **Check for stub plan** — if the matched plan has `Status: Stub` and `Source: Roadmap`:
   - Do NOT re-create the directory — it already exists with `shared/` and `tasks/`.
   - You will edit the existing `README.md` in place (Step 5) rather than overwriting it.
   - Skip to Step 2 (the plan number and directory are already determined).

**Create the directory** (skip if editing an existing stub):

```bash
mkdir -p documentation/plans/{NNN}-{name}/{shared,tasks}
```

```
documentation/plans/001-user-auth/
├── README.md          # The plan document (plan-level content + flat task heading index)
├── plan.json          # Dashboard status (created now, updated at approval and execution)
├── shared/            # Lead-level shared notes (created empty, used during execution)
└── tasks/             # Per-task content — one subdirectory per task, created in Step 5
    ├── task-1/
    │   └── task.md    # Authoritative per-task content (description, files, patterns, research, success criteria, deps)
    └── task-2/
        └── task.md
```

**Create `plan.json`** at plan root with initial planning status (no tasks array yet — that's populated after writing the README in Step 5). Follow `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md` for the format. Set `status` to `"planning"`, all counts to 0.

**When upgrading a stub:** After editing the README status from Stub→Draft, verify `plan.json` at plan root has `"status": "planning"`.

## Step 2: Update Product Documentation — Mandatory

Documentation is not optional. This step ensures product docs exist and are current for the feature area being planned. Do it now, not as part of the plan you are building.

### Process

1. **Scan** `documentation/product/description/` and `documentation/product/requirements/` for docs covering the feature area.
2. **If no relevant docs exist** — create them. Look up the correct reference in docs-manager's Document Type References table and read it before writing.
3. **If docs exist** — review against Stage 1-3 findings and update with any new information.
4. **Follow docs-manager** routing rules for file naming, placement, and cross-referencing between doc types.

Skipping this step requires explicit justification: state what you scanned, what exists, and why no changes are needed. "Nothing changed" without evidence is not acceptable.

### Track Changes

Record what you changed for use in the plan's Documentation Changes table:
- File path
- Action (created / updated)
- Summary of what was added (one sentence)

## Step 3: Review Architecture & Standards — Mandatory

Architecture and standards docs must exist and be current for the area being planned. This is also when you challenge the approach — does it fit the existing architecture? Are there better alternatives?

### Process

1. **Scan** `documentation/technology/architecture/` and `documentation/technology/standards/` for docs covering the area. Gracefully handle missing or empty directories.
2. **If no relevant docs exist** — create them. Look up the correct reference in docs-manager's Document Type References table and read it before writing.
3. **If docs exist** — review against Stage 1-3 findings. Update if decisions during discussion changed the system design, or if the plan requires architectural elements that are not yet documented.
4. **Follow docs-manager** routing rules for file naming, placement, and cross-referencing between doc types.

Design the technological changes that will be part of the plan. Skipping this step requires explicit justification: state what you scanned, what exists, and why no changes are needed.

### Track Changes

Record:
- What you changed in architecture/standards docs
- Which standards are relevant to the plan (will populate each task's Patterns field)
- Which architecture elements are relevant to the plan

## Step 4: Build and Validate Plan

Build the plan using the loaded plan template including the `Execute: /uc:plan-execution {NNN}` header.

**When upgrading a stub plan:** If you're working from a stub (`Status: Stub`, `Source: Roadmap`), use the stub's Objective, Scope, and Success Criteria as your starting point. Refine them based on what you learned in Stages 1-3, but preserve the spirit of the original scope boundary. Update the header fields: `Status: Stub → Draft` and `Source: Roadmap → Feature Mode`.

Reference the documentation updated in Steps 2-3 — do not duplicate content. Each task's **Product context** and **Patterns** fields should point to the relevant files, not restate what's in them.

**Plan README vs per-task files:**
- The plan `README.md` holds plan-level content (Objective, Context, Tech Stack narrative, Scope, Success Criteria, Documentation Changes, Risk Assessment) plus a **flat task heading index** — just `### Task N: {Title} <!-- status:pending -->` followed by `- [ ] **Complete**`.
- Per-task content (description, files, patterns, research, success criteria, dependencies) lives in `tasks/task-N/task.md`. The README does NOT contain these fields.
- The Tech Stack section in the README is a plan-wide narrative overview. The machine-readable research mapping lives per-task in each `task.md`'s `**Research:**` section.

### Task sizing rules

- **Split by feature, not by tech layer.** Each task delivers a complete vertical slice (database through API/UI). Never split into "backend task" and "frontend task" for the same feature. Testing is part of the execution pipeline, not a separate task.
- **Default to 1 task.** Only split when the work has two or more independent features that don't depend on each other.
- **Minimum ~7 files per task.** Each task spins up a full pipeline (Executor + Reviewer + Tester). If a change touches fewer than 7 files, absorb it into a larger task — the pipeline overhead isn't justified.
- **Maximum ~20 files per task.** If a task would touch more than 20 files, consider splitting — but only along feature boundaries, not arbitrary lines.

### Forbidden task patterns

The README task index is a **flat sequence** — no hierarchy, no grouping, no nesting. The execution engine reads `### Task N:` headings sequentially from README and loads each task's content from `tasks/task-N/task.md`. Anything else breaks parsing and execution.

**Do NOT:**
- **Group tasks into phases.** No "Phase 0: Foundation", "Phase 1: Core", etc. If tasks have a natural order, express it through each task.md's Dependencies field, not README section headers. The README task index has one level: `### Task N:`.
- **Use nested numbering.** No T0.1, T1.2, T2.3. Tasks are numbered sequentially: Task 1, Task 2, Task 3, ... Task N. That's it.
- **Split by tech layer.** No separate "web implementation", "native implementation", "tests", "review gate" tasks for the same feature. Each task is a complete vertical slice — one component means one task that delivers types + web + native + tests + stories.
- **Invent custom task formats in README.** No bold-text pseudo-headings (`**T1.1**`), no bullet-list tasks, no sub-tasks within tasks. Every task is an H3 heading matching the exact format: `### Task N: {Title} <!-- status:pending -->` followed by `- [ ] **Complete**`.
- **Put per-task content in README.** Description, files, patterns, research, success criteria, and dependencies go in `tasks/task-N/task.md`. The README is an index only.
- **Omit required fields in task.md.** Every task.md has all fields from `templates/task.md`. No abbreviated one-liner tasks.
- **Create tasks for documentation updates.** Doc changes happen in Stage 4 Steps 2-3 (before the plan is written), not as plan tasks.

If a plan has 20+ features that feel like they need phases, the plan is too large — split into multiple plans instead.

### Task heading format (README)

Each task heading in the README MUST use the format: `### Task N: {Title} <!-- status:pending -->`

Immediately after the heading, add a completion checkbox: `- [ ] **Complete**`

Nothing else goes under the heading in the README. All content lives in `tasks/task-N/task.md`.

### Task content (task.md)

Each task's `tasks/task-N/task.md` file MUST contain all fields from `templates/task.md`:

- **Description** — clear paragraph of what to build/change
- **Product context** — relevant product description or requirements files from Step 2
- **Files** — expected files to create or modify
- **Patterns** — relevant architecture/standards files from Step 3, with optional section hints (e.g., `documentation/technology/standards/error-handling.md (API Error Responses section)`). If none apply: `None identified`
- **Research** — pointers to durable research files under `documentation/technology/research/` that this task depends on, each with a one-line "why this matters for this task" gloss. Populated from research collected in Stage 2 via `/uc:research`. A research file that applies to multiple tasks appears as a pointer in each of those tasks' `task.md` files — duplicating a path is not duplicating content.
- **Success criteria** — numbered list of how to verify the task is done
- **Dependencies** — other tasks that must complete first (or `none`)

## Step 5: Write Plan Files and Populate plan.json

Three write actions, in order:

**5a. Write plan README.md** to `documentation/plans/{NNN}-{name}/README.md` via the Write tool. Plan-level content (Objective, Context, Tech Stack, Scope, Success Criteria, Documentation Changes, Risk Assessment) plus the flat task heading index. The README is the canonical plan overview.

**5b. Write per-task `task.md` files.** For each task, create `tasks/task-N/` and write `tasks/task-N/task.md` using `templates/task.md`. Populate every field. Key points:
- Description, files, patterns, success criteria, dependencies come from your Stage 1-3 work.
- The **Research** section is populated from Stage 2's research-to-task mapping: for every `/uc:research` result that applies to this task, add a pointer entry with a one-line "why this matters for THIS task" gloss. A research file that applies to multiple tasks appears in each of their task.md files — the path is the same, the gloss may differ per task.
- If any task has no external-research dependencies, write `None applicable` in its Research section (explicit, not blank).

**5c. Populate plan.json with tasks:**
1. Parse all `### Task N: {name} <!-- status:pending -->` headings from the README.
2. For each task, extract the `task_id` and `task_name` from the heading and then read `tasks/task-N/task.md` to pull:
   - `goal`: 1-line summary from the task's Description (first sentence is typically fine)
   - `dependencies`: parse from the task.md's Dependencies field (array of `"task-N"` strings, or `[]` if `none`)
   - `status`: `"pending"`
3. Read the existing `plan.json` (created in Step 1 with `status: "planning"`).
4. Set `"tasks"` to the array of task objects, `"total_tasks"` and `"pending_tasks"` to the task count.
5. Keep `"status"` as `"planning"` — do NOT flip to `"approved"` yet (that happens on approval in Step 7).
6. Write the updated `plan.json` back to disk.

This ensures the dashboard can display tasks during the approval window, before the plan is approved. It also means every task has its authoritative `task.md` file on disk before execution begins — `/uc:plan-execution` never has to parse README sections for per-task content.

## Step 6: Present Summary and Request Approval

**Present a concise summary in chat** — NOT the full plan. Include: plan number, plan name, objective, task count, and the file path. The user can read the full plan from the file.

**Include a task list summary** — for each task, show one line with the task name and a brief goal:

```
Tasks:
1. {Task name} — {1-line goal}
2. {Task name} — {1-line goal}
...
```

This gives the user a quick overview of the task breakdown alongside the plan summary.

**Ask for approval via AskUserQuestion** — Options: "Approve" / "Reject with feedback" / "Partially reject (specify changes)"

**Approval gate rules — strictly enforce:**

- Only an explicit "Approve" selection counts as approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve this step. The plan is not approved until the user explicitly says so.

## Step 7: Post-Approval — HARD STOP

When the user explicitly approves the plan, you MUST complete ALL sub-steps before stopping:

1. **Update README status:** change `> Status: Draft` → `> Status: Approved`
2. **Flip plan.json status** — THIS IS MANDATORY, DO NOT SKIP:
   - Read the current `plan.json` at `documentation/plans/{NNN}-{name}/plan.json`
   - Change `"status"` from `"planning"` to `"approved"` (tasks array is already populated from Step 5)
   - Follow the format in `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md`
   - Write the updated `plan.json` back to disk
3. **Commit plan files** — Stage all plan files (README.md, plan.json, directories) and commit:
   ```
   git add documentation/plans/{NNN}-{name}/ && git commit -m "plan: {NNN}-{name}"
   ```
4. **Print execution command and instruct the user to run it in a new window:**
   ```
   Plan committed. To execute, open a new window and run:
   /uc:plan-execution {NNN}
   ```
5. **STOP.** Your turn ends here. No more output after printing the command. Do NOT:
   - Start executing the plan
   - Suggest starting execution
   - Ask if the user wants you to execute
   - Spawn any agents or teams
   - Invoke `/uc:plan-execution` or any other skill
   - Write any more code or make any more changes
   - Continue the conversation for ANY reason
   - Offer next steps or suggestions

## Plan Revision (if rejected)

If the user rejects or partially rejects the plan:

1. Read their feedback.
2. Edit the existing `documentation/plans/{NNN}-{name}/README.md` using the Edit tool to incorporate changes.
3. Re-present the concise summary with changes highlighted.
4. Re-ask for approval via AskUserQuestion.

Repeat until approved or the user abandons the plan.
