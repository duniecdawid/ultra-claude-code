# Phase 5: Completion

### 5.1 All Tasks Done

When all tasks reach "done" stage (all task-teams have exited).

### 5.2 Final Gate

Only `code` tasks count toward this gate — `ops` tasks produce no code to regress. **Skip this step if the plan has no code tasks, or if it has exactly 1 code task AND `documentation/technology/testing/final-gate.md` does not exist** (`[ -f documentation/technology/testing/final-gate.md ]`) — in that case the per-task tester already ran the full suite, so proceed directly to 5.3. If `final-gate.md` exists and the plan has any code task, always run the final gate: its gate-specific criteria (thresholds, smoke targets, cross-task regression checklist) are deliberately skipped during per-task testing, so this is the only place they are evaluated.

Spawn a single Final Gate Tester (fresh team member) for full regression suite:
- The Final Gate Tester self-labels its pane on startup — no labeling needed from you.
- Use the Final Gate Tester spawn prompt from `references/phase-2-spawn-prompts.md`
- If PASS: proceed to operational report
- If FAIL: evaluate whether to re-spawn task-teams for specific fixes or report to user

### 5.3 Collect Operational Report

SendMessage to the Project Manager (`pm-{PLAN_NAME}`): "Execution complete — write operational report"

The PM will:
1. Update the plan README status to "Completed"
2. Write the operational report to `operational-report.md`
3. Confirm when done

Wait for PM's confirmation that `operational-report.md` is saved.

Then send `shutdown_request` to the Project Manager.

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

1. All task-teams have already self-exited after their tasks passed
2. Final Gate Tester exits after reporting
3. Project Manager exits last (after delivering operational report)
4. Remove the sentinel registration (the plan is no longer a wake/advisory target for the limit sentinel):
   ```bash
   rm -f ~/.claude/ultra/sentinel/plans/{PLAN_NAME}.json
   ```
5. Keep plan directory with all artifacts (including `operational-report.md`, `tasks/task-N/task.md`/`plan.md`/`impl.md`, and `shared/lead.md`)
6. Present summary to user — mention that the operational report is available at `documentation/plans/$ARGUMENTS/operational-report.md`

### 5.6 Backlog Review

Runs for every plan, regardless of task types. Read all backlog items in `documentation/backlog/` and assess each against what this plan changed. Update statuses accordingly via the `uc:backlog` skill — e.g. close items the plan resolved, set `related_plan` where relevant; use your judgment on what applies. Tell the user what changed (or that nothing did).

Do this before the follow-up triage (SKILL.md § Phase 5, "Follow-up work"), and carry your picture of the existing backlog into it: a follow-up item that matches an existing backlog item updates/links the existing one instead of creating a duplicate.
