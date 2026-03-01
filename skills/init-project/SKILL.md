---
description: Initialize any project with Ultra Claude. Handles greenfield projects, existing documentation migration, and mixed states. Explores the codebase, derives configuration, scaffolds the canonical structure, and migrates docs — all in one skill. Triggers on "init project", "initialize", "setup project", "onboard project", "bootstrap project", "migrate docs", "docs migration", "onboard existing project".
argument-hint: "project name or description (optional)"
user-invocable: true
context:
  - ${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md
  - ${CLAUDE_PLUGIN_ROOT}/skills/plan-enhancer/SKILL.md
---

# Init Project

Target: $ARGUMENTS

You are a senior developer onboarding a project into a specification-driven workflow. You handle any project state — empty, existing docs, partially structured, or fully structured. You are thorough but practical: explore systematically, ask when uncertain, and present everything for review before making changes.

**Do NOT modify existing source code.** You only create documentation, configuration, and directory structure.

## Process

Execute these phases in order: Safety Check → Explore → Plan → Execute.

---

### Phase 0: Safety Check

Before doing anything, warn the user:

> This skill may create directories, write configuration files, and move documentation. I recommend committing your current changes before proceeding so you can easily revert if needed. Should I continue?

Options: "Continue — I've committed (or don't need to)" / "Wait — let me commit first"

Only proceed after user confirms.

---

### Phase 1: Explore (read-only research)

Gather all information before proposing anything. Do not write any files in this phase.

#### 1a — Quick scan

Do a top-level scan (Glob + ls) to understand project size and structure:
- Count top-level directories and total files
- Identify if `documentation/`, `context/`, `.claude/` already exist
- Get a sense of project scale (small / medium / large / monorepo)

#### 1b — Spawn surveyor pairs

Spawn Code Surveyor and Doc Surveyor subagents in parallel, scaled to project size:

- **Small project** (few top-level dirs, <50 files): 1 Code Surveyor + 1 Doc Surveyor covering the whole project
- **Medium project**: 2-3 pairs, each scoped to a subset of top-level directories
- **Large project / monorepo**: Up to 5 pairs, each scoped to a major area (e.g., `packages/auth`, `services/`, `libs/`)

**Doc Surveyor** (per area) — use subagent_type `uc:Doc Surveyor` with prompt:

> Survey documentation in: [scoped area or project root]
>
> Search comprehensively for ALL documentation artifacts:
> - README.md and README files at any level
> - Any `docs/`, `doc/`, `documentation/`, `wiki/` directories
> - All markdown files (.md) anywhere in the area
> - API specs (OpenAPI/Swagger)
> - ADRs (Architecture Decision Records)
> - Changelogs, contributing guides
> - Any structured text files that serve as documentation
>
> For each found: report location, content type, key topics, and approximate size.

**Code Surveyor** (per area) — use subagent_type `uc:Code Surveyor` with prompt:

> Survey code in: [scoped area or project root]
>
> Focus on:
> 1. Languages, frameworks, build systems (package.json, Cargo.toml, go.mod, pyproject.toml, etc.)
> 2. Directory structure and main entry points
> 3. Test framework and test directories
> 4. External service integrations (APIs, databases, message queues)
> 5. Configuration files and environment setup
> 6. CI/CD pipelines
>
> Return the standard Code Survey format.

Wait for all surveyors to complete. Merge results into unified code + doc reports.

#### 1c — Ask questions

For anything that couldn't be determined from the surveys, ask the user using AskUserQuestion:

- Can't determine project purpose/domain → ask "What does this project do?"
- No test framework detected → ask "What testing setup does this project use? (or 'skip')"
- No environment info found → ask "How do developers set up locally? (or 'skip')"
- Ambiguous document classification → ask "Where should `docs/X.md` go?" with options mapped to canonical structure
- Multiple valid interpretations → ask the user to clarify

Only ask questions that are genuinely unresolvable from the survey data. Don't ask about things you can reasonably infer.

---

### Phase 2: Plan (enter plan mode)

Call `EnterPlanMode`. Using all survey findings + user answers, produce a comprehensive plan covering everything you intend to do. Apply Plan Enhancer format.

The plan includes these task groups, in order:

#### Group 1 — Scaffold canonical structure

- Create each missing directory in the canonical `documentation/` tree (see Docs Manager for the full layout)
- Copy template placeholders from `${CLAUDE_PLUGIN_ROOT}/templates/` where no file exists yet
- Generate `documentation/README.md` index if missing
- Create `context/` directory if missing
- Only create what doesn't already exist — never overwrite

#### Group 2 — Configure project CLAUDE.md and `.claude/` files

**`CLAUDE.md`** (project root) — append an Ultra Claude section if not already present:

If the project has no `CLAUDE.md`, create one. If it already exists, append the Ultra Claude section at the end. Never overwrite existing project-specific content.

The section to add:

```markdown
## Ultra Claude

This project uses [Ultra Claude](https://github.com/duniecdawid/ultra-claude-code), a Claude Code plugin for spec-driven development.

### Conventions

- **Documentation governs code.** Architecture docs are the source of truth. When code diverges from specs, update the spec first.
- **Canonical documentation** lives in `documentation/` — do not create docs outside this structure.
- **Plans** are stored in `documentation/plans/{name}/` with embedded task lists.
- **External system context** (API docs, SDK references) goes in `context/`.
- **Project configuration** for Claude is in `.claude/` (app-context, system-test, environments-info).

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

Adapt the section content based on survey findings:
- If the project has specific technologies, mention relevant tech-research triggers
- If external integrations were found, mention the context/ directory for those specific systems
- Keep the core structure above, but tailor examples to the project

For each `.claude/` config file:

**`.claude/app-context-for-research.md`** — derived from Code Surveyor findings:
- Project Overview (name, purpose, primary language)
- Domain (what problem does this project solve)
- Key Technologies (frameworks, libraries, build tools)
- External Integrations (APIs, databases, services)

**`.claude/system-test.md`** — derived from detected test framework/commands:
- Environment Setup (prerequisites, install commands)
- Running Tests (test command, coverage command)
- Test Patterns (framework, directory structure)

**`.claude/environments-info`** — derived from CI config, environment files, docker-compose:
- Development environment setup
- Required environment variables
- External service dependencies

**`.claude/docs-format`** — default to `markdown` unless existing docs suggest otherwise

For each file:
- Show proposed content in the plan
- Mark as "create" if file doesn't exist, or "update" if it does (with diff)
- Skip files that already exist with real content (not placeholders) unless user wants to overwrite

#### Group 3 — Bootstrap/migrate documentation

Determine the action based on what Phase 1 found:

| Canonical docs exist? | Non-canonical docs exist? | Action |
|---|---|---|
| No | No | **Greenfield**: draft architecture doc from code survey |
| No | Yes | **Migration**: map all found docs to canonical locations |
| Yes | Yes | **Mixed**: draft for gaps + migrate misplaced docs |
| Yes | No | **Already set up**: note what exists, skip this group |

For **greenfield** (no existing docs):
- Draft `documentation/technology/architecture/README.md` from Code Surveyor findings:
  - System components and their responsibilities
  - Data flow between components
  - Technology stack and key dependencies
  - External integrations
- Draft any other documentation that can be reasonably derived from the survey

For **migration** (existing docs in non-standard locations):
- Present a mapping table: current location → target location → action (move)
- Use the Docs Manager routing rules for classification:
  - Architecture, design, component, system, data flow → `technology/architecture/`
  - Convention, standard, pattern, style guide → `technology/standards/`
  - ADR, decision record, RFC, trade-off → `technology/rfcs/`
  - Vision, competitor, market, discovery → `product/description/`
  - Requirement, FR-, NFR-, acceptance criteria → `product/requirements/`
  - External API docs, integration guides → `context/{system}/docs/`
  - Blocker, dependency, open question → `dependencies/`
- Flag ambiguous docs with the user's answers from Phase 1c
- Move files to canonical locations (delete originals after successful move)
- Clean up empty directories left behind after moves

For **mixed** (some canonical, some not):
- Apply both greenfield (for gaps) and migration (for misplaced docs) as appropriate

#### Group 4 — Regenerate index

- Update `documentation/README.md` to reflect final state after all creates/moves

Call `ExitPlanMode` for user approval. The user can discuss, request changes, or approve.

---

### Phase 3: Execute (after plan approval)

Spawn a Task Executor agent (subagent_type `uc:Task Executor`) to carry out the approved plan. Provide the agent with:
- The full approved plan (all task groups)
- The merged survey results for reference
- The canonical structure definition from Docs Manager
- Clear instructions for each task group

The agent executes:
- Create directories
- Write config files
- Copy templates as placeholders
- Move documentation to canonical locations (delete originals after successful move)
- Clean up empty directories left behind after moves
- Generate/update documentation index

For very large projects (many files to move, 4+ task groups with significant work), spawn multiple Task Executor agents in parallel — one per task group.

After agent(s) complete, verify results and report.

---

### Summary

End with a concise report:

- **Scaffolded**: directories created/verified
- **Configured**: CLAUDE.md updated with Ultra Claude section, which `.claude/` files were populated (and which skipped)
- **Documented**: architecture/docs bootstrapped or migrated
- **Migrated**: files moved to canonical locations (originals removed)
- **Gaps remaining**: canonical sections still using placeholders
- **Next steps**:
  - `/uc:doc-code-verification-mode` — verify and improve documentation against actual code (recommended first)
  - `/uc:discovery-mode` — for product research and requirements
  - `/uc:feature-mode` — to plan the first feature
  - `/uc:help` — for guidance on any task

---

## Constraints

- Do NOT modify existing source code
- Do NOT overwrite existing `.claude/` config files without user approval in the plan
- Migration moves files (delete originals after successful move, clean up empty directories)
- Do NOT create files outside `CLAUDE.md`, `documentation/`, `context/`, and `.claude/`
- Ask questions in Phase 1 for anything ambiguous — don't guess
- Always enter plan mode so the user reviews everything before files are created or moved
