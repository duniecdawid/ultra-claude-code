# Components

Reference for all Ultra Claude components: skills, agents, hooks, templates, and configuration files.

## Skills

> **Note:** Per [D15](decisions.md), there is no separate "commands" concept. Skills with `user-invocable: true` in their SKILL.md frontmatter become slash commands, invoked as `/uc:{skill-name}`.

| Skill | Trigger | User-Invocable | Purpose |
|-------|---------|----------------|---------|
| **feature-mode** | "new feature", "plan feature", "start feature" | Yes — `/uc:feature-mode` | Feature Mode: new features with product + architecture context. Includes optional RFC sub-mode for ambiguous/high-risk architecture decisions (AI persona review). |
| **debug-mode** | "debug", "fix", "investigate" | Yes — `/uc:debug-mode` | Debug Mode: issue investigation and fix planning. Spawns investigation team (Researcher + System Tester) during planning phase. Fix execution uses standard plan-execution team. |
| **doc-code-verification-mode** | "verify docs", "check doc-code gaps", "sync docs" | Yes — `/uc:doc-code-verification-mode` | Doc & Code Verification Mode: find and plan fixes for discrepancies |
| **plan-enhancer** | Auto-loaded by all modes | No (internal) | Standardizes plan output: plan directory, README.md with embedded task list, task granularity. Uses Claude Code's plan mode file path override (writes plan to `documentation/plans/{name}/README.md` instead of default `.claude/plan.md`). Ensures task list is embedded in the plan document. |
| **plan-execution** | `/uc:plan-execution` | Yes — `/uc:plan-execution` | Execution engine: reads plan directory, composes dynamic agent team based on plan size, creates role-separated task lists, spawns teammates, coordinates 5-phase execution (setup, parallel work, checkpoint, failure handling, completion) |
| **discovery-mode** | "discovery mode", "research only" | Yes — `/uc:discovery-mode` | Discovery Mode: research only, coding disabled |
| **docs-manager** | Activated by `.claude/docs-format` file | No (auto) | Guards `documentation/` structure — enforces canonical layout, routes docs to correct directories, prevents structural drift |
| **checkpoint** | `/uc:checkpoint` | Yes — `/uc:checkpoint` | Saves task list states, active teammate assignments, execution decisions, and blockers to `plans/{name}/checkpoint-{timestamp}.md` for session recovery |
| **context-management** | "add context", "add external system", "update context" | Yes — `/uc:context-management` | Manages `context/` directory: structures external system knowledge, aggregates docs + code, manages git submodules |
| **docs-migration** | `/uc:docs-migration` | Yes — `/uc:docs-migration` | One-time migration: surveys existing project docs + code, maps them to canonical structure, produces a migration plan |
| **help** | "how to accomplish", "extend the system" | Yes — `/uc:help` | Meta-skill: understands full system, advises on extensions |
| **tech-research** | "how does X work", "research library", "check docs" | Yes — `/uc:tech-research` | External library/framework documentation via Ref.tools |

### Skill File Format

Each skill is a directory under `skills/` containing a `SKILL.md` file (per [D16](decisions.md)). The `SKILL.md` uses YAML frontmatter for metadata and a Markdown body for the system prompt.

```
skills/{skill-name}/SKILL.md
```

**YAML frontmatter fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable skill name |
| `description` | string | Yes | One-line description (shown in help/listings) |
| `argument-hint` | string | No | Placeholder text for user arguments (e.g., `"feature description"`) |
| `user-invocable` | boolean | No | If `true`, skill becomes a slash command (`/uc:{skill-name}`). Default: `false`. |
| `disable-model-invocation` | boolean | No | If `true`, Claude cannot auto-activate this skill. Default: `false`. |
| `allowed-tools` | list | No | Restrict which tools the skill can use |
| `model` | string | No | Override model for this skill (`opus`, `sonnet`, `haiku`) |
| `context` | list | No | Paths to load into context when skill activates (supports `${CLAUDE_PLUGIN_ROOT}`) |
| `agent` | string | No | Agent to delegate execution to (path to agent `.md` file) |
| `hooks` | object | No | Skill-scoped hooks (same format as `hooks.json`) |

**Body format:**

The Markdown body below the frontmatter is the system prompt injected into context when the skill activates.

- `$ARGUMENTS` — replaced with the user's input after the slash command
- `` !`shell-command` `` — preprocessing: runs a shell command and injects stdout into the prompt
- `${CLAUDE_PLUGIN_ROOT}` — resolves to the plugin's root directory (portable paths)

**Example SKILL.md:**

```markdown
---
name: Feature Mode
description: Plan new features with product, architecture, and implementation context
argument-hint: "feature description"
user-invocable: true
context:
  - ${CLAUDE_PLUGIN_ROOT}/skills/plan-enhancer/SKILL.md
---

You are entering Feature Mode for: $ARGUMENTS

Read the following architecture docs before planning:
- documentation/technology/architecture/
- documentation/product/requirements/

[... rest of system prompt ...]
```

## Agents

> **Note:** The Lead is the main Claude Code session itself — not a spawned agent. It runs the plan-execution skill and orchestrates all teammates. See [Execution](execution.md) for Lead behavior.
>
> **Spawning model:** During planning, agents are spawned as **subagents** via the Task tool (results return to Lead). During execution, agents are spawned as **teammates** in an agent team (self-claiming, shared memory, direct messaging). See [Architecture — Agent Coordination](architecture.md#agent-coordination).

| Agent | Model | Tools | Purpose | Spawned As | Spawn Context |
|-------|-------|-------|---------|------------|---------------|
| **researcher** | sonnet | Read, Grep, Glob, WebFetch, WebSearch, mcp__ref | Generic context-gathering agent. Parameterized by the mode that spawns it — focuses on whatever the mode needs (product context, debug investigation, code patterns, etc.). Does not decide where to write — the spawning mode must specify output paths in the spawn prompt. | Subagent (planning) or Teammate (execution) | **Planning:** output file paths, architecture docs path, tech-research skill. **Execution:** + plan README.md, `shared/` directory path, research task list instructions. |
| **task-executor** | opus | Read, Write, Edit, Glob, Grep, Bash | Single-task implementation from research context | Teammate (execution only) | Plan README.md, `shared/` directory path, per-task research file, coding standards path, impl task list instructions |
| **task-tester** | sonnet | Read, Glob, Grep, Bash | Testing gate in execution pipeline. Self-claims from test task list for per-task testing. Also runs full test suite as final gate before team shutdown. Must not modify source code. Bash restricted to running test commands and build tools. | Teammate (execution only) | Plan README.md, `shared/` directory path, success criteria from plan, test task list instructions, system test instructions (.claude/system-test.md), SendMessage target (Lead) for failures |
| **system-tester** | sonnet | Read, Glob, Grep, Bash | Bug reproduction and fix validation in Debug Mode. Attempts to reproduce reported issues, validates fixes resolve the original problem. Must not modify source code. Bash restricted to bug reproduction and fix validation commands. | Subagent (Debug Mode planning) | System test instructions (`.claude/system-test.md`), bug description, reproduction steps |
| **code-review** | sonnet | Read, Glob, Grep | Code review gate in execution pipeline. Self-claims from review task list. Checks code quality, pattern compliance, architecture conformance, duplication. Read-only. PASS promotes to test list, FAIL re-queues to impl list. | Teammate (execution only) | Plan README.md, `shared/` directory path, coding standards path, architecture docs path, review task list instructions |
| **checker** | sonnet | Read, Grep, Glob | Compares specific code against documentation for single topic | Subagent (Verification Mode) | Code path + doc path to compare |
| **code-surveyor** | haiku | Read, Grep, Glob | Quick survey of code package structure | Subagent (Verification Mode) | Target directory to survey |
| **doc-surveyor** | haiku | Read, Grep, Glob | Quick survey of documentation section structure | Subagent (Verification Mode) | Documentation section to survey |
| **market-analyzer** | sonnet | WebSearch, WebFetch, mcp__ref | Market research, competitor analysis, technology trends | Subagent (Discovery Mode) | Research topic, output path |

### Agent File Format

Each agent is a flat `.md` file under `agents/` (per [D17](decisions.md)). YAML frontmatter declares runtime configuration; the body is the agent system prompt.

```
agents/{agent-name}.md
```

**YAML frontmatter fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Human-readable agent name |
| `description` | string | Yes | One-line description |
| `tools` | list | No | Allowed tools (e.g., `[Read, Grep, Glob, Bash]`) |
| `disallowedTools` | list | No | Explicitly blocked tools |
| `model` | string | No | Model override (`opus`, `sonnet`, `haiku`) |
| `permissionMode` | string | No | Permission mode for the agent |
| `maxTurns` | number | No | Maximum agentic turns before stopping |
| `skills` | list | No | Skills the agent can invoke |
| `mcpServers` | list | No | MCP servers available to the agent |
| `hooks` | object | No | Agent-scoped hooks |
| `memory` | string | No | Path to persistent memory file |
| `background` | boolean | No | If `true`, agent runs in background |
| `isolation` | string | No | Isolation mode (e.g., `"worktree"`) |

**Body format:**

The Markdown body is the system prompt given to the agent when spawned. Spawn prompts from the Lead or skill provide additional runtime context on top of this base prompt.

**Example agent file:**

```markdown
---
name: Researcher
description: Generic context-gathering agent, parameterized by spawning mode
model: sonnet
tools:
  - Read
  - Grep
  - Glob
  - WebFetch
  - WebSearch
  - mcp__ref
---

You are a Researcher agent. Your job is to gather context from the codebase,
documentation, and external sources as directed by your spawn prompt.

[... rest of system prompt ...]
```

## Hooks

Hooks are the hard enforcement layer ([D6](decisions.md)) — they cannot be overridden by the AI.

### hooks.json Structure

All hooks are defined in `hooks/hooks.json`. Each hook binds to an event and specifies a handler type.

```json
{
  "hooks": [
    {
      "event": "PreToolUse",
      "match": { "tool": ["Write", "Edit"] },
      "type": "prompt",
      "prompt": "Check if the file being written/edited aligns with architecture docs in documentation/technology/architecture/. If the change contradicts documented architecture, BLOCK the operation and explain why."
    },
    {
      "event": "PostToolUse",
      "match": { "tool": ["TaskUpdate"] },
      "type": "prompt",
      "prompt": "If the task status is being set to 'completed', read the plan README.md success criteria and validate this task meets them. Block completion if criteria are unmet."
    },
    {
      "event": "Stop",
      "type": "prompt",
      "prompt": "If execution is in progress, save a checkpoint to the plan directory before stopping."
    }
  ]
}
```

### Hook Events

| Event | When It Fires | Ultra Claude Usage |
|-------|---------------|-------------------|
| **PreToolUse** | Before a tool call executes | Architecture conformance check on Write/Edit |
| **PostToolUse** | After a tool call completes | Task completion validation on TaskUpdate |
| **Stop** | Session is ending | Checkpoint save during execution |
| **SessionStart** | Session begins | Available but unused |
| **TaskCompleted** | A task is marked complete | Available but unused (covered by PostToolUse) |
| **TeammateIdle** | A teammate has no more work | Available but unused |
| **SubagentStart** | A subagent is spawned | Available but unused |
| **SubagentStop** | A subagent finishes | Available but unused |

### Hook Types

| Type | Description | Example Use |
|------|-------------|-------------|
| **command** | Runs a shell command. Exit code 0 = pass, non-zero = block. | Run a linter before allowing a Write |
| **prompt** | Injects a prompt into the model context for evaluation. Model decides pass/block. | Check architecture conformance |
| **agent** | Spawns an agent to evaluate the action. Agent decides pass/block. | Complex multi-file validation |

Ultra Claude currently uses only `prompt`-type hooks. `command` and `agent` types are available for future use.

### Hooks in Execution Context

| Hook Event | Purpose | Agent Team Behavior |
|------------|---------|---------------------|
| **PreToolUse (Write/Edit)** | Check if file changes align with architecture docs | Unchanged from planning layer |
| **PostToolUse (TaskUpdate)** | Validate task meets documented success criteria | When any agent calls TaskUpdate with `status: "completed"`, reads plan README.md success criteria and validates. Blocks completion if unmet. |
| **Stop** | Verify architectural changes are reflected in architecture docs | Triggers checkpoint save if execution is in progress |

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

### Plugin Manifest (`plugin.json`)

Located at `.claude-plugin/plugin.json`. This is the plugin's identity file.

```json
{
  "name": "uc",
  "version": "0.1.0",
  "description": "Specification-driven development platform for Claude Code",
  "author": "Dawid Duniec",
  "keywords": ["development", "specification-driven", "agent-teams"],
  "skills": "skills/",
  "agents": "agents/",
  "hooks": "hooks/hooks.json",
  "templates": "templates/"
}
```

The `name` field determines the command prefix — all user-invocable skills are namespaced as `/uc:{skill-name}`.

### Settings (`settings.json`)

Located at the plugin root. Currently the only key supported by Claude Code is `agent`:

```json
{
  "agent": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

> **Note:** `.mcp.json` and `.lsp.json` exist in the plugin spec but Ultra Claude does not bundle MCP or LSP servers — it relies on globally configured servers (Ref.tools, Atlassian) per [D7](decisions.md).

### Environment Variable

`${CLAUDE_PLUGIN_ROOT}` resolves to the plugin's root directory at runtime. Use it in SKILL.md `context` paths and agent prompts for portable references to plugin files.

### Project-Level Configuration

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
