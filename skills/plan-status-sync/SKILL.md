---
description: Sync plan and task statuses across README files and execution state JSON. Scans documentation/plans/ for stale statuses, infers correct state from execution artifacts, updates READMEs and creates/fixes plan.json for external consumers. Use when plan statuses are out of date, execution state shows wrong data, after recovering from crashed executions, or to audit plan state. Triggers on "sync plan status", "fix plan status", "plan status cleanup", "update plan statuses", "fix execution state".
user-invocable: true
---

# Plan Status Sync

Scan all plans and reconcile statuses in both README files and execution state JSON (`plan.json` at plan root) with actual execution artifacts.

**For the canonical plan.json format, read `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md`.**

## Step 1: Discover Plans

Glob for `documentation/plans/*/README.md`. If none found, inform user and stop.

## Step 2: Analyze Each Plan

For each plan directory, read:

1. **README.md** — current `> Status:` line, task checkbox states in the flat task heading index, and task count
2. **plan.json** (at plan root) — if exists, check `"status"` field and `"ended_at"`
3. **operational-report.md** — if exists, plan completed
4. **shared/lead.md** — if contains `## Execution Complete`, check which tasks are listed as completed
5. **checkpoint-*.md** — if exist, execution was at least started
6. **Git history** — `git log --oneline --diff-filter=A -- documentation/plans/{PLAN_NAME}/` to get creation date

**Do NOT read per-task content from README sections.** In the new layout, the README is a plan-level overview + flat task heading index only. Per-task content (description, files, patterns, success criteria, research pointers, dependencies) lives in `tasks/task-N/task.md`. This skill only cares about plan-level status and task checkbox markers — it does not read or write per-task content. If you need a task's goal for display purposes, read it from `tasks/task-N/task.md`'s Description field (not from README).

**Legacy plans** with embedded per-task sections in README still work — the checkbox format is the same, and the status markers sit on the `### Task N:` headings regardless of whether per-task fields follow them inline. This skill does not split legacy plans; that's `/uc:plan-execution`'s Phase 1.1 self-heal on resume (or `/uc:migrate`).

### Status Inference Rules

| Artifacts Found | Inferred Status |
|----------------|----------------|
| `operational-report.md` exists | **Completed** |
| `plan.json` with `"status": "completed"` | **Completed** |
| `shared/lead.md` with `## Execution Complete` | **Completed** |
| `plan.json` with `"status": "in_progress"` but no report | **In Progress** (likely abandoned) |
| `checkpoint-*.md` exists but no report | **In Progress** |
| `plan.json` with `"status": "planning"` and no execution artifacts | **Planning** (preserve — plan is still being shaped) |
| `plan.json` with `"status": "stub"` and no execution artifacts | **Stub** (preserve — roadmap stub awaiting feature-mode) |
| `plan.json` with `"status": "approved"` and no execution artifacts | **Approved** (preserve — plan ready for execution) |
| `plan.json` with `"status": "cancelled"` | **Cancelled** (preserve — abandoned planning session; number retained, directory intact; never re-infer as stub/planning) |
| README `Status: Stub` and no plan.json | **Stub** |
| README `Status: Draft` and no plan.json | **Planning** |
| README `Status: Approved` and no plan.json | **Approved** |
| README `Status: Cancelled` and no plan.json | **Cancelled** |
| No artifacts and no recognizable README status | **Planning** (conservative default) |

**Legacy compatibility:** Older plans may have `status/plan.json` instead of `plan.json` at root, or may use old status values. Treat these as equivalent: `executing` → `in_progress`, legacy plan-level `"pending"` → `"approved"` (mirrors the read-side alias that downstream consumers apply). README headers still use `Stub`, `Draft`, `Approved`, `In Progress`, `Completed`.

**Plans without PM tracking:** If a plan has no `plan.json` but DOES have execution artifacts (`shared/lead.md`, task directories with `impl.md` or `plan.md` files), infer status from those artifacts using the rules above.

### Task Completion Inference

For plans inferred as **Completed**, determine which tasks finished:

1. Read `shared/lead.md` — the "Tasks Completed" section lists finished tasks
2. Read `plan.json` tasks array — check for `"status": "completed"` on each task
3. Check for `tasks/task-N/impl.md` existence — if impl.md exists, the task was at minimum implemented (Executor writes impl.md during its Phase 4.5, after review/test passes trigger shutdown)
4. Cross-reference task numbers with README headings (the flat task index)

For plans inferred as **In Progress**, check completed tasks the same way — some tasks may have finished before execution stopped.

## Step 3: Present Changes

Show a summary table:

```
Plan                    | README Status | State JSON Status | Correct Status | Tasks
------------------------|--------------|-----------------|----------------|------
001-user-auth           | Approved     | (no JSON)       | Completed      | 3/3 done
002-api-refactor        | Approved     | in_progress     | In Progress    | 1/4 done
003-new-feature         | Draft        | (no JSON)       | Planning       | (no change)
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

### 4b. Create or Update Execution State JSON

For plans that need execution state fixes, create or update `plan.json` at plan root. Follow `${CLAUDE_PLUGIN_ROOT}/references/plan-status-format.md` for the canonical format.

**If `plan.json` doesn't exist**, create it: populate plan-level fields and the `tasks` array from README task headings, with per-task statuses inferred from artifacts (Step 2).

**If `plan.json` exists but has wrong status**, update the `"status"` and `"ended_at"` fields, and ensure the `tasks` array exists with correct per-task statuses.

**Status value mapping:**
- Inferred "Completed" → `"status": "completed"`
- Inferred "In Progress" → `"status": "in_progress"`
- Inferred "Planning" (plan.json has `"planning"` status, no execution artifacts) → `"status": "planning"` (preserve as-is)
- Inferred "Stub" (README `Status: Stub` or plan.json already `"stub"`) → `"status": "stub"`
- Inferred "Approved" (README `Status: Approved`, plan.json already `"approved"`, or legacy plan.json `"pending"`) → `"status": "approved"`
- Inferred "Cancelled" (plan.json already `"cancelled"`, or README `Status: Cancelled`) → `"status": "cancelled"` (preserve — never re-infer as stub/planning)
- Inferred "Draft" (README `Status: Draft`) → `"status": "planning"`
- Anything else (no README status, no artifacts) → `"status": "planning"` (conservative default)

**Preserve the plan-level `stage` field.** If `plan.json` carries a top-level `stage` field (set by planning modes while `status` is `"planning"`), copy it through unchanged — this skill never invents, advances, or clears `stage`. It is owned by the planning framework, not by sync.

**Legacy migration:** If `status/plan.json` exists but `plan.json` at root does not, read from `status/plan.json`, migrate status values, add tasks array, and write to `plan.json` at root. Optionally remove the old `status/` directory.

Also create `events.json` at plan root if missing (for completed plans):

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
- K plan.json files created or fixed
- T task checkboxes checked off

Review changes with `git diff`, then commit if correct.
```
