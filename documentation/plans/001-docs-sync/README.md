# Plan: Documentation-Code Sync

> **Execute:** `/uc:plan-execution 001`
> Created: 2026-03-14
> Status: Draft
> Source: Verification Mode

## Objective

Bring all HTML documentation (`docs/`) in sync with the current state of agents and skills after a rapid iteration day (15 commits on 2026-03-14).

## Context

- **Verification report:** This plan — discrepancy synthesis is embedded below
- **Architecture:** `docs/architecture.html`
- **Components:** `docs/components.html`
- **Workflows:** `docs/workflows.html`
- **Execution:** `docs/execution.html`
- **System Overview:** `docs/system-overview.html`

## Tech Stack

- HTML (static docs site)

## Scope

### In Scope

- Fix all Critical and Major discrepancies found by verification
- Update agent tables, skill tables, workflow descriptions, execution specs, architecture claims, system overview diagram
- Add documentation for undocumented agents (project-manager) and skills (vscode-setup, tailscale-setup, critical-brainstorm, tmux-team-grid)

### Out of Scope

- Changing any agent or skill code — this is docs-only
- Minor discrepancies (naming inconsistencies, tool ordering) — absorb into nearest task
- `research.html`, `decisions.html`, `migration.html`, `getting-started.html` — not affected by current discrepancies
- PM stage vocabulary mismatch (M7) — deferred pending user decision

## Success Criteria

- [ ] All 10 agents accurately documented in components.html with correct tools, disallowed tools, descriptions
- [ ] All 16 skills documented in components.html with correct triggers and capabilities
- [ ] Workflow descriptions match the 4-stage framework (not the old 6-step flow)
- [ ] Execution pipeline docs include pipeline gate, correct concurrency table, browser smoke test, PM coordination
- [ ] System overview diagram includes all agents and skills
- [ ] `explore` correctly identified as built-in Claude Code agent type, not a UC-custom agent

## Task List

> Every task gets the full pipeline: planning -> impl -> review -> test.
> Tasks must deliver end-to-end testable user value — from database through backend to API/UI. A tester must be able to verify each task by simulating user behavior, not just checking technical artifacts.
> Trivial work (config changes, doc updates, renames) MUST be absorbed into the nearest task — never listed standalone.
> Sequential dependency chains MUST be merged into a single task.

### Task 1: Sync All HTML Documentation with Current Code

- **Description:** Update all 5 HTML documentation files to match current agent/skill code reality. Work through each file systematically:

  **1. `docs/components.html` — Agent & Skill Reference Tables**
  - **Agents table:**
    - Remove `explore` row — it's a built-in Claude Code agent type, not a UC-custom agent file. Add a note explaining the distinction.
    - Add `project-manager` row: model `sonnet`, tools `Read, Write, Glob, Grep, Bash`, description covers dashboard monitoring, stall detection, operational reporting. Spawned as Teammate (execution, one per plan).
    - Fix `task-tester` row: tools are `Read, Write, Edit, Glob, Grep, Bash` plus `mcp__claude-in-chrome__*` (12 browser tools). Remove `disallowedTools: Write, Edit` — there are none. Update description to mention browser/Chrome testing capability.
    - Fix `tech-knowledge`: add note about `skills: [tech-research]` frontmatter field.
  - **Skills table:**
    - Add 4 missing skills: `vscode-setup`, `tailscale-setup`, `critical-brainstorm`, `tmux-team-grid` — all user-invocable.
    - Fix trigger phrases for all 7 skills with incomplete triggers (add missing triggers from SKILL.md descriptions).
    - Fix `plan-enhancer` claim from "Auto-loaded by all modes" to "Loaded by feature-mode, debug-mode, doc-code-verification-mode, init-project via context: field".
    - Fix `docs-manager` triggers — remove fabricated "audit docs" etc.; document activation via `.claude/docs-format` file.
    - Fix `discovery-mode` trigger "research only" → actual triggers from SKILL.md.

  **2. `docs/workflows.html` — Workflow Descriptions**
  - **Feature Mode workflow:** Replace 6-step flow with 4-stage (Understand→Research→Discuss→Write). Stage 2 Research: Phase A spawns Code Surveyor + Doc Surveyor (primary); Phase B conditionally spawns Explore agent. Remove Explore as mandatory step.
  - **Debug Mode workflow:** Remove phantom "4.5 DOCUMENTATION UPDATE" phase. Clarify that doc updates happen in Stage 4 Step 1 (inherited from plan-enhancer).
  - **Plan Execution workflow:** Update concurrency to ranges (1-2/2-3/3-4) not hard ceilings (2/3/4). Add pipeline gate mechanism description. Add browser smoke test to final gate description.
  - **Discovery Mode workflow:** Verify accuracy (was mostly correct per checkers).
  - **Doc-Code Verification workflow:** Verify accuracy (was mostly correct per checkers).

  **3. `docs/execution.html` — Pipeline Specification**
  - **Concurrency table:** Change from hard ceilings (2/3/4) to ranges (1-2/2-3/3-4) matching plan-execution/SKILL.md:73-77.
  - **Pipeline gate:** Add new section documenting pipeline-mode task spawning, implementation approval flow, PIPELINE-SPAWN event type.
  - **Context bridge table:** Add `knowledge-{PLAN_NAME}` teammate name to all spawn prompts. Add `documentation/product/` to Tester's context. Fix Reviewer to show all teammate names (not just Executor).
  - **Coordination model:** Add Project Manager as 4th coordination mechanism — JSON dashboard, background watchdog, Tailscale HTTPS, stall detection, operational report.
  - **Final gate:** Add browser smoke test for frontend projects.
  - **Cost estimate step:** Document the user confirmation step before team spawning.
  - Fix Executor spawn example (Patterns field vs generic architecture docs path); add dependency graph to lead.md description.

  **4. `docs/architecture.html` — Architecture Claims**
  - Fix "three specialized planning modes" → "four" (include Discovery Mode as a full mode, not just a pre-step).
  - Fix Feature Mode description: primary research is Code Surveyor + Doc Surveyor (Phase A); Explore is conditional Phase B.
  - Fix RFC sub-mode trigger: happens during Stage 4 Step 1, not during earlier planning stages.
  - Fix plugin.json description: contains only name/description/author, not structural declarations.
  - Add note distinguishing built-in Claude Code agents (Explore) from UC-custom agents (files in agents/).

  **5. `docs/system-overview.html` — System Diagram**
  - Add `project-manager` to execution layer in the diagram.
  - Add missing skills to support panel or create appropriate categorization for all 16 skills.
  - Add `product/research/` to the repo structure diagram.
  - Ensure Feature Mode card shows Code Surveyor + Doc Surveyor as primary, Explore as conditional.

- **Files:** `docs/components.html`, `docs/workflows.html`, `docs/execution.html`, `docs/architecture.html`, `docs/system-overview.html`
- **Patterns:** Read each agent `.md` frontmatter and each skill `SKILL.md` frontmatter as source of truth. Read plan-execution/SKILL.md, project-manager.md, task-executor.md, task-tester.md for execution details.
- **Success criteria:** All 10 agents accurately documented with correct tools/disallowed tools/descriptions; all 16 skills documented with correct triggers; workflow descriptions match 4-stage framework; execution pipeline includes pipeline gate, correct concurrency, PM coordination, browser smoke test; system overview diagram shows all agents and skills; `explore` correctly identified as built-in; no phantom entries.
- **Dependencies:** None

## Discrepancy Reference

Full discrepancy list from verification (for executor reference):

### Critical (7)
| ID | Issue | Fix Target |
|----|-------|------------|
| C1 | `explore` documented as custom agent — it's a built-in | components.html, architecture.html |
| C2 | `project-manager` agent missing from all docs | components.html, system-overview.html, execution.html |
| C3 | `task-tester` tools completely wrong | components.html |
| C4 | 4 skills undocumented (vscode-setup, tailscale-setup, critical-brainstorm, tmux-team-grid) | components.html |
| C5 | Concurrency table wrong (hard ceilings vs ranges) | execution.html |
| C6 | Pipeline gate undocumented | execution.html |
| C7 | System overview missing agents/skills | system-overview.html |

### Major (18 — M1 invalidated, was about [1m] already cleaned up)
| ID | Issue | Fix Target |
|----|-------|------------|
| M2 | tech-knowledge `skills: [tech-research]` undocumented | components.html |
| M3 | Feature Mode workflow: 6-step vs 4-stage | workflows.html |
| M4 | Debug Mode phantom "4.5" phase | workflows.html |
| M5 | plan-enhancer "all modes" claim wrong | components.html |
| M6 | Trigger phrases incomplete for 7 skills | components.html |
| M7 | PM stage vocabulary mismatch | DEFERRED — needs user decision |
| M8 | Tester product docs in context bridge | execution.html |
| M9 | Final gate browser smoke test undocumented | execution.html, workflows.html |
| M10 | "Three planning modes" should be four | architecture.html |
| M11 | Feature Mode description omits surveyors | architecture.html |
| M12 | RFC trigger timing wrong | architecture.html |
| M13 | plugin.json description misleading | architecture.html |
| M14 | Knowledge agent name missing from context bridge | execution.html |
| M15 | PM coordination mechanism not listed | execution.html |
| M16 | PM operational report undocumented | execution.html |
| M17 | product/research/ missing from system-overview diagram | system-overview.html |
| M18 | No built-in vs custom agent distinction | architecture.html |
| M19 | Cost estimate step undocumented | execution.html |

## Documentation Changes

Documentation updated during Stage 4 (already on disk):

| File | Action | Summary |
|------|--------|---------|
| `documentation/plans/001-docs-sync/README.md` | Created | This fix plan |

Additional documentation gaps identified (not yet addressed):

| File | Needed Change |
|------|---------------|
| `docs/index.html` | May need update if governance level count or feature highlights changed — verify after tasks complete |
| `docs/getting-started.html` | May reference outdated skill names — low priority, verify after tasks complete |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| HTML editing breaks page layout/styles | Medium | Low | Review rendered output after each task; changes are text content only |
| System overview SVG/diagram is complex to edit | Medium | Medium | Read the diagram markup carefully; test render in browser |
| Fixing one section creates inconsistency with another | Low | Medium | Tasks 1-3 are independent file targets; Task 4 cross-references Task 1 output |
