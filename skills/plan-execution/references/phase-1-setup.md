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

Every task gets the full pipeline team: **Executor + Reviewer + Tester**. There is no classification step. A shared Tech Knowledge team member handles external library documentation for all tasks.

### 1.4 Concurrency Decision

Determine how many task-teams can run concurrently:

| Plan Size | Max Concurrent Task-Teams |
|-----------|--------------------------|
| 1-3 tasks | 1-2 |
| 4-8 tasks | 2-3 |
| 9+ tasks  | 3-4 |

Max ceiling: **4 concurrent task-teams**, plus 1 shared knowledge team member.

Each slot = 1 task-team. Executor and Reviewer are spawned when a slot opens. Tester is lazy-spawned when implementation is complete. All members exit together when the task is done.

Tasks only spawn when their slot is available AND all dependencies are completed. No pipeline pre-spawning.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **opus** | Code generation, architectural decisions, codebase research — highest capability required |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Tech Knowledge | sonnet | Documentation retrieval — shared across all tasks |
| Project Manager | sonnet | Operational observation — read-only, low overhead |

### Permission Modes

| Role | Mode | Rationale |
|------|------|-----------|
| **Executor** | **`bypassPermissions`** | **Writes code autonomously; plan reviewed by teammates before implementation** |
| Tech Knowledge | `bypassPermissions` | Read-only documentation retrieval, no approval needed |
| Reviewer | `bypassPermissions` | Read-only analysis, no approval needed |
| Tester | `bypassPermissions` | Runs tests autonomously, no approval needed |
| Project Manager | `bypassPermissions` | Read-only observation, no approval needed |

### 1.5 Present Cost Estimate and Get Confirmation

Present to user BEFORE spawning any teams:

```
Plan: $ARGUMENTS
Tasks: N total
Concurrency: up to M task-teams in parallel
Estimated cost: ~[N * 120]K tokens

Cost per task pipeline: ~120K tokens (Executor ~80K + Reviewer ~30K + Tester ~10K)
  (Reviewer spawns with executor for continuous review; Tester is lazy-spawned — only active during test phase)
Tech Knowledge (plan-wide): ~100K tokens (shared documentation retrieval)
Project Manager (plan-wide): ~50K tokens (observational, runs entire execution)

Proceed? (yes/no)
```

**Wait for explicit user confirmation.** Do not spawn teams without it.

### 1.5b Extra Usage Check

After the user confirms "Proceed", ask one more question:

```
Enable extra usage? (yes/no)

  YES — Development runs as fast as possible with no pauses.
        Requires extra usage enabled on your Anthropic account.

  NO  — Ultra Claude will automatically pause development before
        the 5-hour rate limit is exhausted and resume after reset.

💡 Cost tip: plan during the day, execute overnight — most plans
   complete within the free limit window. Enable extra usage only
   if you need it done as fast as possible.
```

Store the answer in `shared/lead.md` under a config header:

```markdown
## Execution Config
- extra_usage: true  (or false)
```

This value is read by the PM agent to decide whether to activate usage threshold monitoring.
- **If extra_usage = false:** PM monitors `~/.claude/ultra/usage-status.json` and triggers PAUSE/RESUME at 85% five-hour usage. On PAUSE: in-progress tasks finish, teams are shut down, PM enters low-power mode (usage checks only). On RESUME: Lead spawns fresh teams. Multiple cycles supported across 5-hour windows.
- **If extra_usage = true:** No special monitoring. The system trusts the account has extra usage capacity.

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

Create `shared/lead.md` with: plan overview, concurrency decision, key architectural constraints, task dependency graph, critical decisions, and execution config (extra_usage setting from 1.5b).

Create `tasks/` directory. Per-task subdirs (`tasks/task-N/`) are created just-in-time when the first team member spawns for that task.

### 1.8 Shared Team Members Setup

Before spawning any task-teams, set up both plan-wide shared team members: **Project Manager** and **Tech Knowledge**. Their spawn prompts are in `references/phase-2-spawn-prompts.md`.

**Spawn order:**

1. **Project Manager first** — spawn `pm-{PLAN_NAME}` using the PM spawn prompt. The PM has Bash access and will self-label its pane on startup (the spawn prompt includes the labeling instruction). No tmux commands needed from you.

2. **Tech Knowledge second** — read plan README.md `## Tech Stack` section for the technology list. Also scan `documentation/technology/architecture/` and `.claude/ultra/app-context.md` for additional technology references. Spawn `knowledge-{PLAN_NAME}` using the Tech Knowledge spawn prompt below. Tech Knowledge self-labels its pane on startup — no labeling needed from you.

   After spawning, send PM: `"SPAWNED knowledge-{PLAN_NAME}"`

   Agent: `${CLAUDE_PLUGIN_ROOT}/agents/tech-knowledge.md`
   Model: `sonnet` | Mode: `bypassPermissions`

   ```
   You are the shared **Tech Knowledge** team member for the "$ARGUMENTS" plan execution.

   PLAN_NAME={PLAN_NAME}
   ROLE=oversight

   **Technologies to load documentation for:**
   {list from Tech Stack section + any additional technologies identified}

   **Architecture docs to read for context:**
   - `documentation/technology/architecture/`
   - `.claude/ultra/app-context.md` (if exists)

   **Lead name:** {lead name}

   Load documentation for all listed technologies using mcp__ref__ref_search_documentation and mcp__ref__ref_read_url. Read the architecture docs for project context. Then SendMessage to Lead: "Knowledge base ready — loaded docs for: {technology list}"

   You will receive QUERY and LOAD messages from team members throughout execution. Respond per your team member instructions.

   Exit only when shutdown_request arrives from Lead. Approve it to exit.
   ```

3. **Wait for "Knowledge base ready"** signal before proceeding to Phase 2.
