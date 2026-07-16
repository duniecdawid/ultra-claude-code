# Surveyor Spawn Prompts

Prompts for Phase 1b — spawn these as parallel subagent pairs scaled to project size (one-shot fan-out: no `name`, explicit `run_in_background: true` — Mode F per `${CLAUDE_PLUGIN_ROOT}/references/agent-spawn-modes.md`; collect every completion notification before merging).

## Doc Surveyor

Subagent type: `uc:Doc Surveyor`

Prompt per scoped area:

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

## Code Surveyor

Subagent type: `uc:Code Surveyor`

Prompt per scoped area:

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
>    - API patterns (REST controllers, GraphQL resolvers, RPC services) -> `rest-api`
>    - Auth patterns (middleware, JWT, OAuth, RBAC) -> `authentication-authorization`
>    - Data precision (BigDecimal, Decimal, money types) -> `numeric-precision`
>    - Logging (framework, structured logging, PII handling) -> `logging`
>    - Module boundaries (package organization, dependency rules) -> `module-separation`
>    - Error handling (error types, exception hierarchies, Result types) -> `error-handling`
>    - Database access (ORM, raw queries, migrations) -> `database`
>    - Testing patterns (frameworks, conventions, fixtures) -> `testing-conventions`
>    - Security patterns (input validation, encryption, secrets management) -> `security`
>    - Frontend patterns (component library, state management, design tokens) -> `design-system`
>    - Transaction handling (annotations, rollback, saga patterns) -> `transaction-handling`
>    - Idempotency (keys, deduplication, retry logic) -> `idempotency`
>    For each detected signal: report what was found, where (file:line), and prevalence (low/medium/high).
> 8. **Test Infrastructure Details** — for testing config generation:
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
