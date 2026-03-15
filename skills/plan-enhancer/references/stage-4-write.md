# Stage 4: Write

Mandatory for ALL planning modes — no exceptions.

**Purpose:** All file writing happens here — documentation updates, plan scaffolding, plan README. Then approval gate. Then post-approval (commit + print execution command + hard stop).

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

**Create the directory:**

```bash
mkdir -p documentation/plans/{NNN}-{name}/shared documentation/plans/{NNN}-{name}/tasks
```

```
documentation/plans/001-user-auth/
├── README.md          # The plan document (task list embedded)
├── shared/            # Lead-level shared notes (created empty, used during execution)
└── tasks/             # Per-task pipeline artifacts (created empty, used during execution)
```

## Step 2: Update Product Documentation

This is when you update product documentation — do it now, not as part of the plan you are building.

Any changes in system behavior or requirements discovered during Stages 1-3 must be captured in:
- **`documentation/product/description/`** — product description files
- **`documentation/product/requirements/`** — requirements files

Update existing files if they already contain related content. Create new files if needed.

Track what you changed for use in the plan's Documentation Changes table:
- File path
- Action (created / updated)
- Summary of what was added (one sentence)

## Step 3: Review Architecture & Standards

Read all files from `documentation/technology/architecture/` and `documentation/technology/standards/`. Gracefully handle missing or empty directories (skip if not found).

Update architecture if there was a decision during Stages 1-3 that changes the system design, or if the plan requires architectural elements that are not yet documented. This is also a moment to challenge yourself and the user — does the proposed approach fit the existing architecture? Are there better alternatives? Design the technological changes that will be part of the plan.

Update existing files if they already contain related content. Create new files if needed.

Track:
- What you changed in architecture/standards docs
- Which standards are relevant to the plan (will populate each task's Patterns field)
- Which architecture elements are relevant to the plan

## Step 4: Build and Validate Plan

Build the plan using the loaded plan template including the `Execute: /uc:plan-execution {NNN}` header.

Reference the documentation updated in Steps 2-3 — do not duplicate content. Each task's **Product context** and **Patterns** fields should point to the relevant files, not restate what's in them.

### Task sizing rules

- **Split by feature, not by tech layer.** Each task delivers a complete vertical slice (database through API/UI). Never split into "backend task" and "frontend task" for the same feature. Testing is part of the execution pipeline, not a separate task.
- **Default to 1 task.** Only split when the work has two or more independent features that don't depend on each other.
- **Minimum ~7 files per task.** Each task spins up a full pipeline (Executor + Reviewer + Tester). If a change touches fewer than 7 files, absorb it into a larger task — the pipeline overhead isn't justified.
- **Maximum ~20 files per task.** If a task would touch more than 20 files, consider splitting — but only along feature boundaries, not arbitrary lines.

### Task fields

Each task MUST have:
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

1. **Commit plan files** — Stage all plan files (README.md, directories) and commit:
   ```
   git add documentation/plans/{NNN}-{name}/ && git commit -m "plan: {NNN}-{name}"
   ```
2. **Print execution command and instruct the user to run it in a new window:**
   ```
   Plan committed. To execute, open a new window and run:
   /uc:plan-execution {NNN}
   ```
3. **STOP.** Your turn ends here. No more output after printing the command. Do NOT:
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

