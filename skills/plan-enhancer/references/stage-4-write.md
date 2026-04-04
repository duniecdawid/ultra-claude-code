# Stage 4: Write

Mandatory for ALL planning modes — no exceptions.

**Purpose:** All file writing happens here — documentation updates, plan scaffolding, plan README. Then approval gate. Then post-approval (commit + print execution command + hard stop).

## Stage Entry Check

Before beginning any Stage 4 work, verify you actually completed the prior stages. If any of these are false, go back — do not proceed:
- **Stage 1 happened:** You asked the user questions via AskUserQuestion and received answers. (If you cannot point to at least one AskUserQuestion call and response in this conversation, Stage 1 was skipped.)
- **Stage 2 happened:** You spawned research agents or surveyors and synthesized their results. (If there are no agent results in context, Stage 2 was skipped.)
- **Stage 3 happened:** You presented your synthesis, the user engaged in discussion, and you used the Stage 3 exit gate (AskUserQuestion with Proceed/Keep discussing/Abandon). (If there was no exit gate interaction, Stage 3 was skipped.)

This check exists because the most common failure mode is jumping from a detailed user request straight to writing a plan. A detailed request makes Stages 1-3 faster, not unnecessary — fast research still catches things the user missed, and fast discussion still validates your approach.

## Rules

- This is the ONLY stage where files are created or modified
- Product docs are updated in Step 2, architecture/standards in Step 3 — do it now, not as plan tasks
- After plan file is written: approval gate via AskUserQuestion
- After approval: commit, print execution command, STOP

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

4. **Check for existing plan** — if `documentation/plans/*-{name}/` exists (suffix match), read it for revision context

5. **Check for stub plan** — if the matched plan has `Status: Stub` and `Source: Roadmap`:
   - Do NOT re-create the directory — it already exists with `shared/` and `tasks/`
   - You will edit the existing `README.md` in place (Step 5) rather than overwriting it
   - Skip to Step 2 (the plan number and directory are already determined)

**Create the directory** (skip if editing an existing stub):

```bash
mkdir -p documentation/plans/{NNN}-{name}/{shared,tasks}
```

```
documentation/plans/001-user-auth/
├── README.md          # The plan document (task list embedded)
├── plan.json          # Dashboard status (created now, updated at approval and execution)
├── shared/            # Lead-level shared notes (created empty, used during execution)
└── tasks/             # Per-task pipeline artifacts (created empty, used during execution)
```

**Create `plan.json`** at plan root with initial pending status (no tasks array yet — that's populated on approval). Follow `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md` for the format. Set `status` to `"pending"`, all counts to 0.

**When upgrading a stub:** After editing the README status from Stub→Draft, verify `plan.json` at plan root has `"status": "pending"`.

## Step 2: Update Product Documentation — Mandatory

Documentation is not optional. This step ensures product docs exist and are current for the feature area being planned. Do it now, not as part of the plan you are building.

### Process

1. **Scan** `documentation/product/description/` and `documentation/product/requirements/` for docs covering the feature area
2. **If no relevant docs exist** — create them. Look up the correct reference in docs-manager's Document Type References table and read it before writing.
3. **If docs exist** — review against Stage 1-3 findings and update with any new information
4. **Follow docs-manager** routing rules for file naming, placement, and cross-referencing between doc types

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
4. **Follow docs-manager** routing rules for file naming, placement, and cross-referencing between doc types

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

### Task sizing rules

- **Split by feature, not by tech layer.** Each task delivers a complete vertical slice (database through API/UI). Never split into "backend task" and "frontend task" for the same feature. Testing is part of the execution pipeline, not a separate task.
- **Default to 1 task.** Only split when the work has two or more independent features that don't depend on each other.
- **Minimum ~7 files per task.** Each task spins up a full pipeline (Executor + Reviewer + Tester). If a change touches fewer than 7 files, absorb it into a larger task — the pipeline overhead isn't justified.
- **Maximum ~20 files per task.** If a task would touch more than 20 files, consider splitting — but only along feature boundaries, not arbitrary lines.

### Task fields

Each task heading MUST use the format: `### Task N: {Title} <!-- status:pending -->`

Immediately after the heading, add a completion checkbox: `- [ ] **Complete**`

Each task MUST also have:
- A clear description of what to build/change
- **Product context** — relevant product description or requirements files from Step 2
- Expected files to create or modify
- **Patterns** — relevant architecture/standards files from Step 3, with optional section hints (e.g., `documentation/technology/standards/error-handling.md` (API Error Responses section)). If none apply: `None identified`
- Success criteria (how to verify it's done)
- Dependencies on other tasks (if any)

## Step 5: Write Plan File

Write to `documentation/plans/{NNN}-{name}/README.md` via the Write tool — this is the canonical copy that `/uc:plan-execution` reads from. The plan is on disk before the user reviews it.

## Step 6: Present Summary and Request Approval

**Present a concise summary in chat** — NOT the full plan. Include: plan number, plan name, objective, task count, and the file path. The user can read the full plan from the file.

**Ask for approval via AskUserQuestion** — Options: "Approve" / "Reject with feedback" / "Partially reject (specify changes)"

**Approval gate rules — strictly enforce:**
- Only an explicit "Approve" selection counts as approval. Do NOT infer approval from empty, blank, ambiguous, or non-committal responses.
- If the user selects "Other" with empty or unclear text, re-ask the question. Say: "I need an explicit approval, rejection, or feedback before proceeding."
- Never skip or auto-approve this step. The plan is not approved until the user explicitly says so.

## Step 7: Post-Approval — HARD STOP

When the user explicitly approves the plan:

1. **Update status to Approved:**
   - Update README: change `> Status: Draft` → `> Status: Approved`
   - Update `plan.json` at plan root: set `"total_tasks"` and `"pending_tasks"` to the actual task count, and populate the `"tasks"` array with all tasks from the README (parse `### Task N: {name}` headings). Follow the format in `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md` — all tasks should be `pending` with minimal fields.
2. **Commit plan files** — Stage all plan files (README.md, plan.json, directories) and commit:
   ```
   git add documentation/plans/{NNN}-{name}/ && git commit -m "plan: {NNN}-{name}"
   ```
3. **Print execution command and instruct the user to run it in a new window:**
   ```
   Plan committed. To execute, open a new window and run:
   /uc:plan-execution {NNN}
   ```
4. **STOP.** Your turn ends here. No more output after printing the command. Do NOT:
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

1. Read their feedback
2. Edit the existing `documentation/plans/{NNN}-{name}/README.md` using the Edit tool to incorporate changes
3. Re-present the concise summary with changes highlighted
4. Re-ask for approval via AskUserQuestion

Repeat until approved or the user abandons the plan.

