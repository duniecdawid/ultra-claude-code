# Ultra Claude

A Claude Code plugin that implements a spec-driven development platform. Documentation governs code growth. Agent teams coordinate execution.

## What This Is

Ultra Claude is a portable, reusable Claude Code plugin that turns any project into a structured, specification-driven development environment. You install it, it establishes a documentation layer, and from that point forward — documentation controls how the codebase grows.

It is NOT a framework, library, or runtime. It is a collection of **skills**, **agents**, **commands**, and **hooks** packaged as a Claude Code plugin. When installed in a project, Claude Code gains:

- A 4-phase development pipeline (Product Design → Architecture → Planning → Development)
- Agent teams that coordinate research, implementation, and validation in parallel
- Architectural governance via hooks that enforce ADR conformance
- Documentation-vs-code verification that detects drift
- Initiative management with checkpoint/recovery across sessions
- A meta-skill ("Forge") that helps extend the system itself

## The Core Philosophy

### Specification-Driven Development

Code is a derived artifact. The specification is the source of truth.

This does NOT mean:
- Documenting every function (implementation details belong in code)
- Rigid locks that prevent all change (specs evolve)
- Bureaucratic overhead that slows you down

This DOES mean:
- Architecture decisions (ADRs) are documented before implementation
- Product requirements exist before code is written
- When code diverges from specs, you fix the spec first (go back to the right phase)
- AI agents read specs before coding and are constrained by them
- Documentation that is wrong produces broken implementations (forcing function)

### Governance, Not Bureaucracy

Documentation acts like zoning laws — you can build freely within the constraints, but the constraints control the direction of growth. Three levels of enforcement:

| Level | Mechanism | Enforcement |
|-------|-----------|-------------|
| **Soft** | CLAUDE.md rules, ADR index | Advisory — Claude reads them, may drift under context pressure |
| **Medium** | Skills that load ADRs before planning | Workflow-enforced — can't skip the step |
| **Hard** | Hooks (PreToolUse, Stop, TaskCompleted) | Deterministic — cannot be overridden by the AI |

### Change Classification

Not every change needs the same scrutiny:

- **Additive** (new feature within existing patterns) → flows freely
- **Compatible** (extends existing architecture) → lightweight review
- **Breaking** (violates existing ADRs/architecture) → must go back to Phase 2, update the ADR, then proceed

## The 4-Phase Pipeline

Each phase has a persona, produces specific artifacts, and locks its decisions for downstream phases.

### Phase 1: Product Design

- **Persona**: Head of Product (20 years experience)
- **Produces**: Product requirements, feature specs, user flows, success metrics
- **Location**: `documentation/product/features/{name}.md` + `documentation/initiatives/{name}.md`
- **Behavior**: Challenges scope, pushes for clarity, asks "why?", demands measurable outcomes
- **Lock**: Phase 1 decisions are LOCKED after user approval. Phases 2-4 cannot change product scope without going back here.

### Phase 2: Technical Architecture

- **Persona**: Software Architect (20 years experience)
- **Produces**: ADRs in `documentation/decisions/`, updates to `documentation/architecture/`
- **Behavior**: Evaluates technology choices, considers trade-offs, documents alternatives considered
- **Lock**: Phase 2 decisions are LOCKED after user approval. Phases 3-4 cannot change architecture without going back here.

### Phase 3: Implementation Planning

- **Persona**: Senior Engineering Manager / Tech Lead (15 years experience)
- **Produces**: Detailed task breakdown in initiative file with file paths, dependencies, verification criteria
- **Behavior**: Sizes tasks (min 20 min, grouped by shared context), identifies dependencies, defines acceptance criteria
- **Constraint**: Must respect Phase 1 and Phase 2 locked decisions as immutable constraints

### Phase 4: Development

- **Persona**: Senior Software Engineer / Tech Lead (12 years experience)
- **Produces**: Code that conforms to Phases 1-2
- **Behavior**: Reads all prior documentation before writing code. If Phase 1-2 decisions are broken, STOPS and escalates.
- **Execution modes**:
  - **Manual**: Interactive development via `/uc:develop` command
  - **Automated**: Agent team execution via `/uc:execute-initiative` command

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
- Researcher shares findings directly with Implementer (no parent relay)
- Validator challenges Implementer's work directly
- Multiple teammates self-claim from shared task list
- Plan approval workflow gates implementation

### Team Structure for Execute Initiative

```
Lead (main session — user interacts here)
├── Researcher teammate
│   - Gathers context from docs + code
│   - Dual perspective: Product + Technology
│   - Writes research to initiative/NAME/research/
│   - Sends findings to Implementer via SendMessage
│
├── Implementer teammate
│   - Reads research context
│   - Implements one task at a time
│   - Works in own files (no conflicts)
│   - Sends completion to Validator via SendMessage
│
├── Validator teammate
│   - Checks implementation against success criteria
│   - Read-only — cannot modify code
│   - Reports pass/fail to Lead
│   - If fail: sends specific feedback to Implementer
│
└── Full System Tester teammate (spawned as needed)
    - Runs test suite after changes
    - Reports results to Lead
```

### Team Structure for Debugging

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

### Team Structure for Docs vs Code Verification

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

- **No session resume for teammates**: If session breaks, teammates are lost. Mitigated by checkpoint skill saving state to initiative files.
- **One team per session**: Each workflow gets its own session.
- **No nested teams**: Teammates cannot spawn sub-teams. Mitigated by teammates using Task (subagent) for focused sub-tasks.
- **Cost**: Each teammate is ~200K tokens. We minimize by spawning only what's needed, shutting down when done.
- **Permissions**: All teammates inherit lead's permission mode. Pre-approve common operations in settings.

## Component Inventory

### Skills (Purple)

| Skill | Trigger | Invocation | Purpose |
|-------|---------|------------|---------|
| **product-design** | "product design", "phase 1", "start feature" | User | Phase 1: Product requirements and feature design |
| **tech-architecture** | "tech design", "architecture", "phase 2" | User | Phase 2: ADRs, architecture decisions |
| **implementation-planning** | "implementation planning", "phase 3" | User | Phase 3: Task breakdown with file paths and criteria |
| **development** | "start development", "phase 4" | User | Phase 4: Manual implementation against plan |
| **execute-initiative** | `/uc:execute` | User | Phase 4 (automated): Agent team orchestration |
| **verify-docs** | "verify docs", "check doc-code gaps" | User/Auto | Documentation-vs-code verification |
| **docs** | Activated by `.docs-format` file | Auto | Documentation structure management |
| **checkpoint** | `/uc:checkpoint` | User | Save context to initiative files for recovery |
| **forge** | "how to accomplish", "extend the system" | User | Meta-skill: understands full system, advises on extensions |
| **plan-mode-enhance** | Auto-loaded in planning skills | Auto (internal) | Configures plan mode to save plans in initiative directory |
| **discovery-mode** | "discovery mode", "research only" | User | Disables coding, focuses on research |

### Agents (Green)

| Agent | Model | Tools | Purpose |
|-------|-------|-------|---------|
| **researcher** | sonnet | Read, Grep, Glob, WebFetch, mcp__ref | Dual-perspective (Product + Tech) research with discrepancy detection |
| **task-implementer** | sonnet | Read, Write, Edit, Glob, Grep, Bash | Single-task implementation from research context |
| **task-validator** | sonnet | Read, Glob, Grep, Bash | Validates implementation against success criteria (read-only for code, can run tests) |
| **full-system-tester** | haiku | Read, Glob, Grep, Bash | Runs test suite, reports results. Deliberately "dumb" — refuses diagnostic requests |
| **debugging-planner** | sonnet | Read, Glob, Grep | Analyzes issues, proposes hypotheses, creates investigation tasks |
| **verify-checker** | sonnet | Read, Grep, Glob | Compares specific code against documentation for single topic |
| **verify-code-surveyor** | haiku | Read, Grep, Glob | Quick survey of code package structure |
| **verify-doc-surveyor** | haiku | Read, Grep, Glob | Quick survey of documentation section structure |
| **market-analyzer** | sonnet | WebSearch, WebFetch, mcp__ref | Market research, competitor analysis, technology trends |

### Commands (Slash Commands)

| Command | Purpose |
|---------|---------|
| `/uc:feature` | Start Phase 1 → 2 → 3 pipeline for a new feature |
| `/uc:execute` | Launch agent team to execute an initiative |
| `/uc:debug` | Start debugging workflow with agent team |
| `/uc:verify` | Run docs-vs-code verification |
| `/uc:discover` | Enter discovery mode (research only) |
| `/uc:checkpoint` | Save current progress for session recovery |
| `/uc:forge` | Ask the meta-skill how to accomplish something |
| `/uc:status` | Show initiative status, task progress |

### Hooks (Deterministic Enforcement)

| Hook Event | Purpose | Type |
|------------|---------|------|
| **PreToolUse (Write/Edit)** | Check if file changes align with active ADRs | prompt |
| **Stop** | Verify architectural changes have ADR coverage | prompt |
| **TaskCompleted** | Validate task meets documented success criteria | agent |
| **TeammateIdle** | Check if teammate completed all assigned work | prompt |
| **SessionStart** | Load initiative context if resuming | command |

### Documents (Yellow — Templates shipped with plugin)

| Template | Purpose | Created When |
|----------|---------|-------------|
| `_templates/architecture.md` | Architecture document template | Phase 2 |
| `_templates/decision.md` | ADR template (MADR format + AI constraints section) | Phase 2 |
| `_templates/requirement.md` | Formal requirement template (FR-xxx, NFR-xxx) | Phase 1 |
| `_templates/initiative.md` | Initiative tracking file | Phase 3 |
| `_templates/context.md` | External system documentation | As needed |
| `_templates/dependency.md` | Blocking questions/dependencies | As needed |
| `_templates/task.md` | Task template within initiative | Phase 3 |

### Configuration Files

| File | Purpose | Scope |
|------|---------|-------|
| `.docs-format` | Activates docs skill, sets output format (confluence/gitbook) | Project |
| `.claude/ultra-claude.local.md` | Plugin settings: active initiative, team config, feature flags | Project (gitignored) |
| `.claude/environments-info` | How to access dev/staging/prod environments | Project |
| `.claude/app-context-for-research.md` | Domain context for researcher agents | Project |
| `.claude/full-system-test.md` | Instructions for full system test agent | Project |

## Plugin Directory Structure

```
ultra-claude/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── commands/
│   ├── feature.md                     # /uc:feature
│   ├── execute.md                     # /uc:execute
│   ├── debug.md                       # /uc:debug
│   ├── verify.md                      # /uc:verify
│   ├── discover.md                    # /uc:discover
│   ├── checkpoint.md                  # /uc:checkpoint
│   ├── forge.md                       # /uc:forge
│   └── status.md                      # /uc:status
├── agents/
│   ├── researcher.md
│   ├── task-implementer.md
│   ├── task-validator.md
│   ├── full-system-tester.md
│   ├── debugging-planner.md
│   ├── verify-checker.md
│   ├── verify-code-surveyor.md
│   ├── verify-doc-surveyor.md
│   └── market-analyzer.md
├── skills/
│   ├── product-design/
│   │   └── SKILL.md
│   ├── tech-architecture/
│   │   └── SKILL.md
│   ├── implementation-planning/
│   │   └── SKILL.md
│   ├── development/
│   │   └── SKILL.md
│   ├── execute-initiative/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── orchestration-pattern.md
│   ├── verify-docs/
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
│   ├── plan-mode-enhance/
│   │   └── SKILL.md
│   └── discovery-mode/
│       └── SKILL.md
├── hooks/
│   ├── hooks.json                     # Hook configuration
│   └── scripts/
│       ├── check-adr-conformance.sh
│       ├── load-initiative-context.sh
│       └── validate-task-completion.sh
├── templates/                         # Documentation templates
│   ├── architecture.md
│   ├── decision.md
│   ├── requirement.md
│   ├── initiative.md
│   ├── context.md
│   ├── dependency.md
│   └── task.md
├── scripts/
│   └── init-docs.sh                   # Initialize documentation/ in a project
└── README.md
```

## Workflow: How It All Connects

### Starting a New Feature (Full Pipeline)

```
User: /uc:feature "Add user authentication"

1. PHASE 1 — Product Design skill activates
   → Claude (Head of Product persona) challenges scope
   → Creates documentation/product/features/user-auth.md
   → Creates documentation/initiatives/user-auth.md (stub)
   → User approves → Phase 1 LOCKED

2. PHASE 2 — Tech Architecture skill activates
   → Claude (Architect persona) evaluates approaches
   → Creates documentation/decisions/ADR-xxx-auth-strategy.md
   → Updates documentation/architecture/ as needed
   → User approves → Phase 2 LOCKED

3. PHASE 3 — Implementation Planning skill activates
   → Plan Mode Enhance configures plan output location
   → Claude (Engineering Manager persona) creates task breakdown
   → Tasks written to documentation/initiatives/user-auth.md
   → Each task has: file paths, dependencies, success criteria, estimated size
   → User reviews task list

4. PHASE 4 — User chooses execution mode:
   a) /uc:execute user-auth → Agent team (automated)
   b) Manual development → /development skill (interactive)
```

### Executing an Initiative (Agent Team)

```
User: /uc:execute user-auth

1. SETUP
   → Lead reads documentation/initiatives/user-auth.md
   → Lead creates agent team
   → Lead creates shared task list from initiative tasks
   → Lead spawns: Researcher + Implementer + Validator teammates

2. TASK LOOP (for each task in priority order)
   → Researcher claims task research
     - Reads relevant ADRs, architecture docs, existing code
     - Writes findings to initiatives/user-auth/research/task-N.md
     - Sends "research complete" to Implementer
   → Implementer claims task implementation
     - Reads research findings
     - Implements code conforming to Phase 1-2 specs
     - Sends "implementation complete" to Validator
   → Validator claims task validation
     - Checks code against success criteria
     - Runs relevant tests
     - If PASS: sends "validated" to Lead, task marked complete
     - If FAIL: sends specific feedback to Implementer, task re-queued

3. CHECKPOINT (every N tasks or on demand)
   → Lead saves progress to initiatives/user-auth/checkpoint.md
   → Includes: completed tasks, current state, remaining work
   → If session dies, /uc:execute user-auth resumes from checkpoint

4. COMPLETION
   → All tasks done
   → Lead spawns Full System Tester for final verification
   → Lead produces summary report
   → Team cleanup
```

### Discovery Mode

```
User: /uc:discover "Research how competitors handle rate limiting"

1. Discovery Mode skill activates
   → Coding is DISABLED (all Write/Edit tools blocked via hook)
   → Lead creates agent team with Researcher + Market Analyzer

2. Research teammates work in parallel
   → Researcher: Explores internal codebase, reads docs, uses Ref.tools
   → Market Analyzer: Web searches, competitor analysis

3. Findings compiled to documentation/research/{topic}.md
4. No code changes. Pure investigation output.
```

### Docs vs Code Verification

```
User: /uc:verify

1. Verify-docs skill activates
   → Lead creates agent team
   → Spawns Code Surveyor + Doc Surveyor teammates

2. Surveying phase (parallel)
   → Code Surveyors scan codebase structure, patterns, APIs
   → Doc Surveyors scan documentation claims, specs, ADRs

3. Checking phase
   → Lead creates comparison tasks from survey results
   → Spawns Checker teammates for each comparison topic
   → Each Checker: compares doc claim vs code reality

4. Report
   → Discrepancies listed with severity (HIGH/MEDIUM/LOW)
   → Suggestions for fixes (update doc or update code)
   → Lead presents to user
```

## The Forge Meta-Skill

Forge is unique — it has awareness of the ENTIRE Ultra Claude system. Its purpose:

1. **"How do I accomplish X with this system?"** — Advises which skills, agents, and workflows to use
2. **"Extend the system with Y capability"** — Guides creating new skills/agents that fit the architecture
3. **"What's the most efficient path?"** — Suggests workflow optimizations based on the task

Forge achieves this by having a comprehensive system-overview.md reference that describes all components, their relationships, and usage patterns.

## Migration Plan

### What Moves Into the Plugin

| Current Location | Component | Destination |
|-----------------|-----------|-------------|
| `~/.claude/skills/product-design/` | Product Design skill | `ultra-claude/skills/product-design/` |
| `~/.claude/skills/tech-architecture/` | Tech Architecture skill | `ultra-claude/skills/tech-architecture/` |
| `~/.claude/skills/implementation-planning/` | Implementation Planning skill | `ultra-claude/skills/implementation-planning/` |
| `~/.claude/skills/development/` | Development skill | `ultra-claude/skills/development/` |
| `~/.claude/skills/execute-initiative/` | Execute Initiative skill | `ultra-claude/skills/execute-initiative/` |
| `~/.claude/skills/verify-docs/` | Verify Docs skill | `ultra-claude/skills/verify-docs/` |
| `~/.claude/skills/docs/` | Docs skill | `ultra-claude/skills/docs/` |
| `~/.claude/skills/checkpoint/` | Checkpoint skill | `ultra-claude/skills/checkpoint/` |
| `~/.claude/skills/skill-agent-creator/` | Skill/Agent Creator | `ultra-claude/skills/forge/` (evolved into Forge) |
| `~/.claude/agents/verify-checker.md` | Verify Checker agent | `ultra-claude/agents/verify-checker.md` |
| `~/.claude/agents/verify-code-surveyor.md` | Code Surveyor agent | `ultra-claude/agents/verify-code-surveyor.md` |
| `~/.claude/agents/verify-doc-surveyor.md` | Doc Surveyor agent | `ultra-claude/agents/verify-doc-surveyor.md` |

### What Stays Global (NOT in plugin)

| Component | Why |
|-----------|-----|
| `tech-research` | Generic utility, used everywhere, depends on Ref.tools MCP |
| `ha-nodered-knowledge` | Domain-specific, unrelated to development pipeline |
| `prompt-architect` | Generic utility, useful outside Ultra Claude |
| `rebuild-old-website` | One-off project skill |
| `image-content-extractor` | Generic utility agent |

### What's NEW (doesn't exist yet)

| Component | Type | Purpose |
|-----------|------|---------|
| Forge skill | Skill | Meta-skill with full system awareness |
| Plan Mode Enhance skill | Skill | Redirects plan output to initiative directory |
| Discovery Mode skill | Skill | Disables coding, enables research-only workflow |
| Market Analyzer agent | Agent | Web/market research via Perplexity |
| Debugging Planner agent | Agent | Hypothesis-driven debugging coordination |
| Full System Tester agent | Agent | Test suite execution (deliberately simple) |
| All hooks | Hooks | ADR conformance, task validation, initiative context loading |
| All commands | Commands | `/uc:*` namespace |
| All templates | Templates | Documentation scaffolding |
| Plugin manifest | Config | plugin.json |
| Init script | Script | Sets up documentation/ in a new project |

## Key Assumptions

1. **Agent teams will stabilize**. We're building on an experimental feature. If it breaks, we fall back to subagents (the execute-initiative skill already works this way in AXB_Datalake).

2. **One plugin per project**. Ultra Claude is designed to be the primary development methodology plugin. It doesn't compete with other orchestration plugins.

3. **Documentation structure is consistent**. Every project using Ultra Claude follows the same `documentation/` layout. This is non-negotiable — it's how specs govern code.

4. **CLAUDE.md is the entry point**. The plugin augments but does not replace project CLAUDE.md. Project-specific rules live in CLAUDE.md; Ultra Claude provides the framework.

5. **Phase locking is soft, not rigid**. "Locked" means "going back requires explicit user decision to re-enter that phase." It's governance, not a technical lock.

6. **Token cost is acceptable**. Agent teams are expensive (~200K tokens per teammate). The user has accepted this trade-off for the coordination benefits.

7. **The plugin is personal**. This is built for one developer's workflow. It may be shared later, but the primary user is the author.

8. **Hooks are the enforcement layer**. CLAUDE.md rules can be forgotten under context pressure. Hooks cannot be overridden. Critical governance rules go in hooks.

9. **Ref.tools (tech-research) stays external**. It's a global skill with its own MCP server. Ultra Claude skills can reference it but don't own it.

10. **The init script handles project setup**. When Ultra Claude is installed in a new project, `init-docs.sh` creates the `documentation/` directory structure with templates. The user then fills in project-specific content.

## Open Questions (To Resolve Before Implementation)

1. **Command prefix**: Is `/uc:` the right namespace? Alternatives: `/ultra:`, `/forge:`, no prefix (just `/execute`, `/verify`, etc.)?

2. **Team persistence**: When an initiative spans multiple sessions, how do we handle team recreation? Current plan: checkpoint everything to files, recreate team on resume.

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
