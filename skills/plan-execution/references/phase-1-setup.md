# Phase 1: Setup

### 1.0 Lead Tooling Preflight

**Do this before anything else.** Plan execution runs on a real persistent **team** — the Lead spawns teammates (Executor, Reviewer, Tester, PM) that stay alive, message each other, and appear on the team graph. The tools that make this work are **deferred** in a fresh session: they are not in your loaded toolset until you load them. If you skip this step, you will (correctly) observe that `SendMessage`/`Monitor` "aren't in my toolset" and may wrongly conclude the team feature is unavailable and degrade to a lossy one-shot path. Don't. Load the tools first.

**1. Load the deferred agent-teams tools in one call:**

```
ToolSearch("select:SendMessage,Monitor,TaskCreate,TaskUpdate,TaskList")
```

(The `Agent` tool is already directly available — it does not need loading.)

**2. Availability gate.** If `SendMessage` does **not** resolve (ToolSearch reports no match for it), agent teams is not enabled in this environment. **Stop** and tell the user:

> "Plan execution needs agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Run `/uc:setup` to configure it, then re-run `/uc:plan-execution`."

Do **not** improvise a subagent-only fallback — a one-shot pipeline silently drops PM (and its usage monitor), peer messaging, signal durability, and pipeline pre-spawn. Stopping with a clear instruction is the correct behavior.

**2b. Teammate backend gate (tmux).** Agent-teams being enabled is necessary but not sufficient: *how* a named teammate runs is governed by the `teammateMode` setting (`tmux` | `in-process` | `auto`), resolved per session. When it defaults to `in-process`, teammates spawn inside your process with **no tmux panes** — the pane-based coordination this skill is built on silently breaks. Check both preconditions:

```bash
echo "TMUX=${TMUX:-unset}"
jq -r '.teammateMode // "unset"' "$HOME/.claude/settings.json" 2>/dev/null
```

If `$TMUX` is unset (you are not inside a tmux session) **or** `teammateMode` is not `tmux`, **Stop** and tell the user:

> "Plan execution needs tmux-backed team members. Run `/uc:setup` to set `teammateMode: tmux`, (re)launch Claude **inside a tmux session**, then re-run `/uc:plan-execution`."

`auto` does not pass this gate — it silently falls back to in-process when no pane backend is reachable, which is the failure mode we refuse to enter. This is a heuristic pre-check; the authoritative confirmation happens after the first spawn (§1.9).

**3. Primitive mapping — how you actually spawn and communicate.** There is **no** `TeamCreate` tool and no `CommunicateTeamMember`/`WaitForTeamMember` tool. Everything is built from these real primitives:

| Concept | Real invocation |
|---------|-----------------|
| **Spawn a teammate** (Executor/Reviewer/Tester/PM) — persistent, team-graph member, addressable via `SendMessage` | `Agent` tool in **teammate mode**: `name="{role}-{N}"` + `run_in_background: true` + `subagent_type` (the registered type name, e.g. `uc:Task Executor` — not a file path) + `model` + `mode`. Do **not** pass `team_name` — it is deprecated/ignored (the session has a single implicit team). |
| **Spawn a one-shot subagent** (the researcher, via `/uc:research`) — stateless, returns once, not on the team graph | `Agent` tool in **one-shot mode**: no `name`, explicit `run_in_background: false` (sync — the answer gates the next step; see `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`, Mode S). |
| **Lead-side task list** | `TaskCreate(...)` / `TaskUpdate(...)` (this is unrelated to spawning — it tracks task state). |
| **Send / broadcast / wait** | `CommunicateTeamMember`, `CommunicateTeam`, `WaitForTeamMember` are **procedures**, not tools — fixed sequences of `SendMessage` + an `echo >>` append to `signals.jsonl` + `Monitor`, defined in `references/execution-communication-protocol.md`. Never search for a tool by those names. |

The teammate↔subagent distinction is load-bearing (see SKILL.md) — it is expressed by *which mode of the `Agent` tool* you use, not by different tools.

**4. Ensure the usage-monitor script is reachable at a stable path (self-heal).** All usage checks (this skill and PM) invoke `~/.claude/ultra/usage-monitor.sh` — a stable absolute path that does NOT depend on `$CLAUDE_PLUGIN_ROOT` being present in a Bash shell (it often is not). `/uc:setup` creates this symlink; self-heal it here in case setup wasn't re-run:

```bash
mkdir -p ~/.claude/ultra
[ -e ~/.claude/ultra/usage-monitor.sh ] || ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/usage-monitor.sh" ~/.claude/ultra/usage-monitor.sh
# Verify it runs and returns JSON (proves the path + account resolution work BEFORE you rely on it):
bash "$HOME/.claude/ultra/usage-monitor.sh" status
```

The `status` call must print a JSON object with a `band` field. **If it errors or prints no JSON, STOP** — do not proceed into a run where you cannot read usage; tell the user the monitor script is unreachable and to re-run `/uc:setup`. **Never invent or guess a usage status** — every usage figure you act on or report must come from this script's actual stdout.

### 1.0b Usage Mode — ask FIRST (then check limits)

**Step 1 — ask whether we care about the limits at all.** This is the **first user-facing question** of execution (the 1.0 preflight is an environment gate, not a question). Ask it BEFORE reading any usage data — the mode governs whether usage is even checked. Set once, never re-asked mid-run.

```
AskUserQuestion({
  questions: [
    {
      question: "Do you want Ultra Claude to respect the rate limits during this run? Tip: plan during the day, execute overnight — most plans complete within the free limit window. Choose full speed only if you need it done as fast as possible (and have extra usage on your account).",
      header: "Usage mode",
      multiSelect: false,
      options: [
        {
          label: "Yes — auto-pause at limits (Recommended)",
          description: "We care about limits: Ultra Claude checks usage and stops/restarts work automatically around the rate limit. Maps to USAGE_MODE=pause."
        },
        {
          label: "No — full speed, ignore limits",
          description: "We don't care: no usage checking or stopping. If you don't have extra usage on your account, work will hit the rate limit and you'll recover manually. Maps to USAGE_MODE=push-through."
        }
      ]
    }
  ]
})
```

Record the answer (held in context now; written to `shared/lead.md` → `## Execution Config` when that file is created in 1.7, and passed to PM at spawn in 1.9):
- "Yes — auto-pause" → `extra_usage: false`, `USAGE_MODE=pause`
- "No — full speed" → `extra_usage: true`, `USAGE_MODE=push-through`

**Step 2 — only if `USAGE_MODE=pause`, check whether we are already over the limits.** (In `push-through`, skip this entirely — we don't care.) Read current usage from the single monitor script (self-resolves the account — no `$ACCOUNT_KEY` needed yet):

```bash
bash "$HOME/.claude/ultra/usage-monitor.sh" status
```

Read `.band`:
- `clear` → proceed normally.
- `soft` → do NOT start task-1 yet; record `{window}: soft` in `## Usage Blocks` (once `shared/lead.md` exists). The pre-spawn check (Phase 2) governs when slot-fill resumes.
- `critical` → already over the limit. Do NOT spawn into an over-limit window: enter a pre-emptive `stop` hold — record `{window}: stop` with its `resets_at`, arm the self-owned `HOLD-WAKE` (see usage-control.md Hold State), and inform the user (they may prefer to wait for reset, switch accounts, or abort). task-1 spawns when the window resets.

### 1.1 Read Entire Plan Directory

Read ALL files in `documentation/plans/$ARGUMENTS/`:

- `README.md` — plan-level overview + flat task heading index
- `tasks/task-*/task.md` — authoritative per-task content (description, files, patterns, research pointers, success criteria, dependencies). Written by the planning mode in Stage 4.
- `tasks/task-*/plan.md`, `tasks/task-*/impl.md` — existing per-task pipeline artifacts (if resuming)
- `shared/lead.md` — Lead-level shared notes (if resuming)
- `checkpoint-*.md` — checkpoint files (if any)

**Legacy-plan self-heal:** if README contains `### Task N:` headings but `tasks/task-N/task.md` does NOT exist, the plan was written in the pre-split format. Before continuing, extract each task's embedded fields from README into `tasks/task-N/task.md` (following `${CLAUDE_PLUGIN_ROOT}/templates/task.md`), then rewrite README to the flat-index form. For the `**Research:**` section, scan the README's Tech Stack list and map each entry to `documentation/technology/research/libraries/{lib}.md` if that file exists; otherwise write `None applicable` (Lead's pre-spawn knowledge review in Phase 2 will fill the real gaps). If a legacy `shared/knowledge-brief.md` exists, leave it on disk as an inert artifact but don't read it — per-task task.md files are now authoritative. Log the migration in `shared/lead.md`.

You now have the full picture.

### 1.1b Tmux Layout Setup

Run the layout-setup script — **always, unconditionally**. Do not wrap it in a tmux check of your own; the script owns the gate. This keeps the instruction trivial ("run this one script") instead of a conditional you might skip or paraphrase wrong:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-setup.sh"
```

What the script does (so you know what to expect — you don't reproduce it): its single runtime gate is `$TMUX_PANE`. Inside tmux it (1) ensures the layout daemon is running, (2) names this — the Lead/main — pane `@agent-name=main-context`, and (3) turns on the pane-border label display. Outside tmux it no-ops. Per `skills/setup/references/tmux-modes.md`, `$TMUX_PANE` is the runtime signal for tmux commands; the setup-time `tmuxMode` preference does **not** gate runtime behaviour. Every action and skip is logged to `~/.claude/ultra/tmux-layout-setup.log` for debugging.

The layout daemon arranges panes as agents spawn and self-label their panes. **You do NOT run any tmux commands yourself** beyond this one script — agents self-label; PM verifies.

Two layers keep the main pane labelled so the daemon never skips the window: Phase 2's Pre-Spawn Checklist (§2.6) re-runs this same script before every spawn (idempotent), and the daemon itself self-heals — if the Lead pane is ever unlabelled, it infers the Lead from window contents and persists the label (see `scripts/tmux-layout-daemon.js`).

### 1.1c Name the Window

Name the tmux window with the plan so it is identifiable in the status bar. The resolved plan is `$ARGUMENTS` (the full `NNN-name`); read its README title and apply the standardized plan form:

```bash
NNN=$(printf '%s' "$ARGUMENTS" | cut -d- -f1)
TITLE=$(sed -n 's/^# Plan: //p' "documentation/plans/$ARGUMENTS/README.md" | head -1)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-window-name.sh" "UC::P-${NNN}::${TITLE}"
```

This is the window-name analogue of the pane-label setup above — the script owns the `$TMUX_PANE` gate, sanitizes and truncates for the status bar, disables tmux automatic-rename so the name sticks, and no-ops outside tmux. Window naming is orthogonal to the pane-label/layout-daemon system, so there is no conflict.

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

Max ceiling: **4 concurrent task-teams**. The only plan-wide teammate is the **Project Manager** (which owns the usage monitor) — no separate watchdog and no persistent knowledge teammate exists.

Each slot = 1 task-team. Executor and Reviewer are spawned when a slot opens. Tester is lazy-spawned when the Executor signals `code complete` — *before* the Executor writes `impl.md`, so the Tester cold-reads context in parallel with the impl-report write. All members exit together when the task is done.

Tasks normally spawn when their slot is available AND all dependencies are completed. **Exception — pipeline pre-spawn:** when an Executor signals `code complete`, Lead may pre-spawn the next dependent task into a `planning` stage if a concurrency slot is free — see SKILL.md "How a Task-Team Works" and the message handler table for the rules. Pre-spawned successors count toward the concurrency limit and wait at a new gate for `Implementation approved` before writing code. At most one pre-spawn per `code complete` event.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **opus** | Code generation, architectural decisions, codebase research — highest capability required |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Project Manager | sonnet | Event-driven coordination — dashboard, budget tracking, and owns the usage monitor (bash does all checking via Monitor; model wakes only on actionable emits) |
| Researcher (subagent) | sonnet | One-shot external documentation retrieval — spawned by Lead via `/uc:research` on cache miss |

### Permission Modes

| Role | Mode | Rationale |
|------|------|-----------|
| **Executor** | **`bypassPermissions`** | **Writes code autonomously; plan reviewed by teammates before implementation** |
| Reviewer | `bypassPermissions` | Read-only analysis, no approval needed |
| Tester | `bypassPermissions` | Runs tests autonomously, no approval needed |
| Project Manager | `bypassPermissions` | Event-driven coordination + usage monitor, no approval needed |
| Researcher (subagent) | `bypassPermissions` | Writes to `documentation/technology/research/` and `documentation/product/research/` only, stateless, no approval needed |

### 1.5 Cost Estimate

The usage mode was already chosen in 1.0b. Present the cost estimate to the user (informational — no confirmation needed, the user already chose to execute by running the command):

```
Plan: $ARGUMENTS
Tasks: N total
Concurrency: up to M task-teams in parallel
Estimated cost: ~[N * 120]K tokens

Cost per task pipeline: ~100K tokens (Executor ~70K + Reviewer ~20K + Tester ~10K)
  (Reviewer spawns with Executor and immediately sends a REVIEWER TAKE; Tester is lazy-spawned — only active during test phase)
Pre-spawn knowledge review (per task, at spawn time): ~2K per task for cache hits, up to ~15K if /uc:research fires on a gap — Lead only researches if the planner's Research pointers don't cover the task
Mid-execution ADVICE + QUERY: ~1K per message (cache hit) or ~15K (cache miss with researcher subagent)
Project Manager (plan-wide): ~20K tokens (event-driven; owns the usage monitor, wakes only on messages or actionable usage emits)
Usage monitor (plan-wide): near-zero (bash does all checking inside PM's Monitor; emits only on critical-stop / restart)
```

Usage management is a **two-agent** system: **PM (owns the usage monitor) → Lead.**
- **If `USAGE_MODE = pause` (extra_usage false):** PM runs `usage-monitor.sh watch` via the Monitor tool (zero AI tokens on clean ticks). It emits only on the critical-stop crossing and the work-can-restart reset. On a critical-stop, PM asks the Lead to stop in-flight work; on reset, the Lead restarts. The **soft band is not an interrupt** — the Lead enforces it with a `usage-monitor.sh status` check before each spawn (don't start new work while soft-or-worse). Lead tracks blocks per window in `shared/lead.md` → `## Usage Blocks`, guided by `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/usage-control.md`.
- **If `USAGE_MODE = push-through` (extra_usage true):** the monitor suppresses usage emits entirely (it never wakes PM); the Lead does not stop for usage and does not run pre-spawn soft checks. (In every mode the monitor also quietly traces >10-min task silence as `silence_observed` events in events.json — post-mortem data, never an emit.)

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

### 1.8 Resolve Account Identity

Resolve the active account key so the usage monitor and budget checks monitor the correct account (this is the `$ACCOUNT_KEY` passed to PM; the same value `usage-monitor.sh` resolves internally):

```bash
ACCOUNT_KEY=$(source "$HOME/.claude/ultra/lib.sh" && slugifyEmail "$(claude auth status --json 2>/dev/null | jq -r '.email // empty')")
```

Persist this in `shared/lead.md` under execution config so it's available if the session is recovered from a checkpoint.

### 1.9 Project Manager Spawn

Before spawning any task-teams, spawn the plan-wide coordinator: **PM** (PM now owns the usage monitor — there is no separate watchdog agent).

1. Spawn `pm-{PLAN_NAME}` via the `Agent` tool in teammate mode (`name="pm-{PLAN_NAME}"`, `run_in_background: true`) using the PM spawn prompt in `references/phase-2-spawn-prompts.md`. **Pass the resolved `ACCOUNT_KEY` and `USAGE_MODE`** (`pause` or `push-through`, from 1.0b) into the spawn prompt. PM has Bash + Monitor access, self-labels its pane, and starts `usage-monitor.sh watch` on startup.

PM self-labels its tmux pane when tmux is available (skipped otherwise). No tmux commands needed from you.

2. **Verify the teammate backend is really tmux (cancel if not).** The §1.0 gate is a heuristic; this is the authoritative check, against the backend Claude Code actually recorded. Read the session's team config and confirm PM landed on a tmux pane:

```bash
TEAM_CFG=$(grep -rl "\"pm-{PLAN_NAME}\"" "$HOME/.claude/teams"/*/config.json 2>/dev/null | head -1)
[ -z "$TEAM_CFG" ] && TEAM_CFG=$(ls -dt "$HOME/.claude/teams"/session-*/config.json 2>/dev/null | head -1)
jq -r '.members[] | "\(.name) backendType=\(.backendType) pane=\(.tmuxPaneId)"' "$TEAM_CFG" 2>/dev/null
```

PM must show `backendType=tmux` with a real pane id (e.g. `%168`), **not** `backendType=in-process` (pane `in-process`/`leader`). If PM is `in-process`, the environment silently downgraded the backend — **abort the run**: send `shutdown_request` to `pm-{PLAN_NAME}` (and `TaskStop` any background tasks), record the abort in `shared/lead.md`, and stop with the same remediation as the §1.0 gate ("Run `/uc:setup` to set `teammateMode: tmux`, relaunch inside tmux, re-run"). Do **not** continue into Phase 2 on an in-process backend — that is the degraded pipeline the user reported.

There is no Knowledge Brief synthesis step. Research lives per-task in each `tasks/task-N/task.md`'s `**Research:**` section (populated by planning Stage 4), and Lead reviews it per-task at spawn time in Phase 2.

### 1.10 Proceed to Phase 2

Shared setup is done. The usage mode is set (1.0b) and PM (with the usage monitor) is live and confirmed. There is no first-tick STATUS to wait for — the mode/budget decision already happened up front, and the Lead reads usage on demand via `usage-monitor.sh status` at each spawn decision (Phase 2). Task teams can now be spawned per Phase 2.
