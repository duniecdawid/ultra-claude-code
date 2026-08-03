---
description: Ultra Claude system guide. Advises which skills, agents, and workflows to use for any task. Guides extending the system with new capabilities. Use when asking "how do I accomplish X", "what should I use for Y", or "extend the system with Z".
user-invocable: true
argument-hint: "question about Ultra Claude (optional)"
---

# Help

> **Human-facing text.** The catalog entries below are read by users directly and relayed to them verbatim. Keep full sentences and plain prose — structural trims are fine, register compression (caveman/engine passes) is not.

## Startup

Read the current version and recent changes from CHANGELOG.json:

```bash
VERSION=$(jq -r '.[0].version' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")
echo "Ultra Claude v${VERSION}"
echo ""
echo "Recent changes:"
jq -r '.[0:5] | .[] | "  \(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format the output as a readable table. Then answer the user's question. If invoked with no argument, follow the changelog with a brief system overview and list common workflows pointing to the right skill.

## System Architecture

Ultra Claude is a spec-driven development platform built from three layers:

- **Skills** — user-invocable workflows (triggered via `/uc:{name}`) that orchestrate multi-step tasks like planning features, debugging, or managing docs
- **Agents** — specialized subagents spawned by skills to do focused work (code survey, testing, reviewing, execution)
- **References & Templates** — reusable document templates and guides in `skills/docs-manager/references/` and `templates/` that standardize output across all skills

Skills read the codebase and documentation, spawn agents for parallel work, and produce plans or documentation as output. Plans live in `documentation/plans/{NNN}-{name}/` — each a README plus per-task `tasks/task-N/task.md` files — and are executed by agent teams via `/uc:plan-execution`.

## Skills

### Setup & Onboarding

**Dashboard** (`/uc:dashboard`)
Connects projects to the Ultra Claude Dashboard at `dashboard.ultra-claude.dev` for real-time visibility, manages multiple dashboard accounts with per-project routing, and transfers project ownership between accounts. Use when setting up dashboard sync, troubleshooting agent connectivity, checking sync status, controlling which account a project syncs to, or moving a project to another account. Guides agent installation, documents the non-interactive account CLI (`assign`/`default`/`auto-assign`/`move`) plus the interactive REPL, and verifies connectivity with self-contained debug checks.

**Setup** (`/uc:setup`)
One-time machine configuration — installs prerequisites (Node.js, optionally tmux), configures the shell and settings.json for agent teams and tmux teammate panes, removes the legacy `ANTHROPIC_DEFAULT_*_MODEL` pins earlier versions wrote (model choice is Claude Code's and yours, not Ultra Claude's), offers the fullscreen renderer and VS Code settings, optionally scaffolds the user-level `machine-context` skill through an interactive interview, and installs and starts the machine-global limit sentinel. Use after plugin installation, on a new machine, to change tmux mode, fix screen tearing/flicker, add machine-context later, configure VS Code, or update the `ultraclaude-agent` package. Idempotent — writes a version marker and never clobbers user-written machine-context files without explicit confirmation.

**Migrate** (`/uc:migrate`)
Brings projects into Ultra Claude and keeps them current — handles fresh initialization, legacy project detection, and version-aware incremental upgrades via structured migrations in CHANGELOG.json. Use when onboarding a new project, after running `/uc:update`, or when upgrading an existing project to the latest Ultra structure. Produces scaffolded documentation, `.claude/ultra/` configuration, coding standards, a version marker for future upgrades, and a small Ultra Claude promo footer in the project README.

### Planning & Research

**Discovery Mode** (`/uc:discovery-mode`)
Leads product research as a Head of Product persona, spawning an internal Explore subagent in parallel with a `/uc:research --mode=market` call for external competitor/trend analysis, then synthesizing findings into product documentation. Use for product vision, requirements, user personas, competitive analysis, or technology landscape assessment. Produces documentation artifacts (product description, research report, requirements, personas) — never code.

**Roadmap** (`/uc:roadmap`)
Decomposes a product into sequenced plan stubs by analyzing product/architecture docs, building a dependency graph, and topologically sorting build phases. Use after discovery/migrate when the product is too large for a single plan. Produces `ROADMAP.md` with execution order and numbered stub plans ready for `/uc:feature-mode` to detail.

**Feature Mode** (`/uc:feature-mode`)
Plans new features through a 4-stage process: challenge scope, research architecture/code/dependencies (tracking research-to-task mapping for durable per-task pointers), discuss approach with user — including each task's type (code/ops) and executor model (sonnet/opus/fable) per the task-classification rubric — and write the plan. Use when starting a new feature, adding functionality, or planning significant changes. Produces the plan README with a flat task heading index and per-task files (description, type, executor model, files, patterns, Research pointers, success criteria, dependencies) ready for execution.

**Debug Mode** (`/uc:debug-mode`)
Investigates bugs through structured hypothesis generation, parallel evidence gathering via Explore and System Tester agents, and root cause analysis. Use when debugging issues, fixing regressions, or investigating mysterious failures. Produces a fix plan whose task files extend the base template with `**Regression criteria:**` and `**Failing test first:**` sections.

**Critical Brainstorm** (`/uc:critical-brainstorm`)
Interactive devil's advocate mode that stress-tests solutions through research-backed challenge, tradeoff analysis, risk identification, and future problem prediction. Use when you want opinions challenged, need to debate approaches, or think critically about any decision. Stays in dialogue mode through multiple exchanges until you signal satisfaction — no implementation.

**Research** (`/uc:research`)
Cache-first external research covering library/API documentation, architectural patterns, and market/competitor analysis via a single auto-classified interface — fresh cache hits read directly from disk while cache misses dispatch the stateless `researcher` subagent in the background, so the conversation continues and findings are relayed on completion. Use when adding libraries, investigating patterns or best practices, running competitor analysis, asking how Claude Code / Claude Agent SDK / Anthropic API features work, or any "how does X work / what changed in X / best practice for X" question — Claude/Anthropic topics auto-classify as `library` mode. Produces committed research files in two indexed scopes — product/domain research under `documentation/technology/research/` and `documentation/product/research/`, Claude harness research under `.claude/ultra/research/` — with frontmatter-driven per-entry staleness.

### Execution

**Plan Execution** (`/uc:plan-execution`)
Orchestrates multi-task plan execution through per-task teams that self-coordinate from file-based context via the shared task-team-startup protocol — code tasks get Executor + Reviewer + Tester (executor model per task: sonnet/opus/fable), ops tasks a solo Executor — while Lead brokers mid-execution `ADVICE` and `QUERY` (external docs via /uc:research). Use after plan approval by running `/uc:plan-execution {number}`. Produces per-task `plan.md`, `impl.md`, and `test-strategy.md` artifacts, review and test verdicts, and a Project Manager operational report — user decisions ride a non-blocking escalation queue (`shared/escalations.md`) so an unattended run never stalls on a question.

**Checkpoint** (`/uc:checkpoint`)
Saves execution state (task pipeline stages, active teams, decisions, blockers) to a timestamped file for session recovery. Use periodically during long executions, before session shutdown, or before risky changes. Produces a checkpoint that the Lead can read on resume to reconstruct state and continue execution.

### Documentation & Verification

**Docs Manager** (`/uc:docs-manager`)
Guards the canonical documentation structure — routing documents to correct directories, enforcing a single canonical home per fact (drift-prone content lives in one place, linked with standardized anchored cross-links rather than duplicated), and maintaining a navigable index. Always enabled — use proactively whenever any skill or agent creates documentation. Redirects violations, keeps decision residue in RFCs and settled state in design docs, and updates `documentation/README.md` as the source of truth.

**Doc-Code Verification** (`/uc:doc-code-verification-mode`)
Compares documentation claims against code reality using parallel Checker agents, and additionally detects drift-prone content duplicated across documents and broken cross-reference anchors. Use to find doc-code gaps, deduplicate docs, verify cross-link integrity, or sync docs with implementation. Produces a structured plan distinguishing "docs are wrong" vs "code is wrong" with evidence, consolidation tasks that merge duplicated content into one canonical home, and structural-fix tasks carrying a `**Docs-manager reference:**` field pointing at the relevant docs-manager guide.

**Context Management** (`/uc:context-management`)
Manages the `context/` directory as a structured knowledge base for external systems (APIs, SDKs, protocols) with git submodule support. Use when adding external API documentation, SDK references, or system context that informs specs. Produces a `context/README.md` index and organized `{system}/docs/` and `{system}/code/` layout.

### Project Management

**Backlog** (`/uc:backlog`)
Lightweight backlog split across four category files in `documentation/backlog/` — bugs (B-NNN), questions (Q-NNN), ideas (I-NNN), and debt (D-NNN) — with priorities, labels, blocking relationships, and documentation references. Use to note something for later, log a bug, record a question or blocker, flag tech debt, label items with `#tag` syntax, filter by label, or ask "what should we work on". Provides list/add/update/done/label/link/block operations with priority sorting and `#tag` filtering — skills never auto-add items, they triage backlog-worthy findings with the user first.

**Plan Status Sync** (`/uc:plan-status-sync`)
Scans all plans, infers actual status from execution artifacts (operational reports, checkpoints, task completion), and reconciles README statuses with `plan.json` at plan root — preserving `planning` and `cancelled` statuses and the plan-level `stage` field for plans still being shaped or abandoned. Use to fix stale statuses after crashed executions, create missing plan.json for legacy plans, or audit plan state. Produces corrected status files with consolidated plan+task state in a single file.

### Infrastructure

**Harness Builder** (`/uc:harness-builder`)
Knowledge base for building harness components — skills, agents, hooks, protocols — plus a mandatory staged build workflow. Use when creating or refactoring a skill or agent, writing descriptions or prompts, auditing session context cost (`scripts/context_audit.py`), or optimising resident text. Build tasks enter Claude Code's native plan mode and walk structural → lexical → compression (`uc:caveman-compress`) → plan-presentation stages with per-stage discussion gates; non-negotiables include the Opus floor, always invoking `/skill-creator:skill-creator`, description budgets, and before/after refactor testing.

**Rename Window** (`/uc:rename-window`)
Renames the current tmux window via the shared `scripts/tmux-window-name.sh` primitive (sanitizes, truncates for the status bar, and disables tmux automatic-rename so the name sticks). Use to label a window by what it is working on, or to apply Ultra Claude's `UC::P-NNN::<plan>` / `UC::<Mode>::<subject>` convention by hand — planning modes and plan-execution apply it automatically, with the plan ID taking priority. Produces a renamed window that survives shell-prompt redraws; no-ops outside tmux.

**Railway** (`/uc:railway`)
Manages Railway.com deployments via CLI with environment variable-based multi-account token switching, handling deployments, logs, variables, and config-as-code. Use for Railway deployment workflows, account switching, debugging failed deployments (surfaces newest deployment via `--latest` and `deployment list`), or service configuration. Provides command wrappers that resolve the correct token per project directory.

**Tailscale Setup** (`/uc:tailscale-setup`)
Configures Tailscale to expose local services securely within the tailnet via `tailscale serve` or publicly via `tailscale funnel`. Use when exposing dashboards, dev servers, or preparing services for remote access. Validates the full prerequisite chain and enables HTTPS-wrapped local services.

**Update** (`/uc:update`)
Updates Ultra Claude to the latest version via the Claude Code plugin marketplace using `claude plugin update`. Use after hearing about new features or when wanting the latest version. Shows changelog since last update, runs post-update housekeeping (file migration, tmux daemon restart when tmux mode is active, setup verification), and recommends `/uc:migrate` in each project if structural changes occurred.

## Reference Libraries

Reference libraries are shared instruction sets — not skills. Planning modes inherit them and extend them per-stage via files in their own `references/` directories.

**Planning Framework** (`references/planning-framework/`)
Defines the 4-stage planning flow (Understand → Research → Discuss → Write), conversational rules, existing-plan handling, approval gates, and post-approval hard stop. Inherited by feature-mode, debug-mode, and doc-code-verification-mode through per-stage extensions in each mode's `references/stage-N.md`. Discovery-mode does not use it because it produces docs, not plans.

## Agents

Agents are spawned as subagents by skills. They don't run independently — skills orchestrate them. Execution-team agents (Code Reviewer, Project Manager, Task Executor, Task Tester) coordinate through the execution communication protocol (`skills/plan-execution/references/execution-communication-protocol.md`): SendMessage is the primary channel with `signals.jsonl` the durable log and delivery backstop, each agent runs one persistent inbox monitor, and the Executor owns unit/integration tests while the Tester owns acceptance tests.

**Caveman Compress**
Compression-engine wrapper — runs the caveman-compress CLI on a scratch copy of a body artifact (`prompt-body` | `doc-section` | `protocol-format`; never descriptions — the engine preserves frontmatter verbatim) and returns the compressed version plus a cut list tagged clean / fixable-with-repaired-wording / harmful; proposition-only, never edits outside scratch. Spawned at stage 3 of `/uc:harness-builder`'s build workflow, one spawn per artifact, concurrently when several. Parent adopts cuts item by item — no wholesale accept/reject; yield percentage is diagnostic only.

**Checker**
Compares specific code against documentation claims for a single topic, returning discrepancies with severity levels and exact file:line references. Spawned by doc-code verification to verify isolated aspects of the system. Produces structured verification reports identifying factual differences between docs and implementation.

**Code Reviewer**
Sends a standards-aware `REVIEWER TAKE` (persisted as `take.md`) immediately after spawn, before the Executor writes `plan.md`, then reviews completed code against standards, architecture, and patterns as a read-only quality gate. Scope is the Executor's work including its unit/integration tests held to the test-strategy contract — tester-owned acceptance tests sit outside the formal gate. Produces persistent take and feedback files alongside PASS/FAIL verdicts.

**Code Surveyor**
Performs fast structural scans of code packages to catalog files, components, data structures, dependencies, and architectural patterns. Spawned by migrate and verification orchestrators to quickly understand what's implemented. Returns concise structured overviews with file-line references for mapping code to requirements.

**Doc Surveyor**
Explores documentation sections to identify content type, key topics, specifications, and implementation references. Spawned by migrate and verification orchestrators to understand what's documented. Returns structured overviews for mapping documentation claims to implementations and identifying gaps.

**Fresh Eyes**
Reads a body of finished written work — a plan directory, a doc set, any scope it is pointed at — in fresh context with none of the conversation that produced it, and reports where the work is wrong: wrong solution, unforced complexity, an approach out of step with how the field solves this, performance, business requirements not actually satisfied. Offered once at Stage 4 of every planning mode right after the plan files are written, and spawnable ad hoc against any scope; opt-in, because fable burns usage at ~2× opus. Produces findings ordered by how much each should change the work, each with its evidence and what fixing it takes — written to the caller's output path (`shared/plan-review.md` for plans) or returned inline — as propositions the user folds in, never a gate.

**Project Manager**
Operational coordinator for plan execution — derives per-task stage state from signals, owns the background liveness monitor and verifies its `NUDGE` candidates (pinging the executor, escalating to Lead only on confirmed non-response), and tracks per-task budget data from the limit sentinel's passively-written usage events. Spawned once per plan execution; event-driven, waking on messages and monitor emits — it performs no usage-limit monitoring of its own. Produces operational reports analyzing token efficiency, budget utilization, communication health, repeated work, classification calibration (planned task type/model vs what the run showed), and system improvement recommendations.

**System Tester**
Reproduces reported bugs scientifically following exact steps, observing outputs and trying variations to understand boundary conditions — never fixes code. Spawned by Debug Mode to validate bug reports and test proposed fixes. Produces structured reproduction reports with evidence and observations informing fix strategies.

**Task Executor**
Hub of each task team — receives the Reviewer's and Tester's TAKEs, writes `plan.md` (execution delta), implements code plus its own unit/integration tests covering the `TESTER TAKE`'s unit-layer contract, and drives parallel review/test cycles to verdicts; its model is chosen per task at planning (sonnet/opus/fable). Never edits tester-owned acceptance test files — commits them verbatim at task end; brokers external docs via `QUERY:` to Lead and judgment calls via `ADVICE REQUEST`; on an ops task it runs solo, executing the runbook, verifying success criteria itself, and holding monitoring windows via bounded Monitor rounds. Produces `plan.md` and `impl.md` (implementation delta with INTEGRATION and GOTCHA notes, or the ops log for ops tasks).

**Task Tester**
Sends an upfront `TESTER TAKE` at task start (acceptance-case list plus the unit-layer cases the Executor's tests must cover, persisted as `test-strategy.md`), then authors black-box acceptance tests from `task.md`'s success criteria and product docs — never from `impl.md`. Spawned automatically with each task team in `/uc:plan-execution`; verifies code by running tests and launching frontend work in a browser to visually confirm the UI, demanding missing unit coverage via `TEST_FAIL` naming the exact cases rather than patching it. Produces `test-strategy.md` and persistent feedback files alongside pass/fail verdicts with evidence.

**Researcher**
Stateless one-shot researcher spawned by the `/uc:research` skill on cache miss, dispatched in the background by default. Fetches external documentation via Ref.tools or web search in one of three modes (library / patterns / market), merges findings into the target research file via targeted Edits (large files never force a full rewrite), and atomically upserts the research index (Bash mv). Never reads project source code — caller owns cross-referencing.

### Scripts (not agents)

**Usage monitor (`scripts/usage-monitor.sh`)**
Per-plan liveness monitor plus on-demand usage reader — the `watch` subcommand (run persistently by the Project Manager) emits verified-before-escalation `NUDGE` liveness candidates, and the `status` subcommand returns one-shot, time-authoritative JSON of both usage windows with a clear/soft band (soft starts at 90% and only gates starting new work). Use `status` for spawn gating and completion bookkeeping; trust NUDGEs as verified candidates, never blanket stall alerts. Usage-limit handling itself — advisories, post-limit wakes, rollover tracing — lives entirely in the limit sentinel.

**Limit sentinel (`scripts/limit-sentinel.sh`)**
One machine-global background process that handles usage limits reactively — detects limit-killed turns via the StopFailure hook, tracks every account's reset time, and at reset wakes everything that parked: durable `RESUME` signals into each task's `signals.jsonl` plus guarded tmux pane injection, with soft-band advisories and weekly-limit notifications. Installed and started by `/uc:setup`, self-healing via the SessionStart and StopFailure hooks, registered per plan. Execution rides each usage window to 100%, parks on the limit, and resumes automatically — no usage questions asked at plan start.

## Extending the System

Skills live at `skills/{name}/SKILL.md`, agents at `agents/{name}.md`, plan/task templates in `templates/`, documentation references in `skills/docs-manager/references/`. For how to write them — descriptions, prompts, tool grants, the mandatory review gate — use `/uc:harness-builder`.
