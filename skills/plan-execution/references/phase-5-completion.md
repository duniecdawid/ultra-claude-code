# Phase 5: Completion

### 5.2 Final Gate

Enter Phase 5 when all tasks hit "done" stage (all task-teams exited). Only `code` tasks count for gate — `ops` tasks produce no code to regress. **Skip step if plan has no code tasks, or exactly 1 code task AND `documentation/technology/testing/final-gate.md` not exist** (`[ -f documentation/technology/testing/final-gate.md ]`) — per-task tester already ran full suite, go straight to 5.3. If `final-gate.md` exists and plan has any code task, always run final gate: gate-specific criteria (thresholds, smoke targets, cross-task regression checklist) skipped on purpose in per-task testing — evaluated only here.

Spawn one Final Gate Tester (fresh team member) for full regression suite:
- Final Gate Tester self-labels pane on startup — no labeling from you.
- Use Final Gate Tester spawn prompt from `references/phase-2-spawn-prompts.md`
- PASS: go to operational report
- FAIL: decide — re-spawn task-teams for specific fixes, or report to user

### 5.3 Collect Operational Report

SendMessage to Project Manager (`pm-{PLAN_NAME}`): "Execution complete — write operational report"

PM will:
1. Update plan README status to "Completed"
2. Write operational report to `operational-report.md`
3. Confirm when done

Wait for PM confirm `operational-report.md` saved.

Then send `shutdown_request` to Project Manager.

### 5.4 Produce Summary

Append to `documentation/plans/$ARGUMENTS/shared/lead.md`:

```markdown
## Execution Complete

**Plan:** $ARGUMENTS
**Tasks:** N completed, M skipped, K escalated

### Tasks Completed
- {task}: {brief description of what was done}

### Files Modified
- {path} — {created/modified}

### Decisions Made During Execution
- {decision}: {rationale}

### Amendments
- {gap}: {what was missing} — {how it was handled: built in task N / escalated to user}

### Escalations
- ESC-{n} [{class}]: {answered — resolution / still open — standing order in effect}

### Test Results
- Per-task tests: X/Y passed
- Final gate (full suite): PASS/FAIL

### Follow-up Items
- {any recommendations or remaining work}
```

### 5.5 Shutdown

1. All task-teams already self-exited when tasks passed
2. Final Gate Tester exits after report
3. Project Manager exits last (after delivering operational report)
4. Remove sentinel registration (plan no longer wake/advisory target for limit sentinel):
   ```bash
   rm -f ~/.claude/ultra/sentinel/plans/{PLAN_NAME}.json
   ```
5. Keep plan directory with all artifacts (including `operational-report.md`, `tasks/task-N/task.md`/`plan.md`/`impl.md`, and `shared/lead.md`)
6. Present summary to user — mention that the operational report is available at `documentation/plans/$ARGUMENTS/operational-report.md`

### 5.6 Backlog Review

Runs for every plan, regardless of task types. Read all backlog items in `documentation/backlog/` and assess each against what this plan changed. Update statuses accordingly via the `uc:backlog` skill — e.g. close items the plan resolved, set `related_plan` where fits; use judgment. Tell user what changed (or nothing changed).

Do before follow-up triage (SKILL.md § Phase 5, "Follow-up work"), carry backlog picture into it: follow-up item matching existing backlog item → update/link existing, never a duplicate.
