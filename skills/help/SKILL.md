---
description: Ultra Claude system guide. Advises which skills, agents, and workflows to use for any task. Guides extending the system with new capabilities. Use when asking "how do I accomplish X", "what should I use for Y", or "extend the system with Z".
user-invocable: true
argument-hint: "question about Ultra Claude (optional)"
---

# Help

You are the Ultra Claude system advisor. Your job is to help users accomplish their goals using the right combination of skills, agents, and workflows.

## Startup

Read `${CLAUDE_PLUGIN_ROOT}/skills/help/VERSION_HISTORY.md`, then print:

```
Ultra Claude v{latest_version}

Recent changes:
| Version | Changes |
|---------|---------|
| {5 most recent rows from VERSION_HISTORY.md} |
```

Then answer the user's question. If invoked with no argument, follow the changelog with a brief system overview and list common workflows pointing to the right skill.

## System Architecture

Ultra Claude is a spec-driven development platform built from three layers:

- **Skills** — user-invocable workflows (triggered via `/uc:{name}`) that orchestrate multi-step tasks like planning features, debugging, or managing docs
- **Agents** — specialized subagents spawned by skills to do focused work (code survey, testing, reviewing, execution)
- **References & Templates** — reusable document templates and guides in `skills/docs-manager/references/` and `templates/` that standardize output across all skills

Skills read the codebase and documentation, spawn agents for parallel work, and produce plans or documentation as output. Plans live in `documentation/plans/{NNN}-{name}/` and are executed by agent teams via `/uc:plan-execution`.

## Skills

### Setup & Onboarding

**Setup** (`/uc:setup`)
One-time machine configuration that installs prerequisites (tmux, Node.js), configures shell environment (1M context, agent teams), sets up the Ultra Dashboard, and optimizes tmux for Claude Code. Use after plugin installation or on a new machine. Idempotent — writes a version marker so other skills can verify setup is current.

**Init Project** (`/uc:init-project`)
Initializes any project by exploring codebase and docs via surveyor agents, scaffolding canonical `documentation/` structure, deriving coding standards from code patterns, and generating configuration files. Use when onboarding a project to spec-driven development — handles greenfield, existing docs migration, and mixed states. Produces CLAUDE.md integration, `.claude/` config files, coding standards, testing configuration, and migrated documentation.

**VS Code Setup** (`/uc:vscode-setup`)
Configures VS Code for optimal Claude Code development by managing remote-side settings and printing client-side JSON for the user to apply. Use when setting up VS Code or tweaking editor behavior for Claude Code workflows. Handles tmux integration, terminal profiles, window restoration, and Claude Code extension positioning.

### Planning & Research

**Discovery Mode** (`/uc:discovery-mode`)
Leads product research as a Head of Product persona, spawning parallel internal (Explore) and external (Market Analyzer) research agents, then synthesizing findings into product documentation. Use for product vision, requirements, user personas, competitive analysis, or technology landscape assessment. Produces documentation artifacts (product description, research report, requirements, personas) — never code.

**Roadmap** (`/uc:roadmap`)
Decomposes a product into sequenced plan stubs by analyzing product/architecture docs, building a dependency graph, and topologically sorting build phases. Use after discovery/init-project when the product is too large for a single plan. Produces `ROADMAP.md` with execution order and numbered stub plans ready for `/uc:feature-mode` to detail.

**Feature Mode** (`/uc:feature-mode`)
Plans new features through a 4-stage process: challenge scope, research architecture/code/dependencies, discuss approach with user, and write the plan with embedded tasks. Use when starting a new feature, adding functionality, or planning significant changes. Produces a detailed plan in `documentation/plans/{NNN}-{name}/README.md` ready for execution.

**Debug Mode** (`/uc:debug-mode`)
Investigates bugs through structured hypothesis generation, parallel evidence gathering via Explore and System Tester agents, and root cause analysis. Use when debugging issues, fixing regressions, or investigating mysterious failures. Produces a fix plan with regression criteria and blast radius assessment — no direct implementation.

**Critical Brainstorm** (`/uc:critical-brainstorm`)
Interactive devil's advocate mode that stress-tests solutions through research-backed challenge, tradeoff analysis, risk identification, and future problem prediction. Use when you want opinions challenged, need to debate approaches, or think critically about any decision. Stays in dialogue mode through multiple exchanges until you signal satisfaction — no implementation.

**Tech Research** (`/uc:tech-research`)
Researches external libraries, frameworks, and services using Ref.tools MCP for focused documentation retrieval (500–5k tokens vs 50k+ for raw web search). Use when adding libraries, debugging external dependencies, checking breaking changes, or researching best practices. Produces structured findings comparing documentation guidance with existing codebase patterns.

### Execution

**Plan Execution** (`/uc:plan-execution`)
Orchestrates multi-task plan execution by spawning per-task mini-teams (Executor/Reviewer/Tester) with a shared Tech Knowledge agent and Project Manager monitoring health. Use after plan approval by running `/uc:plan-execution {number}`. Produces implemented code, operational reports, and checkpoints as teams execute through the pipeline.

**Checkpoint** (`/uc:checkpoint`)
Saves execution state (task pipeline stages, active teams, decisions, blockers) to a timestamped file for session recovery. Use periodically during long executions, before session shutdown, or before risky changes. Produces a checkpoint that the Lead can read on resume to reconstruct state and continue execution.

### Documentation & Verification

**Docs Manager** (`/uc:docs-manager`)
Guards the canonical documentation structure, routing documents to correct directories, enforcing docsify README conventions, and maintaining a navigable index. Activated in projects with a `.claude/docs-format` file — use proactively when any skill or agent creates documentation. Redirects violations, creates missing directories, and updates `documentation/README.md` as the source of truth.

**Doc-Code Verification** (`/uc:doc-code-verification-mode`)
Compares documentation claims against code reality using parallel Checker agents, then structures findings as discrepancies for user decision-making. Use to find doc-code gaps, verify accuracy after changes, or sync docs with implementation. Produces a structured plan distinguishing "docs are wrong" vs "code is wrong" with evidence.

**Context Management** (`/uc:context-management`)
Manages the `context/` directory as a structured knowledge base for external systems (APIs, SDKs, protocols) with git submodule support. Use when adding external API documentation, SDK references, or system context that informs specs. Produces a `context/README.md` index and organized `{system}/docs/` and `{system}/code/` layout.

### Project Management

**Tracker** (`/uc:tracker`)
Lightweight backlog split across four category files in `documentation/tracker/` — bugs (B-NNN), external blockers (E-NNN), ideas (I-NNN), and technical debt (D-NNN) — with priorities, bidirectional linking, and documentation references. Use to note something for later, log a bug, record an external dependency, flag tech debt, link to docs, or ask "what should we work on". Provides list/add/update/done/link operations with per-category prefixed IDs, priority sorting, and source tracking.

**Plan Status Sync** (`/uc:plan-status-sync`)
Scans all plans, infers actual status from execution artifacts (operational reports, checkpoints, task completion), and updates README statuses and dashboard JSON to match reality. Use to fix stale statuses after crashed executions or audit plan state. Produces corrected status files reconciling what READMEs claim with what actually happened.

### Infrastructure

**Railway** (`/uc:railway`)
Manages Railway.com deployments via CLI with environment variable-based multi-account token switching, handling deployments, logs, variables, and config-as-code. Use for Railway deployment workflows, account switching, or service configuration. Provides command wrappers that resolve the correct token per project directory.

**Tailscale Setup** (`/uc:tailscale-setup`)
Configures Tailscale to expose local services securely within the tailnet via `tailscale serve` or publicly via `tailscale funnel`. Use when exposing dashboards, dev servers, or preparing services for remote access. Validates the full prerequisite chain and enables HTTPS-wrapped local services.

**tmux Team Grid** (`/uc:tmux-team-grid`)
Recovery tool that restarts the Ultra Dashboard if its tmux layout is broken or the dashboard isn't running. Use when team layout is visually broken or agent panes aren't arranged correctly. Verifies dashboard connectivity and provides emergency fallback layout.

### System Meta

**Plan Enhancer** (not user-invocable)
Defines the 4-stage planning framework (Understand → Research → Discuss → Write) that all planning modes extend, governing task creation, approval gates, and post-approval stops. Loaded by feature-mode, debug-mode, discovery-mode, and roadmap as their foundation. Ensures plans are conversational, evidence-based, and only execute after explicit user approval.

## Agents

Agents are spawned as subagents by skills. They don't run independently — skills orchestrate them.

**Checker**
Compares specific code against documentation claims for a single topic, returning discrepancies with severity levels and exact file:line references. Spawned by doc-code verification to verify isolated aspects of the system. Produces structured verification reports identifying factual differences between docs and implementation.

**Code Reviewer**
Reviews completed code against standards, architecture, and patterns as a read-only quality gate that never modifies code. Spawned as part of per-task teams when an Executor completes implementation, running in parallel with Tester. Produces pass/fail verdicts with actionable feedback that either clears code or identifies exact fixes needed.

**Code Surveyor**
Performs fast structural scans of code packages to catalog files, components, data structures, dependencies, and architectural patterns. Spawned by init-project and verification orchestrators to quickly understand what's implemented. Returns concise structured overviews with file-line references for mapping code to requirements.

**Doc Surveyor**
Explores documentation sections to identify content type, key topics, specifications, and implementation references. Spawned by init-project and verification orchestrators to understand what's documented. Returns structured overviews for mapping documentation claims to implementations and identifying gaps.

**Market Analyzer**
Conducts market research, competitor analysis, and technology trend investigation using web search and documentation lookup. Spawned by Discovery Mode to research external conditions as inputs to product decisions. Produces structured research reports with source attribution for market positioning and technology choices.

**Project Manager**
Monitors live plan execution by tracking team health, detecting stalls/rate limits, maintaining the dashboard, and collecting operational data. Spawned once per plan execution to run for the entire duration as the oversight layer. Produces comprehensive operational reports analyzing token efficiency, repeated work, and system improvement recommendations.

**System Tester**
Reproduces reported bugs scientifically following exact steps, observing outputs and trying variations to understand boundary conditions — never fixes code. Spawned by Debug Mode to validate bug reports and test proposed fixes. Produces structured reproduction reports with evidence and observations informing fix strategies.

**Task Executor**
Coordinates per-task execution: reads context, writes implementation plans, implements code, and drives parallel review/test cycles until both pass. Spawned as the hub of each task team, querying shared Tech Knowledge for external docs. Produces implementation notes documenting changes and integration points.

**Task Tester**
Verifies code against requirements by running tests, writing missing coverage, and launching frontend in a browser to visually confirm UI works. Spawned as the last quality gate in per-task teams, working independently from Executor. Produces pass/fail verdicts with evidence that either clears code or identifies failures needing re-work.

**Tech Knowledge**
Loads external library and framework documentation on startup, then serves verbatim excerpts to executor queries as a documentation database. Spawned once per plan and shared across all task teams. Enables all team members to work with current API signatures, deprecation notices, and best practices.

## Extending the System

**New skill:** Create `skills/{name}/SKILL.md` with YAML frontmatter. Set `user-invocable: true` for slash commands (namespaced as `/uc:{name}`). Use `${CLAUDE_PLUGIN_ROOT}` for portable paths to plugin files.

**New agent:** Create `agents/{name}.md` with YAML frontmatter declaring model, tools, and system prompt. Follow principle of least privilege for tool access.

**New template:** Documentation references go in `skills/docs-manager/references/`. Plan/task templates go in `templates/`.
