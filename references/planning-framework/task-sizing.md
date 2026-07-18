# Planning Framework — Task Sizing

Canonical rules for how many tasks a plan gets and how big each task is. This file is consumed at **two points**:

1. **Stage 3 entry** — read before composing the opening synthesis, to build the **Proposed task breakdown** that opens the discussion (see `stage-3.md`).
2. **Stage 4 sizing gate** — re-applied before plan files are written, to confirm the final task list matches what was agreed in discussion (see `stage-4.md` Step 4).

## The cost model — why fewer, larger tasks

Every task spins up a **full pipeline team**: Executor + Reviewer + Tester, each a separate agent with its own context, spawn overhead, and coordination traffic. Token cost scales with the **number of teams**, not with task size — a plan of 6 small tasks costs roughly three times the coordination overhead of a plan of 2 large ones for the same code.

All model tiers run with **1M context**. A task can comfortably carry ~40 files of scope; context capacity is not a reason to split. **Fewer, larger tasks is the explicit goal.** When sizing feels ambiguous, err large.

## Merge-first algorithm

Start from **1 task**. Every split must earn its existence:

1. Draft the whole plan as a single task.
2. Split only where **both** conditions hold:
   - The pieces are truly independent features — no shared files, and no dependency chain that forces them to run sequentially anyway.
   - Merging would concretely hurt — name the harm (e.g., the combined diff exceeds the ~40-file band, or the pieces have disjoint review domains that would dilute the Reviewer).
3. Write the justification down. "It feels like two things" is not a justification. A dependency chain (A must precede B) is an argument for **merging** into one sequential task, not for splitting — splitting sequential work buys no parallelism and doubles team overhead.

## Size band

- **Minimum ~10 files per task.** Below that, absorb it into a neighboring task — the pipeline overhead isn't justified. No exceptions without written justification in the sizing table.
- **Maximum ~40 files per task.** Above that, consider splitting — but only along independent-feature boundaries, never arbitrary lines or tech layers.

## Structural rules

- **Split by feature, not by tech layer.** Each task delivers a complete vertical slice (database through API/UI). Never split into "backend task" and "frontend task" for the same feature.
- **Testing is part of the execution pipeline, not a separate task.** Every task's team includes a Tester.
- **Documentation updates are not tasks.** Doc changes happen in Stage 4 Steps 2-3, before the plan is written.

## Required output — the sizing table

Sizing is not applied silently. Produce a table, one row per task:

| Task | Est. files | Why it can't merge with a neighbor | Verdict |
|------|-----------|-----------------------------------|---------|
| 1. {name} | ~N | {independence justification} | in band / justified exception |

For a **single-task plan**, replace the table with one line: `1 task — no split needed.`

The table appears in three places:
- **Stage 3 opening synthesis** — as the Proposed task breakdown, up for discussion.
- **Plan README** — under `## Task Sizing` (written in Stage 4 Step 5a; gives the Project Manager's retrospective a predicted-vs-actual baseline).
- **Stage 4 approval summary** — file estimates on each task line (Step 6).

## Hard cap — more than 4 tasks needs explicit agreement

A plan exceeding **4 tasks** requires the user's explicit agreement to the split. Normally this happens naturally in Stage 3 when the breakdown is discussed. If a >4-task split was never explicitly agreed there — or the task count grew after the discussion — STOP at the Stage 4 sizing gate before writing any files and ask via AskUserQuestion: "This plan splits into N tasks — approve the split, or merge?" Only explicit approval proceeds.
