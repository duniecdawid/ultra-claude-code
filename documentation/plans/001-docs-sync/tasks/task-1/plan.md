# Task 1 Implementation Plan — Sync All HTML Documentation

## Overview

Update all 5 HTML documentation files to match current agent/skill code. Changes are text-content only — no CSS/JS/layout changes.

## File-by-File Changes

### 1. `docs/components.html`

**Agent table fixes:**
- **Remove `explore` row** (line 104). Replace with a note below the agent table explaining that Explore is a built-in Claude Code agent type (`subagent_type: Explore`), not a UC-custom agent file in `agents/`.
- **Add `project-manager` row** after market-analyzer: model `sonnet`, tools `Read, Write, Glob, Grep, Bash`, no disallowed tools, description from frontmatter, spawned as Teammate (execution, one per plan).
- **Fix `task-tester` row** (line 106): Change tools from `Read, Glob, Grep, Bash` to `Read, Write, Edit, Glob, Grep, Bash` + 12 `mcp__claude-in-chrome__*` tools. Remove `Write, Edit` from disallowed tools column (set to `—`). Update description to mention browser/Chrome testing and test file creation capability.
- **Fix `tech-knowledge` row** (line 103): Add note about `skills: [tech-research]` frontmatter field.

**Skill table fixes:**
- **Add 4 missing skills:** `vscode-setup`, `tailscale-setup`, `critical-brainstorm`, `tmux-team-grid` — all user-invocable: true.
- **Fix `plan-enhancer` trigger** (line 21): Change "Auto-loaded by all modes" to "Loaded by feature-mode, debug-mode, doc-code-verification-mode, init-project via context: field"
- **Fix `docs-manager` trigger** (line 24): Change "audit docs", "reorganize docs", "regenerate index" to actual triggers: "audit, reorganize, or regenerate index" (argument-hint), activation via `.claude/docs-format` file.
- **Fix `discovery-mode` trigger** (line 23): Change "research only" to actual triggers from SKILL.md: "discovery mode", "discovery", "research topic", "gather requirements", "define persona", "product research"
- **Fix `feature-mode` triggers** (line 18): Add missing "add feature"
- **Fix `debug-mode` triggers** (line 19): Add missing "bug", "issue"
- **Fix `doc-code-verification-mode` triggers** (line 20): Add missing "doc verification"
- **Fix `init-project` triggers** (line 27): Add missing "bootstrap project", "onboard project", "onboard existing project"
- **Fix `help` triggers** (line 28): Add "what should I use for Y"
- **Fix `tech-research` triggers** (line 29): Add missing triggers: "why is X failing", "best practice for X", "what changed in X", "look up docs", "check documentation"
- **Fix `context-management` triggers** (line 26): Add "add API docs"

### 2. `docs/workflows.html`

**Feature Mode workflow (lines 15-51):**
- Replace the 6-step flow with the 4-stage framework:
  - Stage 1: UNDERSTAND (scope challenge)
  - Stage 2: RESEARCH — Phase A: Code Surveyor + Doc Surveyor (primary); Phase B: Explore agent (conditional, only when surveyors reveal gaps)
  - Stage 3: DISCUSS (synthesis, brainstorm, exit gate)
  - Stage 4: WRITE (documentation updates including RFC sub-mode, plan scaffolding, approval, post-approval)
- Remove Explore as mandatory step — it's conditional in Phase B

**Debug Mode workflow (lines 210-251):**
- Remove phantom "4.5 DOCUMENTATION UPDATE" phase (lines 229-231)
- The 4-stage framework applies: Stages 1-2 are Debug Mode's, Stages 3-4 are Plan Enhancer's
- Documentation updates happen in Stage 4 Step 1 (inherited from Plan Enhancer)

**Plan Execution summary (line 64):**
- Change "2-4 teams" to note concurrency ranges (1-2/2-3/3-4 not hard ceilings)
- Add pipeline gate mechanism mention
- Add browser smoke test to final gate description

### 3. `docs/execution.html`

**Concurrency table (lines 164-172):**
- Change hard ceilings to ranges: 1-3 tasks → 1-2, 4-8 → 2-3, 9+ → 3-4

**Pipeline gate (new section after concurrency):**
- Add section documenting pipeline-mode task spawning
- When executor signals "implementation complete", Lead checks for dependent successors
- Successor spawned in planning-only mode (implementation blocked until predecessor passes)
- Pipeline-spawned tasks don't count against concurrency while in planning-only mode
- PIPELINE-SPAWN event type

**Context bridge table (lines 48-54):**
- Add `knowledge-{PLAN_NAME}` teammate name to executor context
- Add `documentation/product/` to Tester's context
- Fix Reviewer context to show all teammate names

**Coordination model table (lines 23-36):**
- Add Project Manager as 4th coordination mechanism: JSON dashboard, background watchdog, Tailscale HTTPS, stall detection, operational report

**Team structure diagram (lines 112-155):**
- Add Project Manager to the diagram

**Tester in team structure:**
- Fix Task Tester tools to include Write, Edit, and chrome tools
- Remove DisallowedTools line for Tester

**Final gate (Phase 5, line 394-400):**
- Add browser smoke test for frontend projects

**Cost estimate step:**
- Add step 1.5 between setup and spawning documenting the cost estimate + user confirmation

**Executor spawn example (lines 57-67):**
- Fix to show Patterns field instead of generic architecture docs path
- Add dependency graph mention in lead.md description

### 4. `docs/architecture.html`

- **Line 175**: Change "three specialized planning modes" to "four" (Feature, Debug, Verification, Discovery)
- **Discovery Mode section (lines 220-224)**: Change from "Optional Pre-Step" to a full planning mode
- **Feature Mode description (lines 188-198)**: Change "Spawns Explore agent + loads Docs Manager" to "Spawns Code Surveyor + Doc Surveyor (Phase A, primary); conditionally spawns Explore agent (Phase B, when surveyors reveal gaps)"
- **Feature Mode structure diagram (lines 280-295)**: Restructure to show Phase A (Code Surveyor + Doc Surveyor) as primary, Explore as conditional Phase B
- **RFC trigger timing**: Clarify it happens during Stage 4 Step 1, not earlier
- **plugin.json description**: Fix to state it contains only name/description/author
- **Add note** distinguishing built-in Claude Code agents (Explore) from UC-custom agents (files in agents/)

### 5. `docs/system-overview.html`

- **Execution layer (lines 1044-1120)**: Add project-manager agent card to the team flow
- **Feature Mode card (line 977-985)**: Change agent badges from `Explore, Docs Mgr` to `Code Surv., Doc Surv., Explore (cond.), Docs Mgr`
- **Support skills panel (lines 1178-1207)**: Add missing skills: `vscode-setup`, `tailscale-setup`, `critical-brainstorm`, `tmux-team-grid`
- **Repo structure tree (lines 1130-1170)**: Add `product/research/` to the documentation tree
- **Tester card (lines 1093-1099)**: Fix tools to include Write, Edit, Chrome tools

## Risks

- HTML structure is complex with inline styles — careful to maintain consistent formatting
- system-overview.html uses custom CSS classes for layout — agent card additions must match existing patterns exactly
