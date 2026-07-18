# Sizing Framework

How to decompose a product into plans. Each plan should be independently detailable via `/uc:feature-mode` and executable via `/uc:plan-execution`.

## Target size

A well-sized plan typically produces 1-4 tasks when detailed by feature-mode, touching 20-120 files total. This is roughly one planning + execution cycle. Tasks are large by design (~10-40 files each — see `references/planning-framework/task-sizing.md`): every task spins up a full Executor + Reviewer + Tester team, so fewer, larger tasks is the goal.

## Decomposition heuristics

Apply in order:

1. **Infrastructure first.** If the project needs scaffolding (project structure, build system, CI/CD, deployment config, database setup), that is always the first plan. This is the foundation everything else builds on.

2. **Split by user-facing capability, not technical layer.** A feature must never be split across multiple plans. All architectural layers for a feature — frontend, backend, database, API — belong in one plan. A plan *can* bundle multiple cohesive features, but a single feature must never span multiple plans.

   **Anti-pattern (never do this):**
   - `003-dashboard-backend` + `004-dashboard-frontend` — WRONG. This is one feature split by layer.
   - `005-search-api` + `006-search-ui` — WRONG. Same problem.

   **Correct:**
   - `003-user-dashboard` — includes API endpoints, React components, database queries, everything needed for the dashboard to work end-to-end.
   - `005-search` — includes search service, indexing, API, and UI all in one plan.

   Why this matters: layer splits create artificial dependencies between plans, make scope boundaries ambiguous (where does "backend" end?), and prevent each plan from delivering independently testable value. A plan that only produces API endpoints with no UI delivers nothing a user can verify.

3. **One plan per major requirement.** Map each P0 requirement (from `documentation/product/requirements/`) to its own plan. Related P1/P2 requirements can share a plan if they're cohesive and wouldn't overshoot the size target.

4. **Auth before features needing it.** If the product has user accounts, the auth system is typically the second plan (after infrastructure).

5. **Core domain before extensions.** The primary value proposition of the product should be planned before secondary features, admin panels, integrations, and polish.

6. **Shared components before consumers.** If multiple features need a shared service (notification system, billing engine, search), plan the shared component before the features that consume it.

7. **Persona lens.** If the product has defined personas (from `documentation/product/personas/`), consider organizing plans around persona journeys — the set of features that deliver value to a specific persona.

## Size guardrails

- **Too big (>4 tasks / >150 files):** Split along feature boundaries. Look for independent sub-capabilities within the plan.
- **Too small (<15 files):** Merge with an adjacent plan that shares context. The overhead of a separate plan isn't justified for very small scope.
- **When in doubt, keep it as one plan.** It's easier to split a plan during feature-mode's Stage 1 (scope challenge) than to merge plans that were split prematurely.
