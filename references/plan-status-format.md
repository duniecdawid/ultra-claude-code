# Plan Status Format

All plan and task execution state lives in a single file: `documentation/plans/{slug}/plan.json`.
Do NOT create individual task files or a `status/` directory.

Re-write the entire file on each update. Keep `events.json` separate at the plan root (`documentation/plans/{slug}/events.json`) for the event log.

## Format

```json
{
  "name": "{PLAN_NAME}",
  "description": "One-line plan description from README",
  "plan_file": "documentation/plans/{slug}/README.md",
  "status": "in_progress",
  "stage": null,
  "started_at": "2026-04-04T12:47:09.000Z",
  "ended_at": null,
  "concurrency_limit": 2,
  "total_tasks": 4,
  "completed_tasks": 1,
  "active_tasks": 1,
  "pending_tasks": 2,
  "tasks": [
    {
      "task_id": "task-1",
      "task_name": "Task name from README",
      "status": "completed",
      "goal": "Success criteria summary",
      "type": "code",
      "executor_model": "opus",
      "dependencies": [],
      "started_at": "2026-04-04T12:49:52.000Z",
      "ended_at": "2026-04-04T13:10:00.000Z",
      "retry_count": 0,
      "stages": {
        "planning":       { "started_at": "...", "ended_at": "..." },
        "implementation": { "started_at": "...", "ended_at": "..." },
        "review":         { "started_at": "...", "ended_at": "..." },
        "testing":        { "started_at": "...", "ended_at": "..." }
      },
      "members": [
        { "name": "executor-1", "role": "executor", "model": "opus", "status": "completed", "spawned_at": "...", "ended_at": "..." },
        { "name": "reviewer-1", "role": "reviewer", "model": "sonnet", "status": "completed", "spawned_at": "...", "ended_at": "..." },
        { "name": "tester-1", "role": "tester", "model": "sonnet", "status": "completed", "spawned_at": "...", "ended_at": "..." }
      ],
      "budget": {
        "start_pct": 12,
        "end_pct": 17,
        "cost_pct": 5,
        "completed_at": "2026-04-04T13:10:00.000Z"
      }
    },
    {
      "task_id": "task-2",
      "task_name": "Second task from README",
      "status": "in_progress",
      "goal": "Success criteria summary",
      "dependencies": ["task-1"],
      "started_at": "2026-04-04T13:11:00.000Z",
      "ended_at": null,
      "retry_count": 0,
      "stages": {
        "planning":       { "started_at": "...", "ended_at": "..." },
        "implementation": { "started_at": "...", "ended_at": null },
        "review":         { "started_at": null, "ended_at": null },
        "testing":        { "started_at": null, "ended_at": null }
      },
      "members": [
        { "name": "executor-1", "role": "executor", "model": "opus", "status": "active", "spawned_at": "...", "ended_at": null }
      ]
    },
    {
      "task_id": "task-3",
      "task_name": "Third task from README",
      "status": "pending",
      "dependencies": ["task-1", "task-2"]
    },
    {
      "task_id": "task-4",
      "task_name": "Fourth task from README",
      "status": "pending",
      "dependencies": []
    }
  ]
}
```

## Field Notes

**`name`**: Always use the full plan directory name (`PLAN_NAME`) — the slug that includes the number prefix (e.g., `012-dedicated-plan-page-v2`). Do NOT extract the name from the plan README title or strip the number prefix. The directory name is the canonical identifier.

**`type` / `executor_model`**: from the task.md classification (`references/planning-framework/task-classification.md`); absent = `code` / `opus`. For an `ops` task, `stages.review`/`stages.testing` stay `null` and `members` holds only the executor.

## Plan-Level `stage` Field (distinct from per-task `stages`)

The optional top-level **`stage`** field tracks which of the four planning-framework stages a plan is currently in **while it is being planned** (`status: "planning"`). It is a single string (or `null`), set by the planning modes:

| Value | Meaning | When set |
|-------|---------|----------|
| `"research"` | Stage 2 (Research) | Written when the Stage 1 skeleton is scaffolded (end of Stage 1) — the first persisted value |
| `"discuss"` | Stage 3 (Discuss) | On entering Stage 3 |
| `"write"` | Stage 4 (Write) | On entering Stage 4 |
| `null` | No active planning stage | Cleared on approval (`status` → `approved`); also `null` for any plan that isn't in `planning` |

`"understand"` (Stage 1) is a valid conceptual value but is **never persisted** — the skeleton does not exist yet during Stage 1 Understand, so the earliest value ever written to disk is `"research"`. The set written to disk is therefore `{research, discuss, write, null}`.

> **Do not confuse `stage` with the per-task `stages` object.** `stage` is a **plan-level** string tracking the *planning* phase (research/discuss/write). The per-task **`stages`** object (inside each task) tracks *execution pipeline* timing (`planning`/`implementation`/`review`/`testing` with `started_at`/`ended_at`). They are unrelated — one is about shaping the plan, the other about executing a task.

The dashboard surfaces `stage` as a "Stage N of 4 — {Stage}" indicator, shown only while `status === "planning"`.

## Per-Task Budget

The optional `budget` object tracks usage-limit percentage at task start and end. Written by PM:

| Field | When written | Source |
|-------|-------------|--------|
| `start_pct` | On `SPAWNED task-{N}` | PM reads `usage-status.json` |
| `end_pct` | On `COMPLETED task-{N}, current_pct={Y}` | From Lead's message |
| `cost_pct` | On `COMPLETED` | `end_pct - start_pct` |
| `completed_at` | On `COMPLETED` | ISO timestamp |

Tasks that haven't started yet have no `budget` field. In-progress tasks have only `start_pct`. PM uses the accumulated budget data to compute `avg_cost_pct` for soft-limit alert context.

## Dependencies

The `dependencies` field is an array of task IDs (e.g., `["task-1", "task-3"]`) that must complete before this task can start. An empty array `[]` or omitting the field means no dependencies. The field is optional — plans without dependencies in any task ingest cleanly.

## Allowed Status Values

| Field         | Allowed values                          |
|---------------|-----------------------------------------|
| Plan status   | `stub`, `planning`, `approved`, `in_progress`, `completed`, `cancelled` |
| Task status   | `pending`, `in_progress`, `completed`, `failed` |
| Member status | `active`, `completed`, `failed`         |

`cancelled` marks a planning session that was abandoned after its skeleton was scaffolded (Stage 3 Abandon or Stage 4 give-up). The plan directory and its number are **retained** — the number stays reserved and the plan remains visible as a tombstone rather than disappearing. Re-running a planning mode against the same name resurrects the plan in place under the same number (`status` → `planning`).

**Never** use `executing`, `implementing`, `reviewing`, `testing`, `escalated`, `idle`, `crashed`, `rate-limited`, or any other value in a task or member status field. Pipeline stage is tracked in the `stages` object, not the status. (`planning` is valid at the plan level only — not for tasks or members.)

## Active Stage Detection

Since task status is always `in_progress` during execution (never `planning`, `reviewing`, etc.), determine the current pipeline stage by finding the stage in the `stages` object with `started_at` set but `ended_at` null. Multiple stages can be active simultaneously (e.g., `review` and `testing` run in parallel).

## File Locations

```
documentation/plans/{slug}/
├── README.md        # Plan document (plan-level overview + flat task heading index only)
├── plan.json        # All plan + task state (this format)
├── events.json      # Event log (append-style, separate)
├── shared/
│   └── lead.md      # Lead-level shared notes and amendments log
├── tasks/
│   ├── task-1/
│   │   ├── task.md  # Authoritative per-task content (description, files, patterns, research pointers, success criteria, dependencies). Written by planning mode in Stage 4; Lead amends at spawn time or mid-execution.
│   │   ├── plan.md  # Executor's thin execution delta (written in Phase 3)
│   │   └── impl.md  # Executor's implementation delta (written in Phase 4.5)
│   └── task-2/
│       └── ...
└── ...
```

**README is not a source of per-task content.** Everything per-task lives in `tasks/task-N/task.md`. The README holds plan-level content (Objective, Context, Tech Stack narrative, Scope, Success Criteria, Documentation Changes, Risk Assessment) plus a flat task heading index with status markers (`### Task N: {Title} <!-- status:pending -->` followed by `- [ ] **Complete**`) for the plan-status-sync skill and Project Manager execution state tracking.
