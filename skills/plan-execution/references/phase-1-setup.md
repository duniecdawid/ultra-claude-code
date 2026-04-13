# Phase 1: Setup

### 1.1 Read Entire Plan Directory

Read ALL files in `documentation/plans/$ARGUMENTS/`:

- `README.md` — plan document with embedded task list
- `tasks/*/` — existing per-task pipeline artifacts (if resuming)
- `shared/lead.md` — Lead-level shared notes (if resuming)
- `checkpoint-*.md` — checkpoint files (if any)

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

Every task gets the full pipeline team: **Executor + Reviewer + Tester**. There is no classification step. External library documentation is handled by Lead via the `/uc:research` skill — Lead synthesizes a Knowledge Brief once in Phase 1.8 and brokers mid-execution QUERY messages from teammates.

### 1.4 Concurrency Decision

Determine how many task-teams can run concurrently:

| Plan Size | Max Concurrent Task-Teams |
|-----------|--------------------------|
| 1-3 tasks | 1-2 |
| 4-8 tasks | 2-3 |
| 9+ tasks  | 3-4 |

Max ceiling: **4 concurrent task-teams**, plus 1 shared knowledge team member.

Each slot = 1 task-team. Executor and Reviewer are spawned when a slot opens. Tester is lazy-spawned when the Executor signals `code complete` — *before* the Executor writes `impl.md`, so the Tester cold-reads context in parallel with the impl-report write. All members exit together when the task is done.

Tasks normally spawn when their slot is available AND all dependencies are completed. **Exception — pipeline pre-spawn:** when an Executor signals `code complete`, Lead may pre-spawn the next dependent task into a `planning` stage if a concurrency slot is free — see SKILL.md "How a Task-Team Works" and the message handler table for the rules. Pre-spawned successors count toward the concurrency limit and wait at a new gate for `Implementation approved` before writing code. At most one pre-spawn per `code complete` event.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **opus** | Code generation, architectural decisions, codebase research — highest capability required |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Project Manager | sonnet | Operational observation — read-only, low overhead |
| Researcher (subagent) | sonnet | One-shot external documentation retrieval — spawned by Lead via `/uc:research` on cache miss |

### Permission Modes

| Role | Mode | Rationale |
|------|------|-----------|
| **Executor** | **`bypassPermissions`** | **Writes code autonomously; plan reviewed by teammates before implementation** |
| Reviewer | `bypassPermissions` | Read-only analysis, no approval needed |
| Tester | `bypassPermissions` | Runs tests autonomously, no approval needed |
| Project Manager | `bypassPermissions` | Read-only observation, no approval needed |
| Researcher (subagent) | `bypassPermissions` | Writes to `documentation/technology/research/` and `documentation/product/research/` only, stateless, no approval needed |

### 1.5 Cost Estimate & Usage Mode

Present the cost estimate to the user (informational — no confirmation needed, the user already chose to execute by running the command):

```
Plan: $ARGUMENTS
Tasks: N total
Concurrency: up to M task-teams in parallel
Estimated cost: ~[N * 120]K tokens

Cost per task pipeline: ~120K tokens (Executor ~80K + Reviewer ~30K + Tester ~10K)
  (Reviewer spawns with executor for continuous review; Tester is lazy-spawned — only active during test phase)
Knowledge brief synthesis (Phase 1.8, plan-wide): ~20K tokens amortized (Lead invokes /uc:research once per Tech Stack item — cache hits are free, misses spawn a short-lived researcher subagent)
Mid-execution knowledge queries: ~1K per QUERY (cache hit) or ~15K (cache miss with subagent spawn)
Project Manager (plan-wide): ~50K tokens (observational, runs entire execution)
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
          description: "Ultra Claude pauses before the 5-hour rate limit is exhausted and resumes after reset."
        },
        {
          label: "Yes — full speed",
          description: "No pauses — runs as fast as possible. If you don't have extra usage enabled on your Anthropic account, work will stop at the rate limit and you'll have to recover manually."
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

This value is read by the PM agent to decide whether to activate usage threshold monitoring.
- **If extra_usage = false:** PM monitors `~/.claude/ultra/usage-status.json` and triggers PAUSE/RESUME at 85% five-hour usage. On PAUSE: in-progress tasks finish, teams are shut down, PM enters low-power mode (usage checks only). On RESUME: Lead spawns fresh teams. Multiple cycles supported across 5-hour windows.
- **If extra_usage = true:** No special monitoring. The system trusts the account has extra usage capacity.

Proceed directly to 1.6.

### 1.6 Create Task List

Create ONE task per plan task — no role prefixes. Pipeline stage is tracked in metadata:

```
TaskCreate({
  subject: "task-1: Add JWT middleware",
  description: "Success criteria: ...\nFiles: src/middleware/auth.ts\n...",
  activeForm: "Processing task 1: Add JWT middleware",
  metadata: { "stage": "pending", "retry_count": 0 }
  // stage values: "pending" | "planning" | "impl" | "review" | "test" | "done"
})
```

Each task description must include:
- Success criteria from the plan
- Files involved
- Dependencies on other tasks (use `addBlockedBy` for sequential ordering)

### 1.7 Set Up Directory Structure

```
documentation/plans/$ARGUMENTS/
  README.md
  shared/
    lead.md              # Global Lead notes
  tasks/                 # Per-task pipeline artifacts (created just-in-time)
  checkpoint-*.md
```

Create `shared/lead.md` with: plan overview, concurrency decision, key architectural constraints, task dependency graph, critical decisions, and execution config (extra_usage setting from 1.5).

Create `tasks/` directory. Per-task subdirs (`tasks/task-N/`) are created just-in-time when the first team member spawns for that task.

### 1.8 Project Manager Spawn + Knowledge Brief Synthesis

Before spawning any task-teams, set up the PM teammate and synthesize the Knowledge Brief. **Only the PM is a teammate**; knowledge is handled by Lead via `/uc:research` + the `researcher` subagent (one-shot, Task-tool spawned on cache miss).

**Order:**

1. **Spawn Project Manager** — spawn `pm-{PLAN_NAME}` via TeamCreate using the PM spawn prompt in `references/phase-2-spawn-prompts.md`. PM has Bash access and self-labels its pane on startup. No tmux commands needed from you.

2. **Synthesize the Knowledge Brief:**

   a. Read the plan README.md `## Tech Stack` section and collect the list of technologies. Also scan `documentation/technology/architecture/` and `.claude/ultra/app-context.md` for additional implicit technology references (connectors, databases, protocols the plan assumes).

   b. For each tech item, invoke the `/uc:research` skill directly (via the Skill tool, not via Task). The skill is cache-first — items already researched in this project hit the cache and return immediately with zero agent spawn. Items not yet researched spawn the `researcher` subagent, write a new file under `documentation/technology/research/libraries/`, and return a summary. Lead's context absorbs the summary but not the full doc body — that lives in the committed file.

   ```
   For each tech in Tech Stack:
     /uc:research {tech}
     → skill returns {summary, file_path, expires, cache_hit: true|false}
     → record {tech, one-sentence summary, file_path} in the brief
   ```

   c. Compose the **Knowledge Brief** — one paragraph per tech (≤3 sentences), each ending with the pointer to the research file. Include any gotchas or breaking changes surfaced by the research summaries. The brief should be ≤800 words total — it's a pointer document, not a reference.

   d. Write the brief to `documentation/plans/$ARGUMENTS/shared/knowledge-brief.md` with this structure:

   ```markdown
   # Knowledge Brief — {PLAN_NAME}

   > Synthesized: {today}. Re-invoke `/uc:research {tech}` to refresh any entry.

   ## {Tech 1}

   {1-3 sentence summary of what the team needs to know}. Details: `documentation/technology/research/libraries/{tech1}.md`.

   ## {Tech 2}

   ...

   ## Knowledge Update Log

   (Lead appends here when broadcasting `KNOWLEDGE UPDATE:` messages during execution.)
   ```

3. **No teammate spawning here.** There is no "Knowledge base ready" signal to wait for — the brief is written to disk synchronously.

### 1.9 Proceed to Phase 2

Shared setup is done. Project Manager is live. Knowledge Brief is on disk. Task teams can now be spawned per Phase 2.
