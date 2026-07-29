# Planning Framework — Task Classification

Canonical taxonomy for two per-task choices every plan records: **type** (team shape) and **executor model**. Read alongside `task-sizing.md` at its two consumption points: Stage 3 entry (classify the Proposed task breakdown) and Stage 4 sizing gate (confirm before files are written). Execution reads the recorded values at spawn time (plan-execution Phase 2). A task.md missing either field runs as `code` + `opus` — existing plans need no migration.

## Type — what team the task gets

| Type | What it is | Team |
|------|-----------|------|
| `code` (default) | Delivers reviewable source — features, fixes, refactors | Executor + Reviewer + Tester |
| `ops` | Operates a system: deploy/release, verify, monitor | Solo Executor |

- Anything producing review-worthy source is `code`, however small.
- `ops` has nothing to review and no test suite to run — the success criteria ARE the verification (health checks, log reads, a monitoring window), done by the Executor itself. Deploy/monitor procedure pointers go in the task's **Patterns:**/**Research:** fields like any other task knowledge.
- Work that both writes code and deploys it is two tasks: `code`, then a dependent `ops`. This is the sanctioned exception to merge-first — the team shapes differ, so merging buys nothing.
- `ops` tasks don't count toward the final gate (nothing to regress) and are exempt from the sizing minimum (see `task-sizing.md`).

## Executor model — who runs the task

Only the Executor varies. Reviewer, Tester, PM stay sonnet regardless.

| Model | When |
|-------|------|
| `sonnet` | Mechanical, pattern-following work: config, applying an established codebase pattern, clear spec, low ambiguity. Default for `ops` |
| `opus` | Standard code delivery. Default for `code` |
| `fable` | Hard end: architectural or cross-cutting change, ambiguous or algorithmically hard problem — often the single task a whole plan rides on. **Draws usage credits** — flag explicitly when proposing; never write into a plan the user hasn't seen flagged |

## Where the classification is recorded

- Stage 3 breakdown + sizing table: `Type` and `Model` columns (format owned by `task-sizing.md`), each with one-line justification when non-default.
- `tasks/task-N/task.md`: `**Type:**` and `**Executor model:**` fields (`templates/task.md`).
- `plan.json`: `"type"` and `"executor_model"` per task object.
