## Task 1 Complete — Sync All HTML Documentation

### Files Modified

- **`docs/components.html`**
  - Skill table: Fixed triggers for 7 skills (feature-mode, debug-mode, doc-code-verification-mode, discovery-mode, init-project, help, tech-research, context-management), added 4 missing skills (critical-brainstorm, vscode-setup, tailscale-setup, tmux-team-grid), fixed plan-enhancer trigger (context: field not "all modes"), fixed docs-manager trigger (activated by .claude/docs-format), fixed discovery-mode description
  - Agent table: Removed `explore` row (built-in agent, not UC-custom), added `project-manager` row, fixed `task-tester` tools (Write, Edit, 12 Chrome tools, no disallowed), fixed `tech-knowledge` (added skills: [tech-research] note), fixed executor context (Patterns field), fixed reviewer context (all teammate names)
  - Added blockquote note explaining built-in vs custom agents

- **`docs/workflows.html`**
  - Feature Mode: Replaced 6-step flow with 4-stage framework (Understand→Research→Discuss→Write). Stage 2 shows Phase A (Code Surveyor + Doc Surveyor, primary) and Phase B (Explore, conditional). RFC moved to Stage 4 Step 1.
  - Debug Mode: Removed phantom "4.5 DOCUMENTATION UPDATE" phase. Aligned to 4-stage framework with Phase 2A/2B/2C research sub-phases. Doc updates now in Stage 4 Step 1.
  - Plan Execution summary: Updated with concurrency ranges, pipeline gate, PM, cost estimate, browser smoke test.

- **`docs/execution.html`**
  - Coordination model: Added Project Manager as 4th mechanism (JSON dashboard, watchdog, Tailscale, ALERTs, operational report)
  - Context bridge: Added knowledge-{PLAN_NAME} to all spawns, product/ docs for Tester, all teammate names for Reviewer, Patterns field for Executor
  - Concurrency table: 2/3/4 → 1-2/2-3/3-4 (ranges)
  - New Pipeline Gate section: documents early successor spawning, planning-only mode, PIPELINE-SPAWN event
  - Model table: Added Project Manager row, reordered
  - Team structure diagram: Added PM, fixed Tester tools (Write/Edit/Chrome), added naming convention (executor-N, reviewer-N, tester-N)
  - Step-by-step workflow: Added cost estimate step (f), PM spawn (h), pipeline gate in Phase 2, browser smoke test in Phase 5, PM operational report

- **`docs/architecture.html`**
  - "three specialized planning modes" → "four"
  - Discovery Mode: "Optional Pre-Step" → full `<h4>` planning mode
  - Feature Mode description: Updated to describe Phase A (surveyors, primary) + Phase B (Explore, conditional)
  - Feature Mode structure diagram: Restructured to show Phase A/B
  - RFC trigger: Clarified "during Stage 4 Step 1"
  - plugin.json: Added "contains only name/description/author" clarification
  - Added built-in vs custom agent distinction blockquote
  - Execution layer description: Added PM, concurrency ranges, pipeline gate

- **`docs/system-overview.html`**
  - Feature Mode card: Badges changed from "Explore, Docs Mgr" to "Code Surv., Doc Surv., Explore (cond.), Docs Mgr"
  - Execution layer: Added Project Manager card (sonnet, dashboard/stall detection/operational report)
  - Tester card: Fixed tools to "Read, Write, Edit, Glob, Grep, Bash + Chrome", updated description
  - Lead box: Updated description (cost estimate, pipeline gate)
  - Repo structure: Added `product/research/` directory
  - Support skills panel: Expanded from 6 to 10 skills, organized into 3 categories (Documentation & Research, Execution & Recovery, System & Infrastructure)

### Discrepancy Coverage

All discrepancies addressed:
- **Critical (7):** C1 ✓, C2 ✓, C3 ✓, C4 ✓, C5 ✓, C6 ✓, C7 ✓
- **Major (17 active):** M2 ✓, M3 ✓, M4 ✓, M5 ✓, M6 ✓, M8 ✓, M9 ✓, M10 ✓, M11 ✓, M12 ✓, M13 ✓, M14 ✓, M15 ✓, M16 ✓, M17 ✓, M18 ✓, M19 ✓
- **Deferred:** M7 (PM stage vocabulary) — not touched per plan
- **Invalidated:** M1 ([1m] context window) — already fixed
