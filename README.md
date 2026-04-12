# Ultra Claude

A Claude Code plugin that implements spec-driven development. Documentation governs code growth. Agent teams coordinate execution.

[**Documentation**](https://ultra-claude.dev)

## What This Is

Ultra Claude is a portable, reusable Claude Code plugin that turns any project into a structured, specification-driven development environment. You install it, it establishes a documentation layer, and from that point forward — documentation controls how the codebase grows.

It is NOT a framework, library, or runtime. It is a collection of **skills** and **agents** packaged as a Claude Code plugin. When installed in a project, Claude Code gains:

- Four specialized planning modes (Feature, Debug, Verification, Discovery) + one execution engine
- Agent teams that coordinate research, implementation, and validation in parallel
- Documentation-vs-code verification that detects drift
- Technology standards enforcement (define → enforce → verify loop)
- Plan management with checkpoint/recovery across sessions
- A meta-skill ("Help") that teaches how to use the system

## Core Philosophy

- **Code is a derived artifact.** The specification is the source of truth. Architecture docs exist before code is written, and when code diverges from specs, you fix the spec first.
- **Governance, not bureaucracy.** Documentation acts like zoning laws — you build freely within the constraints, but the constraints control direction.
- **Proportional scrutiny.** Additive changes flow freely. Compatible changes get lightweight review. Breaking changes require updating the architecture doc first.

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
/uc:migrate
```

Use `/uc:help` to see all available commands.

## Plugin Directory Structure

> Skills with `user-invocable: true` become slash commands, namespaced as `/uc:{skill-name}` (e.g., `/uc:feature-mode`). The `uc` prefix comes from the `name` field in `.claude-plugin/plugin.json`.

```
ultra-claude/
├── .claude-plugin/
│   ├── plugin.json                    # Plugin manifest (name, version, paths)
│   └── marketplace.json               # Marketplace metadata
├── settings.json                      # Plugin settings (agent teams flag)
├── agents/                            # Agent definitions (flat .md with YAML frontmatter)
│   ├── checker.md
│   ├── code-review.md
│   ├── code-surveyor.md
│   ├── doc-surveyor.md
│   ├── market-analyzer.md
│   ├── project-manager.md
│   ├── system-tester.md
│   ├── task-executor.md
│   ├── task-tester.md
│   └── tech-knowledge.md
├── skills/                            # Skills (SKILL.md with YAML frontmatter)
│   ├── backlog/
│   ├── checkpoint/
│   ├── context-management/
│   ├── critical-brainstorm/
│   ├── debug-mode/
│   ├── discovery-mode/
│   ├── doc-code-verification-mode/
│   ├── docs-manager/
│   ├── feature-mode/
│   ├── help/
│   ├── migrate/
│   ├── plan-execution/
│   ├── plan-status-sync/
│   ├── railway/
│   ├── roadmap/
│   ├── setup/
│   ├── tailscale-setup/
│   ├── tech-research/
│   ├── update/
│   ├── vscode-launch/
│   └── vscode-setup/
├── references/                        # Shared reference libraries (not skills)
│   ├── plan-status-format.md          # plan.json schema
│   └── planning-framework/            # 4-stage planning rules inherited by feature/debug/verification modes
│       ├── framework.md
│       └── stage-{1,2,3,4}.md
├── templates/                         # Documentation templates for target projects
│   ├── plan.md
│   ├── task.md
│   └── context.md
├── scripts/                           # Runtime scripts
│   ├── tmux-layout-daemon.js
│   ├── statusline.sh
│   └── lib.sh
├── docs/                              # Documentation website (Express + EJS)
└── README.md
```

## Documentation

Detailed documentation is available at [ultra-claude.dev](https://ultra-claude.dev):

| Page | Purpose |
|------|---------|
| [Getting Started](https://ultra-claude.dev/getting-started) | Install, setup, and first feature in 10 minutes |
| [Discovery](https://ultra-claude.dev/docs/discovery) | Product research and market analysis |
| [Feature Planning](https://ultra-claude.dev/docs/feature-planning) | Scope challenge, research, structured plans |
| [Plan Execution](https://ultra-claude.dev/docs/plan-execution) | Agent teams, task pipeline, checkpoints |
| [Debugging](https://ultra-claude.dev/docs/debugging) | Hypothesis-driven bug investigation |
| [Verification](https://ultra-claude.dev/docs/verification) | Doc-code drift detection and fixes |
| [Technology Standards](https://ultra-claude.dev/docs/standards) | Define, enforce, and verify coding standards |
| [Reference](https://ultra-claude.dev/docs/reference) | All 22 skills and 10 agents |
