# Workflows

Step-by-step flows showing how each mode operates end-to-end. For the architecture behind these flows, see [Architecture](architecture.md).

> **Invocation:** All skills are namespaced under the plugin name `uc` (from `plugin.json`). Full invocation names are `/uc:feature-plan-mode`, `/uc:debug-mode`, `/uc:doc-code-verification-mode`, `/uc:discovery-mode`, `/uc:execute-plan`. See [Components](components.md) for the complete skill table.

## Feature Plan Mode

**Entry condition:** User has a feature idea or requirement to implement.
**Exit condition:** Plan approved and ready for execution, or user decides not to proceed.

```
User: /uc:feature "Add user authentication"

1. PLANNING — Feature Plan Mode activates
   → Plan Enhancer triggers plan mode, configures plan directory
   → Researcher subagent + Docs Manager skill gather context (codebase, architecture, product docs)
   → Claude challenges scope, pushes for clarity
   → If architecture decision is ambiguous: suggests RFC mode
     → Creates documentation/technology/rfcs/auth-strategy.md
     → Runs AI persona review (Devil's Advocate, Pragmatist, etc.)
     → Outcome integrated into architecture doc, RFC archived
   → Plan created in documentation/plans/user-auth/README.md (task list embedded)
   → User reviews and approves plan

   → If user rejects plan:
     → User provides feedback on what to change
     → Mode re-enters planning with feedback as additional context
     → Revised plan generated and re-presented
   → If user partially rejects:
     → User specifies in chat which tasks to remove or modify
     → Plan updated in place, task list adjusted
     → Re-presented for final approval

2. EXECUTION
   → /uc:execute user-auth
   → Agent team runs tasks from the plan (see Execute Plan below)
```

**Edge cases:**
- **RFC mode disagreement** — If AI personas reach no consensus, Lead presents all perspectives and user decides.
- **Scope creep during planning** — If research reveals the feature is much larger than expected, Claude flags this and suggests splitting into multiple plans.
- **Missing architecture docs** — If architecture docs don't exist yet, Feature Plan Mode creates them as part of planning.

## Execute Plan

See [Execution](execution.md) for the complete 5-phase workflow.

**Summary:** `/uc:execute {plan-name}` -> Lead reads plan -> creates 4 role-separated task lists -> spawns dynamic team -> teammates self-claim and work in parallel -> Lead promotes tasks between lists -> checkpoints periodically -> Tester runs final gate -> summary report.

## Discovery Mode

**Entry condition:** User wants to research a topic without writing code.
**Exit condition:** Research findings written to documentation, available as context for future planning.

```
User: /uc:discover "Research how competitors handle rate limiting"

1. Discovery Mode skill activates
   → Coding is DISABLED
   → Researcher + Market Analyzer subagents spawned in parallel via Task tool
   → Researcher: Explores internal codebase, reads docs, uses Ref.tools
   → Market Analyzer: Web searches, competitor analysis

2. Findings compiled to documentation/product/description/{topic}.md
3. No code changes. No plan. Pure investigation output.
4. Feeds into future planning sessions as context.
```

**Edge cases:**
- **No relevant results found** — Agents report what they searched and suggest alternative angles or broader/narrower search terms.
- **Contradictory findings** — Researcher and Market Analyzer may find conflicting information. Both perspectives are documented with sources, user decides which to prioritize.
- **Scope too broad** — If the topic is too large for a single discovery session, Lead suggests breaking it into focused sub-topics.

## Doc & Code Verification Mode

**Entry condition:** Codebase and documentation exist; user wants to check consistency.
**Exit condition:** Discrepancy plan approved and ready for execution, or no discrepancies found.

```
User: /uc:verify

1. PLANNING — Doc & Code Verification Mode activates
   → Plan Enhancer triggers plan mode
   → Spawns Code Surveyor + Doc Surveyor subagents in parallel via Task tool
   → Code Surveyors scan codebase structure, patterns, APIs
   → Doc Surveyors scan documentation claims, specs, architecture docs
   → Checker subagents compare doc claims vs code reality
   → Discrepancies listed with severity (HIGH/MEDIUM/LOW)
   → Plan created with fix tasks (update doc or update code)
   → User reviews and approves plan

   → If user rejects plan:
     → User provides feedback on what to change
     → Mode re-enters planning with feedback as additional context
     → Revised plan generated and re-presented
   → If user partially rejects:
     → User specifies in chat which tasks to remove or modify
     → Plan updated in place, task list adjusted
     → Re-presented for final approval

2. EXECUTION
   → /uc:execute {plan-name}
   → Agent team resolves discrepancies per plan
```

**Edge cases:**
- **No discrepancies found** — Mode reports clean status. No plan created.
- **Ambiguous discrepancy** — When it's unclear whether code or docs are "correct," the discrepancy is flagged for user decision rather than auto-resolved.
- **Very large codebase** — Surveyors may hit context limits. Mode supports scoped verification (e.g., `/uc:verify src/auth/` for a specific directory).

## Debug Mode

**Entry condition:** User has a bug or issue to investigate.
**Exit condition:** Fix plan approved and ready for execution, or issue determined to be external/not reproducible.

```
User: /uc:debug "Login fails intermittently on staging"

1. PLANNING — Debug Mode activates
   → Debug Mode skill analyzes the issue description
   → Proposes hypotheses (e.g., race condition, session expiry, cache stale)
   → Spawns Researcher subagents — one per hypothesis, investigating in parallel via Task tool
   → System Tester subagent attempts to reproduce the bug
   → Evidence gathered, hypotheses ranked by likelihood
   → Plan created focused on the fix + verification steps
   → User reviews and approves plan

   → If user rejects plan:
     → User provides feedback on what to change
     → Mode re-enters planning with feedback as additional context
     → Revised plan generated and re-presented
   → If user partially rejects:
     → User specifies in chat which tasks to remove or modify
     → Plan updated in place, task list adjusted
     → Re-presented for final approval

2. EXECUTION
   → /uc:execute {plan-name}
   → Agent team implements the fix
   → System Tester validates the fix resolves the original issue
```

**Edge cases:**
- **Bug not reproducible** — System Tester reports inability to reproduce. Lead presents findings and asks user for more context (environment details, logs, steps to reproduce).
- **Multiple root causes** — Investigation reveals the symptom has multiple contributing causes. Plan includes fixes for all identified causes, ordered by impact.
- **Fix requires architectural change** — If the fix would violate existing architecture, Debug Mode flags this and suggests running Feature Plan Mode instead for a proper design review.
