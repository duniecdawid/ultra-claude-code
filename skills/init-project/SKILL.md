---
description: Initialize any project with Ultra Claude. Handles greenfield projects, existing documentation migration, and mixed states. Explores the codebase, derives configuration, scaffolds the canonical structure, and migrates docs — all in one skill. Triggers on "init project", "initialize", "setup project", "onboard project", "bootstrap project", "migrate docs", "docs migration", "onboard existing project".
argument-hint: "project name or description (optional)"
user-invocable: true
context:
  - ${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md
  - ${CLAUDE_PLUGIN_ROOT}/skills/plan-enhancer/SKILL.md
  - ${CLAUDE_PLUGIN_ROOT}/templates/standard.md
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
> 7. **Standards Signals** — detect patterns suggesting coding standards:
>    - API patterns (REST controllers, GraphQL resolvers, RPC services) → `rest-api`
>    - Auth patterns (middleware, JWT, OAuth, RBAC) → `authentication-authorization`
>    - Data precision (BigDecimal, Decimal, money types) → `numeric-precision`
>    - Logging (framework, structured logging, PII handling) → `logging`
>    - Module boundaries (package organization, dependency rules) → `module-separation`
>    - Error handling (error types, exception hierarchies, Result types) → `error-handling`
>    - Database access (ORM, raw queries, migrations) → `database`
>    - Testing patterns (frameworks, conventions, fixtures) → `testing-conventions`
>    - Security patterns (input validation, encryption, secrets management) → `security`
>    - Frontend patterns (component library, state management, design tokens) → `design-system`
>    - Transaction handling (annotations, rollback, saga patterns) → `transaction-handling`
>    - Idempotency (keys, deduplication, retry logic) → `idempotency`
>    For each detected signal: report what was found, where (file:line), and prevalence (low/medium/high).
> 8. **Test Infrastructure Details** — for system-test.md generation:
>    - Test runner/framework with versions (from config files)
>    - Test directory structure and naming conventions
>    - Test configuration files (jest.config, pytest.ini, etc.)
>    - Exact test commands (from package.json scripts, Makefile, CI config)
>    - Coverage tools and configuration
>    - Integration test infrastructure (Testcontainers, docker-compose, test databases)
>    - E2E test setup (Playwright, Cypress, etc.)
>    - CI test pipeline steps
>
> Return the standard Code Survey format with additional `### Standards Signals` and `### Test Infrastructure` sections appended.

Wait for all surveyors to complete. Merge results into unified code + doc reports.

#### 1c — Ask questions

For anything that couldn't be determined from the surveys, ask the user using AskUserQuestion:

- Can't determine project purpose/domain → ask "What does this project do?"
- No test framework detected → ask "What testing setup does this project use? (or 'skip')"
- No environment info found → ask "How do developers set up locally? (or 'skip')"
- Ambiguous document classification → ask "Where should `docs/X.md` go?" with options mapped to canonical structure
- Multiple valid interpretations → ask the user to clarify

Only ask questions that are genuinely unresolvable from the survey data. Don't ask about things you can reasonably infer. Never assume or fabricate the user's answers — always wait for their actual response via AskUserQuestion.

---

### Phase 2: Plan

Using all survey findings + user answers, produce a comprehensive plan covering everything you intend to do. Apply Plan Enhancer format. Present the complete plan in chat.

The plan includes these task groups, in order:

#### Group 1 — Scaffold canonical structure

- Create each missing directory in the canonical `documentation/` tree (see Docs Manager for the full layout)
- Copy template placeholders from `${CLAUDE_PLUGIN_ROOT}/templates/` where no file exists yet
- Generate `documentation/README.md` index if missing
- Create `context/` directory if missing
- Only create what doesn't already exist — never overwrite

#### Group 2 — Configure project CLAUDE.md and `.claude/` files

**Note:** `.claude/system-test.md` is no longer generated from a simple template in this group. It is produced by the Researcher→Executor pipeline in Phase 3 (Stages B and C). This group still derives the other `.claude/` config files.

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

#### Group 2.5 — Standards and System Test Planning

Compile candidate standards from the Code Surveyor's Standards Signals into a table:

| Signal Topic | Proposed Standard File | Evidence | Action |
|---|---|---|---|
| {topic} | `{filename}.md` | High/Med/Low/None | Recommend/Flag |

Evidence strength determines recommendation:
- **High** (5+ files, consistent patterns) → auto-recommend "Create"
- **Medium** (2-4 files) → recommend with note about limited evidence
- **Low** (1 file or ambiguous) → present but don't recommend
- **None but domain-relevant** (e.g., security for payment systems) → flag for discussion

Present ALL candidates to user via AskUserQuestion with this format:

> **Standards & System Test Approval**
>
> Based on code analysis, here are candidate coding standards and the system-test plan. Please approve each:
>
> | # | Standard | Evidence | Recommendation | Your Choice |
> |---|---|---|---|---|
> | 1 | `rest-api.md` | High (12 controllers) | Create | Create / Skip / Create (I'll add context) |
> | 2 | `error-handling.md` | Medium (3 patterns) | Create | Create / Skip / Create (I'll add context) |
> | ... | | | | |
>
> **System-test.md**: Will generate comprehensive test strategy with {N} security categories based on {domain}. Approve? Yes / No / Modify
>
> You may also add unlisted topics (e.g., "Also create a caching standard").

For any topic where user selects "Create (I'll add context)" — follow up with AskUserQuestion to collect their additional context before proceeding to Phase 3.

User must approve before any researchers spawn. Only an explicit approval counts — empty, blank, or ambiguous responses must be re-asked.

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
  - Vision, positioning, product brief → `product/description/`
  - Competitor, market, research, trends → `product/research/`
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

Ask for approval via AskUserQuestion: "Review the initialization plan above. Proceed?" Options: "Approve" / "Reject with feedback" / "Approve with changes". Only an explicit "Approve" counts — empty, blank, or ambiguous responses must be re-asked.

---

### Phase 3: Execute (after plan approval)

Phase 3 runs in three stages. Stages A and B run in parallel; Stage C waits for Stage B to complete.

#### Stage A: Core Execution (Groups 1-4)

Create `documentation/technology/standards/` directory inline before spawning.

Spawn Task Executor agent(s) (subagent_type `uc:Task Executor`) to carry out Groups 1-4 from the approved plan. Provide the agent with:
- The full approved plan (Groups 1-4)
- The merged survey results for reference
- The canonical structure definition from Docs Manager
- Clear instructions for each task group

The agent executes:
- Create directories (including `documentation/technology/standards/`)
- Write config files (`.claude/app-context-for-research.md`, `.claude/environments-info`, `.claude/docs-format`)
- Copy templates as placeholders
- Move documentation to canonical locations (delete originals after successful move)
- Clean up empty directories left behind after moves
- Generate/update documentation index

For very large projects (many files to move, 4+ task groups with significant work), spawn multiple Task Executor agents in parallel — one per task group.

#### Stage B: Research Phase (parallel with Stage A)

For each approved standard topic + system-test.md, spawn a Researcher (subagent_type `uc:Researcher`). Run up to 5 researchers in parallel; batch if more.

**Standards Researcher spawn prompt** (one per approved topic):

> You are researching coding standards for {topic} in this project.
>
> Context:
> - Project: {name}, Tech stack: {stack}
> - Code Surveyor findings: {relevant standards signals for this topic}
> - User-provided context: {if any, from "I'll add context" responses}
>
> Process:
> 1. Read all files identified in survey signals for this topic
> 2. Grep for additional patterns related to {topic}
> 3. Catalogue findings: file path, line, pattern description, whether it's a good pattern (→ rule) or bad pattern (→ FORBIDDEN)
> 4. Cross-reference architecture docs in `documentation/technology/architecture/`
> 5. Check for existing conventions files
>
> Write findings to: `documentation/technology/standards/{topic}-research.md`
>
> Output format:
> ## Good Patterns Found
> - {pattern}: {file:line} — {description}
>
> ## Anti-Patterns Found
> - {anti-pattern}: {file:line} — {what's wrong, what to use instead}
>
> ## Technology-Specific Conventions
> - {convention}: {evidence}
>
> ## Gaps / Missing Information
> - {what couldn't be determined}

**System-test Researcher spawn prompt:**

> You are researching test infrastructure for this project.
>
> Context:
> - Project: {name}, Tech stack: {stack}, Domain: {domain}
> - Test infra findings: {from Code Surveyor's Test Infrastructure section}
>
> Process:
> 1. Read all test config files, CI pipelines, existing test files
> 2. Catalog every test command (package.json scripts, Makefile targets, CI steps)
> 3. Assess domain security needs (payment system → all categories; CRUD app → auth + validation)
> 4. Document the test pyramid as it currently exists
>
> Write findings to: `.claude/system-test-research.md`
>
> Output: test commands, frameworks, infra, security concerns, domain-specific risks, existing test patterns.

#### Stage C: Standards Writing (after Stage B completes)

Wait for all Stage B researchers to finish. Then, for each approved standard + system-test.md, spawn a Task Executor (subagent_type `uc:Task Executor`). Run up to 5 executors in parallel; batch if more.

**Standards Executor spawn prompt** (one per approved topic):

> You are a senior architect specializing in {topic} with deep expertise in {tech stack}. Using prompt-architect methodology, craft a coding standard document from research findings.
>
> Inputs:
> - Research file: `documentation/technology/standards/{topic}-research.md`
> - Template: `${CLAUDE_PLUGIN_ROOT}/templates/standard.md`
> - Sibling standards being created: {list all approved topics}
>
> Prompt-Architect Principles Applied:
> - PERSONA: You are the team's authority on {topic}. Write with the confidence of someone who has seen this pattern fail and succeed across dozens of projects.
> - CONTEXT: Ground every rule in the project's actual code. Reference file:line from the research.
> - FEW-SHOT: Follow the template structure exactly. FORBIDDEN table must have real entries, not placeholders.
> - CHAIN-OF-THOUGHT: For each rule, reason: "Pattern X was found in N files → this is the established convention → codify as rule"
>
> Output Requirements:
> 1. Header block: Title, Established {today}, Applies to {project + stack}
> 2. Principle: One paragraph. Grounded in project's domain.
> 3. FORBIDDEN table: Minimum 3 entries from actual anti-patterns found in research or known pitfalls for this tech stack. Every entry specific and actionable.
> 4. Content sections: Code examples matching project's conventions. Tables, numbered rules, checklists.
> 5. Related: Link to sibling standards by filename.
>
> Quality gates:
> - Every FORBIDDEN entry traceable to research findings or known pitfalls
> - Code examples use project's actual language/framework/naming
> - Rules specific enough for mechanical code review
> - If research has < 3 concrete rules, write NOTE about thin evidence and produce minimal standard
>
> Write to: `documentation/technology/standards/{topic}.md`
> Delete research file after: `documentation/technology/standards/{topic}-research.md`

**System-test Executor spawn prompt:**

> You are a senior QA architect designing test strategies. Using prompt-architect methodology, craft system-test.md from research.
>
> Inputs:
> - Research: `.claude/system-test-research.md`
> - Project domain: {domain}
>
> Output structure for `.claude/system-test.md`:
> 1. **Status**: Current test suite state (what exists, what's missing)
> 2. **Test Stack**: Frameworks, tools, versions (from actual config files)
> 3. **Running Tests**: Exact commands by type (unit, integration, e2e)
> 4. **Test Strategy**: Test pyramid — what each layer covers in this project
> 5. **Security Testing Standards**: Domain-calibrated categories (payment system = all 9 categories; CRUD app = auth + validation + API security)
> 6. **Test Infrastructure Policy**: Rules for actual infra (Testcontainers, docker-compose, test databases, mocking)
> 7. **Tester Agent Rules**: Numbered rules for AI testers on this project — what to check, what to skip, how to validate
>
> Quality: Commands verified against config files. Security categories calibrated to domain. If no tests yet, recommend setup for tech stack.
>
> Write to: `.claude/system-test.md`
> Delete research file after: `.claude/system-test-research.md`

#### Parallelism Summary

- **Stage A + Stage B**: Run in parallel (write to different paths)
- **Stage C**: Waits for Stage B to complete (needs research files)
- **Within Stage B**: All Researchers run in parallel (up to 5 at a time, batch if more)
- **Within Stage C**: All Executors run in parallel (up to 5 at a time, batch if more)

After all stages complete, verify results and report.

---

### Summary

End with a concise report:

- **Scaffolded**: directories created/verified
- **Configured**: CLAUDE.md updated with Ultra Claude section, which `.claude/` files were populated (and which skipped)
- **Documented**: architecture/docs bootstrapped or migrated
- **Migrated**: files moved to canonical locations (originals removed)
- **Standards created**: {list of files with core principle for each}
- **System test**: system-test.md with {N} security categories, {N} tester rules
- **Standards gaps**: topics where evidence was thin (flagged with NOTE sections in the standard files)
- **Gaps remaining**: canonical sections still using placeholders
- **Next steps**:
  - Review generated standards and refine based on team preferences
  - Add project-specific code examples to strengthen thin standards
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
- Always present the full plan and get user approval before creating or moving files
