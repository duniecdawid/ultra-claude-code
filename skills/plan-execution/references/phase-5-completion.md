# Phase 5: Completion

### 5.2 Final Gate

Enter Phase 5 when all tasks hit "done" stage (all task-teams exited). Only `code` tasks count for gate — `ops` tasks produce no code to regress. **Skip step if plan has no code tasks, or exactly 1 code task AND `documentation/technology/testing/final-gate.md` not exist** (`[ -f documentation/technology/testing/final-gate.md ]`) — per-task tester already ran full suite, go straight to 5.3. If `final-gate.md` exists and plan has any code task, always run final gate: gate-specific criteria (thresholds, smoke targets, cross-task regression checklist) skipped on purpose in per-task testing — evaluated only here.

Spawn one Final Gate Tester (fresh team member) for full regression suite:
- Final Gate Tester self-labels pane on startup — no labeling from you.
- Use Final Gate Tester spawn prompt from `references/phase-2-spawn-prompts.md`
- PASS: go to 5.3
- FAIL: decide — re-spawn task-teams for specific fixes, or report to user

### 5.3 Request Operational Report

SendMessage to Project Manager (`pm-{PLAN_NAME}`): "Execution complete — write operational report"

PM will:
1. Update plan README status to "Completed"
2. Write operational report to `operational-report.md`
3. Confirm when done

**Do NOT wait for PM here.** PM works in background; run 5.4 and 5.5 meanwhile. PM confirmation collected in 5.6.

### 5.4 Backlog Review + Auto-Close

Runs for every plan, regardless of task types. Read all backlog items in `documentation/backlog/` AND the Follow-up Items collected during execution. Scan both against what this plan changed:

- Backlog item the plan resolved → close via `uc:backlog`, no question asked. Set `related_plan` where fits; use judgment.
- Follow-up item the plan already resolved → drop from triage list, no question asked.

Present user the list of backlog items closed by this plan (or say nothing changed).

### 5.5 Follow-up Triage

Execution complete — nothing blocks on user questions any more, so **AskUserQuestion use resumes normally** here (the Phases 2–4 ban and escalation queue no longer apply).

Triage each remaining detected issue per `${CLAUDE_PLUGIN_ROOT}/references/backlog-triage.md` (post-execution variant): one question per issue with options Fix now / Add to backlog / Ignore / Let's talk about it, recommended option first with "(Recommended)". Batch up to 10 questions per call. "Let's talk about it" → discuss, then act on the agreed disposition.

Carry the 5.4 backlog picture in: follow-up item matching an existing backlog item → update/link existing, never a duplicate. Handle "Fix now" items inline after triage completes.

### 5.6 Collect PM Report, Summary, Shutdown

Wait for PM confirm `operational-report.md` saved (may already have arrived during 5.4–5.5). Then send `shutdown_request` to Project Manager.

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
- {item} — {triage outcome: fixed now / backlog / ignored}
```

Shutdown:

1. All task-teams already self-exited when tasks passed
2. Final Gate Tester exits after report
3. Project Manager exits last (after delivering operational report)
4. Remove sentinel registration (plan no longer wake/advisory target for limit sentinel):
   ```bash
   rm -f ~/.claude/ultra/sentinel/plans/{PLAN_NAME}.json
   ```
5. Keep plan directory with all artifacts (including `operational-report.md`, `tasks/task-N/task.md`/`plan.md`/`impl.md`, and `shared/lead.md`)
6. Present summary to user — mention that the operational report is available at `documentation/plans/$ARGUMENTS/operational-report.md`
