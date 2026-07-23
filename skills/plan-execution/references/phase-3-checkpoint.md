# Phase 3: Checkpoint

## Content

Write to `documentation/plans/$ARGUMENTS/checkpoint-{YYYY-MM-DD-HHmm}.md`:

```markdown
# Checkpoint: $ARGUMENTS

**Saved:** {ISO timestamp}

## Active Pipeline Teams

| Task | Active Team Members | Notes |
|------|---------------------|-------|
| task-1 | E-1, Rev-1, T-1 | In review stage |
| task-2 | E-2, Rev-2, T-2 | Implementing |

## Task Pipeline Status

| # | Task | Stage | Retry | Notes |
|---|------|-------|-------|-------|
| 1 | JWT middleware | done | 0 | All stages passed |
| 2 | Login endpoint | review | 1 | Retry after review fail |
| 3 | Env config | active | 0 | In implementation |
| 4 | User model | pending | 0 | Blocked by task 1 |
| 5 | Dashboard  | planning | 0 | Pipeline-spawned, awaiting task 3 |

## Progress Summary

- Done: N/{total} tasks
- In pipeline: M tasks (planning: A, impl: B, review: C, test: D)
- Pending: K tasks

## Decisions Made

- {decision}: {rationale}

## Files Modified

- {path} — {created/modified} — {purpose}

## Blockers

- {description}: {status}

## Usage State

- 5h: {none|soft}   (resets_at {ISO} when non-none)
- 7d: {none|soft|limit}   (resets_at {ISO} when non-none)
- tasks_in_progress: [task-2 (stage: review, retry: 1), task-3 (stage: impl, retry: 0)]
```

Note: `shared/lead.md` and `tasks/*/` files are already on disk — no need to duplicate in checkpoint. The Usage State section records the `## Usage Blocks` snapshot from `shared/lead.md` — nothing else; agents are never deliberately paused, and a limit death mid-task is crash-shaped (recovered by re-spawn + stage inference, phase-4). Populate it only when a `SENTINEL ADVISORY`/`SENTINEL NOTICE` records a soft/limit block — omit it for routine checkpoints.
