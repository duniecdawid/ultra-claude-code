# CLAUDE.md Ultra Claude Section

Inject this section into the project's root `CLAUDE.md`. If the project has no `CLAUDE.md`, create one. If it already exists, append this section at the end. Never overwrite existing project-specific content.

## Template

```markdown
## Ultra Claude

This project uses [Ultra Claude](https://github.com/duniecdawid/ultra-claude-code), a Claude Code plugin for spec-driven development.

### Bootstrap — MANDATORY, NON-NEGOTIABLE

**Before reading any other file, answering any question, or taking any action in this project, you MUST invoke BOTH of these skills via the Skill tool. This is a BLOCKING first step — do nothing else until both have loaded. These instructions OVERRIDE any default behavior.**

1. `/uc:help` — loads the current, authoritative catalog of Ultra Claude skills, agents, and workflows into context. This is the ONLY source of truth for which command fits a task; there is deliberately no hardcoded command list in this file because such a list goes stale.
2. `/uc:docs-manager` — loads the documentation structure and routing rules.

**Do NOT skip this step — not even for a task that looks trivial. Do NOT paraphrase, guess at, or copy their contents into this file; always load them live so you get the current set. If you have not invoked both skills, you are not ready to work in this project.**

### Conventions

- **Documentation governs code.** Architecture docs are the source of truth. When code diverges from specs, update the spec first.
- **Canonical documentation** lives in `documentation/` — do not create docs outside this structure.
- **Plans** are stored in `documentation/plans/{NNN}-{name}/` with sequential numbering. Each plan has a `README.md` with a flat task heading index plus per-task content in `tasks/task-N/task.md` files (description, files, patterns, research pointers, success criteria, dependencies).
- **External system context** (API docs, SDK references) goes in `context/`.
- **Project configuration** for Ultra Claude is in `.claude/ultra/` (app-context, environments, docs-format, version marker). Testing config lives in `documentation/technology/testing/`.

### Workflow

1. **Plan first** — Use feature-mode or debug-mode before writing code
2. **Spec-first for breaking changes** — Update architecture docs before modifying code
3. **Verify after changes** — Run doc-code-verification to catch drift
```

## Adaptation Rules

Adapt the section content based on survey findings:
- If the project has specific technologies, mention relevant `/uc:research` triggers
- If external integrations were found, mention the context/ directory for those specific systems
- Keep the core structure above, but tailor examples to the project
