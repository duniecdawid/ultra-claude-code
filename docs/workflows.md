# Workflows

Step-by-step flows showing how each mode operates end-to-end. For the architecture behind these flows, see [Architecture](architecture.md).

## Feature Plan Mode

```
User: /uc:feature "Add user authentication"

1. PLANNING — Feature Plan Mode activates
   → Plan Enhancer triggers plan mode, configures plan directory
   → Researcher + Docs Manager gather context (codebase, architecture, product docs)
   → Claude challenges scope, pushes for clarity
   → If architecture decision is ambiguous: suggests RFC mode
     → Creates documentation/technology/rfcs/auth-strategy.md
     → Runs AI persona review (Devil's Advocate, Pragmatist, etc.)
     → Outcome integrated into architecture doc, RFC archived
   → Plan created in documentation/plans/user-auth/README.md (task list embedded)
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute user-auth
   → Agent team runs tasks from the plan (see Execute Plan below)
```

## Execute Plan

See [Execution](execution.md) for the complete 5-phase workflow.

**Summary:** `/uc:execute {plan-name}` -> Lead reads plan -> creates 4 role-separated task lists -> spawns dynamic team -> teammates self-claim and work in parallel -> Lead promotes tasks between lists -> checkpoints periodically -> Tester runs final gate -> summary report.

## Discovery Mode

```
User: /uc:discover "Research how competitors handle rate limiting"

1. Discovery Mode skill activates
   → Coding is DISABLED
   → Researcher + Market Analyzer agents work in parallel
   → Researcher: Explores internal codebase, reads docs, uses Ref.tools
   → Market Analyzer: Web searches, competitor analysis

2. Findings compiled to documentation/product/description/{topic}.md
3. No code changes. No plan. Pure investigation output.
4. Feeds into future planning sessions as context.
```

## Doc & Code Verification Mode

```
User: /uc:verify

1. PLANNING — Doc & Code Verification Mode activates
   → Plan Enhancer triggers plan mode
   → Spawns Code Surveyor + Doc Surveyor agents in parallel
   → Code Surveyors scan codebase structure, patterns, APIs
   → Doc Surveyors scan documentation claims, specs, architecture docs
   → Checker agents compare doc claims vs code reality
   → Discrepancies listed with severity (HIGH/MEDIUM/LOW)
   → Plan created with fix tasks (update doc or update code)
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute {plan-name}
   → Agent team resolves discrepancies per plan
```

## Debug Mode

```
User: /uc:debug "Login fails intermittently on staging"

1. PLANNING — Debug Mode activates
   → Debug Mode skill analyzes the issue description
   → Proposes hypotheses (e.g., race condition, session expiry, cache stale)
   → Spawns Researcher teammates — one per hypothesis, investigating in parallel
   → System Tester attempts to reproduce the bug
   → Evidence gathered, hypotheses ranked by likelihood
   → Plan created focused on the fix + verification steps
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute {plan-name}
   → Agent team implements the fix
   → System Tester validates the fix resolves the original issue
```
