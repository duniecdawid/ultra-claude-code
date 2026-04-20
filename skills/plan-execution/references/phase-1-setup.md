# Phase 1: Setup

### 1.1 Read Entire Plan Directory

Read ALL files in `documentation/plans/$ARGUMENTS/`:

- `README.md` — plan-level overview + flat task heading index
- `tasks/task-*/task.md` — authoritative per-task content (description, files, patterns, research pointers, success criteria, dependencies). Written by the planning mode in Stage 4.
- `tasks/task-*/plan.md`, `tasks/task-*/impl.md` — existing per-task pipeline artifacts (if resuming)
- `shared/lead.md` — Lead-level shared notes (if resuming)
- `checkpoint-*.md` — checkpoint files (if any)

**Legacy-plan self-heal:** if README contains `### Task N:` headings but `tasks/task-N/task.md` does NOT exist, the plan was written in the pre-split format. Before continuing, extract each task's embedded fields from README into `tasks/task-N/task.md` (following `${CLAUDE_PLUGIN_ROOT}/templates/task.md`), then rewrite README to the flat-index form. For the `**Research:**` section, scan the README's Tech Stack list and map each entry to `documentation/technology/research/libraries/{lib}.md` if that file exists; otherwise write `None applicable` (Lead's pre-spawn knowledge review in Phase 2 will fill the real gaps). If a legacy `shared/knowledge-brief.md` exists, leave it on disk as an inert artifact but don't read it — per-task task.md files are now authoritative. Log the migration in `shared/lead.md`.

You now have the full picture.

### 1.1b Tmux Layout Daemon

Start the standalone tmux layout daemon so panes are automatically arranged as agents spawn:

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-daemon.js" --ensure
```

Then label this pane as the main context so the layout daemon discovers and manages this window:

```bash
tmux set-option -p -t $TMUX_PANE @agent-name "main-context"
tmux set-option -w pane-border-status top
tmux set-option -w pane-border-format " #{@agent-name} "
```

The layout daemon arranges panes as agents spawn and self-label their panes. **You do NOT run any tmux commands yourself** — agents self-label; PM verifies.

### 1.2 Resume Detection

If `checkpoint-*.md` files exist:

1. Read the LATEST checkpoint (highest timestamp)
2. Read `shared/lead.md`
3. Present to user:
   ```
   Found checkpoint from [timestamp].
   Progress: [X/Y] tasks completed, [Z] in pipeline.
   Completed: [brief list]
   Remaining: [brief list]
   Resume from checkpoint? (yes/no)
   ```
4. If yes: skip completed work, re-spawn teams for incomplete tasks using per-task files as context
5. If no: confirm user wants to discard progress, then start fresh

### 1.3 Task Pipeline

Every task gets the full pipeline team: **Executor + Reviewer + Tester**. There is no classification step. External library knowledge comes from each task's `**Research:**` pointers in `tasks/task-N/task.md`, populated by planning Stage 2 and reviewed per-task by Lead just before spawning (see Phase 2). Mid-execution gaps flow through the `ADVICE` channel; Lead invokes `/uc:research` as needed and appends new pointers to task.md.

### 1.4 Concurrency Decision

Determine how many task-teams can run concurrently:

| Plan Size | Max Concurrent Task-Teams |
|-----------|--------------------------|
| 1-3 tasks | 1-2 |
| 4-8 tasks | 2-3 |
| 9+ tasks  | 3-4 |

Max ceiling: **4 concurrent task-teams**. Plan-wide teammates are the **Project Manager** and the **Haiku Watchdog** — no persistent knowledge teammate exists.

Each slot = 1 task-team. Executor and Reviewer are spawned when a slot opens. Tester is lazy-spawned when the Executor signals `code complete` — *before* the Executor writes `impl.md`, so the Tester cold-reads context in parallel with the impl-report write. All members exit together when the task is done.

Tasks normally spawn when their slot is available AND all dependencies are completed. **Exception — pipeline pre-spawn:** when an Executor signals `code complete`, Lead may pre-spawn the next dependent task into a `planning` stage if a concurrency slot is free — see SKILL.md "How a Task-Team Works" and the message handler table for the rules. Pre-spawned successors count toward the concurrency limit and wait at a new gate for `Implementation approved` before writing code. At most one pre-spawn per `code complete` event.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **opus** | Code generation, architectural decisions, codebase research — highest capability required |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Project Manager | sonnet | Event-driven coordination — dashboard, watchdog validation, budget tracking |
| Watchdog | haiku | Monitor-based sensor — bash script checks every 60s, model wakes only on alerts. Zero tokens on clean ticks. |
| Researcher (subagent) | sonnet | One-shot external documentation retrieval — spawned by Lead via `/uc:research` on cache miss |

### Permission Modes

| Role | Mode | Rationale |
|------|------|-----------|
| **Executor** | **`bypassPermissions`** | **Writes code autonomously; plan reviewed by teammates before implementation** |
| Reviewer | `bypassPermissions` | Read-only analysis, no approval needed |
| Tester | `bypassPermissions` | Runs tests autonomously, no approval needed |
| Project Manager | `bypassPermissions` | Event-driven coordination, no approval needed |
| Watchdog | `bypassPermissions` | Read-only sensor, no approval needed |
| Researcher (subagent) | `bypassPermissions` | Writes to `documentation/technology/research/` and `documentation/product/research/` only, stateless, no approval needed |

### 1.5 Cost Estimate & Usage Mode

Present the cost estimate to the user (informational — no confirmation needed, the user already chose to execute by running the command):

```
Plan: $ARGUMENTS
Tasks: N total
Concurrency: up to M task-teams in parallel
Estimated cost: ~[N * 120]K tokens

Cost per task pipeline: ~100K tokens (Executor ~70K + Reviewer ~20K + Tester ~10K)
  (Reviewer spawns with Executor and immediately sends a REVIEWER TAKE; Tester is lazy-spawned — only active during test phase)
Pre-spawn knowledge review (per task, at spawn time): ~2K per task for cache hits, up to ~15K if /uc:research fires on a gap — Lead only researches if the planner's Research pointers don't cover the task
Mid-execution ADVICE + QUERY: ~1K per message (cache hit) or ~15K (cache miss with researcher subagent)
Project Manager (plan-wide): ~20K tokens (event-driven, no cron — wakes only on messages)
Watchdog (plan-wide, Haiku): near-zero (bash does all checking, model wakes only on alerts via Monitor)
```

Then ask the usage mode question:

```
AskUserQuestion({
  questions: [
    {
      question: "Enable extra usage? Tip: plan during the day, execute overnight — most plans complete within the free limit window. Enable extra usage only if you need it done as fast as possible.",
      header: "Usage mode",
      multiSelect: false,
      options: [
        {
          label: "No — auto-pause at limits (Recommended)",
          description: "Ultra Claude monitors usage and pauses/resumes automatically when approaching the 5-hour rate limit."
        },
        {
          label: "Yes — full speed",
          description: "No usage monitoring or pausing. If you don't have extra usage enabled on your Anthropic account, work will stop at the rate limit and you'll have to recover manually."
        }
      ]
    }
  ]
})
```

After the user answers, store in `shared/lead.md` under a config header:

```markdown
## Execution Config
- extra_usage: true  (or false)
```

Usage management is a three-agent system: **Haiku watchdog → PM → Lead.**
- **If extra_usage = false:** A Haiku watchdog runs a bash monitoring script every 60 seconds via Monitor (zero AI tokens on clean ticks — model wakes only on alerts). The script checks two independent rate-limit windows (5h: 80% CONSERVE / 90% PAUSE / 95% KILL, 7d: 90% / 95% / 98%) and executor staleness. On alert, it signals PM with a window-qualified message. PM validates, adds operational context, and forwards to Lead with a `[5h]` or `[7d]` label. Lead's response is uniform across windows: on CONSERVE, let active teams finish their current task and stop spawning new ones (checkpoint on next `task done`); on PAUSE, tell all agents to go idle (zero tokens while waiting); on KILL, force-terminate agents via shutdown_request and checkpoint. Lead tracks blocks per window in `shared/lead.md` → `## Usage Blocks` and resumes when all blocks clear — guided by `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/usage-control.md`. Lead also performs a pre-task-1 budget assessment (of both windows) before starting any work.
- **If extra_usage = true:** The watchdog still runs (it also handles stall detection), but Lead does not load the usage-control reference and does not perform budget assessments. Usage alerts from PM are noted but Lead trusts the account has extra usage capacity.

Proceed directly to 1.6.

### 1.6 Create Task List

Create ONE Lead-side task per plan task — no role prefixes. Pipeline stage is tracked in metadata. Source the task subject/description from `tasks/task-N/task.md` (it's already on disk from planning Stage 4 — do NOT parse README sections for task content):

```
TaskCreate({
  subject: "task-1: {title from task.md heading}",
  description: "{1-line summary from task.md Description} | See tasks/task-1/task.md",
  activeForm: "Processing task 1: {title}",
  metadata: { "stage": "pending", "retry_count": 0 }
  // stage values: "pending" | "planning" | "impl" | "review" | "test" | "done"
})
```

Set `addBlockedBy` from each task.md's Dependencies field (sequential ordering). The TaskCreate description is a pointer, not a content duplicate — the authoritative content is task.md itself.

### 1.7 Set Up Directory Structure

```
documentation/plans/$ARGUMENTS/
  README.md              # plan-level overview + flat task heading index
  plan.json              # canonical task state (PM maintains)
  shared/
    lead.md              # Lead-level shared notes, amendments log
  tasks/
    task-1/
      task.md            # authoritative per-task content (from planning Stage 4)
      plan.md            # Executor writes in Phase 3 of its workflow (execution delta only)
      impl.md            # Executor writes in Phase 4.5 (implementation delta + gotchas)
    task-2/
      task.md
      ...
  checkpoint-*.md
```

`tasks/task-N/task.md` files already exist from planning Stage 4 — do NOT re-create them. Do create or update `shared/lead.md` with: plan overview, concurrency decision, key architectural constraints, task dependency graph, critical decisions, execution config (extra_usage setting from 1.5), and the amendments log (initially empty).

`plan.md` and `impl.md` are written later by the Executor during its workflow — do not pre-create them here.

### 1.8 Project Manager & Watchdog Spawn

Before spawning any task-teams, spawn the plan-wide utility agents: **PM and Haiku watchdog.**

1. Spawn `pm-{PLAN_NAME}` via TeamCreate using the PM spawn prompt in `references/phase-2-spawn-prompts.md`. PM has Bash access and self-labels its pane on startup.

2. Spawn `watchdog-{PLAN_NAME}` via TeamCreate using the watchdog spawn prompt in `references/phase-2-spawn-prompts.md`. The watchdog runs on Haiku (cheap), uses a bash monitoring script via Monitor (zero AI tokens on clean ticks), and signals PM on usage thresholds and stalls. It always runs regardless of `extra_usage` setting — stall detection is useful in all cases.

Both agents self-label their tmux panes. No tmux commands needed from you.

There is no Knowledge Brief synthesis step. Research lives per-task in each `tasks/task-N/task.md`'s `**Research:**` section (populated by planning Stage 4), and Lead reviews it per-task at spawn time in Phase 2.

### 1.9 Pre-Task-1 Budget Assessment

Before spawning the first task-team, read the current usage percentage:

```bash
pct=$(jq -r '.accounts | [.[]] | sort_by(.updated_at) | last | .rate_limits.five_hour.used_percentage // 0' ~/.claude/ultra/usage-status.json 2>/dev/null || echo 0)
```

`pct` is the **used** percentage (how much of the 5-hour window has been consumed). Low pct (e.g., 5%) = plenty of budget. High pct (e.g., 80%) = little remaining.

If `extra_usage = false` and pct is already elevated (e.g., >50%), read `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/usage-control.md` and assess whether the plan can complete within the remaining budget (100 - pct). You may decide to proceed normally, reduce concurrency, or wait for the rate-limit window to reset. This is your judgment call based on the total plan scope. If pct is low (e.g., <30%), proceed normally — no need to read the reference.

If `extra_usage = true`, skip this assessment.

### 1.10 Proceed to Phase 2

Shared setup is done. Project Manager and watchdog are live. Task teams can now be spawned per Phase 2.
