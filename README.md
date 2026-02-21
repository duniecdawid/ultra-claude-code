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

## Core Philosophy

- **Code is a derived artifact.** The specification is the source of truth. Architecture docs exist before code is written, and when code diverges from specs, you fix the spec first.
- **Governance, not bureaucracy.** Documentation acts like zoning laws — you build freely within the constraints, but the constraints control direction. Three enforcement levels: soft (CLAUDE.md), medium (skills), hard (hooks).
- **Not every change needs the same scrutiny.** Additive changes flow freely. Compatible changes get lightweight review. Breaking changes require updating the architecture doc first.

## Quick Start

> **TODO**: Installation and first-use instructions will be added when the plugin implementation begins.

## Plugin Directory Structure

```
ultra-claude/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest
├── commands/                          # /uc:* slash commands
│   ├── feature.md
│   ├── debug.md
│   ├── verify.md
│   ├── execute.md
│   ├── discover.md
│   ├── checkpoint.md
│   ├── forge.md
│   └── status.md
├── agents/                            # Agent definitions
│   ├── researcher.md
│   ├── task-executor.md
│   ├── task-tester.md
│   ├── code-review.md
│   ├── system-tester.md
│   ├── checker.md
│   ├── code-surveyor.md
│   ├── doc-surveyor.md
│   └── market-analyzer.md
├── skills/                            # Skills (extend main context)
│   ├── feature-plan-mode/
│   ├── debug-mode/
│   ├── doc-code-verification-mode/
│   ├── plan-enhancer/
│   ├── execute-plan/
│   ├── discovery-mode/
│   ├── docs-manager/
│   ├── checkpoint/
│   ├── forge/
│   └── tech-research/
├── hooks/                             # Deterministic enforcement
│   ├── hooks.json
│   └── scripts/
├── templates/                         # Documentation templates for target projects
├── scripts/
│   └── init-docs.sh                   # Initialize documentation/ in a new project
├── docs/                              # Plugin documentation (this project)
├── assets/                            # Diagrams, images
└── README.md
```

## Documentation

| Document | Purpose |
|----------|---------|
| [Architecture](docs/architecture.md) | System design: philosophy, layers, modes, governance, agent teams |
| [Components](docs/components.md) | Reference tables: skills, agents, commands, hooks, templates, config |
| [Workflows](docs/workflows.md) | Step-by-step flows for each mode |
| [Decisions](docs/decisions.md) | Architectural decisions + open questions |
| [Migration](docs/migration.md) | Old → new skill mapping *(temporary)* |
| [Research](docs/research.md) | Evaluated solutions, methodology references |
