# Stage 3 — Compression

Scope: stage 3 of the build workflow — mechanical engine compression of body artifacts via the `uc:caveman-compress` agent, and item-by-item adoption of its cuts. No user gate; output flows into stage 4.

Applies to body artifacts only — `prompt-body` | `doc-section` | `protocol-format`. Descriptions were finished at stage 2 and never reach the engine.

**Human-facing exemption.** Artifacts whose text humans read directly or that is relayed to users verbatim — the `skills/help` catalog entries, README prose, onboarding/getting-started text — skip this stage entirely: structural cuts (stage 1) apply, register compression does not. Caveman register in human-facing prose reads as broken English and pays back its token savings in comprehension. [JUDGMENT, user directive 2026-07-29 — the help SKILL.md engine pass was reverted for this reason.]

## Spawn

One spawn per artifact; several artifacts → all spawns in one message, concurrently.

**The engine cannot run inside plan mode** [MEASURED 2026-07-30] — it overwrites its target and writes a backup under `~/.local/share/caveman-compress/backups/`, and plan mode blocks writes wherever they land. Hand-compressing instead is forbidden while the CLI is reachable (`efficient-communication.md` § Never). So a build task carries the pass as its **first execution action**: stage 3 spawns the agents anyway (their read-only prep — sibling discriminators, off-limits spans, byte-exact inventory — is what makes the later run one-shot), stage 4 records the stage-2 text as documented compression input, and the run happens against the real files once the plan is approved. Re-message the same agents by `agentId` rather than re-spawning; they resume with their prep intact.

```
Agent(
  subagent_type: "uc:caveman-compress",
  run_in_background: false,          # results are needed to assemble the plan
  description: "compress <artifact>",
  prompt: "Artifact: <absolute path, or the inline text>.
           Kind: prompt-body | doc-section | protocol-format.
           Payload zones: <inventory from stage 1; or none>.
           Siblings it must stay distinguishable from: <paths, or none>."
)
```

## Adopt

Work the returned CUTS list **item by item**: adopt `clean` cuts as-is, adopt `fixable` cuts in their repaired form, skip `harmful` ones. Never accept or reject a proposition wholesale — yield percentage is diagnostic information, not a decision rule. Fold adopted cuts into the final artifact text in the plan file.

- Any adopted description change (from stage 2 or exposed here) requires the before/after trigger test (`testing-refactors.md`) as an execution step in the plan.
- If the agent cannot be spawned (not installed in this session), say so explicitly and apply the house rules in `efficient-communication.md` by hand — never silently skip the step.
