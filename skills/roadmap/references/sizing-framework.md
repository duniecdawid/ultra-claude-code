# Sizing Framework

How to decompose a product into plans. Each plan should be independently detailable via `/uc:feature-mode` and executable via `/uc:plan-execution`.

## Target size

A well-sized plan typically produces 3-8 tasks when detailed by feature-mode, touching 20-100 files total. This is roughly one planning + execution cycle.

## Decomposition heuristics

Apply in order:

1. **Infrastructure first.** If the project needs scaffolding (project structure, build system, CI/CD, deployment config, database setup), that is always the first plan. This is the foundation everything else builds on.

2. **Split by user-facing capability, not technical layer.** "User authentication" is a plan. "Backend API" is not (too broad). "Database schema" is not (it's infrastructure or part of a feature). Each plan should deliver something a user or stakeholder can see or use.

3. **One plan per major requirement.** Map each P0 requirement (from `documentation/product/requirements/`) to its own plan. Related P1/P2 requirements can share a plan if they're cohesive and wouldn't overshoot the size target.

4. **Auth before features needing it.** If the product has user accounts, the auth system is typically the second plan (after infrastructure).

5. **Core domain before extensions.** The primary value proposition of the product should be planned before secondary features, admin panels, integrations, and polish.

6. **Shared components before consumers.** If multiple features need a shared service (notification system, billing engine, search), plan the shared component before the features that consume it.

7. **Persona lens.** If the product has defined personas (from `documentation/product/personas/`), consider organizing plans around persona journeys — the set of features that deliver value to a specific persona.

## Size guardrails

- **Too big (>8 tasks / >100 files):** Split along feature boundaries. Look for independent sub-capabilities within the plan.
- **Too small (<2 tasks / <15 files):** Merge with an adjacent plan that shares context. The overhead of a separate plan isn't justified for very small scope.
- **When in doubt, keep it as one plan.** It's easier to split a plan during feature-mode's Stage 1 (scope challenge) than to merge plans that were split prematurely.
