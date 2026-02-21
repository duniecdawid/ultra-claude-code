# Architecture

Ultra Claude enhances Claude Code with specification-driven development. This document describes the system design: philosophy, layers, agent coordination, and governance.

## Specification-Driven Development

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

## Governance Model

Documentation acts like zoning laws — you can build freely within the constraints, but the constraints control the direction of growth. Three levels of enforcement:

| Level | Mechanism | Enforcement |
|-------|-----------|-------------|
| **Soft** | CLAUDE.md rules, architecture docs | Advisory — Claude reads them, may drift under context pressure |
| **Medium** | Skills that load architecture docs before planning | Workflow-enforced — can't skip the step |
| **Hard** | Hooks (PreToolUse, PostToolUse, Stop) | Deterministic — cannot be overridden by the AI |

## Change Classification

Not every change needs the same scrutiny:

- **Additive** (new feature within existing patterns) → flows freely
- **Compatible** (extends existing architecture) → lightweight review
- **Breaking** (violates existing architecture) → must update the architecture doc first, then re-plan

## Documentation Structure

Every project using Ultra Claude follows this canonical layout. The structure is non-negotiable — it's how specs govern code.

```
project/
├── documentation/
│   ├── technology/
│   │   ├── architecture/          # System design, components, data flow, tech stack
│   │   ├── standards/             # Coding conventions, patterns, quality bars, security rules
│   │   └── rfcs/                  # Structured reviews for ambiguous/high-risk decisions
│   ├── product/
│   │   ├── description/           # Vision, discovery outputs, market research
│   │   └── requirements/          # Formal requirements (FR-xxx, NFR-xxx)
│   ├── plans/
│   │   └── {feature-name}/
│   │       ├── README.md          # Plan document (includes task list)
│   │       ├── shared/            # Per-role shared memory (execution)
│   │       └── research/          # Researcher findings per task
│   └── dependencies/              # Blocking questions, external dependencies
│
├── context/                       # External systems — integration knowledge
│   └── {system-name}/
│       ├── docs/                  # API docs, specs, guides, protocols
│       └── code/                  # Git submodules, SDKs, code samples
│
└── src/                           # The derived artifact — governed by specs
```

### Docs Manager as Guardian

The **docs-manager** skill (activated by `.claude/docs-format` in the project) guards this structure:

- **Routing**: When any mode or agent creates documentation, docs-manager ensures it lands in the correct directory. Architecture decisions go to `technology/architecture/`, not floating in the root. Discovery outputs go to `product/description/`, not a random location.
- **Structure enforcement**: Docs-manager knows the canonical layout and rejects writes that violate it. If an agent tries to create `documentation/auth-notes.md` (wrong — no top-level files), docs-manager routes it to the correct subdirectory.
- **Initialization**: On first use (`init-docs.sh`), the full directory tree is scaffolded with README placeholders so the structure is visible from day one.
- **Format awareness**: The `.claude/docs-format` file tells docs-manager the output format (Confluence, GitBook, plain Markdown). Docs-manager ensures all generated documentation conforms to the chosen format.
- **Index generation**: Docs-manager generates and maintains `documentation/README.md` — a navigable index of the entire documentation tree. The README lists every section with descriptions and links, so a newcomer (human or agent) can orient themselves instantly. The index is regenerated automatically whenever documentation is added or restructured.

### What Goes Where

| Content | Directory | Created By |
|---------|-----------|------------|
| System design, component diagrams, data flow | `technology/architecture/` | Feature Plan Mode |
| Coding conventions, API standards, error handling patterns | `technology/standards/` | Manual or Feature Plan Mode |
| Decision reviews (problem, options, outcome) | `technology/rfcs/` | Feature Plan Mode (optional) |
| Product vision, competitor analysis, market research | `product/description/` | Discovery Mode |
| Formal requirements (FR-xxx, NFR-xxx) | `product/requirements/` | Feature Plan Mode |
| Plans, task lists, research per initiative | `plans/{name}/` | All planning modes via Plan Enhancer |
| Blocking questions, external dependencies | `dependencies/` | Manual / as needed |

### Context Directory (Top-Level)

`context/` lives at the project root, **not** inside `documentation/`. It contains integration knowledge about external systems — both documentation and code. Each external system gets its own subdirectory:

```
context/
├── stripe/
│   ├── docs/                      # API reference, webhook specs, migration guides
│   └── code/                      # Git submodule → stripe SDK or example repo
├── auth0/
│   ├── docs/                      # OIDC flows, tenant config, rule patterns
│   └── code/                      # Git submodule → auth0 samples
└── internal-api/
    ├── docs/                      # OpenAPI spec, data model, rate limits
    └── code/                      # Git submodule → shared proto definitions
```

**Why top-level?** Context is not specification — it's reference material about the outside world. It can contain code (git submodules, SDKs) which doesn't belong inside `documentation/`. Agents read context during research; it informs the spec but is not the spec.

### Context Manager Skill

The **context-manager** skill manages the `context/` directory:

- **Structuring**: Creates `{system-name}/docs/` and `{system-name}/code/` directories for each external system. Ensures consistent layout across all context entries.
- **Aggregation**: Collects and organizes information from multiple sources (API docs, specs, code samples) into the appropriate context subdirectory. Deduplicates and keeps context current.
- **Git submodules**: Manages git submodules in `code/` directories — adding, updating, and tracking external code dependencies that agents need for integration work.
- **Agent-ready summaries**: Maintains a `context/README.md` index so agents (especially Researcher) can quickly discover what external system knowledge is available before diving into files.

### Migrate Docs Skill

The **migrate-docs** skill (`/uc:migrate`) is a one-time onboarding tool for projects that already have documentation in a non-standard layout. It uses surveyor agents to understand what exists and produces a migration plan.

**How it works:**

1. **Survey** — Spawns Code Surveyor and Doc Surveyor agents in parallel to scan the entire project:
   - Doc Surveyors inventory all existing documentation: READMEs, wikis, markdown files, API docs, ADRs, specs — wherever they live
   - Code Surveyors scan for inline documentation patterns, doc comments, and code-adjacent docs
2. **Map** — Classifies each discovered document against the canonical structure:
   - "This looks like architecture" → `documentation/technology/architecture/`
   - "This is an API spec for Stripe" → `context/stripe/docs/`
   - "This is a product requirement" → `documentation/product/requirements/`
   - "Unknown / doesn't fit" → flagged for user decision
3. **Plan** — Produces a migration plan (via Plan Enhancer) with tasks to:
   - Move files to their canonical locations
   - Merge duplicates or conflicting docs
   - Create missing structure (directories that don't exist yet)
   - Flag documents that need manual review
4. **Execute** — The plan can be run via `/uc:execute` like any other plan

**When to use:** Only when onboarding an existing project to Ultra Claude. Not needed for greenfield projects (those use `init-docs.sh`).

## Two Layers: Planning and Execution

Instead of a rigid multi-phase pipeline, there are **three specialized planning modes** that each optimize plan mode for a specific use case, and **one execution engine** that runs any plan.

### Planning Layer

All planning modes trigger Claude Code's plan mode automatically, enhanced by **Plan Enhancer** — a shared skill that:
- Redirects the plan from Claude's default location to a plan directory
- Generates the plan as `README.md` (or configured main page name) with the task list embedded — Claude recognizes this as a single coherent plan
- Ensures task granularity is right for agentic execution
- Standardizes the output structure so all plans look the same regardless of entry point

#### Feature Plan Mode

For new features. Uses Researcher + Docs Manager to gather context about the codebase, existing architecture, and product requirements before planning.

- Challenges scope, pushes for clarity, asks "why?"
- Considers product requirements, architecture, and implementation in one pass
- When architecture decisions are ambiguous or high-risk, suggests **RFC mode** for structured review (AI personas: Devil's Advocate, Pragmatist, Security/Reliability, Cost-conscious — and/or human reviewers)
- Produces a plan in `documentation/plans/{name}/`
- Architecture decisions go to `documentation/technology/architecture/`
- If RFC mode is triggered, RFC goes to `documentation/technology/rfcs/`

#### Debug Mode

For fixing things. The mode skill itself handles planning — it analyzes the issue, proposes hypotheses, and spawns Researcher + System Tester to investigate.

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

Discovery feeds into planning but does not produce a plan itself. Output goes to `documentation/product/description/{topic}.md`.

### Execution Layer

The execution engine is documented in detail in [Execution](execution.md).

In summary: Execute Plan reads any plan README.md and runs it through a dynamically composed agent team. The Lead creates four role-separated task lists (research -> implementation -> review -> testing), spawns teammates with role-specific prompts that bridge the context gap, and coordinates via per-role shared files. Teammates self-claim tasks from their role's list and work in parallel.

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
- Task Tester challenges Task Executor's work directly
- Multiple teammates self-claim from shared task list
- Plan approval workflow gates implementation

### Team Structures

See [Workflows](workflows.md) for how these teams operate end-to-end.

#### Execute Plan Team

Lead + up to 5 teammates across 4 roles: Researcher, Executor, Code Reviewer, Tester.
Tasks flow through role-separated lists: research -> implementation -> review -> testing.
Teammates self-claim work and coordinate via per-role shared files.

See [Execution](execution.md) for full team structure, context bridge, shared memory, checkpoints, and error recovery.

#### Debug Mode Team

```
Lead (main session — Debug Mode skill handles planning)
├── Researcher teammate(s)
│   - Each investigates a different hypothesis in parallel
│   - Sends evidence to Lead
│
└── System Tester teammate
    - Reproduces the bug
    - Validates the fix
```

#### Doc & Code Verification Team

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

#### Discovery Mode Team

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

## The Help Meta-Skill

Help is unique — it has awareness of the ENTIRE Ultra Claude system. Its purpose:

1. **"How do I accomplish X with this system?"** — Advises which skills, agents, and workflows to use
2. **"Extend the system with Y capability"** — Guides creating new skills/agents that fit the architecture
3. **"What's the most efficient path?"** — Suggests workflow optimizations based on the task

Help achieves this by having a comprehensive system-overview.md reference that describes all components, their relationships, and usage patterns.
