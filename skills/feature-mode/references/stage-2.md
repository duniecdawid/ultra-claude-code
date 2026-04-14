# Feature Mode — Stage 2: Research

Before applying the rules below, read the base rules:
`${CLAUDE_PLUGIN_ROOT}/references/planning-framework/stage-2.md`

The instructions below extend the base rules with feature-mode-specific behavior.
**Precedence:** base first, then extensions. If they conflict, the extension wins.

## Mode Extensions

Use the base research skills (code-surveyor, doc-surveyor, research) to understand how the feature fits into the existing system. Scope the surveyors with these focal points:

- **Code** — What components will this feature build on, extend, or interact with?
- **Documentation** — What architecture, product description, and requirements docs are relevant?
- **External libraries** — Are there new dependencies or integrations to investigate? Invoke `/uc:research` whenever the answer is yes — it's cache-first, so repeated lookups across plans are free.

If the surveyors reveal **cross-component complexity** (a feature touching multiple subsystems with non-obvious interactions) or **undocumented patterns** (code conventions that need to be understood before extending), spawn additional Explore agents to do deeper investigation. The base surveyors give you a structural map; Explore gives you the line-by-line context for the parts that matter.

## Feature-Mode Tech Stack Sweep

The base Stage 2 rules mandate a Tech Stack sweep via `/uc:research --fill-only`. For feature mode, the file set for the sweep comes from your draft task breakdown. Concretely:

1. After the initial code-surveyor pass, you'll have a picture of the files this feature will create or extend. Write out the draft file list in your working notes.
2. For every file in that list that already exists, read its imports/requires/use declarations. For new files you plan to create, anticipate which libraries they'll pull in (from the existing patterns the code-surveyor surfaced — if you're adding a new API endpoint to an Express app, it'll import express, zod, and whatever ORM the rest of the codebase uses).
3. Deduplicate the resulting library list.
4. Sweep: one `/uc:research {library} --fill-only` call per library. The skill's canonicalization rules route different phrasings of the same library to the same research file, so you don't need to worry about "did I already research this under a different name."
5. Track the library-to-draft-task mapping in your working notes. You'll use this mapping in Stage 4 Step 5b to populate each `task.md`'s `**Research:**` section.

**Do this even when the feature is "just extending existing code."** The whole point of the rule is that "existing libraries" are often the ones that most need verification — the planner's training-data memory of that library may be stale, and the execution teams will be writing against whatever the current version actually looks like, not what the planner remembers.

## Stage Transition

When the base verification gates pass and you have synthesized findings you can discuss, announce:

> **▶ PROCEED TO STAGE 3: DISCUSS**

Then read:
`${CLAUDE_PLUGIN_ROOT}/skills/feature-mode/references/stage-3.md`
