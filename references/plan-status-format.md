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
  "started_at": "2026-04-04T12:47:09.000Z",
  "ended_at": null,
  "elapsed_seconds": 325,
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
      "dependencies": [],
      "started_at": "2026-04-04T12:49:52.000Z",
      "ended_at": "2026-04-04T13:10:00.000Z",
      "elapsed_seconds": 1208,
      "retry_count": 0,
      "stages": {
        "planning":       { "started_at": "...", "ended_at": "...", "elapsed_seconds": 144 },
        "implementation": { "started_at": "...", "ended_at": "...", "elapsed_seconds": 800 },
        "review":         { "started_at": "...", "ended_at": "...", "elapsed_seconds": 120 },
        "testing":        { "started_at": "...", "ended_at": "...", "elapsed_seconds": 144 }
      },
      "members": [
        { "name": "executor-1", "role": "executor", "model": "opus", "status": "completed", "spawned_at": "...", "ended_at": "..." },
        { "name": "reviewer-1", "role": "reviewer", "model": "sonnet", "status": "completed", "spawned_at": "...", "ended_at": "..." },
        { "name": "tester-1", "role": "tester", "model": "sonnet", "status": "completed", "spawned_at": "...", "ended_at": "..." }
      ]
    },
    {
      "task_id": "task-2",
      "task_name": "Second task from README",
      "status": "in_progress",
      "goal": "Success criteria summary",
      "dependencies": ["task-1"],
      "started_at": "2026-04-04T13:11:00.000Z",
      "ended_at": null,
      "elapsed_seconds": 60,
      "retry_count": 0,
      "stages": {
        "planning":       { "started_at": "...", "ended_at": "...", "elapsed_seconds": 30 },
        "implementation": { "started_at": "...", "ended_at": null, "elapsed_seconds": 30 },
        "review":         { "started_at": null, "ended_at": null, "elapsed_seconds": 0 },
        "testing":        { "started_at": null, "ended_at": null, "elapsed_seconds": 0 }
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

## Dependencies

The `dependencies` field is an array of task IDs (e.g., `["task-1", "task-3"]`) that must complete before this task can start. An empty array `[]` or omitting the field means no dependencies. The field is optional — plans without dependencies in any task ingest cleanly.

## Allowed Status Values

| Field         | Allowed values                          |
|---------------|-----------------------------------------|
| Plan status   | `pending`, `in_progress`, `completed`   |
| Task status   | `pending`, `in_progress`, `completed`, `failed` |
| Member status | `active`, `completed`, `failed`         |

**Never** use `executing`, `implementing`, `planning`, `reviewing`, `testing`, `escalated`, `idle`, `crashed`, `rate-limited`, or any other value in a status field. Pipeline stage is tracked in the `stages` object, not the status.

## Active Stage Detection

Since task status is always `in_progress` during execution (never `planning`, `reviewing`, etc.), determine the current pipeline stage by finding the stage in the `stages` object with `started_at` set but `ended_at` null. Multiple stages can be active simultaneously (e.g., `review` and `testing` run in parallel).

## File Locations

```
documentation/plans/{slug}/
├── README.md        # Plan document with task list
├── plan.json        # All plan + task state (this format)
├── events.json      # Event log (append-style, separate)
├── shared/          # Lead-level shared notes
├── tasks/           # Per-task pipeline artifacts
└── ...
```
