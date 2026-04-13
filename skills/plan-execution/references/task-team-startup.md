# Task-Team Startup Protocol

All task-team agents (Executor, Reviewer, Tester) follow this protocol as their **First Action** after pane labeling. Re-spawned agents follow the same protocol — there is no separate "resume" flow. This is the single DRY source for startup behavior; individual agent workflows reference this file rather than restating it.

## 1. Pane labeling

```bash
tmux set-option -p -t $TMUX_PANE @agent-name "task-$TASK_ID-$ROLE_SUFFIX"
```

Where `$TASK_ID` is from your spawn prompt and `$ROLE_SUFFIX` is `executor`, `reviewer`, or `tester`. See your individual agent file for the exact command.

## 2. Startup read

Read in this order. Paths below assume `$PLAN_DIR` (from your spawn prompt) is the plan's root directory.

1. **`$PLAN_DIR/tasks/task-$TASK_ID/task.md`** — **must exist, hard error if missing.** This is your authoritative source of truth for task description, files, patterns, success criteria, research pointers, and dependencies. Everything else is supporting context.
2. **`$PLAN_DIR/tasks/task-$TASK_ID/plan.md`** — read if present (see wait rules below). Executor writes this during its Phase 3; Reviewer does not read it during the advisory phase (it does not exist when you send the REVIEWER TAKE).
3. **`$PLAN_DIR/tasks/task-$TASK_ID/impl.md`** — read if present (see wait rules). Executor writes this during its Phase 4.5.
4. **`$PLAN_DIR/shared/lead.md`** — plan-wide Lead notes and amendments log.
5. **`$PLAN_DIR/README.md`** — plan-level overview only. Do NOT parse per-task sections here — everything per-task is in task.md.

Role-specific reads (standards/architecture/product docs/testing docs) are NOT part of the startup read — they're covered in each agent's workflow.

## 3. Research — lazy-read, not startup-read

`task.md`'s `**Research:**` section lists pointers to durable files under `documentation/technology/research/`. **Do NOT auto-read those files during startup.** You only know the paths at this point. Read the actual research file content on demand — when a question arises during planning, review, or testing that the gloss suggests the research answers. This keeps startup tokens bounded while making the research discoverable.

## 4. Wait rules

| File | Executor | Reviewer | Tester |
|---|---|---|---|
| `task.md` | Must exist at startup (hard error if missing) | Must exist at startup | Must exist at startup |
| `plan.md` | Creates it in step 3.2 of its workflow after receiving REVIEWER TAKE and exploring the codebase | Does NOT read plan.md — Reviewer's upfront input is sent BEFORE plan.md exists; later formal review reads source files, not plan.md | Absent at lazy-spawn (Executor already wrote it before code-complete); read during startup pass if present, otherwise on first `FILE-UPDATED` broadcast |
| `impl.md` | Creates it in step 4.5 of its workflow | Absent until "ready for review"; read on that signal | Absent at lazy-spawn (Executor is writing it in parallel with your startup); read when "ready for test" arrives — ONLY for the file list |

## 5. FILE-UPDATED broadcast protocol

When you write or edit any file in `tasks/task-$TASK_ID/`, broadcast:

```
FILE-UPDATED task-$TASK_ID/{filename}: {one-line reason}
```

to every currently-alive teammate AND Lead. Fire-and-forget — no acknowledgement. Save points only (initial write, deliberate revisions) — NOT during draft-in-progress edits. Examples of valid save points:

- `task.md` — Lead initial write, Lead amendment, Lead research addition
- `plan.md` — Executor initial write, Executor revision after ADVICE round
- `impl.md` — Executor initial write, Executor update after fix cycle

When you receive a `FILE-UPDATED` broadcast, re-read the named file before your next action. No acknowledgement required.

Broadcasts only go to currently-alive teammates. A lazy-spawned Tester does not need earlier broadcasts — it reads current state on its own startup. Same for pipeline successors.

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
