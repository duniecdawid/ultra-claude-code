# Phase 1: Setup

### 1.0 Lead Tooling Preflight

**Do this before anything else.** Plan execution run on real persistent **team** — Lead spawn teammates (Executor, Reviewer, Tester, PM) that stay alive, message each other, appear on team graph. Tools that make this work **deferred** in fresh session: not in your loaded toolset until you load them. Skip this step and you (correctly) see `SendMessage`/`Monitor` "aren't in my toolset", then may wrongly conclude team feature unavailable and degrade to lossy one-shot path. Don't. Load tools first.

**1. Load deferred agent-teams tools in one call:**

```
ToolSearch("select:SendMessage,Monitor,TaskCreate,TaskUpdate,TaskList")
```

(`Agent` tool already available — no loading needed.)

**2. Availability gate.** If `SendMessage` **not** resolve (ToolSearch report no match), agent teams not enabled in this environment. **Stop**, tell user:

> "Plan execution needs agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Run `/uc:setup` to configure it, then re-run `/uc:plan-execution`."

Do **not** improvise subagent-only fallback — one-shot pipeline silently drop PM (and its liveness monitor), peer messaging, signal durability, pipeline pre-spawn. Stop with clear instruction = right move.

**2b. Teammate backend gate (tmux).** Agent-teams enabled necessary but not sufficient: *how* named teammate run governed by `teammateMode` setting (`tmux` | `in-process` | `auto`), resolved per session. When default `in-process`, teammates spawn inside your process with **no tmux panes** — pane coordination this skill built on break silently. Check both preconditions:

```bash
echo "TMUX=${TMUX:-unset}"
jq -r '.teammateMode // "unset"' "$HOME/.claude/settings.json" 2>/dev/null
```

If `$TMUX` unset (you not inside tmux session) **or** `teammateMode` not `tmux`, **Stop**, tell user:

> "Plan execution needs tmux-backed team members. Run `/uc:setup` to set `teammateMode: tmux`, (re)launch Claude **inside a tmux session**, then re-run `/uc:plan-execution`."

`auto` not pass gate — it fall back silent to in-process when no pane backend reachable, exact failure mode we refuse. This heuristic pre-check; authoritative confirm come after first spawn (§1.9).

**3. Primitive mapping — how you actually spawn and communicate.** **No** `TeamCreate` tool, no `CommunicateTeamMember`/`WaitForTeamMember` tool. All built from these real primitives:

| Concept | Real invocation |
|---------|-----------------|
| **Spawn a teammate** (Executor/Reviewer/Tester/PM) — persistent, team-graph member, addressable via `SendMessage` | `Agent` tool in **teammate mode**: `name="{role}-{N}"` + `run_in_background: true` + `subagent_type` (the registered type name, e.g. `uc:Task Executor` — not a file path) + `model` + `mode`. Do **not** pass `team_name` — it is deprecated/ignored (the session has a single implicit team). |
| **Spawn a one-shot subagent** (the researcher, via `/uc:research`) — stateless, returns once, not on the team graph | `Agent` tool in **one-shot mode**: no `name`, explicit `run_in_background` — `true` by default (the Lead stays responsive to teammates while research runs; relay the ANSWER on the completion notification), `false` only via `--sync` when the very next action is gated. See `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`. |
| **Lead-side task list** | `TaskCreate(...)` / `TaskUpdate(...)` (this is unrelated to spawning — it tracks task state). |
| **Send / broadcast / wait** | `CommunicateTeamMember`, `CommunicateTeam`, `WaitForTeamMember` are **procedures**, not tools — fixed sequences of `SendMessage` + an `echo >>` append to `signals.jsonl` + `Monitor`, defined in `references/execution-communication-protocol.md`. Never search for a tool by those names. |

Teammate↔subagent split load-bearing (see SKILL.md) — expressed by *which mode of `Agent` tool* you use, not by different tools.

**4. Ensure usage-monitor and limit-sentinel scripts reachable at stable paths (self-heal), and sentinel running.** All usage checks (this skill and PM) invoke `~/.claude/ultra/usage-monitor.sh` — stable absolute path, NOT dependent on `$CLAUDE_PLUGIN_ROOT` existing in Bash shell (often not). Machine-global limit sentinel live at same kind of stable path. `/uc:setup` create both symlinks; self-heal here in case setup not re-run:

```bash
mkdir -p ~/.claude/ultra
[ -e ~/.claude/ultra/usage-monitor.sh ] || ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/usage-monitor.sh" ~/.claude/ultra/usage-monitor.sh
[ -e ~/.claude/ultra/limit-sentinel.sh ] || ln -sf "${CLAUDE_PLUGIN_ROOT}/scripts/limit-sentinel.sh" ~/.claude/ultra/limit-sentinel.sh
# Verify the monitor runs and returns JSON (proves the path + account resolution work BEFORE you rely on it):
bash "$HOME/.claude/ultra/usage-monitor.sh" status
# Start (or confirm) the machine-global limit sentinel, then gate on it actually running:
bash ~/.claude/ultra/limit-sentinel.sh ensure
bash ~/.claude/ultra/limit-sentinel.sh status
```

`usage-monitor.sh status` call must print JSON object with `band` field. **If error or no JSON, STOP** — no proceed into run where you cannot read usage; tell user monitor script unreachable, re-run `/uc:setup`. **Never invent or guess usage status** — every usage figure you act on or report must come from this script real stdout.

`limit-sentinel.sh status` call must report `running:true` — sentinel = guaranteed post-limit resume for this run. **If cannot start** (`ensure` fail or `status` still `running:false`): do NOT stop — warn user automatic post-limit resume unavailable this run, remember sentinel down for §1.0b (fallback HOLD-WAKE apply only if account already limited — see usage-control.md "Fallback HOLD-WAKE").

### 1.0b Usage gating default (no question)

**No usage-mode question.** Limit handling always-on and reactive (see `usage-control.md`); only knob = spawn gating, default ON. Record `gating: on` in `## Execution Config` (written to `shared/lead.md` when file created in 1.7) — unless user plan-execution invocation explicitly ask ignore limits ("full speed", "ignore limits", "push through"), then record `gating: off`. Never ask; never re-decide mid-run.

Then run **one** status check (self-resolve account — no `$ACCOUNT_KEY` needed yet):

```bash
bash "$HOME/.claude/ultra/usage-monitor.sh" status
```

Read `.band`:
- `clear` → proceed normal.
- `soft` → record `{window}: soft` in `## Usage Blocks` (once `shared/lead.md` exist), no spawn until clear — this spawning gate, not stop. Pre-spawn check (Phase 2) govern when slot-fill resume.
- If account **already over limit** AND sentinel not started in §1.0: arm fallback HOLD-WAKE per usage-control.md ("Fallback HOLD-WAKE") before park. With running sentinel, no self-wake needed — sentinel wake this pane at reset.

### 1.1 Read Entire Plan Directory

Read ALL files in `documentation/plans/$ARGUMENTS/`:

- `README.md` — plan-level overview + flat task heading index
- `tasks/task-*/task.md` — authoritative per-task content (description, files, patterns, research pointers, success criteria, dependencies). Written by planning mode in Stage 4.
- `tasks/task-*/plan.md`, `tasks/task-*/impl.md` — existing per-task pipeline artifacts (if resuming)
- `shared/lead.md` — Lead-level shared notes (if resuming)
- `checkpoint-*.md` — checkpoint files (if any)

**Legacy-plan self-heal:** if README got `### Task N:` headings but `tasks/task-N/task.md` NOT exist, plan written in pre-split format. Before continue, extract each task embedded fields from README into `tasks/task-N/task.md` (follow `${CLAUDE_PLUGIN_ROOT}/templates/task.md`), then rewrite README to flat-index form. For `**Research:**` section, scan README Tech Stack list, map each entry to `documentation/technology/research/libraries/{lib}.md` if file exist; else write `None applicable` (Lead pre-spawn knowledge review in Phase 2 fill real gaps). If legacy `shared/knowledge-brief.md` exist, leave on disk as inert artifact but no read it — per-task task.md now authoritative. Log migration in `shared/lead.md`.

### 1.1b Tmux Layout Setup

Run layout-setup script — **always, unconditionally**. No wrap in your own tmux check; script own the gate. Keep instruction trivial ("run this one script") instead of conditional you might skip or paraphrase wrong:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-setup.sh"
```

Script single runtime gate = `$TMUX_PANE` (no-op outside tmux). Inside tmux it ensure layout daemon running, name this — Lead/main — pane `@agent-name=main-context`, turn on pane-border labels; actions and skips log to `~/.claude/ultra/tmux-layout-setup.log`. Daemon arrange panes as agents spawn and self-label. **You run NO tmux commands yourself** beyond this one script — agents self-label; PM verify; Pre-Spawn Checklist (§2.6) re-run this script before every spawn, daemon self-heal unlabelled Lead pane.

### 1.1c Name the Window

Name tmux window with plan so identifiable in status bar. Resolved plan = `$ARGUMENTS` (full `NNN-name`); read its README title, apply standardized plan form:

```bash
NNN=$(printf '%s' "$ARGUMENTS" | cut -d- -f1)
TITLE=$(sed -n 's/^# Plan: //p' "documentation/plans/$ARGUMENTS/README.md" | head -1)
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tmux-window-name.sh" "UC::P-${NNN}::${TITLE}"
```

Window-name analogue of pane-label setup above — script own `$TMUX_PANE` gate, sanitize and truncate for status bar, disable tmux automatic-rename so name stick, no-op outside tmux. Window naming orthogonal to pane-label/layout-daemon system, so no conflict.

### 1.2 Resume Detection

If `checkpoint-*.md` files exist:

1. Read LATEST checkpoint (highest timestamp)
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
5. If no: confirm user want discard progress, then start fresh
6. Either way, if `shared/escalations.md` exist with `open` entries, re-print them after resume summary — still awaiting user decision (see `phase-4-failure-handling.md` § "Non-Blocking Escalation Queue")

### 1.3 Task Pipeline

Team shape and executor model per-task, read from `tasks/task-N/task.md` (`**Type:**`, `**Executor model:**`; missing = `code` + `opus`): `code` task get full pipeline team — **Executor + Reviewer + Tester** — `ops` task get **solo Executor** (rubric: `${CLAUDE_PLUGIN_ROOT}/references/planning-framework/task-classification.md`). External library knowledge come from each task `**Research:**` pointers in same task.md, populated by planning Stage 2, reviewed per-task by Lead just before spawn (see Phase 2). Mid-execution gaps flow through `ADVICE` channel; Lead invoke `/uc:research` as needed, append new pointers to task.md.

### 1.4 Concurrency Decision

Decide how many task-teams can run concurrent:

| Plan Size | Max Concurrent Task-Teams |
|-----------|--------------------------|
| 1-3 tasks | 1-2 |
| 4-8 tasks | 2-3 |
| 9+ tasks  | 3-4 |

Max ceiling: **4 concurrent task-teams**. Only plan-wide teammate = **Project Manager** (own liveness monitor) — no persistent knowledge teammate, usage limits handled reactive by machine-global limit sentinel (process, not agent).

Each slot = 1 task-team. For `code` task, Executor, Reviewer, Tester all spawn together when slot open — Reviewer and Tester front-load takes (REVIEWER TAKE, TESTER TAKE) before Executor plan. All members exit together when task done. `ops` task slot hold its solo Executor.

Tasks normally spawn when slot available AND all dependencies completed. **Exception — pipeline pre-spawn:** when Executor signal `code complete`, Lead may pre-spawn next dependent task into `planning` stage if concurrency slot free — see SKILL.md "How a Task-Team Works" and message handler table for rules. Pre-spawned successors count toward concurrency limit, wait at new gate for `Implementation approved` before write code. At most one pre-spawn per `code complete` event.

### Model Assignment

| Role | Model | Rationale |
|------|-------|-----------|
| **Executor** | **per task** — task.md `**Executor model:**` (`sonnet` / `opus` / `fable`; absent → opus) | Chosen at planning per task-classification rubric — executor only role whose model vary |
| Reviewer | sonnet | Pattern recognition, architecture conformance |
| Tester | sonnet | Test execution, failure diagnosis |
| Project Manager | sonnet | Event-driven coordination — dashboard, budget tracking, own liveness monitor (bash do all checking via Monitor; model wake only on NUDGE candidates) |
| Researcher (subagent) | sonnet | One-shot external documentation retrieval — spawned by Lead via `/uc:research` on cache miss |

### Permission Modes

Every spawned role — Executor, Reviewer, Tester, PM, researcher subagent — run with mode `bypassPermissions`.

### 1.5 Usage Gating & Limit Sentinel

Gating recorded in 1.0b; sentinel ensured in §1.0 — full semantics in `references/usage-control.md`.
With `gating: on` (default) Lead run pre-spawn soft-band check and track blocks in `shared/lead.md` → `## Usage Blocks`; with `gating: off` it skip those checks and sentinel skip advisories (reset wakes always happen).
Proceed to 1.6.

### 1.6 Create Task List

Create ONE Lead-side task per plan task — no role prefixes. Pipeline stage tracked in metadata. Source task subject/description from `tasks/task-N/task.md` (already on disk from planning Stage 4 — do NOT parse README sections for task content):

```
TaskCreate({
  subject: "task-1: {title from task.md heading}",
  description: "{1-line summary from task.md Description} | See tasks/task-1/task.md",
  activeForm: "Processing task 1: {title}",
  metadata: { "stage": "pending", "retry_count": 0 }
  // stage values: "pending" | "planning" | "impl" | "review" | "test" | "done"
  // ops tasks skip "review" and "test": pending → planning → impl → done
})
```

Set `addBlockedBy` from each task.md Dependencies field (sequential ordering). TaskCreate description = pointer, not content duplicate — authoritative content = task.md itself.

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

`tasks/task-N/task.md` files already exist from planning Stage 4 — do NOT re-create. Do create or update `shared/lead.md` with: plan overview, concurrency decision, key architectural constraints, task dependency graph, critical decisions, execution config (`gating: on|off` from 1.0b, `account_key` from 1.8), amendments log (initially empty).

`plan.md` and `impl.md` written later by Executor during its workflow — no pre-create here.

### 1.8 Resolve Account Identity

Resolve active account key so sentinel registration (§1.9b) and budget checks reference right account (same value `usage-monitor.sh` resolve internally):

```bash
ACCOUNT_KEY=$(source "$HOME/.claude/ultra/lib.sh" && slugifyEmail "$(claude auth status --json 2>/dev/null | jq -r '.email // empty')")
```

Persist in `shared/lead.md` under execution config so available if session recovered from checkpoint.

### 1.9 Project Manager Spawn

Before spawn any task-teams, spawn plan-wide coordinator: **PM** (own liveness monitor).

1. Spawn `pm-{PLAN_NAME}` via `Agent` tool in teammate mode (`name="pm-{PLAN_NAME}"`, `run_in_background: true`) using PM spawn prompt in `references/phase-2-spawn-prompts.md`. PM got Bash + Monitor access, self-label its pane, start liveness monitor (`usage-monitor.sh watch "$PLAN_DIR"` — no account or mode arguments) on startup.

PM self-label its tmux pane when tmux available (skipped otherwise). No tmux commands needed from you.

2. **Verify teammate backend really tmux (cancel if not).** §1.0 gate = heuristic; this = authoritative check, against backend Claude Code actually recorded. Read session team config, confirm PM landed on tmux pane:

```bash
TEAM_CFG=$(grep -rl "\"pm-{PLAN_NAME}\"" "$HOME/.claude/teams"/*/config.json 2>/dev/null | head -1)
[ -z "$TEAM_CFG" ] && TEAM_CFG=$(ls -dt "$HOME/.claude/teams"/session-*/config.json 2>/dev/null | head -1)
jq -r '.members[] | "\(.name) backendType=\(.backendType) pane=\(.tmuxPaneId)"' "$TEAM_CFG" 2>/dev/null
```

PM must show `backendType=tmux` with real pane id (e.g. `%168`), **not** `backendType=in-process` (pane `in-process`/`leader`). If PM `in-process`, environment downgraded backend silent — **abort run**: send `shutdown_request` to `pm-{PLAN_NAME}` (and `TaskStop` any background tasks), record abort in `shared/lead.md`, stop with same remediation as §1.0 gate ("Run `/uc:setup` to set `teammateMode: tmux`, relaunch inside tmux, re-run"). Do **not** continue into Phase 2 on in-process backend — that the degraded pipeline user reported.

No Knowledge Brief synthesis step. Research live per-task in each `tasks/task-N/task.md` `**Research:**` section (populated by planning Stage 4), Lead review it per-task at spawn time in Phase 2.

### 1.9b Sentinel Registration

Write sentinel registration file so machine-global limit sentinel know this plan panes and account (which pane to inject `SENTINEL` messages into, which tasks to append `RESUME` to at reset, whether advisories apply). `$GATING` = `gating` value from 1.0b (`on` or `off`); `$ACCOUNT_KEY` from 1.8:

```bash
PLAN_ABS=$(cd "$PLAN_DIR" && pwd)
mkdir -p ~/.claude/ultra/sentinel/plans
jq -n --arg pd "$PLAN_ABS" --arg ak "$ACCOUNT_KEY" --arg g "$GATING" \
      --arg lp "$TMUX_PANE" --arg ts "$(tmux display-message -p '#{session_name}')" \
      --arg ca "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{plan_dir:$pd, account_key:$ak, gating:$g, lead_pane:$lp, tmux_session:$ts, created_at:$ca}' \
      > ~/.claude/ultra/sentinel/plans/{PLAN_NAME}.json
```

On checkpoint-resume, re-write this file (idempotent) — Lead pane and tmux session may have changed since original run. Registration removed at Phase 5 completion.

### 1.10 Proceed to Phase 2

Setup done — gating recorded (1.0b), PM live and confirmed (1.9), sentinel registration written (1.9b). Spawn task teams per Phase 2 (no first-tick STATUS to wait for).
