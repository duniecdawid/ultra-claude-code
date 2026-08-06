# Task-Team Startup Protocol

All task-team agents (Executor, Reviewer, Tester) follow this as **First Action** after pane labeling. Re-spawned agents follow same protocol — no separate "resume" flow. This = single DRY source for startup behavior; agent workflows reference this file, no restate.

## 1. Pane labeling

```bash
[ -n "$TMUX_PANE" ] && tmux set-option -p -t $TMUX_PANE @agent-name "task-$TASK_ID-$ROLE_SUFFIX"
```

`$TASK_ID` from spawn prompt, `$ROLE_SUFFIX` = `executor`, `reviewer`, or `tester`. Exact command in your agent file. Skipped when not inside tmux.

## 2. Startup read

Read in this order. Paths assume `$PLAN_DIR` (from spawn prompt) = plan root directory.

1. **`$PLAN_DIR/tasks/task-$TASK_ID/task.md`** — **must exist, hard error if missing.** Authoritative truth for task description, files, patterns, success criteria, research pointers, dependencies. All else = supporting context.
2. **`$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl`** — read if present. Append-only signal log for durable pipeline state. See Section 5 and `execution-communication-protocol.md` for full protocol. Key for crash recovery — re-spawned agents infer precise pipeline state from signal log.
3. **`$PLAN_DIR/tasks/task-$TASK_ID/plan.md`** — read if present (wait rules below). Executor writes during Phase 3; Reviewer does not read it during advisory phase (does not exist when REVIEWER TAKE sent).
4. **`$PLAN_DIR/tasks/task-$TASK_ID/impl.md`** — read if present (wait rules). Executor writes during Phase 4.5.
5. **`$PLAN_DIR/tasks/task-$TASK_ID/test-strategy.md`** — read if present (wait rules). Tester writes in step 1 (TESTER TAKE + tester-owned test-file list).
6. **`$PLAN_DIR/shared/lead.md`** — plan-wide Lead notes + amendments log.
7. **`$PLAN_DIR/README.md`** — plan-level overview only. Do NOT parse per-task sections here — all per-task lives in task.md.

Role-specific reads (standards/architecture/product docs/testing docs) NOT part of startup read — covered in each agent's workflow.

## 2.5 Arm your inbox monitor

Right after startup read, arm the **one persistent inbox monitor** that wakes you for rest of your life (protocol §3). Set `PROCESSED_LINES` to current `signals.jsonl` line count, then arm `tail -n +$((PROCESSED_LINES+1)) -F` over `signals.jsonl` filtered to your role's signal alternation, with `persistent: true`. From then, every "wait" = just *yield your turn* — NO arm another monitor per wait. Protocol §3 has exact command, per-role alternations, cursor handling, `TaskStop` teardown, Bash fallback. This replaces old bounded-round waits entirely.

**Yield rule (protocol §3 — the fleet-stop guard):** end turn only with named wait recorded — append `WAITING_ON` (or `BLOCKED_ON`) naming what you await as last act before yielding. No nameable awaited signal ⇒ not waiting ⇒ keep calling tools. PM never answers courtesy status reports — sending one is never grounds to end your turn; PM-initiated status checks two-way — always reply, briefly.

## 3. Research — lazy-read, not startup-read

`task.md` `**Research:**` section lists pointers to durable files under `documentation/technology/research/`. **Do NOT auto-read those files during startup.** You only know paths at this point. Read actual research content on demand — when question arises during planning, review, or testing that gloss suggests research answers. Keeps startup tokens bounded, research still discoverable.

## 4. Wait rules

**Ops task** (task.md `**Type:** ops`): Executor solo — no Reviewer or Tester exists, no take ever arrives, take-blocking rules below don't apply (see Ops Tasks section in executor's agent file).

| File | Executor | Reviewer | Tester |
|---|---|---|---|
| `task.md` | Must exist at startup (hard error if missing) | Must exist at startup | Must exist at startup |
| `signals.jsonl` | Read on startup for crash-recovery state inference, then arm persistent inbox monitor (§2.5). Waits = `WaitForTeamMember` per protocol §3 — one inbox wakes you, no per-wait monitors. | Read on startup for crash recovery, then arm inbox monitor. `WaitForTeamMember` (per §3) for `REVIEW_REQUESTED`/`REREVIEW_REQUESTED`/`EXIT_REQUESTED`/`SHUTDOWN`. | Read on startup for crash recovery, then arm inbox monitor. `WaitForTeamMember` (per §3) for `TEST_REQUESTED`/`RETEST_REQUESTED`/`EXIT_REQUESTED`/`SHUTDOWN`. |
| `plan.md` | Blocks on BOTH takes (via SendMessage or `REVIEWER_TAKE_READY` + `TESTER_TAKE_READY` signals in signals.jsonl, with `take.md` + `test-strategy.md`) before calling `Write` on plan.md. Explores codebase + mentally drafts approach while waiting. Creates in step 3 of workflow once both takes arrive. | Does NOT read plan.md — Reviewer upfront input sent BEFORE plan.md exists; later formal review reads source files, not plan.md | Does NOT read plan.md — Tester upfront input (TESTER TAKE) sent BEFORE plan.md exists; verification targets success criteria + product docs, not Executor approach |
| `impl.md` | Creates in step 4.5 of workflow | Absent until "ready for review"; read on that signal | Absent until "ready for test"; read on that signal — ONLY for file list |
| `test-strategy.md` | Reads on `TESTER_TAKE_READY` (plan.md gate) and again at step 6 for tester-owned test-file list to commit | Consults during formal review for unit-layer test contract | Creates in step 1 of workflow; appends every test file it authors to `**Tester-owned test files:**` list |

## 5. Execution Communication Protocol

All inter-agent communication uses unified execution communication protocol. Read `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/execution-communication-protocol.md` during startup — defines three functions:

- **`CommunicateTeamMember(to, message, signal?, content_file?)`** — send to one agent
- **`CommunicateTeam(message, signal?, content_file?)`** — broadcast to all active teammates + Lead
- **`WaitForTeamMember(signal, from?)`** — wait to receive signal. SendMessage = primary wake; durable channel = your one persistent inbox monitor following signals.jsonl, wakes you on any relevant append. Waiting = just *yield your turn* — arm no per-wait monitor; per §3 yield rule, append `WAITING_ON` naming awaited signal before yielding (mechanics, per-role alternations, cursor, teardown, Bash fallback in protocol §3 — never restate, reference)

**FILE-UPDATED broadcasts** use `CommunicateTeam`:
```
CommunicateTeam(message: "FILE-UPDATED task-$TASK_ID/{filename}: {one-line reason}")
```
Critical save points (plan.md, impl.md initial writes): add `signal` parameter for durable delivery. Low-stakes updates (fix cycle notes): omit signal — SendMessage-only fine.

Receive `FILE-UPDATED` broadcast → re-read named file before next action. No acknowledgement required.

Broadcasts go to all teammates — full team (Executor, Reviewer, Tester) alive from task start. Crash re-spawned agent no need earlier broadcasts — reads current state on own startup.

## 6. ADVICE channel (Executor only)

Executor: hit a case wanting Lead's judgment or orchestration knowledge? Send:

```
ADVICE REQUEST task-$TASK_ID [{case}]: {context + question}
```

`{case}` one of:
- `complicated` — hard problem, want second mind on framing
- `deep-reasoning` — load-bearing design call, want thinking partner
- `knowledge` — asking Lead's orchestration context (other tasks, plan history, user intent from approval)
- `deviation` — MANDATORY and BLOCKING. About to deviate from task.md scope (new files, skipped criterion, contradicts REVIEWER TAKE). MUST send and wait for `APPROVED` or `AMEND: {instructions}` before committing deviation.

Lead replies `ADVICE task-$TASK_ID: {guidance}` for non-deviation cases, or `APPROVED` / `AMEND: ...` for deviation. Non-deviation cases non-blocking by default — you decide whether to wait.

**No ADVICE for trivial decisions.** Lead's time shared across all active tasks. ADVICE ≠ QUERY (external library docs via `/uc:research`): ADVICE = Lead's judgment + orchestration context; QUERY = external knowledge.

## 7. QUERY channel (any team member)

External library / framework / API / pattern documentation? Send:

```
QUERY: {question}
```

to Lead. Lead runs `/uc:research` (cache hit or fresh miss), writes or refreshes research file, replies `ANSWER: {excerpts + pointer}`, AND appends new pointer to `task.md` `**Research:**` section with `FILE-UPDATED` broadcast — new research durable for re-spawns + future teammates.
