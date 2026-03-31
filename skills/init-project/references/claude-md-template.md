# CLAUDE.md Ultra Claude Section

Inject this section into the project's root `CLAUDE.md`. If the project has no `CLAUDE.md`, create one. If it already exists, append this section at the end. Never overwrite existing project-specific content.

## Template

```markdown
## Ultra Claude

This project uses [Ultra Claude](https://github.com/duniecdawid/ultra-claude-code), a Claude Code plugin for spec-driven development.

### Bootstrap — MANDATORY

At the start of every conversation, invoke these skills (via the Skill tool) before doing any work:

1. `/uc:help` — Understand Ultra Claude's skills, agents, and workflows
2. `/uc:docs-manager` — Understand the documentation structure and routing rules

Do not skip this step. Do not copy skill content into this file — always load them live.

### Conventions

- **Documentation governs code.** Architecture docs are the source of truth. When code diverges from specs, update the spec first.
- **Canonical documentation** lives in `documentation/` — do not create docs outside this structure.
- **Plans** are stored in `documentation/plans/{NNN}-{name}/` with sequential numbering and embedded task lists.
- **External system context** (API docs, SDK references) goes in `context/`.
- **Project configuration** for Claude is in `.claude/` (app-context, environments-info). Testing config lives in `documentation/technology/testing/`.

### Key Commands

| Command | Purpose |
|---------|---------|
| `/uc:help` | Guide to all skills and workflows |
| `/uc:feature-mode` | Plan new features with architecture context |
| `/uc:debug-mode` | Investigate bugs with parallel research |
| `/uc:doc-code-verification-mode` | Verify documentation matches code |
| `/uc:discovery-mode` | Product research and requirements |
| `/uc:plan-execution` | Execute approved plans with agent teams |
| `/uc:tech-research` | Research external library docs via Ref.tools |

### Workflow

1. **Plan first** — Use feature-mode or debug-mode before writing code
2. **Spec-first for breaking changes** — Update architecture docs before modifying code
3. **Verify after changes** — Run doc-code-verification to catch drift
```

## Adaptation Rules

Adapt the section content based on survey findings:
- If the project has specific technologies, mention relevant tech-research triggers
- If external integrations were found, mention the context/ directory for those specific systems
- Keep the core structure above, but tailor examples to the project
