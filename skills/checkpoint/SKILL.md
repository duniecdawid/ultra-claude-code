---
description: Save execution state for session recovery. Captures per-task pipeline stages, active team assignments, decisions, and blockers to plan directory. Use when context is long, stopping mid-execution, or as periodic progress save.
user-invocable: true
argument-hint: "plan name (optional — auto-detected from active execution)"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
---

# Checkpoint

Save current execution state to a checkpoint file so the session can be recovered later. This is the persistence mechanism that makes plan execution resilient to session death.

## When to Use

- **During execution** — periodic save every 3 completed tasks
- **On user request** — `/uc:checkpoint` or `/uc:checkpoint {plan-name}`
- **Before stopping** — manual save before ending a session
- **Before risky changes** — save state before attempting something uncertain

## Process

### Step 1: Identify the Active Plan

If `$ARGUMENTS` provides a plan name, use it. Otherwise:

1. Check `documentation/plans/` for directories with active execution state
2. Look for plans with existing `shared/` directory contents (indicates execution started)
3. If multiple plans are active, ask the user which one to checkpoint
4. If no plan is active, inform the user there's nothing to checkpoint

### Step 2: Gather Checkpoint Data

Collect from the current session:

**Task Pipeline States:**
- Read TaskList to get all tasks
- Record each task's pipeline stage from metadata: pending, research, impl, review, test, done
- Record retry count for tasks that have been through fix cycles

**Active Pipeline Teams:**
- Which task-teams are currently running
- Which team members are spawned for each task (by role and name)
- What pipeline stage each team is in (research, impl, review, test)

**Execution Decisions:**
- Decisions made by Lead during this session
- Plan amendments (if any tasks were modified mid-execution)
- Escalations and their outcomes

**Blockers:**
- Tasks that are blocked and why
- Escalations to user that are pending

**Files Modified:**
- List files created or modified during this execution session

### Step 3: Write Checkpoint File

Write to `documentation/plans/{plan-name}/checkpoint-{YYYY-MM-DD-HHmm}.md`:

```markdown
# Checkpoint: {plan-name}

**Saved:** {ISO timestamp}
**Session:** {brief description of what this session accomplished}

## Active Pipeline Teams

| Task | Active Team Members | Notes |
|------|---------------------|-------|
| task-1 | R-1, E-1, Rev-1, T-1 | Reviewer active |
| task-2 | R-2, E-2, Rev-2, T-2 | Awaiting plan feedback |

## Task Pipeline Status

| # | Task | Stage | Retry | Notes |
|---|------|-------|-------|-------|
| 1 | {title} | {pending/research/impl/review/test/done} | {0-10} | {notes} |
| 2 | {title} | {pending/research/impl/review/test/done} | {0-10} | {notes} |

## Progress Summary

- **Done:** {N}/{total} tasks
- **In pipeline:** {M} tasks (research: {A}, impl: {B}, review: {C}, test: {D})
- **Pending:** {K} tasks

## Decisions Made This Session

- {Decision}: {rationale}

## Files Modified

- `{path}` — {created/modified} — {purpose}

## Blockers

- {Blocker description}: {status}

## Next Steps (for Resume)

1. {What should happen first on resume}
2. {What should happen next}
3. {Any tasks that need special attention}
```

### Step 4: Confirm to User

After writing the checkpoint:

```
Checkpoint saved to:
  documentation/plans/{plan-name}/checkpoint-{timestamp}.md

Progress: {N}/{total} tasks complete. {M} in pipeline.

To resume later:
  /uc:plan-execution {plan-name}
  (Lead will detect the checkpoint and offer to resume)
```

## Checkpoint Triggers

| Trigger | Who Initiates | Behavior |
|---------|--------------|----------|
| User `/uc:checkpoint` | User | Full checkpoint with confirmation |
| Every 3 completed tasks | Lead (automatic) | Lightweight checkpoint, no user prompt |
| Before plan amendments | Lead (automatic) | Save state before risky changes |

## Resume Compatibility

The checkpoint format is designed to be parseable by the Lead on resume. Critical fields:
- **Task Pipeline Status** — Lead reconstructs task state from stage + per-task files on disk
- **Active Pipeline Teams** — Lead knows which task-teams to re-spawn (and which roles within each)
- **Progress Summary** — Lead skips completed work
- **Next Steps** — Lead prioritizes what to do first

On resume, the Lead:
1. Reads the latest checkpoint
2. Reads `shared/lead.md` for accumulated decisions
3. Reads `tasks/*/` files for per-task pipeline artifacts
4. Rebuilds task list from checkpoint data
5. Re-spawns teams for incomplete tasks using existing per-task files as context

## Constraints

- Do NOT modify the plan README.md — checkpoints are separate files
- Do NOT overwrite previous checkpoints — each gets a unique timestamp
- Do NOT checkpoint if there's no active execution (inform user instead)
- Do NOT include full code snippets — reference file paths
- Keep checkpoint files under 200 lines — focus on state, not narrative
