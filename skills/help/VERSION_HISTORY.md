# Ultra Claude Version History

| Version | Date | Changes |
|---------|------|---------|
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
