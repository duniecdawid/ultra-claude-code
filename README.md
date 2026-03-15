# Ultra Claude

A Claude Code plugin that implements a spec-driven development platform. Documentation governs code growth. Agent teams coordinate execution.

[**Documentation**](https://duniecdawid.github.io/ultra-claude-code/index.html)

## What This Is

Ultra Claude is a portable, reusable Claude Code plugin that turns any project into a structured, specification-driven development environment. You install it, it establishes a documentation layer, and from that point forward — documentation controls how the codebase grows.

It is NOT a framework, library, or runtime. It is a collection of **skills** and **agents** packaged as a Claude Code plugin. When installed in a project, Claude Code gains:

- Three specialized planning modes (Feature, Debugging, Verification) + one execution engine
- Agent teams that coordinate research, implementation, and validation in parallel
- Documentation-vs-code verification that detects drift
- Plan management with checkpoint/recovery across sessions
- A meta-skill ("Help") that teaches how to use the system

## Core Philosophy

- **Code is a derived artifact.** The specification is the source of truth. Architecture docs exist before code is written, and when code diverges from specs, you fix the spec first.
- **Governance, not bureaucracy.** Documentation acts like zoning laws — you build freely within the constraints, but the constraints control direction. Two enforcement levels: soft (CLAUDE.md) and medium (skills).
- **Not every change needs the same scrutiny.** Additive changes flow freely. Compatible changes get lightweight review. Breaking changes require updating the architecture doc first.

## Installation

```bash
# Add the marketplace
/plugin marketplace add duniecdawid/ultra-claude-code

# Install the plugin
/plugin install uc@ultra-claude
```

After installing, run setup to configure your machine (one-time):

```
/uc:setup
```

Then initialize your target project:

```
/uc:init-project
```

Use `/uc:help` to see all available commands.

## Plugin Directory Structure

> Skills with `user-invocable: true` become slash commands, namespaced as `/uc:{skill-name}` (e.g., `/uc:feature-mode`). The `uc` prefix comes from the `name` field in `.claude-plugin/plugin.json`.

```
ultra-claude/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest (name, version, paths)
├── settings.json                      # Plugin settings (agent teams flag)
├── agents/                            # Agent definitions (flat .md with YAML frontmatter)
│   ├── tech-knowledge.md
│   ├── task-executor.md
│   ├── task-tester.md
│   ├── code-review.md
│   ├── system-tester.md
│   ├── checker.md
│   ├── code-surveyor.md
│   ├── doc-surveyor.md
│   └── market-analyzer.md
├── skills/                            # Skills (SKILL.md with YAML frontmatter)
│   ├── feature-mode/
│   │   └── SKILL.md
│   ├── debug-mode/
│   │   └── SKILL.md
│   ├── doc-code-verification-mode/
│   │   └── SKILL.md
│   ├── plan-enhancer/
│   │   └── SKILL.md
│   ├── plan-execution/
│   │   └── SKILL.md
│   ├── discovery-mode/
│   │   └── SKILL.md
│   ├── docs-manager/
│   │   └── SKILL.md
│   ├── context-management/
│   │   └── SKILL.md
│   ├── init-project/
│   │   └── SKILL.md
│   ├── checkpoint/
│   │   └── SKILL.md
│   ├── help/
│   │   └── SKILL.md
│   ├── setup/
│   │   └── SKILL.md
│   └── tech-research/
│       └── SKILL.md
├── templates/                         # Documentation templates for target projects
├── docs/                              # Plugin documentation (this project)
└── README.md
```

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.html) | System design: philosophy, layers, modes, governance, agent teams |
| [Execution](docs/execution.html) | Execution engine: agent teams, task lists, shared memory, lifecycle |
| [Components](docs/components.html) | Reference tables: skills, agents, templates, config |
| [Workflows](docs/workflows.html) | Step-by-step flows for each mode |
| [Decisions](docs/decisions.html) | Architectural decisions + open questions |
| [Migration](docs/migration.html) | Old → new skill mapping *(temporary)* |
| [Research](docs/research.html) | Evaluated solutions, methodology references |
