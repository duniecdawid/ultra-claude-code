# Ultra Claude Version History

| Version | Date | Changes |
|---------|------|---------|
| 2026.03.15-5 | 2026-03-15 | Tech Knowledge agent: move constraints to top, add explicit "never read codebase" directive — agent should only research external docs, not browse project source |
| 2026.03.15-4 | 2026-03-15 | Dashboard staleness detection: show warning/critical banners on detail view and stale dots on homepage when PM stops updating status files (executing plans only) |
| 2026.03.15-3 | 2026-03-15 | Add /uc:setup skill — one-time machine setup (1M context env vars, agent teams, tmux, node, optional Tailscale). Writes version marker to ~/.claude/uc-setup.json for quick currency checks. Plan-execution now checks setup marker and suggests /uc:setup when missing. |
| 2026.03.15-2 | 2026-03-15 | Reinforce 3-digit zero-padded plan numbering in plan-enhancer skill and plan template |
| 2026.03.15-1 | 2026-03-15 | Docs-code sync: fix all HTML docs to match current agents/skills — fix agent tables (add project-manager, fix task-tester tools, remove phantom explore), add 4 missing skills, update workflows to 4-stage framework, add pipeline gate and PM coordination to execution docs, fix architecture claims and system overview diagram |
| 2026.03.14-17 | 2026-03-14 | Global singleton PM dashboard: single persistent server aggregates all projects/plans on port 3847, PM registers/deregisters plans via API, one URL for all executions |
| 2026.03.14-16 | 2026-03-14 | tmux-team-grid: fix Write tool error — skill only has Bash, must use cat heredoc to write script file |
| 2026.03.14-15 | 2026-03-14 | Fix 1M context for real: Agent tool model enum doesn't support [1m] suffix — use ANTHROPIC_DEFAULT_*_MODEL env vars in .bashrc instead; clean up misleading [1m] from agent frontmatter and skill spawn instructions |
| 2026.03.14-14 | 2026-03-14 | Add version field to plugin.json (0.1.0), add version consistency rule to CLAUDE.md |
| 2026.03.14-13 | 2026-03-14 | tmux-team-grid: adaptive layouts (startup/execution/final-gate), cross-session isolation fixes, final-gate pane support; plan-execution: pane-diffing for knowledge/PM/final-gate spawns |
| 2026.03.14-12 | 2026-03-14 | Fix 1M context not working: add [1m] suffix to spawn Model instructions in plan-execution skill (was overriding agent frontmatter); add pane title tracking to PM and tmux-team-grid improvements |
| 2026.03.14-11 | 2026-03-14 | Remove Glob/Grep from Tech Knowledge agent to prevent codebase analysis; expand research brief template with verbatim doc excerpts for executors |
| 2026.03.14-10 | 2026-03-14 | Add proactive technology research: Code Reviewer queries Tech Knowledge to verify external library usage against docs, Tech Knowledge sends research briefs to executors on task spawn, new [DOCS] failure category |
| 2026.03.14-9 | 2026-03-14 | Enable 1M context for Code Reviewer, Task Tester, and Project Manager (sonnet[1m]) agents |
| 2026.03.14-8 | 2026-03-14 | Enable 1M context for Task Executor (opus[1m]) and Tech Knowledge (sonnet[1m]) agents |
| 2026.03.14-7 | 2026-03-14 | Restructure planning to 4-stage framework (Understand → Research → Discuss → Write). Add mandatory Discussion Protocol before file writing. Move doc updates to Stage 4. Fix plan directory numbering enforcement. |
| 2026.03.14-6 | 2026-03-14 | Add proactive standards review: plan-enhancer annotates tasks with specific pattern files, executor/reviewer use targeted patterns, tester gains test-writing capability |
| 2026.03.14-5 | 2026-03-14 | Add `skills: [tech-research]` to Tech Knowledge agent — preloads research methodology into agent context at spawn |
| 2026.03.14-4 | 2026-03-14 | Replace per-task Researchers with shared Tech Knowledge agent + Explore agents. Teams now 3 agents (Executor/Reviewer/Tester) + 1 shared knowledge agent. Executors do their own codebase research. |
| 2026.03.14-3 | 2026-03-14 | Add critical-brainstorm skill: devil's advocate mode with web research, critical analysis, and interactive discussion |
| 2026.03.14-2 | 2026-03-14 | Add sequential numbering to plan folders (001-name format) with number-based execution references |
| 2026.03.14-1 | 2026-03-14 | Fix missing pipeline stage updates: Lead now sends STAGE messages for research, planning, and implementation to PM dashboard |
| 2026.03.13-2 | 2026-03-13 | Add CLAUDE.md with version history commit instructions |
| 2026.03.13-1 | 2026-03-13 | Add version history display to help skill |
| 2026.03.12-1 | 2026-03-12 | Unify task list: merge plan tasks and active teams into single mobile-first view |
| 2026.03.11-2 | 2026-03-11 | Add Plan Tasks section to status dashboard |
| 2026.03.11-1 | 2026-03-11 | Fix PM dashboard CWD bug: use absolute paths for all plan directory operations |
| 2026.03.10-2 | 2026-03-10 | Refactor PM to dashboard/monitoring role, Lead owns all orchestration |
| 2026.03.10-1 | 2026-03-10 | Add tailscale-setup skill for configuring serve/funnel |
