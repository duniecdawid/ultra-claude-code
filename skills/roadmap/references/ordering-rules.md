# Ordering Rules

How to build the dependency graph and determine plan execution order.

## Hard dependencies (must respect)

These represent real technical constraints — violating them means the later plan cannot succeed:

1. **Infrastructure before everything.** Project scaffold, CI/CD, database setup, deployment config must exist before feature work begins.
2. **Authentication before features requiring auth.** Any feature that needs user identity depends on the auth plan.
3. **Data models before features that read/write them.** If a feature depends on entities created by another plan, the entity-creating plan comes first.
4. **Shared services before consumers.** A notification system, payment engine, or search service must be built before features that use it.
5. **Architecture doc dependencies.** If architecture docs specify explicit component dependencies or a layered system, respect those layers.

## Soft preferences (break ties)

When two plans have no hard dependency between them, prefer this order:

1. Higher-priority requirements (P0) before lower (P1, P2)
2. Plans with more downstream dependents earlier (unblock more work)
3. Simpler/smaller plans before complex ones (build momentum, validate patterns early)
4. User-facing features before admin/internal features
5. Read-heavy features before write-heavy features (reads are simpler to validate)

## Parallel opportunities

Plans at the same depth in the dependency graph can be built in parallel. Call these out explicitly in the roadmap — they represent opportunities to accelerate the build by running multiple feature-mode + plan-execution cycles concurrently.

## Incremental detection

When existing plans are found in `documentation/plans/`:

1. Read each existing plan's README.md and extract its scope
2. Remove covered scope from the decomposition — don't re-plan what's already planned
3. Find the highest plan number N; new stubs start at N+1
4. Plans with `Status: Stub` are from a prior roadmap run — leave them as-is unless the user asks to revise
5. Plans with `Status: Completed` provide infrastructure — treat their deliverables as available for new plans to depend on
6. Plans with `Status: In Progress` or `Status: Approved` are active work — don't create plans that conflict with their scope
