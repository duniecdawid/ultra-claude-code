# Task-Team Startup Protocol

All task-team agents (Executor, Reviewer, Tester) follow this protocol as their **First Action** after pane labeling. Re-spawned agents follow the same protocol — there is no separate "resume" flow. This is the single DRY source for startup behavior; individual agent workflows reference this file rather than restating it.

## 1. Pane labeling

```bash
[ -n "$TMUX_PANE" ] && tmux set-option -p -t $TMUX_PANE @agent-name "task-$TASK_ID-$ROLE_SUFFIX"
```

Where `$TASK_ID` is from your spawn prompt and `$ROLE_SUFFIX` is `executor`, `reviewer`, or `tester`. See your individual agent file for the exact command. Skipped when not running inside tmux.

## 2. Startup read

Read in this order. Paths below assume `$PLAN_DIR` (from your spawn prompt) is the plan's root directory.

1. **`$PLAN_DIR/tasks/task-$TASK_ID/task.md`** — **must exist, hard error if missing.** This is your authoritative source of truth for task description, files, patterns, success criteria, research pointers, and dependencies. Everything else is supporting context.
2. **`$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl`** — read if present. Append-only signal log for durable pipeline state. See Section 5 and `execution-communication-protocol.md` for the full protocol. Especially important for crash recovery — re-spawned agents infer precise pipeline state from the signal log.
3. **`$PLAN_DIR/tasks/task-$TASK_ID/plan.md`** — read if present (see wait rules below). Executor writes this during its Phase 3; Reviewer does not read it during the advisory phase (it does not exist when you send the REVIEWER TAKE).
4. **`$PLAN_DIR/tasks/task-$TASK_ID/impl.md`** — read if present (see wait rules). Executor writes this during its Phase 4.5.
4.5. **`$PLAN_DIR/tasks/task-$TASK_ID/test-strategy.md`** — read if present (see wait rules). Tester writes this in its step 1 (TESTER TAKE + tester-owned test-file list).
5. **`$PLAN_DIR/shared/lead.md`** — plan-wide Lead notes and amendments log.
6. **`$PLAN_DIR/README.md`** — plan-level overview only. Do NOT parse per-task sections here — everything per-task is in task.md.

Role-specific reads (standards/architecture/product docs/testing docs) are NOT part of the startup read — they're covered in each agent's workflow.

## 2.5 Arm your inbox monitor

Immediately after the startup read, arm the **one persistent inbox monitor** that will wake you for the rest of your life (protocol §3). Set `PROCESSED_LINES` to the current `signals.jsonl` line count, then arm `tail -n +$((PROCESSED_LINES+1)) -F` over `signals.jsonl` filtered to your role's signal alternation, with `persistent: true`. From then on every "wait" is just *yield your turn* — do NOT arm another monitor per wait. See protocol §3 for the exact command, per-role alternations, cursor handling, `TaskStop` teardown, and the Bash fallback. This replaces the old bounded-round waits entirely.

**Yield rule (protocol §3 — the fleet-stop guard):** you may end a turn only with a named wait recorded — append `WAITING_ON` (or `BLOCKED_ON`) naming what you await as the last act before yielding. No nameable awaited signal ⇒ you are not waiting ⇒ keep calling tools. PM never answers courtesy status reports, so sending one is never grounds to end your turn; PM-initiated status checks are two-way — always reply, briefly.

## 3. Research — lazy-read, not startup-read

`task.md`'s `**Research:**` section lists pointers to durable files under `documentation/technology/research/`. **Do NOT auto-read those files during startup.** You only know the paths at this point. Read the actual research file content on demand — when a question arises during planning, review, or testing that the gloss suggests the research answers. This keeps startup tokens bounded while making the research discoverable.

## 4. Wait rules

For an **ops task** (task.md `**Type:** ops`) the Executor is solo — no Reviewer or Tester exists, no take ever arrives, and the take-blocking rules below don't apply (see the Ops Tasks section in the executor's agent file).

| File | Executor | Reviewer | Tester |
|---|---|---|---|
| `task.md` | Must exist at startup (hard error if missing) | Must exist at startup | Must exist at startup |
| `signals.jsonl` | Read on startup for crash recovery state inference, then arm the persistent inbox monitor (§2.5). Waits are `WaitForTeamMember` per protocol §3 — the one inbox wakes you, no per-wait monitors. | Read on startup for crash recovery, then arm the inbox monitor. `WaitForTeamMember` (per §3) for `REVIEW_REQUESTED`/`REREVIEW_REQUESTED`/`EXIT_REQUESTED`/`SHUTDOWN`. | Read on startup for crash recovery, then arm the inbox monitor. `WaitForTeamMember` (per §3) for `TEST_REQUESTED`/`RETEST_REQUESTED`/`EXIT_REQUESTED`/`SHUTDOWN`. |
| `plan.md` | Blocks on BOTH takes (via SendMessage or `REVIEWER_TAKE_READY` + `TESTER_TAKE_READY` signals in signals.jsonl, with `take.md` + `test-strategy.md`) before calling `Write` on plan.md. Explores codebase + mentally drafts the approach while waiting. Creates it in step 3 of its workflow once both takes have arrived. | Does NOT read plan.md — Reviewer's upfront input is sent BEFORE plan.md exists; later formal review reads source files, not plan.md | Does NOT read plan.md — Tester's upfront input (TESTER TAKE) is sent BEFORE plan.md exists; verification targets success criteria + product docs, not the Executor's approach |
| `impl.md` | Creates it in step 4.5 of its workflow | Absent until "ready for review"; read on that signal | Absent until "ready for test"; read on that signal — ONLY for the file list |
| `test-strategy.md` | Reads on `TESTER_TAKE_READY` (plan.md gate) and again at step 6 for the tester-owned test-file list to commit | Consults during formal review for the unit-layer test contract | Creates it in step 1 of its workflow; appends every test file it authors to the `**Tester-owned test files:**` list |

## 5. Execution Communication Protocol

All inter-agent communication uses the unified execution communication protocol. Read `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/execution-communication-protocol.md` during startup — it defines three functions:

- **`CommunicateTeamMember(to, message, signal?, content_file?)`** — send to one agent
- **`CommunicateTeam(message, signal?, content_file?)`** — broadcast to all active teammates + Lead
- **`WaitForTeamMember(signal, from?)`** — wait to receive a signal. SendMessage is the primary wake; the durable channel is your one persistent inbox monitor that follows signals.jsonl and wakes you on any relevant append. Waiting is just *yield your turn* — you arm no per-wait monitor, and per the §3 yield rule you append `WAITING_ON` naming the awaited signal before yielding (mechanics, per-role alternations, cursor, teardown, and Bash fallback in protocol §3 — never restate them, reference them)

**FILE-UPDATED broadcasts** use `CommunicateTeam`:
```
CommunicateTeam(message: "FILE-UPDATED task-$TASK_ID/{filename}: {one-line reason}")
```
For critical save points (plan.md, impl.md initial writes), add a `signal` parameter for durable delivery. For low-stakes updates (fix cycle notes), omit the signal — SendMessage-only is fine.

When you receive a `FILE-UPDATED` broadcast, re-read the named file before your next action. No acknowledgement required.

Broadcasts go to all teammates — the full team (Executor, Reviewer, Tester) is alive from task start. A crash re-spawned agent does not need earlier broadcasts — it reads current state on its own startup.

## 6. ADVICE channel (Executor only)

If you're the Executor and you hit a case where you want Lead's judgment or orchestration knowledge, send:

```
ADVICE REQUEST task-$TASK_ID [{case}]: {context + question}
```

Where `{case}` is one of:
- `complicated` — hard problem, want another mind on the framing
- `deep-reasoning` — load-bearing design call, want a thinking partner
- `knowledge` — asking for Lead's orchestration context (other tasks, plan history, user intent from approval)
- `deviation` — MANDATORY and BLOCKING. You're about to deviate from task.md's scope (new files, skipped criterion, contradicts REVIEWER TAKE). You MUST send this and wait for `APPROVED` or `AMEND: {instructions}` before committing the deviation.

Lead replies with `ADVICE task-$TASK_ID: {guidance}` for the non-deviation cases, or `APPROVED` / `AMEND: ...` for deviation. Non-deviation cases are non-blocking by default — you decide whether to wait.

**Don't use ADVICE for trivial decisions.** Lead's time is shared across all active tasks. ADVICE is distinct from QUERY (external library docs via `/uc:research`): ADVICE is for Lead's judgment and orchestration context; QUERY is for external knowledge.

## 7. QUERY channel (any team member)

For external library / framework / API / pattern documentation, send:

```
QUERY: {question}
```

to Lead. Lead runs `/uc:research` (cache hit or fresh miss), writes or refreshes the research file, replies `ANSWER: {excerpts + pointer}`, AND appends the new pointer to `task.md`'s `**Research:**` section with a `FILE-UPDATED` broadcast — so the new research is durable for re-spawns and future teammates.
