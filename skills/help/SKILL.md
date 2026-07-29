---
description: Ultra Claude system guide. Advises which skills, agents, and workflows to use for any task. Guides extending the system with new capabilities. Use when asking "how do I accomplish X", "what should I use for Y", or "extend the system with Z".
user-invocable: true
argument-hint: "question about Ultra Claude (optional)"
---

# Help

## Startup

Read current version + recent changes from CHANGELOG.json:

```bash
VERSION=$(jq -r '.[0].version' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")
echo "Ultra Claude v${VERSION}"
echo ""
echo "Recent changes:"
jq -r '.[0:5] | .[] | "  \(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format output as readable table. Then answer user question. No argument? Follow changelog with brief system overview + common workflows, each pointing to right skill.

## System Architecture

Ultra Claude = spec-driven development platform, three layers:

- **Skills** — user-invocable workflows (trigger via `/uc:{name}`). Orchestrate multi-step tasks: plan features, debug, manage docs
- **Agents** — specialized subagents skills spawn for focused work (code survey, testing, reviewing, execution)
- **References & Templates** — reusable doc templates + guides in `skills/docs-manager/references/` and `templates/`. Standardize output across all skills

Skills read codebase + docs, spawn agents for parallel work, produce plans or docs. Plans live in `documentation/plans/{NNN}-{name}/` — each = README plus per-task `tasks/task-N/task.md` files. Agent teams execute them via `/uc:plan-execution`.

## Skills

### Setup & Onboarding

**Dashboard** (`/uc:dashboard`)
Connect projects to Ultra Claude Dashboard at `dashboard.ultra-claude.dev` for real-time visibility, manage many dashboard accounts with per-project routing, transfer project ownership between accounts. Use for: dashboard sync setup, agent connectivity trouble, sync status check, control which account project sync to, move project to other account. Guide agent install, document non-interactive account CLI (`assign`/`default`/`auto-assign`/`move`) plus interactive REPL, verify connectivity with self-contained debug checks.

**Setup** (`/uc:setup`)
One-time machine config — install prerequisites (Node.js, optional tmux), configure shell + settings.json for 1M context, agent teams, tmux teammate panes, offer fullscreen renderer + VS Code settings, optional scaffold of user-level `machine-context` skill via interactive interview, install + start machine-global limit sentinel. Use after plugin install, on new machine, to change tmux mode, fix screen tearing/flicker, add machine-context later, configure VS Code, update `ultraclaude-agent` package, refresh outdated model pins. Idempotent — write version marker, never clobber user-written machine-context files without explicit confirmation.

**Migrate** (`/uc:migrate`)
Bring projects into Ultra Claude, keep them current — fresh init, legacy project detection, version-aware incremental upgrades via structured migrations in CHANGELOG.json. Use when onboard new project, after `/uc:update`, or upgrade existing project to latest Ultra structure. Produce scaffolded docs, `.claude/ultra/` config, coding standards, version marker for future upgrades, small Ultra Claude promo footer in project README.

### Planning & Research

**Discovery Mode** (`/uc:discovery-mode`)
Lead product research as Head of Product persona — spawn internal Explore subagent parallel with `/uc:research --mode=market` call for external competitor/trend analysis, then synthesize findings into product docs. Use for product vision, requirements, user personas, competitive analysis, technology landscape assessment. Produce documentation artifacts (product description, research report, requirements, personas) — never code.

**Roadmap** (`/uc:roadmap`)
Decompose product into sequenced plan stubs: analyze product/architecture docs, build dependency graph, topologically sort build phases. Use after discovery/migrate when product too big for single plan. Produce `ROADMAP.md` with execution order + numbered stub plans ready for `/uc:feature-mode` to detail.

**Feature Mode** (`/uc:feature-mode`)
Plan new features via 4-stage process: challenge scope, research architecture/code/dependencies (track research-to-task mapping for durable per-task pointers), discuss approach with user, write plan. Use when start new feature, add functionality, plan significant changes. Produce plan README with flat task heading index + per-task files (description, files, patterns, Research pointers, success criteria, dependencies) ready for execution.

**Debug Mode** (`/uc:debug-mode`)
Investigate bugs via structured hypothesis generation, parallel evidence gathering via Explore + System Tester agents, root cause analysis. Use when debug issues, fix regressions, investigate mysterious failures. Produce fix plan — task files extend base template with `**Regression criteria:**` and `**Failing test first:**` sections.

**Critical Brainstorm** (`/uc:critical-brainstorm`)
Interactive devil's advocate mode — stress-test solutions via research-backed challenge, tradeoff analysis, risk identification, future problem prediction. Use when want opinions challenged, need debate approaches, or think critically about any decision. Stay in dialogue mode through many exchanges until you signal satisfaction — no implementation.

**Research** (`/uc:research`)
Cache-first external research: library/API docs, architectural patterns, market/competitor analysis via single auto-classified interface — fresh cache hits read straight from disk; cache misses dispatch stateless `researcher` subagent in background — conversation continue, findings relayed on completion. Use when add libraries, investigate patterns or best practices, run competitor analysis, ask how Claude Code / Claude Agent SDK / Anthropic API features work, or any "how does X work / what changed in X / best practice for X" question — Claude/Anthropic topics auto-classify as `library` mode. Produce committed research files in two indexed scopes — product/domain research under `documentation/technology/research/` + `documentation/product/research/`, Claude harness research under `.claude/ultra/research/` — frontmatter-driven per-entry staleness.

### Execution

**Plan Execution** (`/uc:plan-execution`)
Orchestrate multi-task plan execution via per-task Executor + Reviewer + Tester teams that self-coordinate from file-based context via shared task-team-startup protocol; Lead brokers mid-execution `ADVICE` and `QUERY` (external docs via /uc:research). Use after plan approval: run `/uc:plan-execution {number}`. Produce per-task `plan.md`, `impl.md`, `test-strategy.md` artifacts, review + test verdicts, Project Manager operational report — user decisions ride non-blocking escalation queue (`shared/escalations.md`) so unattended run never stall on question.

**Checkpoint** (`/uc:checkpoint`)
Save execution state (task pipeline stages, active teams, decisions, blockers) to timestamped file for session recovery. Use periodically during long executions, before session shutdown, before risky changes. Produce checkpoint Lead can read on resume — reconstruct state, continue execution.

### Documentation & Verification

**Docs Manager** (`/uc:docs-manager`)
Guard canonical documentation structure — route documents to correct directories, enforce single canonical home per fact (drift-prone content live in one place, linked with standardized anchored cross-links, not duplicated), maintain navigable index. Always enabled — use proactively whenever any skill or agent create documentation. Redirect violations, keep decision residue in RFCs + settled state in design docs, update `documentation/README.md` as source of truth.

**Doc-Code Verification** (`/uc:doc-code-verification-mode`)
Compare documentation claims against code reality with parallel Checker agents; also detect drift-prone content duplicated across documents + broken cross-reference anchors. Use to find doc-code gaps, deduplicate docs, verify cross-link integrity, sync docs with implementation. Produce structured plan distinguishing "docs are wrong" vs "code is wrong" with evidence, consolidation tasks merging duplicated content into one canonical home, structural-fix tasks carrying `**Docs-manager reference:**` field pointing at relevant docs-manager guide.

**Context Management** (`/uc:context-management`)
Manage `context/` directory as structured knowledge base for external systems (APIs, SDKs, protocols) with git submodule support. Use when add external API docs, SDK references, or system context that informs specs. Produce `context/README.md` index + organized `{system}/docs/` and `{system}/code/` layout.

### Project Management

**Backlog** (`/uc:backlog`)
Lightweight backlog split across four category files in `documentation/backlog/` — bugs (B-NNN), questions (Q-NNN), ideas (I-NNN), debt (D-NNN) — with priorities, labels, blocking relationships, documentation references. Use to note something for later, log bug, record question or blocker, flag tech debt, label items with `#tag` syntax, filter by label, ask "what should we work on". Provide list/add/update/done/label/link/block operations with priority sorting + `#tag` filtering — skills never auto-add items, they triage backlog-worthy findings with user first.

**Plan Status Sync** (`/uc:plan-status-sync`)
Scan all plans, infer actual status from execution artifacts (operational reports, checkpoints, task completion), reconcile README statuses with `plan.json` at plan root — preserve `planning` + `cancelled` statuses and plan-level `stage` field for plans still being shaped or abandoned. Use to fix stale statuses after crashed executions, create missing plan.json for legacy plans, audit plan state. Produce corrected status files — consolidated plan+task state in single file.

### Infrastructure

**Harness Builder** (`/uc:harness-builder`)
Knowledge base for building harness components — skills, agents, hooks, protocols — plus a mandatory staged build workflow. Use when create or refactor skill or agent, write descriptions or prompts, audit session context cost (`scripts/context_audit.py`), optimise resident text. Build tasks enter Claude Code native plan mode and walk structural → lexical → compression (`uc:caveman-compress`) → plan-presentation stages with per-stage discussion gates; non-negotiables include Opus floor, always-invoke `/skill-creator:skill-creator`, description budgets, before/after refactor testing.

**Rename Window** (`/uc:rename-window`)
Rename current tmux window via shared `scripts/tmux-window-name.sh` primitive (sanitize, truncate for status bar, disable tmux automatic-rename so name stick). Use to label window by what it work on, or apply Ultra Claude `UC::P-NNN::<plan>` / `UC::<Mode>::<subject>` convention by hand — planning modes + plan-execution apply automatically, plan ID take priority. Produce renamed window that survive shell-prompt redraws; no-op outside tmux.

**Railway** (`/uc:railway`)
Manage Railway.com deployments via CLI with environment variable-based multi-account token switching — deployments, logs, variables, config-as-code. Use for Railway deployment workflows, account switching, debugging failed deployments (surface newest deployment via `--latest` and `deployment list`), service configuration. Provide command wrappers that resolve correct token per project directory.

**Tailscale Setup** (`/uc:tailscale-setup`)
Configure Tailscale to expose local services securely within tailnet via `tailscale serve` or publicly via `tailscale funnel`. Use when expose dashboards, dev servers, or prep services for remote access. Validate full prerequisite chain, enable HTTPS-wrapped local services.

**Update** (`/uc:update`)
Update Ultra Claude to latest version via Claude Code plugin marketplace using `claude plugin update`. Use after hear about new features or want latest version. Show changelog since last update, run post-update housekeeping (file migration, tmux daemon restart when tmux mode active, setup verification), recommend `/uc:migrate` in each project if structural changes happened.

## Reference Libraries

Reference libraries = shared instruction sets — not skills. Planning modes inherit them, extend per-stage via files in own `references/` directories.

**Planning Framework** (`references/planning-framework/`)
Define 4-stage planning flow (Understand → Research → Discuss → Write), conversational rules, existing-plan handling, approval gates, post-approval hard stop. Inherited by feature-mode, debug-mode, doc-code-verification-mode through per-stage extensions in each mode's `references/stage-N.md`. Discovery-mode does not use it — produce docs, not plans.

## Agents

Skills spawn agents as subagents. Agents don't run independently — skills orchestrate. Execution-team agents (Code Reviewer, Project Manager, Task Executor, Task Tester) coordinate via execution communication protocol (`skills/plan-execution/references/execution-communication-protocol.md`): SendMessage = primary channel, `signals.jsonl` = durable log + delivery backstop, each agent run one persistent inbox monitor, Executor own unit/integration tests, Tester own acceptance tests.

**Caveman Compress**
Compression engine wrapper — run caveman-compress CLI on scratch copy of body artifact (`prompt-body` | `doc-section` | `protocol-format`; never descriptions — engine preserve frontmatter verbatim), return compressed version plus cut list tagged clean / fixable-with-repaired-wording / harmful; proposition-only, never edit outside scratch. Spawned at stage 3 of `/uc:harness-builder` build workflow, one spawn per artifact, concurrent when several. Parent adopt cuts item by item — no wholesale accept/reject, yield percentage diagnostic only.

**Checker**
Compare specific code against documentation claims for single topic, returning discrepancies with severity levels + exact file:line references. Spawned by doc-code verification to verify isolated aspects of system. Produce structured verification reports — factual differences between docs and implementation.

**Code Reviewer**
Send standards-aware `REVIEWER TAKE` (persisted as `take.md`) immediately after spawn, before Executor write `plan.md`, then review completed code against standards, architecture, patterns as read-only quality gate. Scope = Executor work including its unit/integration tests held to test-strategy contract — tester-owned acceptance tests sit outside formal gate. Produce persistent take + feedback files alongside PASS/FAIL verdicts.

**Code Surveyor**
Fast structural scans of code packages — catalog files, components, data structures, dependencies, architectural patterns. Spawned by migrate + verification orchestrators to quickly understand what implemented. Return concise structured overviews with file-line references for mapping code to requirements.

**Doc Surveyor**
Explore documentation sections — identify content type, key topics, specifications, implementation references. Spawned by migrate + verification orchestrators to understand what documented. Return structured overviews for mapping documentation claims to implementations + finding gaps.

**Project Manager**
Operational coordinator for plan execution — derive per-task stage state from signals, own background liveness monitor, verify its `NUDGE` candidates (ping executor, escalate to Lead only on confirmed non-response), track per-task budget data from limit sentinel's passively-written usage events. Spawned once per plan execution; event-driven — wake on messages + monitor emits, do no usage-limit monitoring itself. Produce operational reports: token efficiency, budget utilization, communication health, repeated work, system improvement recommendations.

**System Tester**
Reproduce reported bugs scientifically — follow exact steps, observe outputs, try variations to understand boundary conditions — never fix code. Spawned by Debug Mode to validate bug reports + test proposed fixes. Produce structured reproduction reports with evidence + observations that inform fix strategies.

**Task Executor**
Hub of each task team — receive Reviewer + Tester TAKEs, write `plan.md` (execution delta), implement code plus own unit/integration tests covering `TESTER TAKE` unit-layer contract, drive parallel review/test cycles to verdicts. Never edit tester-owned acceptance test files — commit them verbatim at task end; broker external docs via `QUERY:` to Lead, judgment calls via `ADVICE REQUEST`. Produce `plan.md` + `impl.md` (implementation delta with INTEGRATION and GOTCHA notes).

**Task Tester**
Send upfront `TESTER TAKE` at task start (acceptance-case list plus unit-layer cases Executor tests must cover, persisted as `test-strategy.md`), then author black-box acceptance tests from `task.md` success criteria + product docs — never from `impl.md`. Spawned automatically with each task team in `/uc:plan-execution`; verify code by running tests, launch frontend work in browser to visually confirm UI, demand missing unit coverage via `TEST_FAIL` naming exact cases — never patch it itself. Produce `test-strategy.md` + persistent feedback files alongside pass/fail verdicts with evidence.

**Researcher**
Stateless one-shot researcher spawned by `/uc:research` skill on cache miss, dispatched in background by default. Fetch external documentation via Ref.tools or web search in one of three modes (library / patterns / market), merge findings into target research file via targeted Edits (large files never force full rewrite), atomically upsert research index (Bash mv). Never read project source code — caller own cross-referencing.

### Scripts (not agents)

**Usage monitor (`scripts/usage-monitor.sh`)**
Per-plan liveness monitor plus on-demand usage reader — `watch` subcommand (run persistently by Project Manager) emit verified-before-escalation `NUDGE` liveness candidates; `status` subcommand return one-shot, time-authoritative JSON of both usage windows with clear/soft band (soft start at 90%, only gate starting new work). Use `status` for spawn gating + completion bookkeeping; trust NUDGEs as verified candidates, never blanket stall alerts. Usage-limit handling itself — advisories, post-limit wakes, rollover tracing — live entirely in limit sentinel.

**Limit sentinel (`scripts/limit-sentinel.sh`)**
One machine-global background process that handles usage limits reactively — detect limit-killed turns via StopFailure hook, track every account's reset time, at reset wake everything that parked: durable `RESUME` signals into each task's `signals.jsonl` plus guarded tmux pane injection, with soft-band advisories + weekly-limit notifications. Installed + started by `/uc:setup`, self-healing via SessionStart + StopFailure hooks, registered per plan. Execution ride each usage window to 100%, park on limit, resume automatically — no usage questions asked at plan start.

## Extending the System

Skills live at `skills/{name}/SKILL.md`, agents at `agents/{name}.md`, plan/task templates in `templates/`, documentation references in `skills/docs-manager/references/`. How to write them — descriptions, prompts, tool grants, mandatory review gate — use `/uc:harness-builder`.
