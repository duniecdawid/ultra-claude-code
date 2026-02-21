# Migration Plan

> **Temporary document.** Delete after migration from global skills to the plugin is complete.

## What Moves Into the Plugin

Old global skills are refactored into the new plugin structure. The mapping is not 1:1 — old phase-based skills are consolidated into planning modes.

| Old Global Skill | Becomes | Destination |
|-----------------|---------|-------------|
| `product-design` + `tech-architecture` + `implementation-planning` | Feature Mode | `skills/feature-mode/SKILL.md` |
| `development` + `execute-initiative` | Plan Execution | `skills/plan-execution/SKILL.md` |
| `verify-docs` | Doc & Code Verification Mode | `skills/doc-code-verification-mode/SKILL.md` |
| `docs` | Docs Manager | `skills/docs-manager/SKILL.md` |
| `checkpoint` | Checkpoint | `skills/checkpoint/SKILL.md` |
| `skill-agent-creator` | Help (evolved) | `skills/help/SKILL.md` |
| `tech-research` | Tech Research | `skills/tech-research/SKILL.md` |
| `verify-checker` | Checker agent | `agents/checker.md` |
| `verify-code-surveyor` | Code Surveyor agent | `agents/code-surveyor.md` |
| `verify-doc-surveyor` | Doc Surveyor agent | `agents/doc-surveyor.md` |

> **Note:** Each migrated skill needs proper YAML frontmatter in its `SKILL.md` (name, description, user-invocable, etc.). See [Components — Skill File Format](components.md#skill-file-format) for the full field reference.

## What Stays Global (NOT in Plugin)

| Component | Why |
|-----------|-----|
| `ha-nodered-knowledge` | Domain-specific, unrelated to development pipeline |
| `prompt-architect` | Generic utility, useful outside Ultra Claude |
| `skill-agent-creator` | Generic utility, useful outside Ultra Claude |
| `rebuild-old-website` | One-off project skill |
| `image-content-extractor` | Generic utility agent |

## Global Skills Archived After Migration

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
| `verify-checker` (→ checker) | `~/.claude/agents/verify-checker.md` |
| `verify-code-surveyor` (→ code-surveyor) | `~/.claude/agents/verify-code-surveyor.md` |
| `verify-doc-surveyor` (→ doc-surveyor) | `~/.claude/agents/verify-doc-surveyor.md` |

## What's New

Components that don't exist yet and need to be built from scratch.

| Component | Type | Purpose |
|-----------|------|---------|
| Feature Mode skill | Skill | Consolidates old product-design, tech-architecture, implementation-planning |
| Debug Mode skill | Skill | Issue investigation and fix planning |
| Plan Enhancer skill | Skill | Standardizes all plan output: plan directory, README.md with embedded task list, task granularity |
| Plan Execution skill | Skill | Single execution engine for all plans (consolidates old development + execute-initiative) |
| Help skill | Skill | Meta-skill with full system awareness |
| Discovery Mode skill | Skill | Disables coding, enables research-only workflow |
| Context Management skill | Skill | Manages top-level context/ — external system docs, code, git submodules |
| Docs Migration skill | Skill | One-time onboarding: surveys existing project, maps docs to canonical structure, produces migration plan |
| Task Executor agent | Agent | Single-task implementation from research context |
| Task Tester agent | Agent | Runs tests, checks success criteria pass/fail |
| Code Review agent | Agent | Static analysis: code quality, compliance, duplication prevention |
| System Tester agent | Agent | Full test suite execution (deliberately simple) |
| Market Analyzer agent | Agent | Web/market research via Perplexity |
| RFC review personas | Config | Built-in: Devil's Advocate, Pragmatist, Security/Reliability, Cost-conscious. User-extensible. |
| All hooks | Hooks | Architecture conformance, task validation, plan context loading |
| All templates | Templates | Documentation scaffolding |
| Plugin manifest | Config | plugin.json |
| Init script | Script | Sets up documentation/ in a new project |
