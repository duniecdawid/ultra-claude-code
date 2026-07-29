# Phase 5: Completion

### 5.1 All Tasks Done

When all tasks reach "done" stage (all task-teams have exited).

### 5.2 Final Gate

**Skip this step only if the plan has 1 task AND `documentation/technology/testing/final-gate.md` does not exist** (`[ -f documentation/technology/testing/final-gate.md ]`) — in that case the per-task tester already ran the full suite, so proceed directly to 5.3. If `final-gate.md` exists, always run the final gate even for a single-task plan: its gate-specific criteria (thresholds, smoke targets, cross-task regression checklist) are deliberately skipped during per-task testing, so this is the only place they are evaluated.

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
