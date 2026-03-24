# Phase 4: Failure Handling

## Retry Flow (Team-Internal)

Failures are handled entirely within the task-team — no Lead involvement:

1. Reviewer/Tester sends FAIL verdict directly to Executor
2. Executor fixes code, updates `tasks/task-N/impl.md`
3. Executor tells Reviewer/Tester "ready for re-review/re-test"
4. Same Reviewer/Tester re-evaluates (they're still alive with full context)
5. Repeat up to 10 fix cycles total

If 10 cycles exceeded: Executor tells Lead "escalation needed" with history.

## Escalation to User

When the Lead receives an escalation:

```
Task "{name}" has exceeded 10 fix cycles.

Latest failure:
  {reviewer/tester feedback summary}

Fix history:
  {brief summary of each cycle's feedback}

Options:
1. Provide additional guidance for the executor
2. Skip this task
3. Abort execution
```

## Team Member Crash

Lead detects: idle notification without preceding "task done" message, or extended silence.

Recovery:
1. Re-spawn the crashed role into the existing team with per-task file context
2. Include names of surviving teammates in the spawn prompt
3. Surviving teammates continue — Executor drives re-coordination
4. Log crash in `shared/lead.md`

## Session Death

Handled automatically by Phase 1.2 (Resume Detection) when user reruns `/uc:plan-execution $ARGUMENTS`. Checkpoint + `shared/lead.md` + `tasks/*/` files preserve all progress. Lead reconstructs task state from metadata.stage and per-task files on disk, then re-spawns teams for incomplete tasks.
