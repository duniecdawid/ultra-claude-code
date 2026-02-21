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
     → Creates documentation/rfcs/auth-strategy.md
     → Runs AI persona review (Devil's Advocate, Pragmatist, etc.)
     → Outcome integrated into architecture doc, RFC archived
   → Plan created in documentation/plans/user-auth/README.md
   → Task list created in documentation/plans/user-auth/task_list.md
   → User reviews and approves plan

2. EXECUTION
   → /uc:execute user-auth
   → Agent team runs tasks from the plan (see Execute Plan below)
```

## Execute Plan

The execution engine runs any plan — Feature, Debug, or Verification all use the same flow.

```
User: /uc:execute user-auth

1. SETUP
   → Lead reads documentation/plans/user-auth/README.md + task_list.md
   → Lead creates agent team
   → Lead spawns: Researcher + Task Executor + Task Tester teammates
   → Lead checks for existing research (doesn't repeat work)

2. TASK LOOP (for each task in priority order)
   → Researcher gathers context for the task
     - Reads architecture docs, existing code
     - Writes findings to plans/user-auth/research/task-N.md
     - Sends "research complete" to Task Executor
   → Task Executor implements the task
     - Reads research findings
     - Implements code conforming to plan and architecture
     - Sends "implementation complete" to Task Tester
   → Task Tester checks the implementation
     - Runs relevant tests, checks success criteria
     - If PASS: task marked complete
     - If FAIL: sends specific feedback to Task Executor, task re-queued
   → No user approval required between tasks

3. CHECKPOINT (every N tasks or on demand)
   → Saves progress to plan directory
   → Task list + plan can be used to recover if session dies
   → /uc:execute user-auth resumes from checkpoint

4. COMPLETION
   → All tasks done
   → System Tester runs final verification
   → Summary report produced
```

## Discovery Mode

```
User: /uc:discover "Research how competitors handle rate limiting"

1. Discovery Mode skill activates
   → Coding is DISABLED
   → Researcher + Market Analyzer agents work in parallel
   → Researcher: Explores internal codebase, reads docs, uses Ref.tools
   → Market Analyzer: Web searches, competitor analysis

2. Findings compiled to documentation/product/{topic}.md
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
