# Components

Reference for all Ultra Claude components: skills, agents, commands, hooks, templates, and configuration files.

## Skills

| Skill | Trigger | Invocation | Purpose |
|-------|---------|------------|---------|
| **feature-plan-mode** | "new feature", "plan feature", "start feature" | User | Feature Plan Mode: new features with product + architecture context |
| **debug-mode** | "debug", "fix", "investigate" | User | Debug Mode: issue investigation and fix planning |
| **doc-code-verification-mode** | "verify docs", "check doc-code gaps", "sync docs" | User | Doc & Code Verification Mode: find and plan fixes for discrepancies |
| **plan-enhancer** | Auto-loaded by all modes | Auto (internal) | Standardizes plan output: plan directory, README.md with embedded task list, task granularity |
| **execute-plan** | `/uc:execute` | User | Execution engine: runs any plan through agent team |
| **discovery-mode** | "discovery mode", "research only" | User | Discovery Mode: research only, coding disabled |
| **docs-manager** | Activated by `.claude/docs-format` file | Auto | Guards `documentation/` structure — enforces canonical layout, routes docs to correct directories, prevents structural drift |
| **checkpoint** | `/uc:checkpoint` | User | Save context to plan files for recovery |
| **context-manager** | "add context", "add external system", "update context" | User | Manages `context/` directory: structures external system knowledge, aggregates docs + code, manages git submodules |
| **migrate-docs** | `/uc:migrate` | User | One-time migration: surveys existing project docs + code, maps them to canonical structure, produces a migration plan |
| **help** | "how to accomplish", "extend the system" | User | Meta-skill: understands full system, advises on extensions |
| **tech-research** | "how does X work", "research library", "check docs" | User/Auto | External library/framework documentation via Ref.tools |

## Agents

| Agent | Model | Tools | Purpose | Spawn Context |
|-------|-------|-------|---------|---------------|
| **researcher** | sonnet | Read, Grep, Glob, WebFetch, mcp__ref | Generic context-gathering agent. Parameterized by the mode that spawns it — focuses on whatever the mode needs (product context, debug investigation, code patterns, etc.) | Plan README.md, shared-context.md, architecture docs path, research task list instructions |
| **task-executor** | sonnet | Read, Write, Edit, Glob, Grep, Bash | Single-task implementation from research context | Plan README.md, shared-context.md, per-task research file, coding standards path, impl task list instructions |
| **task-tester** | sonnet | Read, Glob, Grep, Bash | Testing gate in execution pipeline. Self-claims from test task list for per-task testing. Also runs full test suite as final gate before team shutdown. Read-only for source code. | Plan README.md, shared-context.md, success criteria from plan, test task list instructions, system test instructions (.claude/system-test.md), SendMessage target (Lead) for failures |
| **code-review** | sonnet | Read, Glob, Grep | Code review gate in execution pipeline. Self-claims from review task list. Checks code quality, pattern compliance, architecture conformance, duplication. Read-only. PASS promotes to test list, FAIL re-queues to impl list. | Plan README.md, shared-context.md, coding standards path, architecture docs path, review task list instructions |
| **checker** | sonnet | Read, Grep, Glob | Compares specific code against documentation for single topic | — |
| **code-surveyor** | haiku | Read, Grep, Glob | Quick survey of code package structure | — |
| **doc-surveyor** | haiku | Read, Grep, Glob | Quick survey of documentation section structure | — |
| **market-analyzer** | sonnet | WebSearch, WebFetch, mcp__ref | Market research, competitor analysis, technology trends | — |

## Commands

| Command | Purpose |
|---------|---------|
| `/uc:feature` | Enter Feature Plan Mode |
| `/uc:debug` | Enter Debug Mode |
| `/uc:verify` | Enter Doc & Code Verification Mode |
| `/uc:execute` | Execute a plan through agent team |
| `/uc:discover` | Enter Discovery Mode (research only, no coding) |
| `/uc:checkpoint` | Save current progress for session recovery |
| `/uc:migrate` | Survey existing project and migrate docs to canonical structure |
| `/uc:help` | Ask the meta-skill how to accomplish something |
| `/uc:status` | Show plan status, task progress |

## Hooks

| Hook Event | Purpose | Type | Agent Team Behavior |
|------------|---------|------|---------------------|
| **PreToolUse (Write/Edit)** | Check if file changes align with architecture docs | prompt | Unchanged from planning layer |
| **Stop** | Verify architectural changes are reflected in architecture docs | prompt | Triggers checkpoint save if execution is in progress |
| **TaskCompleted** | Validate task meets documented success criteria | agent | Validates against plan README.md success criteria; blocks completion if unmet |
| **TeammateIdle** | Check if teammate completed all assigned work | prompt | Checks if role-list still has claimable tasks; notifies Lead if tasks remain. For Code Reviewer: also checks all reviewed tasks have written feedback. |
| **SessionStart** | Load plan context if resuming | command | — |

## Templates

Shipped with the plugin. Copied into target projects by `init-docs.sh`.

| Template | Purpose | Created When |
|----------|---------|-------------|
| `templates/architecture.md` | Architecture document template | Planning (any mode) |
| `templates/rfc.md` | RFC template (problem, proposed solution, alternatives, open questions, outcome) | Planning (optional, for tough decisions) |
| `templates/requirement.md` | Formal requirement template (FR-xxx, NFR-xxx) | Planning |
| `templates/plan.md` | Plan template (README.md with embedded task list) | Planning |
| `templates/context.md` | External system context template (docs + code layout) | As needed |
| `templates/dependency.md` | Blocking questions/dependencies | As needed |
| `templates/task.md` | Individual task template (used within plan README.md) | Planning |

## Configuration Files

| File | Purpose | Scope |
|------|---------|-------|
| `.claude/docs-format` | Activates docs-manager skill, sets output format (confluence/gitbook) | Project |
| `.claude/ultra-claude.local.md` | Plugin settings: active plan, team config, feature flags | Project (gitignored) |
| `.claude/environments-info` | How to access dev/staging/prod environments | Project |
| `.claude/app-context-for-research.md` | Domain context for researcher agents | Project |
| `.claude/system-test.md` | Instructions for system tester agent | Project |
| `documentation/plans/{name}/shared-context.md` | Persistent shared memory between teammates during execution | Plan |
| `documentation/plans/{name}/checkpoint-{timestamp}.md` | Session state snapshot for recovery | Plan |

All project-level configuration lives in the project's `.claude/` directory. This keeps the project root clean and groups all Claude Code configuration in one place.

## Color Coding Convention

Used in diagrams and the Miro board for visual consistency:

| Color | Meaning |
|-------|---------|
| **Purple** | Skill (procedural knowledge, extends main context) |
| **Green** | Agent (isolated execution, spawned via Task tool or as teammate) |
| **Yellow** | Document (artifact, template, reference file) |
| **Blue** | Instruction/configuration file (.claude/ configs) |
| **Orange** | Tag/mode indicator (e.g., "Use Plan Mode") |
