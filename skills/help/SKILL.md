---
description: Ultra Claude system guide. Advises which skills, agents, and workflows to use for any task. Guides extending the system with new capabilities. Use when asking "how do I accomplish X", "what should I use for Y", or "extend the system with Z".
user-invocable: true
argument-hint: "question about Ultra Claude (optional)"
---

# Help

You are the Ultra Claude system advisor. Your job is to help users accomplish their goals using the right combination of skills, agents, and workflows.

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

Skills read the codebase and documentation, spawn agents for parallel work, and produce plans or documentation as output. Plans live in `documentation/plans/{NNN}-{name}/` and are executed by agent teams via `/uc:plan-execution`.

## Skills

### Setup & Onboarding

**Dashboard** (`/uc:dashboard`)
Connects to the Ultra Claude Dashboard at `dashboard.ultra-claude.dev` for real-time project visibility, manages multiple dashboard accounts with optional per-project account routing, and transfers project ownership between accounts (agent `move` or the dashboard's Incoming-transfers inbox). Use when setting up dashboard sync, troubleshooting agent connectivity, checking sync status, controlling which account a project syncs to, or moving/transferring a project to another account. Guides agent installation and setup, documents the non-interactive CLI account commands (`assign`/`default`/`auto-assign`/`move`) plus the interactive REPL — including that a cross-account `move` is an ownership transfer the daemon auto-reconciles (re-route or "transferred away"), while a same-workspace `assign` still needs a one-shot `push <project> --account <account>` back-fill — and verifies connectivity with self-contained debug checks.

**Setup** (`/uc:setup`)
One-time machine configuration that installs prerequisites (Node.js, optionally tmux), guides tmux mode selection (per-project, per-terminal, none, or custom), configures shell environment (1M context, agent teams) and sets `teammateMode` in settings.json so plan-execution teammates spawn as tmux panes rather than the silent in-process default, offers the Claude Code fullscreen renderer for flicker-free flat-memory output (opt-out, gated on Claude Code v2.1.89+, written as `"tui": "fullscreen"` in settings.json), offers to update the `ultraclaude-agent` npm package when already installed and outdated (never auto-installs), checks dashboard connectivity when the agent is installed, (optionally) scaffolds a user-level `machine-context` skill at `~/.claude/skills/machine-context/` via an interactive interview capturing the user's Chrome setup, VM/host topology, dev runtimes, network conventions, and the limit sentinel's account→profile map / notify command / standalone-wake toggle, installs the StopFailure hook and starts the machine-global limit sentinel (automatic post-limit session resume), (when VS Code is detected, opt-in) offers recommended client-side VS Code settings for the Claude Code extension printed as merged JSON to paste — alongside the mode-aware terminal profiles it already writes per tmux mode. Use after plugin installation, on a new machine, when fixing screen tearing/flicker, to add machine-context after the fact, to change tmux mode, to configure VS Code for Claude Code, to pick up a newly-published `ultraclaude-agent` version, or to upgrade the pinned default Opus/Sonnet models after a version bump (a re-run detects an outdated `[1m]` pin and rewrites it in place). Idempotent — writes a version marker, never clobbers user-written machine-context files without explicit confirmation.

**Migrate** (`/uc:migrate`)
Brings projects into Ultra Claude and keeps them current — handles fresh initialization, legacy project detection, and version-aware incremental upgrades via structured migrations in CHANGELOG.json. Use when onboarding a new project, after running `/uc:update`, or when upgrading an existing project to the latest Ultra structure. Produces scaffolded documentation, `.claude/ultra/` configuration, coding standards, a version marker for future upgrades, and a small Ultra Claude promo footer in the project README.

### Planning & Research

**Discovery Mode** (`/uc:discovery-mode`)
Leads product research as a Head of Product persona, spawning an internal Explore subagent in parallel with a `/uc:research --mode=market` call for external competitor/trend analysis, then synthesizing findings into product documentation. Use for product vision, requirements, user personas, competitive analysis, or technology landscape assessment. Produces documentation artifacts (product description, research report, requirements, personas) — never code.

**Roadmap** (`/uc:roadmap`)
Decomposes a product into sequenced plan stubs by analyzing product/architecture docs, building a dependency graph, and topologically sorting build phases. Use after discovery/migrate when the product is too large for a single plan. Produces `ROADMAP.md` with execution order and numbered stub plans ready for `/uc:feature-mode` to detail.

**Feature Mode** (`/uc:feature-mode`)
Plans new features through a 4-stage process: challenge scope, research architecture/code/dependencies (tracking research-to-task mapping for durable per-task pointers), discuss approach with user, and write the plan. Use when starting a new feature, adding functionality, or planning significant changes. Produces a plan README with a flat task heading index plus per-task `tasks/task-N/task.md` files (description, files, patterns, Research pointers, success criteria, dependencies) ready for execution.

**Debug Mode** (`/uc:debug-mode`)
Investigates bugs through structured hypothesis generation, parallel evidence gathering via Explore and System Tester agents, and root cause analysis. Use when debugging issues, fixing regressions, or investigating mysterious failures. Produces a fix plan with per-task `task.md` files that extend the base template with `**Regression criteria:**` and `**Failing test first:**` sections.

**Critical Brainstorm** (`/uc:critical-brainstorm`)
Interactive devil's advocate mode that stress-tests solutions through research-backed challenge, tradeoff analysis, risk identification, and future problem prediction. Use when you want opinions challenged, need to debate approaches, or think critically about any decision. Stays in dialogue mode through multiple exchanges until you signal satisfaction — no implementation.

**Research** (`/uc:research`)
Cache-first external research covering library/API documentation, architectural patterns, and market/competitor analysis via a single auto-classified interface — fresh cache hits read directly from disk while cache misses dispatch the stateless `researcher` subagent in the background by default (`--sync` to block), so the conversation continues and findings are relayed on completion. Use when adding libraries, investigating patterns or best practices, running competitor analysis, asking how Claude Code / Claude Agent SDK / Anthropic API features work, or any "how does X work / what changed in X / best practice for X" question — Claude/Anthropic topics auto-classify as `library` mode and the researcher queries Ref.tools plus the curated `docs.claude.com` URL roots in parallel. Produces committed research files in two scopes with separate indexes: product/domain research under `documentation/technology/research/{libraries,patterns}/` and `documentation/product/research/` (indexed at `documentation/technology/research/index.json`), and Claude harness research under `.claude/ultra/research/` (flat layout, indexed at `.claude/ultra/research/index.json`) — frontmatter-driven per-entry staleness (library 10d, patterns 90d, market 30d, historical research frozen).

### Execution

**Plan Execution** (`/uc:plan-execution`)
Orchestrates multi-task plan execution via file-based team context: Lead spawns the full Executor + Reviewer + Tester team with minimal pointer prompts, and every team member (including pipeline successors and crash re-spawns) reads its task directory (`tasks/task-N/task.md` + `plan.md` + `impl.md` + `test-strategy.md` + `shared/lead.md` + plan README) as its first action via the shared task-team-startup protocol. Reviewer and Tester speak first via a `REVIEWER TAKE` and `TESTER TAKE` sent to Executor before planning, Executor writes a thin `plan.md` execution delta and runs a deviation self-check (no universal Lead plan-review gate), and Lead brokers mid-execution `ADVICE` (complicated / deep-reasoning / knowledge / deviation) and `QUERY` (external docs via /uc:research, with durable per-task Research pointers appended to task.md). Use after plan approval by running `/uc:plan-execution {number}`.

**Checkpoint** (`/uc:checkpoint`)
Saves execution state (task pipeline stages, active teams, decisions, blockers) to a timestamped file for session recovery. Use periodically during long executions, before session shutdown, or before risky changes. Produces a checkpoint that the Lead can read on resume to reconstruct state and continue execution.

### Documentation & Verification

**Docs Manager** (`/uc:docs-manager`)
Guards the canonical documentation structure — routing documents to correct directories, enforcing a single canonical home per fact (drift-prone content lives in one place, linked with standardized anchored cross-links rather than duplicated), and maintaining a navigable index. Activated in projects with a `.claude/ultra/docs-format` file — use proactively when any skill or agent creates documentation. Redirects violations, keeps decision residue in RFCs and settled state in design docs, and updates `documentation/README.md` as the source of truth.

**Doc-Code Verification** (`/uc:doc-code-verification-mode`)
Compares documentation claims against code reality using parallel Checker agents, and additionally detects drift-prone content duplicated across documents and broken cross-reference anchors. Use to find doc-code gaps, deduplicate docs, verify cross-link integrity, or sync docs with implementation. Produces a structured plan distinguishing "docs are wrong" vs "code is wrong" with evidence plus consolidation tasks that merge duplicated content into one canonical home, and structural-fix tasks get a `**Docs-manager reference:**` field in their `task.md` pointing at the relevant docs-manager guide.

**Context Management** (`/uc:context-management`)
Manages the `context/` directory as a structured knowledge base for external systems (APIs, SDKs, protocols) with git submodule support. Use when adding external API documentation, SDK references, or system context that informs specs. Produces a `context/README.md` index and organized `{system}/docs/` and `{system}/code/` layout.

### Project Management

**Backlog** (`/uc:backlog`)
Lightweight backlog split across four category files in `documentation/backlog/` — bugs (B-NNN), questions (Q-NNN), ideas (I-NNN), and debt (D-NNN) — with priorities, labels, directional blocking relationships, bidirectional linking, and documentation references. Use to note something for later, log a bug, record a question or blocker, flag tech debt, label items with `#tag` syntax, filter by label, or ask "what should we work on". Skills never auto-add items — when they surface backlog-worthy work, they triage with the user first (see `${CLAUDE_PLUGIN_ROOT}/references/backlog-triage.md`). Provides list/add/update/done/label/unlabel/labels/link/block operations with per-category prefixed IDs, priority sorting, `#tag` filtering (AND semantics), computed blocked-by, and source tracking.

**Plan Status Sync** (`/uc:plan-status-sync`)
Scans all plans, infers actual status from execution artifacts (operational reports, checkpoints, task completion), and reconciles README statuses with `plan.json` at plan root — preserving `planning` and `cancelled` statuses and the plan-level `stage` field for plans still being shaped or abandoned. Use to fix stale statuses after crashed executions, create missing plan.json for legacy plans, or audit plan state. Produces corrected status files with consolidated plan+task state in a single file.

### Infrastructure

**Chrome Debug** (`/uc:chrome-debug`)
Diagnoses and auto-recovers Claude-in-Chrome browser connection failures — stale native host after auto-updates, suspended service workers, bridge pairing races, profile-scoped manifest paths, and `switch_browser` naming-prompt timeouts. Use on any `mcp__claude-in-chrome__*` failure or as a pre-flight health check before browser automation; supports single-browser and dual-browser setups. Reads machine-specific paths and preferences from `~/.claude/skills/machine-context/chrome-debug.md` when present and falls back to runtime detection via `$HOME`/`whoami`/`jq` otherwise.

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

Agents are spawned as subagents by skills. They don't run independently — skills orchestrate them.

**Checker**
Compares specific code against documentation claims for a single topic, returning discrepancies with severity levels and exact file:line references. Spawned by doc-code verification to verify isolated aspects of the system. Produces structured verification reports identifying factual differences between docs and implementation.

**Code Reviewer**
Writes `take.md` with a standards-aware `REVIEWER TAKE` using `CommunicateTeamMember` immediately after spawn (before plan.md is written), then reviews completed code against standards, architecture, and patterns as a read-only quality gate — scope is the Executor's work including its unit/integration tests (held to the test-strategy contract), while tester-owned acceptance tests sit outside the formal gate. Uses `WaitForTeamMember` (one persistent inbox monitor that follows signals.jsonl and wakes it on any relevant signal) to receive review/re-review/exit requests and `CommunicateTeamMember` for all verdicts (PASS/FAIL with signal backup). Produces persistent take and feedback files alongside pass/fail verdicts.

**Code Surveyor**
Performs fast structural scans of code packages to catalog files, components, data structures, dependencies, and architectural patterns. Spawned by migrate and verification orchestrators to quickly understand what's implemented. Returns concise structured overviews with file-line references for mapping code to requirements.

**Doc Surveyor**
Explores documentation sections to identify content type, key topics, specifications, and implementation references. Spawned by migrate and verification orchestrators to understand what's documented. Returns structured overviews for mapping documentation claims to implementations and identifying gaps.

**Project Manager**
Operational coordinator for plan execution — maintains execution state by reading `signals.jsonl` per task for stage derivation, owns the background liveness monitor (`scripts/usage-monitor.sh watch` via the Monitor tool) and verifies its NUDGE candidates (a task silent with no named `WAITING_ON` wait and no repo activity — PM verifies, pings the executor, and escalates to Lead only on a confirmed non-response), tracks per-task budget data by consuming the limit sentinel's passively-written usage events, and at startup emits the per-project Ultra Claude Dashboard deep-link only when the project is connected to the dashboard. Spawned once per plan execution; event-driven, waking on messages from Lead/executors and on its monitor's NUDGE emits — it performs no usage-limit monitoring or forwarding of its own. Produces comprehensive operational reports analyzing token efficiency, budget utilization, communication channel health, repeated work, and system improvement recommendations.

**Usage monitor (`scripts/usage-monitor.sh`)**
The per-plan liveness monitor plus the on-demand usage-status reader — a `watch` subcommand (PM runs it persistently via the Monitor tool; emits ONLY `NUDGE` liveness candidates per the protocol's yield rule: task silent >10 min with no named `WAITING_ON` wait and no repo file activity, while quietly tracing `silence_observed` into `events.json`) and a `status` subcommand (one-shot, time-authoritative JSON of both windows with a clear/soft band — soft starts at 90% and only gates STARTING new work; there is no critical tier because nothing stops in-flight work anymore). It resolves the account in one place so no caller hand-reads `usage-status.json`; usage-limit handling itself (advisories, post-limit wakes, rollover tracing) lives entirely in the limit sentinel. Use `status` for spawn gating and completion bookkeeping; trust NUDGEs as verified-before-escalation candidates, never blanket stall alerts.

**Limit sentinel (`scripts/limit-sentinel.sh`)**
ONE machine-global background process (not an agent) that handles usage limits reactively: it detects limit-killed turns via the StopFailure hook, tracks every account's reset time from `usage-status.json`, and at reset (+90s) wakes everything that parked — durable `RESUME` signals into each task's `signals.jsonl` plus guarded tmux pane injection (fleet panes, then the Lead pane, then standalone sessions), with 90% soft-band advisories injected into plan Lead panes, window pre-opens for mapped accounts, and weekly-limit notifications via the machine-context notify command. Installed and started by `/uc:setup` (symlink + StopFailure hook + `ensure`), self-healing via the SessionStart and StopFailure hooks, registered per plan at phase 1 (`~/.claude/ultra/sentinel/plans/`). It replaces the old proactive CRITICAL/PAUSE machinery entirely — execution rides each window to 100%, parks on the limit, and resumes automatically, with no usage questions asked at plan start.

**System Tester**
Reproduces reported bugs scientifically following exact steps, observing outputs and trying variations to understand boundary conditions — never fixes code. Spawned by Debug Mode to validate bug reports and test proposed fixes. Produces structured reproduction reports with evidence and observations informing fix strategies.

**Task Executor**
Coordinates per-task execution using the unified communication protocol: receives the Reviewer's `REVIEWER TAKE` and the Tester's `TESTER TAKE` via `WaitForTeamMember`, writes `plan.md` with `CommunicateTeam(signal: "PLAN_READY")`, implements code plus its own unit/integration tests (covering the TESTER TAKE's unit-layer contract; tester-owned acceptance test files are never edited, only committed verbatim at task end), signals code complete via fire-and-forget `CommunicateTeamMember(signal: "CODE_COMPLETE")`, and drives parallel review/test cycles via `CommunicateTeamMember`/`WaitForTeamMember` (one persistent inbox monitor delivers every relevant signal as an event — SendMessage stays the primary channel; the signal file is the durable state log and delivery backstop). Spawned as the hub of each task team; brokers external docs via `QUERY:` to Lead and judgment calls via `ADVICE REQUEST` (with `ADVICE_RESPONSE` signal backup). Produces `plan.md` (execution delta) and `impl.md` (implementation delta with INTEGRATION and GOTCHA notes).

**Task Tester**
Spawns with the team at task start, sends an upfront `TESTER TAKE` (acceptance-case list + the unit-layer cases the Executor's tests must cover, persisted as `test-strategy.md`), then authors black-box acceptance tests from `task.md`'s success criteria and product docs (never `impl.md` — impl.md is for the file list only) and verifies code by running tests and launching frontend in a browser to visually confirm UI works. Use is automatic within `/uc:plan-execution` — it owns the acceptance test layer (Executor owns unit/integration tests) and demands missing unit coverage via `TEST_FAIL` naming the exact cases instead of patching it. Produces `test-strategy.md` and persistent feedback files alongside pass/fail verdicts with evidence, sent via `CommunicateTeamMember`/`WaitForTeamMember` (one persistent inbox monitor, message-responsive).

**Researcher**
Stateless one-shot researcher spawned by the `/uc:research` skill on cache miss, dispatched in the background by default. Fetches external documentation via Ref.tools or web search in one of three modes (library / patterns / market), merges findings into the target file under `documentation/technology/research/` or `documentation/product/research/` via targeted Edits (large files never force a full rewrite), and atomically upserts the research index (Bash mv). Never reads project source code — caller owns cross-referencing.

## Extending the System

**New skill:** Create `skills/{name}/SKILL.md` with YAML frontmatter. Set `user-invocable: true` for slash commands (namespaced as `/uc:{name}`). Use `${CLAUDE_PLUGIN_ROOT}` for portable paths to plugin files.

**New agent:** Create `agents/{name}.md` with YAML frontmatter declaring model, tools, and system prompt. Follow principle of least privilege for tool access.

**New template:** Documentation references go in `skills/docs-manager/references/`. Plan/task templates go in `templates/`.
