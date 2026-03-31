# Executor Spawn Prompts (Phase 3 — Stage C)

Spawn these after Stage B Explore agents complete. Use subagent_type `uc:Task Executor`. Run up to 5 executors in parallel; batch if more.

Pass the Explore agent results directly into the executor spawn prompt — no intermediate research file needed since Explore agents return results inline.

## Standards Executor

One per approved standard topic:

> You are a senior architect specializing in {topic} with deep expertise in {tech stack}. Using prompt-architect methodology, craft a coding standard document from the exploration findings below.
>
> Inputs:
> - Exploration findings: {paste the Explore agent results directly here}
> - Template: `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/standard.md`
> - Sibling standards being created: {list all approved topics}
>
> Prompt-Architect Principles Applied:
> - PERSONA: You are the team's authority on {topic}. Write with the confidence of someone who has seen this pattern fail and succeed across dozens of projects.
> - CONTEXT: Ground every rule in the project's actual code. Reference file:line from the research.
> - FEW-SHOT: Follow the template structure exactly. FORBIDDEN table must have real entries, not placeholders.
> - CHAIN-OF-THOUGHT: For each rule, reason: "Pattern X was found in N files -> this is the established convention -> codify as rule"
> - FEW-SHOT findings are provided inline in the prompt (from Explore agent results)
>
> Output Requirements:
> 1. Header block: Title, Established {today}, Applies to {project + stack}
> 2. Principle: One paragraph. Grounded in project's domain.
> 3. FORBIDDEN table: Minimum 3 entries from actual anti-patterns found in research or known pitfalls for this tech stack. Every entry specific and actionable.
> 4. Content sections: Code examples matching project's conventions. Tables, numbered rules, checklists.
> 5. Related: Link to sibling standards by filename.
>
> Quality gates:
> - Every FORBIDDEN entry traceable to exploration findings or known pitfalls
> - Code examples use project's actual language/framework/naming
> - Rules specific enough for mechanical code review
> - If findings have < 3 concrete rules, write NOTE about thin evidence and produce minimal standard
>
> Write to: `documentation/technology/standards/{topic}.md`

## Testing Config Executor

One executor for the full testing directory:

> You are a senior QA architect designing test strategies. Using prompt-architect methodology, craft a multi-file testing configuration from the exploration findings below.
>
> Inputs:
> - Exploration findings: {paste the Explore agent results directly here}
> - Project domain: {domain}
>
> Write **6 files** to `documentation/technology/testing/`:
>
> 1. **`README.md`** — Test strategy overview:
>    - Current test suite state (what exists, what's missing)
>    - Test stack: frameworks, tools, versions (from actual config files)
>    - Test pyramid: what each layer covers in this project
>
> 2. **`commands.md`** — Exact test commands:
>    - Commands by type (unit, integration, e2e)
>    - Dev server start command
>    - Coverage command
>    - Build/lint commands relevant to testing
>
> 3. **`infrastructure.md`** — Test infrastructure policy:
>    - Rules for actual infra (Testcontainers, docker-compose, test databases, mocking)
>    - Environment setup prerequisites
>    - Test data management
>
> 4. **`security.md`** — Security testing standards:
>    - Domain-calibrated categories (payment system = all 9 categories; CRUD app = auth + validation + API security)
>
> 5. **`agent-rules.md`** — Tester agent rules:
>    - Numbered rules for AI testers on this project — what to check, what to skip, how to validate
>
> 6. **`final-gate.md`** — Final gate tester instructions:
>    - Pages/routes to smoke test in browser
>    - Acceptance thresholds (e.g., all tests must pass, no console errors)
>    - Cross-task regression priorities
>    - Manual verification checklist items specific to this project
>
> Quality: Commands verified against config files. Security categories calibrated to domain. If no tests yet, recommend setup for tech stack. If project has legacy `.claude/system-test.md`, migrate its content into the new files and note that the old file can be removed.
