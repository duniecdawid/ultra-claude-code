---
description: Save execution state for session recovery. Captures all 4 task list states, active teammate assignments, decisions, and blockers to plan directory. Use when context is long, stopping mid-execution, or as periodic progress save.
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
- **Before stopping** — the Stop hook also triggers this, but manual save is safer
- **Before risky changes** — save state before attempting something uncertain
- **On teammate idle** — when a teammate's task list empties

## Process

### Step 1: Identify the Active Plan

If `$ARGUMENTS` provides a plan name, use it. Otherwise:

1. Check `documentation/plans/` for directories with active execution state
2. Look for plans with existing `shared/` directory contents (indicates execution started)
3. If multiple plans are active, ask the user which one to checkpoint
4. If no plan is active, inform the user there's nothing to checkpoint

### Step 2: Gather Checkpoint Data

Collect from the current session:

**Task List States (all 4 role-separated lists):**
- Read TaskList to get all tasks across all 4 lists
- Record status of each: pending, in_progress, completed, failed
- Record owner (which teammate) for in_progress tasks
- Record retry count for failed tasks

**Active Teammates:**
- Which teammates are currently spawned (by role)
- What each is working on (current in_progress task)
- Model and configuration used

**Execution Decisions:**
- Decisions made by Lead during this session
- Plan amendments (if any tasks were modified mid-execution)
- Re-queued tasks with failure context

**Blockers:**
- Tasks that are blocked and why
- Escalations to user that are pending

**Files Modified:**
- List files created or modified during this execution session

### Step 3: Write Checkpoint File

Write to `documentation/plans/{plan-name}/checkpoint-{YYYY-MM-DD-HHMMSS}.md`:

```markdown
# Checkpoint: {plan-name}

**Saved:** {ISO timestamp}
**Session:** {brief description of what this session accomplished}

## Team Composition

| Role | Model | Status |
|------|-------|--------|
| Researcher | sonnet | {active/idle/not-spawned} |
| Executor 1 | opus | {active/idle/not-spawned} |
| Executor 2 | opus | {active/idle/not-spawned} |
| Code Reviewer | sonnet | {active/idle/not-spawned} |
| Tester | sonnet | {active/idle/not-spawned} |

## Task Lists

### Research Tasks
| # | Task | Status | Owner | Notes |
|---|------|--------|-------|-------|
| 1 | {title} | {pending/in_progress/completed} | {teammate or —} | {notes} |

### Implementation Tasks
| # | Task | Status | Owner | Retries | Notes |
|---|------|--------|-------|---------|-------|
| 1 | {title} | {pending/in_progress/completed/failed} | {teammate or —} | {0-2} | {notes} |

### Review Tasks
| # | Task | Status | Owner | Result | Notes |
|---|------|--------|-------|--------|-------|
| 1 | {title} | {pending/in_progress/completed} | {reviewer or —} | {PASS/FAIL/—} | {notes} |

### Testing Tasks
| # | Task | Status | Owner | Result | Notes |
|---|------|--------|-------|--------|-------|
| 1 | {title} | {pending/in_progress/completed} | {tester or —} | {PASS/FAIL/—} | {notes} |

## Progress Summary

- **Research:** {N}/{total} complete
- **Implementation:** {N}/{total} complete
- **Review:** {N}/{total} complete ({M} passed, {K} failed)
- **Testing:** {N}/{total} complete ({M} passed, {K} failed)

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

Progress: {N}/{total} tasks complete across all stages.

To resume later:
  /uc:plan-execution {plan-name}
  (Lead will detect the checkpoint and offer to resume)
```

## Checkpoint Triggers

| Trigger | Who Initiates | Behavior |
|---------|--------------|----------|
| User `/uc:checkpoint` | User | Full checkpoint with confirmation |
| Every 3 completed tasks | Lead (automatic) | Lightweight checkpoint, no user prompt |
| Teammate idle | Lead (automatic) | Checkpoint when a role's list empties |
| Stop hook | System | Emergency checkpoint before session end |

## Resume Compatibility

The checkpoint format is designed to be parseable by the Lead on resume. Critical fields:
- **Task Lists** — Lead rebuilds TaskCreate/TaskUpdate from these tables
- **Team Composition** — Lead knows which teammates to re-spawn
- **Progress Summary** — Lead skips completed work
- **Next Steps** — Lead prioritizes what to do first

## Constraints

- Do NOT modify the plan README.md — checkpoints are separate files
- Do NOT overwrite previous checkpoints — each gets a unique timestamp
- Do NOT checkpoint if there's no active execution (inform user instead)
- Do NOT include full code snippets — reference file paths
- Keep checkpoint files under 200 lines — focus on state, not narrative
