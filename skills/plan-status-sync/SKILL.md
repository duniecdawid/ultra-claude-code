---
description: Sync plan and task statuses across README files and dashboard JSON. Scans documentation/plans/ for stale statuses, infers correct state from execution artifacts, updates READMEs and creates/fixes status/project.json for the Ultra Dashboard. Use when plan statuses are out of date, dashboard shows wrong columns, after recovering from crashed executions, or to audit plan state. Triggers on "sync plan status", "fix plan status", "plan status cleanup", "update plan statuses", "fix dashboard statuses".
user-invocable: true
---

# Plan Status Sync

Scan all plans and reconcile statuses in both README files and dashboard JSON (`status/project.json`) with actual execution artifacts.

## Step 1: Discover Plans

Glob for `documentation/plans/*/README.md`. If none found, inform user and stop.

## Step 2: Analyze Each Plan

For each plan directory, read:

1. **README.md** — current `> Status:` line, task checkbox states, and task count
2. **status/project.json** — if exists, check `"status"` field and `"ended_at"`
3. **operational-report.md** — if exists, plan completed
4. **shared/lead.md** — if contains `## Execution Complete`, check which tasks are listed as completed
5. **checkpoint-*.md** — if exist, execution was at least started
6. **Git history** — `git log --oneline --diff-filter=A -- documentation/plans/{PLAN_NAME}/` to get creation date

### Status Inference Rules

| Artifacts Found | Inferred Status |
|----------------|----------------|
| `operational-report.md` exists | **Completed** |
| `status/project.json` with `"status": "completed"` | **Completed** |
| `shared/lead.md` with `## Execution Complete` | **Completed** |
| `status/project.json` with `"status": "executing"` but no report | **In Progress** (likely abandoned) |
| `checkpoint-*.md` exists but no report | **In Progress** |
| No execution artifacts at all | Keep current status (Draft/Approved/Stub) |

**Additional heuristic for plans without PM tracking:** Many plans were executed before the PM tracked status. If a plan has NO `status/` directory but DOES have execution artifacts (`shared/lead.md`, task directories with `impl.md` or `plan.md` files), infer status from those artifacts using the rules above.

### Task Completion Inference

For plans inferred as **Completed**, determine which tasks finished:

1. Read `shared/lead.md` — the "Tasks Completed" section lists finished tasks
2. Read `status/teams/task-*.json` — check for `"status": "completed"`
3. Check for `tasks/task-N/impl.md` existence — if impl.md exists, the task was at minimum implemented
4. Cross-reference task numbers with README headings

For plans inferred as **In Progress**, check completed tasks the same way — some tasks may have finished before execution stopped.

## Step 3: Present Changes

Show a summary table:

```
Plan                    | README Status | Dashboard Status | Correct Status | Tasks
------------------------|--------------|-----------------|----------------|------
001-user-auth           | Approved     | (no JSON)       | Completed      | 3/3 done
002-api-refactor        | Approved     | executing       | In Progress    | 1/4 done
003-new-feature         | Draft        | (no JSON)       | Draft          | (no change)
```

If no changes needed, inform user and stop.

## Step 4: Apply Changes

After user confirms, for each plan that needs updates:

### 4a. Update README

1. Read the plan README
2. Update the `> Status:` line to the inferred status
3. For completed tasks, change:
   - `<!-- status:pending -->` to `<!-- status:completed -->` on the task heading
   - `- [ ] **Complete**` to `- [x] **Complete**`
4. Write the updated README

For plans that **lack the checkbox format** (created before this feature), add it:
- Find `### Task N:` headings without `<!-- status: -->` comments
- Append `<!-- status:completed -->` or `<!-- status:pending -->` based on inference
- Add `- [x] **Complete**` or `- [ ] **Complete**` as the first bullet after the heading

### 4b. Create or Update Dashboard JSON

For plans that need dashboard status fixes, create or update `status/project.json`.

**If `status/project.json` doesn't exist**, create it:

```bash
mkdir -p documentation/plans/{PLAN_NAME}/status
```

```json
{
  "name": "{PLAN_NAME}",
  "description": "{Objective from README}",
  "plan_file": "documentation/plans/{PLAN_NAME}/README.md",
  "status": "{inferred status: completed|executing|pending}",
  "started_at": "{from git log or checkpoint timestamp, ISO format}",
  "ended_at": "{from operational-report timestamp or git log, null if not completed}",
  "elapsed_seconds": 0,
  "concurrency_limit": 0,
  "total_tasks": {N from README task count},
  "completed_tasks": {N from inference},
  "active_tasks": 0,
  "pending_tasks": {total - completed}
}
```

**If `status/project.json` exists but has wrong status**, update only the `"status"` and `"ended_at"` fields.

**Status value mapping for dashboard:**
- Inferred "Completed" → `"status": "completed"`
- Inferred "In Progress" → `"status": "executing"`
- Inferred "Draft"/"Approved" → don't create JSON (dashboard correctly shows these as "Planning")

Also create `status/events.json` if missing (for completed plans):

```json
{
  "events": [
    {
      "timestamp": "{started_at}",
      "type": "execution_started",
      "task_id": null,
      "agent": "plan-status-sync",
      "message": "Retroactively inferred from execution artifacts"
    },
    {
      "timestamp": "{ended_at}",
      "type": "execution_completed",
      "task_id": null,
      "agent": "plan-status-sync",
      "message": "Retroactively inferred from execution artifacts"
    }
  ]
}
```

## Step 5: Summary

Report what was changed:
```
Updated N plan(s):
- M README status lines updated
- K dashboard status/project.json files created or fixed
- T task checkboxes checked off

Review changes with `git diff`, then commit if correct.
```
