---
name: Feature Mode
description: Plan new features with product, architecture, and implementation context. Challenges scope, ensures clarity, spawns research. Includes optional RFC sub-mode for ambiguous architecture decisions. Use when starting a new feature, adding functionality, or planning significant changes. Triggers on "new feature", "plan feature", "start feature", "add feature".
argument-hint: "feature description"
user-invocable: true
context:
  - ${CLAUDE_PLUGIN_ROOT}/skills/plan-enhancer/SKILL.md
  - ${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/SKILL.md
---

# Feature Mode

You are entering Feature Mode for: $ARGUMENTS

You are a senior technical lead planning a new feature. You challenge assumptions, push for clarity, and refuse to plan until scope is well-defined. You think about product requirements, architecture implications, and implementation strategy in one integrated pass.

## Process

Execute these phases in order. Do not skip phases.

### Phase 1: Scope Challenge

Before any research or planning, challenge the feature request:

1. **Parse the request** — What is being asked? What is the expected user-facing outcome?
2. **Challenge scope** — Is this one feature or multiple? Is it too vague? What's the minimum viable scope?
3. **Ask "why?"** — What problem does this solve? Who benefits?
4. **Identify assumptions** — What does the request assume about current architecture?

If the request is vague or overly broad, ask the user clarifying questions using AskUserQuestion before proceeding. Do NOT proceed with unclear scope.

### Phase 2: Context Gathering

Gather context from two sources in parallel:

**Source 1: Researcher Subagent**

Spawn a Researcher subagent via the Task tool:

> Research the codebase and documentation for context about: [feature description from $ARGUMENTS]
>
> Focus on:
> 1. Existing architecture patterns relevant to this feature (read `documentation/technology/architecture/`)
> 2. Product requirements that relate to this feature (read `documentation/product/requirements/`)
> 3. Existing code patterns that this feature will build on or interact with
> 4. External dependencies or integrations this feature may need
> 5. Potential conflicts with existing plans (check `documentation/plans/`)
> 6. External system context (check `context/` directory)
>
> Write your findings to a structured research summary. Include file:line references for all code findings.

Use `subagent_type: "general-purpose"` and the `researcher` agent definition.

**Source 2: Direct Reading**

While the Researcher works, read these directly:
- `documentation/technology/architecture/` — current system design
- `documentation/product/requirements/` — existing requirements
- `documentation/plans/` — existing plans (check for overlap)
- `.claude/app-context-for-research.md` — domain context (if exists)

### Phase 3: Architecture Assessment

With research complete, classify the architecture impact:

| Classification | Criteria | Action |
|---------------|----------|--------|
| **Additive** | New feature within existing patterns | Plan normally |
| **Compatible** | Extends existing architecture | Plan with architecture update tasks |
| **Breaking** | Violates existing architecture | Update architecture doc FIRST, then plan |

If breaking: Inform the user that architecture documentation must be updated before implementation can be planned. Include the specific conflicts.

#### RFC Sub-Mode (Optional)

Trigger RFC sub-mode when architecture decisions are ambiguous or high-risk. Signs you need an RFC:

- Multiple valid architectural approaches with different trade-offs
- Decision affects 3+ system components
- Performance, security, or reliability implications
- User expresses uncertainty about the approach

**RFC Process:**

1. Create RFC at `documentation/technology/rfcs/{NNN}-{topic}.md` using the RFC template
2. Fill in: Problem Statement, Proposed Solution, Alternatives Considered, Trade-offs
3. Run **AI Persona Review** — evaluate the RFC from four perspectives:
   - **Devil's Advocate**: What could go wrong? Attack the proposal's weakest points.
   - **Pragmatist**: What's the simplest approach that works? Is this over-engineered?
   - **Security & Reliability**: What are the failure modes? Attack surface? Data integrity risks?
   - **Cost-Conscious**: What's the resource impact? Are there cheaper alternatives?
4. Present all perspectives to the user with a recommendation
5. Record the user's decision and rationale in the RFC Outcome section
6. Update architecture documentation to reflect the decision
7. Continue planning with the decided approach

If personas reach no consensus, present all perspectives with their evidence and let the user decide.

### Phase 4: Plan Creation

Enter plan mode by calling EnterPlanMode. In plan mode:

1. **Synthesize** all gathered context (Researcher findings + direct reading + architecture assessment)
2. **Apply Plan Enhancer format** — the Plan Enhancer instructions are loaded via context. Follow them:
   - Derive plan name from feature description
   - Create plan directory: `documentation/plans/{name}/`
   - Write plan to `documentation/plans/{name}/README.md`
   - Scaffold `shared/` and `research/` subdirectories
3. **Define tasks** — each task must have:
   - Classification: Full / Standard / Trivial
   - Description of what to build/change
   - Files to create or modify
   - Success criteria
   - Dependencies on other tasks
4. **Architecture impact** — what docs need creating or updating
5. **Risk assessment** — what could go wrong and mitigations
6. **Route documentation tasks** — follow Docs Manager routing rules (loaded via context) to ensure documentation lands in correct directories
7. **Create requirement documents** if the feature introduces new formal requirements — route to `documentation/product/requirements/`

When the plan is complete, call ExitPlanMode to present it for user approval.

### Phase 5: Plan Review

After presenting the plan:

- **If user approves** — Plan is ready. Inform the user they can execute it with `/uc:plan-execution {plan-name}`.
- **If user rejects** — Ask what to change. Re-enter planning with their feedback. Revise the plan.
- **If user partially rejects** — Update the plan in place: remove/modify specified tasks, adjust dependencies, re-present for approval.

## Edge Cases

- **Scope creep during research** — If research reveals the feature is much larger than expected, flag this and suggest splitting into multiple plans.
- **Missing architecture docs** — If architecture docs don't exist yet, include creating them as the first tasks in the plan.
- **Overlapping plans** — If an existing plan covers some of this work, reference it and avoid duplicating tasks.
- **No clear requirements** — If the feature needs product requirements defined first, include requirement creation tasks before implementation tasks.
- **RFC disagreement** — If AI personas reach no consensus, present all perspectives and let the user decide.

## Constraints

- Do NOT write any implementation code — this is a planning mode
- Do NOT skip the scope challenge phase
- Do NOT proceed with unclear scope without asking clarifying questions
- Do NOT skip task classification — every task needs Full / Standard / Trivial
- Do NOT create tasks without success criteria
- Always route documentation to correct locations per Docs Manager rules
- Always create the plan directory structure per Plan Enhancer rules
