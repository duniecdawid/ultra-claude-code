# Stage 4 — Compression

Scope: stage 4 of the build workflow — mechanical engine compression of body artifacts via the `uc:caveman-compress` agent, and item-by-item adoption of its cuts. No user gate; output flows into stage 5 — read `references/stage-5-present.md` when done.

Applies to body artifacts only — `prompt-body` | `doc-section` | `protocol-format`. Descriptions were finished at stage 3 and never reach the engine.

**Human-facing exemption.** Artifacts whose text humans read directly or that is relayed to users verbatim — the `skills/help` catalog entries, README prose, onboarding/getting-started text — skip this stage entirely: structural cuts (stage 1) apply, register compression does not. Caveman register in human-facing prose reads as broken English and pays back its token savings in comprehension. [JUDGMENT, user directive 2026-07-29 — the help SKILL.md engine pass was reverted for this reason.]

## Spawn

One spawn per artifact; several artifacts → all spawns in one message, concurrently. The artifact path is the **real file** — it already carries the stage 1–3 edits. (Superseded 2026-08-06: the workflow no longer runs in native plan mode, which blocked the engine's writes; the engine runs during this stage.)

```
Agent(
  subagent_type: "uc:caveman-compress",
  run_in_background: false,          # results are needed before presenting
  description: "compress <artifact>",
  prompt: "Artifact: <absolute path, or the inline text>.
           Kind: prompt-body | doc-section | protocol-format.
           Payload zones: <inventory from stage 1; or none>.
           Siblings it must stay distinguishable from: <paths, or none>."
)
```

## Adopt

Work the returned CUTS list **item by item**: adopt `clean` cuts as-is, adopt `fixable` cuts in their repaired form, skip `harmful` ones. Never accept or reject a proposition wholesale — yield percentage is diagnostic information, not a decision rule. Fold adopted cuts directly into the file and surface the results in discussion.

- If the agent cannot be spawned (not installed in this session), say so explicitly and apply the house rules in `efficient-communication.md` by hand — never silently skip the step.
