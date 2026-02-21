# Components

Reference for all Ultra Claude components: skills, agents, commands, hooks, templates, and configuration files.

## Skills

| Skill | Trigger | Invocation | Purpose |
|-------|---------|------------|---------|
| **feature-plan-mode** | "new feature", "plan feature", "start feature" | User | Feature Plan Mode: new features with product + architecture context. Includes optional RFC sub-mode for ambiguous/high-risk architecture decisions (AI persona review). |
| **debug-mode** | "debug", "fix", "investigate" | User | Debug Mode: issue investigation and fix planning. Spawns investigation team (Researcher + System Tester) during planning phase. Fix execution uses standard execute-plan team. |
| **doc-code-verification-mode** | "verify docs", "check doc-code gaps", "sync docs" | User | Doc & Code Verification Mode: find and plan fixes for discrepancies |
| **plan-enhancer** | Auto-loaded by all modes | Auto (internal) | Standardizes plan output: plan directory, README.md with embedded task list, task granularity. Uses Claude Code's plan mode file path override (writes plan to `documentation/plans/{name}/README.md` instead of default `.claude/plan.md`). Ensures task list is embedded in the plan document. |
| **execute-plan** | `/uc:execute` | User | Execution engine: reads plan directory, composes dynamic agent team based on plan size, creates role-separated task lists, spawns teammates, coordinates 5-phase execution (setup, parallel work, checkpoint, failure handling, completion) |
| **discovery-mode** | "discovery mode", "research only" | User | Discovery Mode: research only, coding disabled |
| **docs-manager** | Activated by `.claude/docs-format` file | Auto | Guards `documentation/` structure — enforces canonical layout, routes docs to correct directories, prevents structural drift |
| **checkpoint** | `/uc:checkpoint` | User | Saves task list states, active teammate assignments, execution decisions, and blockers to `plans/{name}/checkpoint-{timestamp}.md` for session recovery |
| **context-manager** | "add context", "add external system", "update context" | User | Manages `context/` directory: structures external system knowledge, aggregates docs + code, manages git submodules |
| **migrate-docs** | `/uc:migrate` | User | One-time migration: surveys existing project docs + code, maps them to canonical structure, produces a migration plan |
| **help** | "how to accomplish", "extend the system" | User | Meta-skill: understands full system, advises on extensions |
| **tech-research** | "how does X work", "research library", "check docs" | User/Auto | External library/framework documentation via Ref.tools |

## Agents

> **Note:** The Lead is the main Claude Code session itself — not a spawned agent. It runs the execute-plan skill and orchestrates all teammates. See [Execution](execution.md) for Lead behavior.

| Agent | Model | Tools | Purpose | Spawn Context |
|-------|-------|-------|---------|---------------|
| **researcher** | sonnet | Read, Grep, Glob, WebFetch, WebSearch, mcp__ref | Generic context-gathering agent. Parameterized by the mode that spawns it — focuses on whatever the mode needs (product context, debug investigation, code patterns, etc.). Does not decide where to write — the spawning mode must specify output paths in the spawn prompt. | Varies by mode. Spawner always provides: output file paths (where to save findings), architecture docs path, tech-research skill (auto-loaded for external library/framework documentation). Execute-plan adds: plan README.md, `shared/` directory path, research task list instructions. |
| **task-executor** | sonnet | Read, Write, Edit, Glob, Grep, Bash | Single-task implementation from research context | Plan README.md, `shared/` directory path, per-task research file, coding standards path, impl task list instructions |
| **task-tester** | sonnet | Read, Glob, Grep, Bash | Testing gate in execution pipeline. Self-claims from test task list for per-task testing. Also runs full test suite as final gate before team shutdown. Must not modify source code. Bash restricted to running test commands and build tools. | Plan README.md, `shared/` directory path, success criteria from plan, test task list instructions, system test instructions (.claude/system-test.md), SendMessage target (Lead) for failures |
| **system-tester** | sonnet | Read, Glob, Grep, Bash | Bug reproduction and fix validation in Debug Mode. Attempts to reproduce reported issues, validates fixes resolve the original problem. Must not modify source code. Bash restricted to bug reproduction and fix validation commands. | Debug Mode team, system test instructions (`.claude/system-test.md`) |
| **code-review** | sonnet | Read, Glob, Grep | Code review gate in execution pipeline. Self-claims from review task list. Checks code quality, pattern compliance, architecture conformance, duplication. Read-only. PASS promotes to test list, FAIL re-queues to impl list. | Plan README.md, `shared/` directory path, coding standards path, architecture docs path, review task list instructions |
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
| **PostToolUse (TaskUpdate)** | Validate task meets documented success criteria | prompt | When any agent calls TaskUpdate with `status: "completed"`, reads plan README.md success criteria and validates. Blocks completion if unmet. |
| **Stop** | Verify architectural changes are reflected in architecture docs | prompt | Triggers checkpoint save if execution is in progress |

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
| `documentation/plans/{name}/shared/` | Per-role shared memory directory. Each role writes only to their own file (`researcher.md`, `executor.md`, `reviewer.md`, `tester.md`, `lead.md`). All teammates read all files before each task claim. | Plan |
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
