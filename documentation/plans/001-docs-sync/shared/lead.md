# Lead Notes: 001-docs-sync

## Plan Overview
Docs-only plan: update 5 HTML files in docs/ to match current agent and skill code after rapid iteration (15 commits on 2026-03-14).

## Concurrency
Single task-team (1 Executor + 1 Reviewer + 1 Tester). No Tech Knowledge or PM needed — pure HTML docs work.

## Key Constraints
- Do NOT modify any agent or skill code — docs only
- Read agent `.md` frontmatter and skill `SKILL.md` frontmatter as source of truth
- M7 (PM stage vocabulary mismatch) is DEFERRED — do not attempt to fix
- M1 ([1m] context window) is INVALIDATED — models correctly show plain sonnet/opus after cleanup commit 2026.03.14-15

## Task Dependency Graph
- Task 1: no dependencies (single consolidated task)

## Discrepancy Reference
See plan README.md "Discrepancy Reference" section for full C1-C7, M2-M19 list.
