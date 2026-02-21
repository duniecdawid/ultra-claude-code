# Ultra Claude

A Claude Code plugin that implements a spec-driven development platform. Documentation governs code growth. Agent teams coordinate execution.

## What This Is

Ultra Claude is a portable, reusable Claude Code plugin that turns any project into a structured, specification-driven development environment. You install it, it establishes a documentation layer, and from that point forward — documentation controls how the codebase grows.

It is NOT a framework, library, or runtime. It is a collection of **skills**, **agents**, **commands**, and **hooks** packaged as a Claude Code plugin. When installed in a project, Claude Code gains:

- Three specialized planning modes (Feature, Debugging, Verification) + one execution engine
- Agent teams that coordinate research, implementation, and validation in parallel
- Architectural governance via hooks that enforce architecture conformance
- Documentation-vs-code verification that detects drift
- Plan management with checkpoint/recovery across sessions
- A meta-skill ("Forge") that helps extend the system itself

## The Core Philosophy

### Specification-Driven Development

Code is a derived artifact. The specification is the source of truth.

This does NOT mean:
- Documenting every function (implementation details belong in code)
- Rigid locks that prevent all change (specs evolve)
- Bureaucratic overhead that slows you down

This DOES mean:
- Architecture documentation is kept current and reflects all decisions
- Product requirements exist before code is written
- When code diverges from specs, you fix the spec first, then re-plan
- AI agents read specs before coding and are constrained by them
- Documentation that is wrong produces broken implementations (forcing function)

### Governance, Not Bureaucracy

Documentation acts like zoning laws — you can build freely within the constraints, but the constraints control the direction of growth. Three levels of enforcement:

| Level | Mechanism | Enforcement |
|-------|-----------|-------------|
| **Soft** | CLAUDE.md rules, architecture docs | Advisory — Claude reads them, may drift under context pressure |
| **Medium** | Skills that load architecture docs before planning | Workflow-enforced — can't skip the step |
| **Hard** | Hooks (PreToolUse, Stop, TaskCompleted) | Deterministic — cannot be overridden by the AI |

### Change Classification

Not every change needs the same scrutiny:

- **Additive** (new feature within existing patterns) → flows freely
- **Compatible** (extends existing architecture) → lightweight review
- **Breaking** (violates existing architecture) → must update the architecture doc first, then re-plan

## Two Layers: Planning and Execution

Ultra Claude enhances Claude Code's built-in plan mode. Instead of a rigid multi-phase pipeline, there are **three specialized planning modes** that each optimize plan mode for a specific use case, and **one execution engine** that runs any plan.

### Planning Layer

All planning modes trigger Claude Code's plan mode automatically, enhanced by **Plan Mode Enhance** — a shared skill that:
- Redirects the plan from Claude's default location to a plan directory
- Ensures task granularity is right for agentic execution
- Creates a task list compatible with Claude's task system
- Standardizes the output structure so all plans look the same regardless of entry point

#### Feature Plan Mode

For new features. Uses Researcher + Docs agents to gather context about the codebase, existing architecture, and product requirements before planning.

- Challenges scope, pushes for clarity, asks "why?"
- Considers product requirements, architecture, and implementation in one pass
- When architecture decisions are ambiguous or high-risk, suggests **RFC mode** for structured review (AI personas: Devil's Advocate, Pragmatist, Security/Reliability, Cost-conscious — and/or human reviewers)
- Produces a plan in `documentation/plans/{name}/`

#### Debugging Mode

For fixing things. Uses Debugging Planner + Researcher + Full System Tester to investigate before planning.

- Analyzes the issue, proposes hypotheses
- Collects logs, reproduces the bug
- Produces a plan focused on the fix + verification

#### Doc & Code Verification Mode

For periodic sync. Uses surveyors/checkers to find discrepancies between documentation and code, then produces a plan of things to fix.

- Reviews system structure, spawns verificators to look for issues
- Generates a list of discrepancies with severity
- Produces a plan to resolve them (update docs or update code)

### Discovery Mode (Optional Pre-Step)

Research only — coding is disabled. Focused on building product vision, exploring competitors, researching technology options. Uses Researcher + Market Analyzer agents.

Discovery feeds into planning but does not produce a plan itself. Output goes to `documentation/research/{topic}.md`.

### Execution Layer

**Execute Plan** — a single execution engine that takes any plan produced by any mode and runs it through the agent team. It doesn't care how the plan was created — Feature Plan, Debugging, or Verification all produce the same standardized structure.

The execution engine:
- Reads the plan and task list from the plan directory
- Spawns agents: Researcher, Task Executor, Validator, Full System Tester
- Is aware of already-performed research (doesn't repeat work)
- Runs tasks without requiring user approval between every task
- Saves progress via checkpoints for session recovery

## Agent Teams Architecture

Ultra Claude uses Claude Code's experimental agent teams as its PRIMARY coordination mechanism.

### Why Agent Teams (Not Subagents)

| Feature | Subagents | Agent Teams |
|---------|-----------|-------------|
| Communication | Report back to parent only | Teammates message each other directly |
| Coordination | Parent manages everything | Shared task list, self-claiming |
| Context | Results summarized back | Each has full independent context |
| Best for | Focused tasks | Complex work requiring collaboration |

Agent teams enable patterns that subagents cannot:
- Researcher shares findings directly with Task Executor (no parent relay)
- Validator challenges Task Executor's work directly
- Multiple teammates self-claim from shared task list
- Plan approval workflow gates implementation

### Team Structure for Execute Plan

```
Lead (main session — user interacts here)
├── Researcher teammate
│   - Gathers context from architecture docs + code
│   - Checks for existing research (doesn't repeat work)
│   - Writes findings to plans/NAME/research/
│   - Sends findings to Task Executor via SendMessage
│
├── Task Executor teammate
│   - Reads research context
│   - Implements one task at a time
│   - Works in own files (no conflicts)
│   - Sends completion to Validator via SendMessage
│
├── Validator teammate
│   - Checks implementation against success criteria
│   - Read-only — cannot modify code
│   - Reports pass/fail to Lead
│   - If fail: sends specific feedback to Task Executor
│
└── Full System Tester teammate (spawned as needed)
    - Runs test suite after changes
    - Reports results to Lead
```

### Team Structure for Debugging Mode

```
Lead (main session)
├── Debugging Planner teammate
│   - Analyzes the issue
│   - Proposes investigation hypotheses
│   - Creates investigation tasks
│
├── Researcher teammate(s)
│   - Each investigates a different hypothesis in parallel
│   - Sends evidence to Lead
│
└── Full System Tester teammate
    - Reproduces the bug
    - Validates the fix
```

### Team Structure for Doc & Code Verification Mode

```
Lead (main session)
├── Code Surveyor teammate(s)
│   - Survey code packages/modules
│   - Report structure and patterns
│
├── Doc Surveyor teammate(s)
│   - Survey documentation sections
│   - Report what's documented
│
└── Checker teammate(s)
    - Compare code structure vs doc claims
    - Report discrepancies with severity
```

### Team Structure for Discovery Mode

```
Lead (main session — coding DISABLED)
├── Researcher teammate
│   - Deep code/docs research
│   - Uses Ref.tools for external library docs
│
└── Market Analyzer teammate
    - Uses Perplexity/web for market research
    - Competitor analysis, technology trends
```

### Agent Team Constraints We Accept

- **No session resume for teammates**: If session breaks, teammates are lost. Mitigated by checkpoint skill saving state to plan files.
- **One team per session**: Each workflow gets its own session.
- **No nested teams**: Teammates cannot spawn sub-teams. Mitigated by teammates using Task (subagent) for focused sub-tasks.
- **Cost**: Each teammate is ~200K tokens. We minimize by spawning only what's needed, shutting down when done.
- **Permissions**: All teammates inherit lead's permission mode. Pre-approve common operations in settings.

## Component Inventory

### Skills (Purple)

| Skill | Trigger | Invocation | Purpose |
|-------|---------|------------|---------|
| **feature-plan-mode** | "new feature", "plan feature", "start feature" | User | Feature Plan Mode: new features with product + architecture context |
| **debugging-mode** | "debug", "fix", "investigate" | User | Debugging Mode: issue investigation and fix planning |
| **doc-code-verification-mode** | "verify docs", "check doc-code gaps", "sync docs" | User | Doc & Code Verification Mode: find and plan fixes for discrepancies |
| **plan-mode-enhance** | Auto-loaded by all modes | Auto (internal) | Standardizes plan output: plan directory, task granularity, task list |
| **execute-plan** | `/uc:execute` | User | Execution engine: runs any plan through agent team |
| **discovery-mode** | "discovery mode", "research only" | User | Discovery Mode: research only, coding disabled |
| **docs** | Activated by `.docs-format` file | Auto | Documentation structure management |
| **checkpoint** | `/uc:checkpoint` | User | Save context to plan files for recovery |
| **forge** | "how to accomplish", "extend the system" | User | Meta-skill: understands full system, advises on extensions |
| **tech-research** | "how does X work", "research library", "check docs" | User/Auto | External library/framework documentation via Ref.tools |

### Agents (Green)

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **researcher** | sonnet | Read, Grep, Glob, WebFetch, mcp__ref | Context gathering: codebase, architecture, product docs |
| **task-executor** | sonnet | Read, Write, Edit, Glob, Grep, Bash | Single-task implementation from research context |
| **task-validator** | sonnet | Read, Glob, Grep, Bash | Validates implementation against success criteria (read-only for code, can run tests) |
| **code-review** | sonnet | Read, Glob, Grep | Checks code compliance with existing patterns, prevents duplication |
| **full-system-tester** | haiku | Read, Glob, Grep, Bash | Runs test suite, reports results. Deliberately "dumb" — refuses diagnostic requests |
| **debugging-planner** | sonnet | Read, Glob, Grep | Analyzes issues, proposes hypotheses, creates investigation tasks |
| **verify-checker** | sonnet | Read, Grep, Glob | Compares specific code against documentation for single topic |
| **verify-code-surveyor** | haiku | Read, Grep, Glob | Quick survey of code package structure |
| **verify-doc-surveyor** | haiku | Read, Grep, Glob | Quick survey of documentation section structure |
| **market-analyzer** | sonnet | WebSearch, WebFetch, mcp__ref | Market research, competitor analysis, technology trends |

### Commands (Slash Commands)

| Command | Purpose |
|---------|---------|
| `/uc:feature` | Enter Feature Plan Mode |
| `/uc:debug` | Enter Debugging Mode |
| `/uc:verify` | Enter Doc & Code Verification Mode |
| `/uc:execute` | Execute a plan through agent team |
| `/uc:discover` | Enter Discovery Mode (research only, no coding) |
| `/uc:checkpoint` | Save current progress for session recovery |
| `/uc:forge` | Ask the meta-skill how to accomplish something |
| `/uc:status` | Show plan status, task progress |

### Hooks (Deterministic Enforcement)

| Hook Event | Purpose | Type |
|------------|---------|------|
| **PreToolUse (Write/Edit)** | Check if file changes align with architecture docs | prompt |
| **Stop** | Verify architectural changes are reflected in architecture docs | prompt |
| **TaskCompleted** | Validate task meets documented success criteria | agent |
| **TeammateIdle** | Check if teammate completed all assigned work | prompt |
| **SessionStart** | Load plan context if resuming | command |

### Documents (Yellow — Templates shipped with plugin)

| Template | Purpose | Created When |
|----------|---------|-------------|
| `_templates/architecture.md` | Architecture document template | Planning (any mode) |
| `_templates/rfc.md` | RFC template (problem, proposed solution, alternatives, open questions, outcome) | Planning (optional, for tough decisions) |
| `_templates/requirement.md` | Formal requirement template (FR-xxx, NFR-xxx) | Planning |
| `_templates/plan.md` | Plan tracking file | Planning |
| `_templates/context.md` | External system documentation | As needed |
| `_templates/dependency.md` | Blocking questions/dependencies | As needed |
| `_templates/task.md` | Task template within plan | Planning |

### Configuration Files

| File | Purpose | Scope |
|------|---------|-------|
| `.docs-format` | Activates docs skill, sets output format (confluence/gitbook) | Project |
| `.claude/ultra-claude.local.md` | Plugin settings: active plan, team config, feature flags | Project (gitignored) |
| `.claude/environments-info` | How to access dev/staging/prod environments | Project |
| `.claude/app-context-for-research.md` | Domain context for researcher agents | Project |
| `.claude/full-system-test.md` | Instructions for full system test agent | Project |

## Plugin Directory Structure

```
ultra-claude/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── commands/
│   ├── feature.md                     # /uc:feature (plan a new feature)
│   ├── debug.md                       # /uc:debug (plan a fix)
│   ├── verify.md                      # /uc:verify (plan doc-code sync)
│   ├── execute.md                     # /uc:execute (run a plan)
│   ├── discover.md                    # /uc:discover (research only)
│   ├── checkpoint.md                  # /uc:checkpoint
│   ├── forge.md                       # /uc:forge
│   └── status.md                      # /uc:status
├── agents/
│   ├── researcher.md
│   ├── task-executor.md
│   ├── task-validator.md
│   ├── code-review.md
│   ├── full-system-tester.md
│   ├── debugging-planner.md
│   ├── verify-checker.md
│   ├── verify-code-surveyor.md
│   ├── verify-doc-surveyor.md
│   └── market-analyzer.md
├── skills/
│   ├── feature-plan-mode/
│   │   └── SKILL.md
│   ├── debugging-mode/
│   │   └── SKILL.md
│   ├── doc-code-verification-mode/
│   │   └── SKILL.md
│   ├── plan-mode-enhance/
│   │   └── SKILL.md
│   ├── execute-plan/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── orchestration-pattern.md
│   ├── discovery-mode/
│   │   └── SKILL.md
│   ├── docs/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── structure-guide.md
│   ├── checkpoint/
│   │   └── SKILL.md
│   ├── forge/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── system-overview.md
│   └── tech-research/
│       └── SKILL.md
├── hooks/
│   ├── hooks.json                     # Hook configuration
│   └── scripts/
│       ├── check-architecture-conformance.sh
│       ├── load-plan-context.sh
│       └── validate-task-completion.sh
├── templates/                         # Documentation templates
│   ├── architecture.md
│   ├── rfc.md
│   ├── requirement.md
│   ├── plan.md
│   ├── context.md
│   ├── dependency.md
│   └── task.md
├── scripts/
│   └── init-docs.sh                   # Initialize documentation/ in a project
└── README.md
```

## Workflow: How It All Connects

### Feature Plan Mode

```
User: /uc:feature "Add user authentication"

1. PLANNING — Feature Plan Mode activates
   → Plan Mode Enhance triggers plan mode, configures plan directory
   → Researcher + Docs agents gather context (codebase, architecture, product docs)
   → Claude challenges scope, pushes for clarity
   → If architecture decision is ambiguous: suggests RFC mode
     → Creates documentation/rfcs/auth-strategy.md
     → Runs AI persona review (Devil's Advocate, Pragmatist, etc.)
     → Outcome integrated into architecture doc, RFC archived
   → Plan created in documentation/plans/user-auth/plan.md
   → Task list created in documentation/plans/user-auth/task_list.md
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute user-auth
   → Agent team runs tasks from the plan
```

### Executing a Plan (Agent Team)

```
User: /uc:execute user-auth

1. SETUP
   → Lead reads documentation/plans/user-auth/plan.md + task_list.md
   → Lead creates agent team
   → Lead spawns: Researcher + Task Executor + Validator teammates
   → Lead checks for existing research (doesn't repeat work)

2. TASK LOOP (for each task in priority order)
   → Researcher gathers context for the task
     - Reads architecture docs, existing code
     - Writes findings to plans/user-auth/research/task-N.md
     - Sends "research complete" to Task Executor
   → Task Executor implements the task
     - Reads research findings
     - Implements code conforming to plan and architecture
     - Sends "implementation complete" to Validator
   → Validator checks the implementation
     - Checks code against success criteria
     - Runs relevant tests
     - If PASS: task marked complete
     - If FAIL: sends specific feedback to Task Executor, task re-queued
   → No user approval required between tasks

3. CHECKPOINT (every N tasks or on demand)
   → Saves progress to plan directory
   → Task list + plan can be used to recover if session dies
   → /uc:execute user-auth resumes from checkpoint

4. COMPLETION
   → All tasks done
   → Full System Tester runs final verification
   → Summary report produced
```

### Discovery Mode

```
User: /uc:discover "Research how competitors handle rate limiting"

1. Discovery Mode skill activates
   → Coding is DISABLED
   → Researcher + Market Analyzer agents work in parallel
   → Researcher: Explores internal codebase, reads docs, uses Ref.tools
   → Market Analyzer: Web searches, competitor analysis

2. Findings compiled to documentation/research/{topic}.md
3. No code changes. No plan. Pure investigation output.
4. Feeds into future planning sessions as context.
```

### Doc & Code Verification Mode

```
User: /uc:verify

1. PLANNING — Doc & Code Verification Mode activates
   → Plan Mode Enhance triggers plan mode
   → Spawns Code Surveyor + Doc Surveyor agents in parallel
   → Code Surveyors scan codebase structure, patterns, APIs
   → Doc Surveyors scan documentation claims, specs, architecture docs
   → Checker agents compare doc claims vs code reality
   → Discrepancies listed with severity (HIGH/MEDIUM/LOW)
   → Plan created with fix tasks (update doc or update code)
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute {plan-name}
   → Agent team resolves discrepancies per plan
```

## The Forge Meta-Skill

Forge is unique — it has awareness of the ENTIRE Ultra Claude system. Its purpose:

1. **"How do I accomplish X with this system?"** — Advises which skills, agents, and workflows to use
2. **"Extend the system with Y capability"** — Guides creating new skills/agents that fit the architecture
3. **"What's the most efficient path?"** — Suggests workflow optimizations based on the task

Forge achieves this by having a comprehensive system-overview.md reference that describes all components, their relationships, and usage patterns.

## Migration Plan

### What Moves Into the Plugin

Old global skills are refactored into the new plugin structure. The mapping is not 1:1 — old phase-based skills are consolidated into planning modes.

| Old Global Skill | Becomes | Destination |
|-----------------|---------|-------------|
| `product-design` + `tech-architecture` + `implementation-planning` | Feature Plan Mode | `ultra-claude/skills/feature-plan-mode/` |
| `development` + `execute-initiative` | Execute Plan | `ultra-claude/skills/execute-plan/` |
| `verify-docs` | Doc & Code Verification Mode | `ultra-claude/skills/doc-code-verification-mode/` |
| `docs` | Docs | `ultra-claude/skills/docs/` |
| `checkpoint` | Checkpoint | `ultra-claude/skills/checkpoint/` |
| `skill-agent-creator` | Forge (evolved) | `ultra-claude/skills/forge/` |
| `tech-research` | Tech Research | `ultra-claude/skills/tech-research/` |
| `verify-checker` | Verify Checker agent | `ultra-claude/agents/verify-checker.md` |
| `verify-code-surveyor` | Code Surveyor agent | `ultra-claude/agents/verify-code-surveyor.md` |
| `verify-doc-surveyor` | Doc Surveyor agent | `ultra-claude/agents/verify-doc-surveyor.md` |

### What Stays Global (NOT in plugin)

| Component | Why |
|-----------|-----|
| `ha-nodered-knowledge` | Domain-specific, unrelated to development pipeline |
| `prompt-architect` | Generic utility, useful outside Ultra Claude |
| `skill-agent-creator` | Generic utility, useful outside Ultra Claude |
| `rebuild-old-website` | One-off project skill |
| `image-content-extractor` | Generic utility agent |

### Global Skills Archived After Migration

When plugin versions are ready, the originals move to `~/.claude/archive/` rather than being deleted.

| Component | Archived From |
|-----------|--------------|
| `tech-research` | `~/.claude/skills/tech-research/` |
| `product-design` | `~/.claude/skills/product-design/` |
| `tech-architecture` | `~/.claude/skills/tech-architecture/` |
| `implementation-planning` | `~/.claude/skills/implementation-planning/` |
| `development` | `~/.claude/skills/development/` |
| `execute-initiative` | `~/.claude/skills/execute-initiative/` |
| `verify-docs` | `~/.claude/skills/verify-docs/` |
| `docs` | `~/.claude/skills/docs/` |
| `checkpoint` | `~/.claude/skills/checkpoint/` |
| `verify-checker` | `~/.claude/agents/verify-checker.md` |
| `verify-code-surveyor` | `~/.claude/agents/verify-code-surveyor.md` |
| `verify-doc-surveyor` | `~/.claude/agents/verify-doc-surveyor.md` |

### What's NEW (doesn't exist yet)

| Component | Type | Purpose |
|-----------|------|---------|
| Feature Plan Mode skill | Skill | Feature Plan Mode (consolidates old product-design, tech-architecture, implementation-planning) |
| Debugging Mode skill | Skill | Debugging Mode for issue investigation and fixes |
| Plan Mode Enhance skill | Skill | Standardizes all plan output: plan directory, task granularity, task list |
| Execute Plan skill | Skill | Single execution engine for all plans (consolidates old development + execute-initiative) |
| Forge skill | Skill | Meta-skill with full system awareness |
| Discovery Mode skill | Skill | Disables coding, enables research-only workflow |
| Debugging Planner agent | Agent | Hypothesis-driven debugging coordination |
| Market Analyzer agent | Agent | Web/market research via Perplexity |
| Task Executor agent | Agent | Single-task implementation from research context |
| Full System Tester agent | Agent | Test suite execution (deliberately simple) |
| Code Review agent | Agent | Checks code compliance, prevents duplication |
| RFC review personas | Config | Built-in: Devil's Advocate, Pragmatist, Security/Reliability, Cost-conscious. User-extensible. |
| All hooks | Hooks | Architecture conformance, task validation, plan context loading |
| All commands | Commands | `/uc:*` namespace |
| All templates | Templates | Documentation scaffolding |
| Plugin manifest | Config | plugin.json |
| Init script | Script | Sets up documentation/ in a new project |

## Key Assumptions

1. **Agent teams will stabilize**. We're building on an experimental feature. If it breaks, we fall back to subagents (the execute-plan skill already works this way via Task tool).

2. **Documentation structure is consistent**. Every project using Ultra Claude follows the same `documentation/` layout. This is non-negotiable — it's how specs govern code.

3. **CLAUDE.md is the entry point**. The plugin augments but does not replace project CLAUDE.md. Project-specific rules live in CLAUDE.md; Ultra Claude provides the framework.

4. **Token cost is acceptable**. Agent teams are expensive (~200K tokens per teammate). The user has accepted this trade-off for the coordination benefits.

5. **The plugin is personal**. This is built for one developer's workflow. It may be shared later, but the primary user is the author.

6. **Hooks are the enforcement layer**. CLAUDE.md rules can be forgotten under context pressure. Hooks cannot be overridden. Critical governance rules go in hooks.

7. **Ref.tools MCP is a prerequisite**. The tech-research skill is bundled in the plugin, but it depends on Ref.tools MCP being configured in the environment. The plugin owns the skill; the user owns the MCP server setup.

8. **The init script handles project setup**. When Ultra Claude is installed in a new project, `init-docs.sh` creates the `documentation/` directory structure with templates. The user then fills in project-specific content.

## Open Questions (To Resolve Before Implementation)

1. **Command prefix**: Is `/uc:` the right namespace? Alternatives: `/ultra:`, `/forge:`, no prefix (just `/execute`, `/verify`, etc.)?

2. **Team persistence**: When a plan spans multiple sessions, how do we handle team recreation? Current approach: checkpoint everything to files, recreate team on resume.

3. **Discovery mode enforcement**: Should coding be disabled via hooks (hard) or CLAUDE.md instructions (soft)? Hook is more reliable but requires careful implementation.

4. **Docs format flexibility**: Should the plugin mandate a specific documentation format (Confluence-style, GitBook-style) or be format-agnostic?

5. **How does the plugin interact with projects that already have documentation?** Does it adapt to existing structure or require migration to the Ultra Claude layout?

6. **Should the Forge skill be a skill or a command?** Skills auto-activate based on triggers; commands require explicit invocation. Forge might benefit from explicit invocation to avoid unwanted activation.

7. **MCP servers**: Should the plugin bundle any MCP servers? Current thinking: no — rely on globally configured MCP servers (Ref.tools, Atlassian).

## Research That Informed This Design

### Existing Solutions Evaluated

| Solution | What We Took | What We Skipped |
|----------|-------------|-----------------|
| [levnikolaevich/claude-code-skills](https://github.com/levnikolaevich/claude-code-skills) | Checkpoint/recovery system, quality gate pattern, doc-first pipeline | 103-skill complexity, Agile/RICE methodology, Linear integration |
| [wshobson/agents (Conductor)](https://github.com/wshobson/agents) | Doc-first workflow (Context→Spec→Plan→Implement), phase-gated execution | 112-agent marketplace scale, four-tier model strategy |
| [github/spec-kit](https://github.com/github/spec-kit) | Constitution concept, spec evolution model, change classification | CLI tooling, multi-agent-tool support (we're Claude Code only) |
| [avifenesh/agentsys](https://github.com/avifenesh/agentsys) | Drift detection pattern (77% fewer tokens) | Full 12-phase pipeline |
| [obra/superpowers](https://github.com/obra/superpowers) | Skill-creation meta-skill pattern | Specific implementation choices |
| [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow) | SPARC methodology concepts | Unstable alpha, 400+ open issues, scope creep |
| [Anthropic official plugins](https://github.com/anthropics/claude-code/tree/main/plugins) | Plugin structure, hook patterns, agent definitions | Specific plugin implementations |

### Methodology References

| Source | Key Insight |
|--------|-------------|
| [Addy Osmani — Good specs for AI agents](https://addyosmani.com/blog/good-spec/) | Three-tier boundary: Always/Ask First/Never |
| [InfoQ — Spec-Driven Development](https://www.infoq.com/articles/spec-driven-development/) | Specs as "type system for distributed architecture" |
| [O'Reilly — Agentic AI for Architecture Governance](https://www.oreilly.com/radar/how-agentic-ai-empowers-architecture-governance/) | MCP as governance abstraction layer |
| [Fowler/Bockeler — Understanding SDD](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) | Three maturity levels: Spec-First → Spec-Anchored → Spec-as-Source |
| [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams) | Official architecture, constraints, patterns |
| [Claude Code Plugin Structure](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md) | Official plugin format, auto-discovery, manifest |

## Color Coding Convention (from Miro Board)

Throughout this project and its documentation:
- **Purple** = Skill (procedural knowledge, extends main context)
- **Green** = Agent (isolated execution, spawned via Task tool or as teammate)
- **Yellow** = Document (artifact, template, reference file)
- **Blue** = Instruction/configuration file (.claude/ configs)
- **Orange** = Tag/mode indicator (e.g., "Use Plan Mode")
