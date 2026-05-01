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
1. Re-spawn the crashed role into the existing team using the SAME minimal spawn prompt from `phase-2-spawn-prompts.md`. No context is rebuilt — the re-spawned agent runs the startup protocol (`task-team-startup.md`) and reads `tasks/task-$TASK_ID/task.md`, `signals.jsonl`, `plan.md` (if present), `impl.md` (if present) plus `shared/lead.md` directly from disk.
2. Include names of surviving teammates in the spawn prompt (the standard teammate list).
3. Surviving teammates continue — Executor drives re-coordination.
4. Log crash in `shared/lead.md`.

**The per-task files are the re-spawn context.** There is no separate "resume prompt" — `task.md` tells the agent what to do, `signals.jsonl` provides precise pipeline state, `plan.md` (if present) shows what was planned, `impl.md` (if present) shows what was implemented so far. Re-spawned agents infer pipeline stage from the signal log + file presence + any message that triggered their re-spawn.

**Signal-based state inference for crash recovery** (see `execution-communication-protocol.md` §6 for the full table):
- `REVIEWER_TAKE_READY` present, no `plan.md` → take sent, planning not started
- `REVIEW_FAIL` present, no subsequent `REREVIEW_REQUESTED` → fix cycle interrupted
- `REVIEW_PASS` + `TEST_PASS` both present → task was complete, may need shutdown only
- `SHUTDOWN` present → team should have exited, re-spawn unnecessary
- `PAUSE` present with no subsequent `RESUME` → team was paused, wait for Lead

## Session Death

Handled automatically by Phase 1.2 (Resume Detection) when user reruns `/uc:plan-execution $ARGUMENTS`. Checkpoint + `shared/lead.md` + `tasks/*/` files (including `signals.jsonl`) preserve all progress. Lead reconstructs task state from metadata.stage, `signals.jsonl` entries, and per-task files on disk, then re-spawns teams for incomplete tasks using the same minimal spawn prompts as initial spawn.

**Legacy plan resume:** if Phase 1.1 detects a plan with embedded per-task sections in README but no `tasks/task-N/task.md` files, run the legacy-plan self-heal from `phase-1-setup.md` §1.1 BEFORE re-spawning anything. Teams can't re-spawn without their task.md files on disk.

## Pipeline-Spawned Successors During Failure

Pipeline mode pre-spawns the next dependent task's team when an Executor signals `code complete`, parking the successor's Executor at a wait gate until its predecessor passes. These failure modes interact with parked successors:

**Predecessor escalation (max retries exceeded):**
- Parked successor stays alive through the escalation. Its plan is already written, reviewed by its Reviewer, and approved by the Lead — that context is valuable to preserve.
- Include the parked successor in the escalation message to the user: "Task {N} escalating. Task {M} is pre-spawned and parked awaiting implementation approval from {N}."
- If user chooses **continue/retry**: successor stays parked; it will receive `Implementation approved` when the predecessor eventually reaches `task done`.
- If user chooses **skip/abort** the predecessor: Lead shuts down the parked successor (send `shutdown_request` to executor-{M} and reviewer-{M}) before moving on, and clears M from the pipeline-parked list in `shared/lead.md`.

**Predecessor plan-invalidating discovery:**
- Pause the pipeline per existing rules. Parked successor stays parked during the pause.
- If the amendment leaves the successor's task intact: once the predecessor reaches `task done`, send `Implementation approved` as usual.
- If the amendment drops or materially changes the successor's task: shut down the parked successor explicitly, clear it from the pipeline-parked list, and let the normal slot-fill spawn the new/amended task fresh when ready.

**Predecessor team member crash:**
- Re-spawn the crashed role per the existing crash recovery flow. Parked successor is unaffected — it's still waiting for `Implementation approved`, which will only arrive after the predecessor's `task done`.

**Parked successor's own team member crashes:**
- Treat like a normal crash: re-spawn with context. If the crashed role was the Executor and it was mid-planning, the re-spawned Executor re-reads `plan.md` and continues. If it was already parked at the wait gate, it resumes parking on respawn (the spawn prompt's Pipeline mode block will restore the gate behavior).

**Session death while a successor is parked:**
- Parked-gate state is **not persisted** in checkpoints. On resume, any task found in `planning` stage that was pipeline-spawned should be re-spawned as a normal (non-pipeline) task once its predecessor completes. The original plan artifact on disk still has the plan work that was already done, so the new Executor can re-read it rather than starting from scratch. This keeps resume logic simple — pipeline pre-spawn is a latency optimization, not a correctness guarantee.
