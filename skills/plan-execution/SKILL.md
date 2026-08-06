---
description: Executes approved plans through per-task pipeline teams (Executor/Reviewer/Tester) orchestrated by the Lead. Use when user says 'execute plan', 'run plan', 'start execution', or '/uc:plan-execution'. NEVER auto-trigger after plan approval — planning modes print the execution command for the user to run manually.
argument-hint: "plan number or name (e.g., '1', '001-user-auth')"
user-invocable: true
---

> **Spawn modes of `Agent` tool** — canonical definitions: `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`; primitive mapping: Phase 1 §1.0 (no `TeamCreate` tool exist).
> **Teammate mode / Mode T** (`name="{role}-{N}"` + `run_in_background: true`, no `team_name`): persistent execution roles — Executor, Reviewer, Tester, PM — SendMessage coordination; exit via `shutdown_request`.
> **One-shot mode** (no `name`, explicit `run_in_background` per spawn-modes reference): stateless workers, invisible to team graph — the `researcher`, Lead invoke via `/uc:research` (background default; `--sync` only when very next action gated).
> **Never** one-shot execution role; **always** one-shot stateless research — distinction load-bearing.
>
> **File-based team context.** Spawn prompts = minimal pointers. Per-task content (description, success criteria, patterns, research, files, dependencies) live in `documentation/plans/{plan}/tasks/task-N/task.md`, written by planning mode at Stage 4. Every team member — pipeline successors, crash re-spawns too — read task directory as First Action via `${CLAUDE_PLUGIN_ROOT}/skills/plan-execution/references/task-team-startup.md`. File writes broadcast `FILE-UPDATED task-N/{file}: reason` to active teammates — state stay in sync, no verbose messages.

# Plan Execution

You = **Lead** — orchestrator, domain authority for plan execution. You spawn teams, manage pipeline, handle shutdowns, approve pipeline implementations. PM (Project Manager) monitor health, maintain execution state files, produce operational reports. You send terse status updates to PM — keep execution state current.

**Plan:** $ARGUMENTS

## Plan Resolution

First: resolve `$ARGUMENTS` to full plan directory name:

1. **Pure number** (e.g., `1`, `3`, `12`) — zero-pad to 3 digits, scan `documentation/plans/` for directory matching `{NNN}-*` (e.g., `1` → `001-*`)
2. **Already `NNN-*` format** (e.g., `001-user-auth`) — use as-is
3. **Semantic name** (e.g., `user-auth`) — scan `documentation/plans/` for directory matching `*-{ARGUMENTS}`

No match → tell user, stop. Store resolved full directory name — all later `$ARGUMENTS` references in skill use resolved name.

## Prerequisites

**Quick setup check:** Read `~/.claude/ultra/uc-setup.json`. Missing, or `version` older than current plugin version (from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`) → warn: "Run `/uc:setup` to configure your environment." Continue checks below regardless.

Before start, read:
- `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md` — task executors write to `documentation/`, must follow docs-manager structure, references, routing rules.

Then verify:

1. Plan exist at `documentation/plans/$ARGUMENTS/README.md`
2. Agent teams enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: "1"` in settings)
3. Teammates spawn as **tmux panes** — both: you run **inside tmux session** (`$TMUX` set), and `teammateMode: "tmux"` in `~/.claude/settings.json`. Without this, named teammates default `in-process` (no panes), pipeline silently degrade. §1.0/§1.9 backend gate enforce — **stops** execution rather than run in-process.
4. Testing config: verify `documentation/technology/testing/` exist. Missing → warn: "No testing configuration found. Run `/uc:migrate` to set up documentation/technology/testing/." Continue execution — agents get limited testing guidance.

Prerequisites 1-3 missing → suggest `/uc:setup` (relaunch inside tmux), stop.

---

## Phase 1: Setup

**First, run Lead Tooling Preflight (§1.0):** load deferred agent-teams tools via `ToolSearch`, confirm `SendMessage` resolve; then clear **teammate backend gate** ($TMUX set + `teammateMode: tmux`). Teammates spawn with `Agent` tool, teammate mode (`name` + `run_in_background: true`) — no `TeamCreate` tool. `SendMessage` unavailable, or teammates would spawn `in-process` not tmux panes → stop, tell user run `/uc:setup` (relaunch inside tmux); never fall back to one-shot or in-process pipeline. §1.9 post-spawn check confirm recorded `backendType` = `tmux`, abort run if `in-process`.

Then read plan directory (all `tasks/task-N/task.md` files from planning Stage 4), detect resume state, handle legacy-plan self-heal if needed, decide concurrency, create Lead-side task list, spawn Project Manager. No Knowledge Brief synthesis — per-task research live in each task.md, Lead review per-task at spawn time, Phase 2.
→ Read `references/phase-1-setup.md`

---

## Phase 2: Pipeline Orchestration

Each task get dedicated mini-team, self-coordinate internally. **Lead** orchestrate everything — spawn full executor + reviewer + tester team, manage shutdowns, review plans. **PM** maintain execution state, monitor pipeline liveness.

### How a Task-Team Works

Executor, Reviewer, Tester spawn together at task start:

```
Reviewer:   reads task.md + standards + architecture + patterns → synthesizes REVIEWER TAKE
            → sends to Executor IMMEDIATELY (before Executor plans) → reads files as Executor progresses
            → formal review on "ready for review" → sends PASS/FAIL to Executor
Tester:     reads task.md + product docs + testing config → writes test-strategy.md
            → sends TESTER TAKE to Executor (acceptance-case list + unit-layer cases the
              Executor's tests must cover) in parallel with the REVIEWER TAKE
            → drafts black-box acceptance tests against task.md-declared interfaces while code is written
            → on "ready for test": verifies independently against success criteria + product docs
              → sends PASS/FAIL to Executor (unit-coverage gaps = FAIL naming missing cases, never patched)
Executor:   reads task.md (startup) → explores codebase → BLOCKS until BOTH takes arrive
            → writes plan.md (thin execution delta that extends task.md — does not restate it)
            → runs deviation self-check → if clean, proceeds to implement (no Lead gate)
            → if deviation: sends ADVICE REQUEST task-N [deviation] to Lead, waits for APPROVED/AMEND
            → writes code AND its unit/integration tests, broadcasts FILE-UPDATED on save points
            → signals Lead "code complete — writing impl report" BEFORE writing impl.md (fire-and-forget;
              Lead may pre-spawn the next dependent team in parallel)
            → writes tasks/task-N/impl.md
            → tells Reviewer "ready for review" AND Tester "ready for test" simultaneously (dual-write: signal + SendMessage)
            → PM reads signals.jsonl for execution state tracking (no STAGE-DONE/RETRY messages)
            → if FAIL: Executor fixes → "Ready for re-review" + "Ready for re-test" sent to both simultaneously
Both PASS:  Executor commits tester-owned acceptance test files → confirms teammates ready to exit
            → tells Lead "task done" → Lead sends shutdown_request → team exits
```

**Key principles:**
- **ONE dedicated team per task, NO sharing.** Task 1 get own Executor-1, Reviewer-1, Tester-1. Task 2 get own set. Never cross.
- **File-based team context** — spawn prompts minimal. Per-task content live in `tasks/task-N/task.md` (Lead-authored at planning, Lead amend during execution), `plan.md` (Executor execution delta), `impl.md` (Executor implementation notes), `test-strategy.md` (Tester take + owned-test-file list). Agents read task directory as first action on startup.
- **Takes before plan** — Reviewer, Tester front-load `REVIEWER TAKE` / `TESTER TAKE` right after startup reads; Executor block plan.md on both (explore codebase while waiting; escalate via `ADVICE REQUEST [knowledge]` if take stall). Replace old advisory plan-review round-trip; Reviewer formal code review later unchanged.
- **Executor plan.md = thin extension, not replan.** Record only what task.md lack — concrete function/class/signature choices, criterion-to-approach mapping by ID, take incorporation (reviewer + tester), risks. task.md stay authoritative.
- **Test authorship split by layer (dev/QA).** Executor write unit/integration tests with code; Tester own black-box acceptance tests from success criteria + product docs, in files listed in `test-strategy.md` — Executor never edit them, commit verbatim at task end. Unit-coverage gaps demanded via `TEST_FAIL`, never patched by Tester.
- **Successor pre-spawn (pipeline)** — same `code complete` signal evaluate whether next dependent task can start early. Free concurrency slot + pending task's only remaining blocker = this task → Lead pre-spawn that successor's Executor + Reviewer in `planning` stage (after append Pipeline mode block to successor task.md). Pre-spawned Executor research, plan, pass deviation self-check, then park at wait gate until Lead send `Implementation approved` when predecessor reach `task done`. Max one pre-spawn per `code complete` event.
- **Lead review research per-task at spawn time** — before every teammate spawn (`Agent` tool, teammate mode), Lead read task's task.md, verify every core technology task touch covered by `**Research:**` pointer. Mostly planner already met bar; if not, Lead invoke `/uc:research`, append pointers. See `references/phase-2-spawn-prompts.md` "Pre-Spawn Checklist" for exact rules.
- **PM = monitoring layer** — maintain execution state files, track parallel review/test timing, monitor pipeline liveness.
- **ADVICE and QUERY channels stay open** — Executor (ADVICE for Lead judgment/orchestration context, QUERY for external library docs); Reviewer, Tester (QUERY only).
- **Max 10 fix cycles** between executor/reviewer/tester before escalate to Lead — Lead queue non-blocking `max-cycles` escalation (§ "Non-Blocking Escalations").

### Team Composition

Every `code` task get same team: **Executor + Reviewer + Tester**; `ops` task get solo Executor (per-task type + executor model come from task.md — see `references/phase-1-setup.md` §1.3). Only plan-wide shared teammate = **Project Manager** (`pm-{PLAN_NAME}`). No persistent knowledge teammate — per-task research live in each task.md, Lead broker gaps via `ADVICE`/`QUERY` → `/uc:research`.

### Phase 2 Startup

Spawn initial task-teams, fill concurrency slots. Per slot: find next pending unblocked task (all dependencies completed), run **Pre-Spawn Checklist** from `references/phase-2-spawn-prompts.md` (task.md exist, knowledge review, pipeline-mode block if applicable), then spawn executor-N, reviewer-N, tester-N in parallel.

**Pre-spawn soft-limit check (skip only when `## Execution Config` record `gating: off`):** before each spawn, run `bash "$HOME/.claude/ultra/usage-monitor.sh" status`, read `.band`. If `soft`: do NOT spawn — record `{window}: soft` in `## Usage Blocks`, let in-flight work finish; re-check on next slot-fill opportunity, resume spawning once `clear`. This gating = only proactive limit element left — nothing ever stop in-flight work (limit itself = pause; limit sentinel = resume — see `references/usage-control.md`).

After spawn each team:
- SendMessage to PM: `"SPAWNED task-{N}: {task description from task.md heading}"` then `"STAGE task-{N} planning"`

### Message Handlers

Message arrive → match table below, execute action.

**Stay silent between wakes.** Message or monitor line wake you → process handler row, act — do NOT narrate state, plans, teammate activity, or that you woke. Many wakes = unavoidable lifecycle notifications (teammate come to rest, no-op message); on those, no action, no output. Only user-visible outputs = three listed below. (Replace former per-wake "wake-up trace" diagnostic — that made every unavoidable auto-wake verbose.)

**Three allowed user-visible outputs from Lead:**
1. Dashboard URL, if project connected to dashboard (relayed from PM at startup)
2. Escalation notices — printed question + standing-order line from § "Non-Blocking Escalations" below (include `SENTINEL NOTICE [7d]` decision)
3. Phase 5 completion summary

| Message | Action |
|---------|--------|
| Executor: `"Task {N} done — all stages passed"` | Read current usage via monitor script (account-correct): `pct=$(bash "$HOME/.claude/ultra/usage-monitor.sh" status \| jq '.five_hour.pct')`. **Write SHUTDOWN signal:** `echo '{"ts":"...","signal":"SHUTDOWN","author":"lead"}' >> tasks/task-{N}/signals.jsonl`. Send shutdown_request to executor-{N}, reviewer-{N}, tester-{N}. SendMessage to PM: `"COMPLETED task-{N}, current_pct={pct}"` then `"SHUTDOWN task-{N}"`. **Then check parked successors:** scan `shared/lead.md` pipeline-parked list — any pre-spawned executor-{M} parked at wait gate with predecessor = task-{N} → **dual-write IMPL_APPROVED signal:** `echo '{"ts":"...","signal":"IMPL_APPROVED","author":"lead"}' >> tasks/task-{M}/signals.jsonl`. SendMessage to executor-{M}: `"Implementation approved — predecessor task {N} passed all stages. Proceed to implement."`, clear M from parked list. **Then fill freed slot:** find next unblocked, non-pre-spawned pending task → run Pre-Spawn Checklist + spawn if found, SendMessage to PM: `"SPAWNED task-{K}: {description}"` then `"STAGE task-{K} planning"`. |
| Executor: `"Task {N} code complete — writing impl report"` | SendMessage to PM: `"STAGE task-{N} review"`, `"STAGE task-{N} testing"`. No reply to Executor — signal fire-and-forget (full team, tester-{N} included, alive since task start). **Then evaluate pipeline pre-spawn:** find max one pending task M where (a) all M's blockers `done` except task N, (b) current active task-teams `<` concurrency limit, (c) no other pre-spawned successor already parked at wait gate. Found → run Pre-Spawn Checklist for task-{M} (knowledge review, append Pipeline mode block to `tasks/task-{M}/task.md`), spawn executor-{M} + reviewer-{M} + tester-{M} via `Agent` tool (teammate mode: `name` + `run_in_background: true`), set task-{M} stage = `planning`, record `M → blocked_by N` in pipeline-parked list in `shared/lead.md`. SendMessage to PM: `"SPAWNED task-{M}: {description} (pipeline)"` then `"STAGE task-{M} planning"`. No eligible successor or no slot → do nothing — normal slot-fill handle it when task N reach `task done`. |
| Executor: `"Task {M} planning complete — awaiting implementation approval"` | Pipeline-spawned executor finished planning (own deviation self-check included), now parked at wait gate. Confirm M in `shared/lead.md` parked list. No reply needed — executor wait silent. Predecessor `task done` arrive → done-row handler above send `Implementation approved` message. |
| Executor: `"ADVICE REQUEST task-{N} [deviation]: {reason}"` | **Blocking.** Read `tasks/task-{N}/plan.md` + specific deviation reason. Decide: deviation justified by new information from planning/codebase exploration? Executor wait on `ADVICE_RESPONSE` signal — reply via `CommunicateTeamMember(to: "executor-{N}", message: {verdict}, signal: "ADVICE_RESPONSE")` per protocol §1 (verdict in signal's `note`) — never raw SendMessage. Justified → verdict `APPROVED` — also amend `tasks/task-{N}/task.md` to reflect new scope (e.g., add files to Files list, adjust success criteria), broadcast `FILE-UPDATED task-{N}/task.md: deviation approved — {short reason}`. Not justified → verdict `AMEND: {specific instructions}` — tell Executor how bring plan.md back into task.md scope. |
| Executor: `"ADVICE REQUEST task-{N} [complicated / deep-reasoning / knowledge]: {context + question}"` | **Non-blocking.** Read task.md if need context. Think through question with orchestration context (other tasks in flight, plan history, user intent from approval). Reply `ADVICE task-{N}: {guidance}` via `CommunicateTeamMember(..., signal: "ADVICE_RESPONSE")` per protocol §1 — Executor may be parked on that signal. No second-guess Executor judgment — default: answer question Executor actually asked, not rewrite approach. |
| Executor: `"QUERY: {question}"` (or Reviewer/Tester) | Invoke `/uc:research` with question. Cache hit return instant; cache miss spawn `researcher` subagent via `Agent` tool (one-shot mode). Reply `ANSWER: {excerpts + pointer}`. Also append pointer to `tasks/task-{N}/task.md` `**Research:**` section, broadcast `FILE-UPDATED task-{N}/task.md: research addition — {lib}`. New research durable for re-spawns, other teammates. |
| Any team member: `"FILE-UPDATED task-{N}/{file}: {reason}"` | No Lead action unless Lead about to act on that file. Broadcasts mainly for teammates. Stage transitions recorded in signals.jsonl per task — PM read signals.jsonl direct for execution state derivation. |
| Executor: `"Task {N} escalation needed"` | Queue per § "Non-Blocking Escalations". Append `max-cycles` entry with fix history; standing order: ack executor-{N} with plain `"escalation queued — hold, decision follows"`, keep team alive parked (context preserved for guided retry). Pre-spawned successor M parked with N as predecessor → note in entry — stay parked. Independent tasks continue. On drain — "retry with guidance": relay guidance to executor-{N}, reset cycle budget; "skip": shut down team-{N} + parked M, mark skipped; "abort": Phase 5 early shutdown. |
| Executor: `"PLAN-INVALIDATING: ..."` | Pause pipeline, handle per § "Mid-Execution Plan Changes → Plan invalidations" below: amend scoped damage, or queue `plan-invalid` escalation if plan look fundamentally wrong. |
| PM: `"Dashboard live at {URL}"` | Show user immediately: `"📊 Live dashboard: {URL}"` — do NOT silently consume. PM send this **only when project connected to Ultra Claude Dashboard** — absence normal; no message = no dashboard line to show. |
| User-channel: `"SENTINEL ADVISORY [{window}]: {pct}% used, resets {ISO}. ..."` (injected by the limit sentinel — protocol §7 system channel) | Budget tightening; push-delivered equivalent of pre-spawn check finding `soft`. Record `{window}: soft` in `## Usage Blocks` (with `resets_at`). Finish in-flight work; no new tasks until block clear. No agent paused; forward nothing. **When last in-flight team shut down, arm `HOLD-WAKE` self-wake at `resets_at + 120`** — soft-band stop park nothing, so your pane injection = plan's only wake. See `references/usage-control.md`. |
| User-channel: `"SENTINEL RESET [{window}]: window reset. RESUME appended to active tasks and sent to team panes ..."` | Window reset, sentinel already woke fleet (signals.jsonl `RESUME` with `author:"sentinel"` + pane injections). **Idempotent verification, not waking:** remove `{window}:` entry from `## Usage Blocks`; each in-progress task: check post-reset activity, re-send `"RESUME: usage reset. Continue work."` via `CommunicateTeamMember(..., signal: "RESUME")` to any agent still parked; **find previous agents before re-spawn — limit park agents, never kill:** run liveness probe (`phase-4-failure-handling.md` § "Liveness probe"), re-spawn only members probe prove gone (normal crash path — stage inferred from disk); re-run pre-spawn check, refill slots. |
| User-channel: `"SENTINEL NOTICE [7d]: weekly limit reached; resets {ISO} ..."` | Days-long park — user decision, not automation problem. Record `7d: limit` in `## Usage Blocks`, queue `sentinel-7d` escalation per § "Non-Blocking Escalations" (standing order: park plan, recover on eventual `SENTINEL RESET [7d]` — that path need no user input). Printed notice offer alternatives: switch plan to other account, or abort/park plan. |
| User: reply referencing an open escalation (by id, task, or topic) | Drain queue: match reply against `open` entries in `shared/escalations.md`, apply decision (guidance / retry / skip / amend / abort), mark each addressed entry `answered` with resolution, unwind standing order where decision differ (un-hold parked team, shut down skipped chain, refill slots after lifted pause). Re-print entries still `open`. |
| Monitor: `HOLD-WAKE` (fallback self-wake — armed when you go idle under a soft block with nothing in flight, or when phase-1 found the sentinel down while already limited) | Run same idempotent recovery as `SENTINEL RESET`: clear every block whose recorded `resets_at` passed, verify/wake still-parked agents, refill slots. Sentinel wake already handled → every step no-op. Any block's `resets_at` still future → re-arm at next-earliest `resets_at`. |
| PM: `"NUDGE-ESCALATION task-{N}: ..."` | PM already verified + pinged: task silent, no named wait (`WAITING_ON`/`BLOCKED_ON`, protocol §3 yield rule), no repo file activity, executor no answer PM status check — evidence-based, rare, not old blanket stall alert. Verify counterparty yourself with liveness probe (`phase-4-failure-handling.md` § "Liveness probe" — team config, then pane, then ping), re-send/re-signal missing item via `CommunicateTeamMember`, or apply Phase 4 failure handling (re-spawn) only if probe prove team dead. Never leave confirmed wrongly-parked task unresolved. |

After process message (handler action only — no narration), return to waiting silent. Checkpoint if triggered. Fill slots whenever one free.

### Non-Blocking Escalations

**Never call `AskUserQuestion` during execution (Phases 2–4).** Blocking question freeze Lead mid-turn — teammate messages cannot wake it, every task stall with it, even tasks question no touch. All user decisions flow through escalation queue instead: print question as plain text, end turn, keep coordinating. User answer whenever they return (minutes later or next morning); execution never sit blocked on prompt.

Mechanics (full protocol + standing-orders table in `references/phase-4-failure-handling.md` § "Non-Blocking Escalation Queue"):

1. **Append** entry to `documentation/plans/$ARGUMENTS/shared/escalations.md` (`ESC-{n}`, class, context, options with recommended default).
2. **Apply class's standing order** — reversible default that keep run alive: hold team parked, defer gap, park for reset (per-class table in reference; never skip, abort, or expand scope without user).
3. **Print** one plain-text notice (allowed output #2): question, standing order applied, entry id. Then end turn — event loop stay live.
4. **Continue** everything unaffected: only chain behind escalation hold; independent tasks keep spawning, completing.
5. **Drain on reply** (handler row above): apply user decision, mark entry `answered`, unwind standing order where decision differ.

Every remaining task behind open escalation → Lead go idle await reply — still wakeable by teammate messages, sentinel events, reply itself.

### Usage Response Protocol (reactive)

Usage limits handled reactive by machine-global **limit sentinel** (process, not agent — see `references/usage-control.md`). No usage mode, no upfront question, nothing ever stop in-flight work: **limit itself = pause; sentinel = resume.** Lead have exactly two jobs:

- **Spawn gating (non-interrupt).** Pre-spawn check from Phase 2 Startup: `soft` band → no new work; in-flight continue to 100%. Skip only when `## Execution Config` record `gating: off` (explicit user opt-out at plan start — "full speed" / "ignore limits").
- **Sentinel messages (injected into pane on protocol §7 system channel).** Handle per `SENTINEL ADVISORY` / `SENTINEL RESET` / `SENTINEL NOTICE` rows above. Operational input only — never scope changes, never approvals. Recovery always idempotent: sentinel wake fleet; you verify, re-spawn only crashes liveness probe confirm (limit park agents, never kill), refill slots.

**Usage Blocks tracking in `shared/lead.md`:**

```markdown
## Usage Blocks
- 5h: soft        (since 2026-07-23T18:09:00Z, resets_at 2026-07-23T18:50:00Z, pct=91)
- 7d: none
```

Block values: `soft` (soft band — no new spawns, in-flight continue) or `limit` (7d NOTICE — user informed, await reset/decision). Any block non-`none` → Lead spawn no new teams. Blocks clear on `SENTINEL RESET`, `clear` pre-spawn check, or fallback `HOLD-WAKE` whose `resets_at` passed.

**Governing principle: Lead may go idle only while guaranteed wake exist.** Sentinel = primary guarantee (verified in phase-1 preflight), but its wake = one tmux injection into one pane. Arm fallback `HOLD-WAKE` self-wake at `resets_at + 120` whenever you go idle with no teammate left to wake you — soft block with nothing in flight, or phase-1 find account limited with sentinel unstartable. Nothing parked after soft-band stop, so no `RESUME` reach any `signals.jsonl`; see "Fallback HOLD-WAKE" in `references/usage-control.md`. Never schedule wake earlier than `resets_at` — pre-reset wakes burn failed turns into active limit.

### Lead Priority Order

1. **Executor "task done"** — shutdown team, send `Implementation approved` to any parked successor, fill slots with next unblocked task.
2. **Executor ADVICE REQUEST [deviation]** — blocking. Read plan.md, decide APPROVED/AMEND, amend task.md + broadcast if approved.
3. **Executor "code complete"** — advance PM stage bookkeeping + evaluate pipeline pre-spawn of next dependent task.
4. **Executor ADVICE REQUEST [complicated/deep-reasoning/knowledge]** — non-blocking from Executor side but still answer promptly.
5. **QUERY messages** (any teammate) — run /uc:research, reply, amend task.md.
6. **PM alerts** — act on recommendations.
7. **Escalations** — queue + standing order per § "Non-Blocking Escalations"; drain on user replies.
8. **Checkpoint** — periodic save per Phase 3 triggers.

### Spawn Prompts

Ready to spawn teammates → read detailed spawn prompts per role.
→ Read `references/phase-2-spawn-prompts.md`

### Planning Without a Universal Gate

NO universal Lead plan review: task.md already encode user-approved scope, takes cover standards/architecture/testing fit, plan.md structurally thin delta — cannot silently expand scope. Both takes arrive → Executor write plan.md, run deviation self-check (every proposed file in task.md Files list, every criterion mapped, no take contradiction), implement direct on clean pass. Only failed self-check reach Lead — `ADVICE REQUEST task-{N} [deviation]`, blocking, answered `APPROVED` or `AMEND` — while `complicated` / `deep-reasoning` / `knowledge` cases = optional non-blocking pulls on Lead judgment, open throughout execution.

---

## Phase 3: Checkpoint

Save checkpoint when ANY of these:
- Every 3 completed tasks
- User run `/uc:checkpoint`
- Before risky plan amendments
- `SENTINEL ADVISORY`/`SENTINEL NOTICE` record soft/limit block (save state before possibly long parked period)

Triggered → Read `references/phase-3-checkpoint.md` for checkpoint template + content format.

---

## Phase 4: Failure Handling

Retry flow, escalation, crash recovery, session death.
→ Read `references/phase-4-failure-handling.md`

---

## Phase 5: Completion

Final gate, operational report, summary, shutdown, backlog review.
→ Read `references/phase-5-completion.md`

**Follow-up work:** Execution reveal follow-up work, bugs, ideas, tech debt not in plan → collect in completion summary under "Follow-up Items". After shutdown (step 5.5), first run backlog review (step 5.6 — update existing backlog items in light of completed plan), then triage each follow-up item with user per `${CLAUDE_PLUGIN_ROOT}/references/backlog-triage.md` (3-option variant — execution complete, so omit "Include in plan"). Check each candidate against just-reviewed backlog — matches update/link existing item, no add duplicate.

---

## Mid-Execution Plan Changes

### Discovered gaps (missing work that's in-scope)

Teammate discover work in plan scope but missed in task breakdown:

1. **Assess effort:** single file / endpoint / < 1 task worth?
2. **Small:** amend current task's `tasks/task-N/task.md` (add to Files, add success criterion, extend Description), broadcast `FILE-UPDATED task-N/task.md: amendment — {reason}`. Record amendment in `shared/lead.md` amendments log.
3. **Large:** queue `gap` escalation per § "Non-Blocking Escalations" — too big to silently add (standing order: defer — plan continue as written; gap recorded in entry + Follow-up Items). User reply can still pull it in as amendment or new task.
4. **Always log:** record every discovered gap + how handled in completion summary under "Amendments" — user get full visibility.

### Plan invalidations (from executor directly)

Teammate send `PLAN-INVALIDATING: ...`:

1. **Receive urgent message** with evidence.
2. **Pause pipeline** — no spawn new task-teams.
3. **Evaluate scope:**
   - **Single task affected** — update that task's `tasks/task-N/task.md` direct, broadcast FILE-UPDATED, current team handle.
   - **Multiple tasks affected** — update each affected `tasks/task-N/task.md`, broadcast per file, record in `shared/lead.md`, cancel pending tasks if necessary.
   - **Plan fundamentally wrong** — queue `plan-invalid` escalation with evidence (standing order: no new spawns; in-flight tasks finish, slots stay unfilled). User decide on drain: amend or abort.
4. **Resume pipeline** after resolution.

Parked pipeline successors stay parked through pause. Amendment (or user drain decision) drop or materially change parked successor's task → shut down that successor explicit before resume.

---

## Communication Protocol

| Channel | Direction | Use For |
|---------|-----------|---------|
| **Team-internal** | Executor↔Reviewer, Executor↔Tester | Direct peer-to-peer within task team. Technical collaboration. |
| **TAKEs** | Reviewer → Executor, Tester → Executor | REVIEWER TAKE (standards/architecture perspective) + TESTER TAKE (acceptance-case list + unit-layer test contract) sent parallel right after each agent's startup read, BEFORE Executor write plan.md. Persisted as `take.md` / `test-strategy.md` (latter also hold tester-owned test-file list), flagged via `REVIEWER_TAKE_READY` / `TESTER_TAKE_READY` signals. Executor block plan.md until both arrive. |
| **FILE-UPDATED broadcast** | Any agent → active teammates + Lead | `FILE-UPDATED task-N/{file}: reason` after write task.md / plan.md / impl.md at deliberate save point. Fire-and-forget, recipients re-read named file before next action. |
| **ADVICE** | Executor → Lead | `ADVICE REQUEST task-N [{case}]: {context + question}` — case = `complicated` / `deep-reasoning` / `knowledge` / `deviation`. Lead reply `ADVICE task-N: {guidance}` (or `APPROVED` / `AMEND` for deviation). Deviation mandatory + blocking; others optional, Executor decide waiting. |
| **QUERY** | Any team member → Lead | `QUERY: {question}` for external library/API/pattern docs. Lead run `/uc:research` — cache hit return immediate, cache miss spawn `researcher` subagent via `Agent` tool (one-shot mode). Lead reply `ANSWER: ...` AND append pointer to task's task.md Research section with FILE-UPDATED broadcast. |
| **Task file amendment** | Lead → `tasks/task-N/task.md` | Lead update task.md for mid-execution amendments, deviation approvals, research additions, pipeline-mode block appending. Every write trigger FILE-UPDATED broadcast. |
| **Operational status** | Executor → Lead | "Code complete — writing impl report", "planning complete — awaiting implementation approval" (pipeline-spawned), "task done", "escalation needed", "PLAN-INVALIDATING: ...". Lead act on these. |
| **Pipeline pre-spawn** | Lead → `Agent` (teammate mode) | Lead pre-spawn next dependent task's executor + reviewer + tester when predecessor signal `code complete` + concurrency slot free. Lead append Pipeline mode block to successor task.md before spawn; successor Executor read it during startup, park at wait gate after deviation self-check. |
| **Implementation approval** | Lead → Executor (pipeline-spawned) | `"Implementation approved — predecessor task {N} passed all stages. Proceed to implement."` — sent to parked executor when predecessor reach `task done`. |
| **Communication protocol** | All agents → `signals.jsonl` + SendMessage | Unified protocol, three procedures (not tools): `CommunicateTeamMember` (direct), `CommunicateTeam` (broadcast), `WaitForTeamMember` (receive). Each wrap SendMessage with durable signal layer. See `execution-communication-protocol.md`. |
| **Lead spawns the task team** | Lead → `Agent` (teammate mode) | Lead spawn executor, reviewer, tester together when slot open (after Pre-Spawn Checklist). |
| **Lead shuts down teams** | Lead → team members | Lead send shutdown_request after executor report "task done" (executor first confirm all teammates replied "READY TO EXIT"). |
| **Pane self-labeling** | Agent local | Spawn prompt define `TASK_ID`/`ROLE`; agent run tmux label per agent instructions (skipped when not in tmux). PM verify after SPAWNED (skipped when not in tmux). |
| **Lead → PM** | Lead → PM | Terse status updates (`SPAWNED`, `STAGE`, `COMPLETED`, `SHUTDOWN`, etc.) for execution state. |
| **PM → Lead** | PM → Lead | Status URL (startup), NUDGE-ESCALATIONs. |
| **PM → team members** | PM → any team member | Status checks, monitoring only. |
| **Per-task files** | Persistent | `tasks/task-N/task.md` (Lead/planning — authoritative task content), `tasks/task-N/signals.jsonl` (all agents — append-only signal log for durable pipeline state), `tasks/task-N/plan.md` (Executor — execution delta), `tasks/task-N/impl.md` (Executor — implementation delta), `tasks/task-N/take.md` (Reviewer — REVIEWER TAKE text), `tasks/task-N/test-strategy.md` (Tester — TESTER TAKE + owned-test-file list), `tasks/task-N/review-feedback.md` (Reviewer — failure details), `tasks/task-N/test-feedback.md` (Tester — failure details). Team members read via startup protocol. |

---

## Lead Behavior

### What You Do
- **Run Pre-Spawn Checklist every task** before spawn teammate — task.md exist, review research coverage (invoke /uc:research for gaps or staleness), append Pipeline mode block if pipeline-spawning. See `references/phase-2-spawn-prompts.md`.
- Spawn executor + reviewer + tester to fill concurrency slots (deps completed; pre-spawn soft-band check first), shut down completed teams
- Process every incoming message per Message Handlers table — ADVICE/QUERY brokering, pipeline pre-spawn, implementation approvals, sentinel messages, escalation queue + drains, plan-invalidating discoveries
- Send terse status updates to PM after each action (SPAWNED, STAGE, COMPLETED, SHUTDOWN, etc.)
- **Display dashboard URL to user** if PM send one — user's primary monitoring tool
- Checkpoint when triggered; run Phase 5 when all tasks done

### What You Do NOT Do
- Narrate teammate activity to user
- Comment on state transitions to user
- Send verbose status summaries (PM status updates = terse one-liners)
- Silently consume PM dashboard URL without show user

### Anti-Patterns

Real examples from past executions — do NOT produce output like this:
- "Reviewed building context. Pipeline progressing."
- "Waiting for executor-1 plan submission"
- "Executor-2 is writing. Implementing approved plan."
- "Executor-1 passed review. Publishing."
- "Waiting for executor-1 results. Executor-2 building fast."
- "Shared documentation plan and style guide with executor-1 and executor-2."
- "Executor-1 is idle waiting for knowledge response. Normal flow..."
- "Tester-1 ready and waiting. All team members standing by"
- "Plan looks solid." (unless formal `APPROVED` response to `ADVICE REQUEST task-N [deviation]`)
- "Executor-1 processing the approval"
- "Executor-1 has finished implementation and notified both"

All = **state narration** — describe teammate activity, predict what happens next, fill empty turns with status. Forbidden.

**No** per-wake-up text. Woken → process handler, act silent — emit nothing unless action = one of three allowed user-visible outputs (dashboard URL, escalation notice, completion summary).

---

## Constraints

- Never write implementation code — you orchestrate, not implement
- Never narrate or comment operational events to user — process wakes silent, act; only user-visible outputs = three allowed
- Never invent, guess, recall usage figure — every usage band/percentage you act on or report MUST come from actual stdout of `bash "$HOME/.claude/ultra/usage-monitor.sh" status`. Command error or no JSON → no fabricate status: surface failure, stop (monitor unreachable — re-run `/uc:setup`).
- Never call `AskUserQuestion` during execution — every user decision go through non-blocking escalation queue (§ "Non-Blocking Escalations"); blocking prompt deafen Lead to all teammates
- Always send terse status updates to PM after spawns, shutdowns, stage transitions
- Always checkpoint before session end
- Max 10 fix cycles per task before queue `max-cycles` escalation
- Any Usage Block non-`none`: no spawn new teams (in-flight work continue); blocks clear via `SENTINEL RESET`, `clear` pre-spawn check, or fallback `HOLD-WAKE`
- Always run final gate test suite before declare completion (only `code` tasks count: skip when plan have ≤1 code task and no `documentation/technology/testing/final-gate.md` exist, or plan have no code tasks at all — otherwise gate run so project's final-gate-only criteria honored)
- Keep shared/lead.md updated with plan-level decisions + amendments log; per-task amendments go to tasks/task-N/task.md (with FILE-UPDATED broadcasts), not shared/lead.md
- Never write to tasks/task-N/plan.md or tasks/task-N/impl.md — Executor-owned files
