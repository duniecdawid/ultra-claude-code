# Phase 5: Completion

### 5.1 All Tasks Done

When all tasks reach "done" stage (all task-teams have exited).

### 5.2 Final Gate

Spawn a single Final Gate Tester (fresh team member) for full regression suite:
- The Final Gate Tester uses the tester agent which has Bash, but it won't self-label (its spawn prompt doesn't include a labeling instruction). Use pane-diffing to find the new pane, then label it:
  ```bash
  tmux set-option -p -t {NEW_PANE} @agent-name "final-gate"
  ```
  The layout watcher will automatically detect the label and add a final-gate column.
- Use the Final Gate Tester spawn prompt from `references/phase-2-spawn-prompts.md`
- If PASS: proceed to operational report
- If FAIL: evaluate whether to re-spawn task-teams for specific fixes or report to user

### 5.3 Collect Operational Report

SendMessage to the Project Manager (`pm-{PLAN_NAME}`): "Execution complete — write operational report"

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

### Test Results
- Per-task tests: X/Y passed
- Final gate (full suite): PASS/FAIL

### Follow-up Items
- {any recommendations or remaining work}
```

### 5.5 Shutdown

1. All task-teams have already self-exited after their tasks passed
2. Final Gate Tester exits after reporting
3. Project Manager exits after delivering operational report
4. Knowledge team member exits last (send shutdown_request to `knowledge-{PLAN_NAME}` after PM exits)
5. Keep plan directory with all artifacts (including `operational-report.md`)
6. Present summary to user — mention that the operational report is available at `documentation/plans/$ARGUMENTS/operational-report.md`
