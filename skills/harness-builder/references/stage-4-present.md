# Stage 4 — Present

Scope: stage 4 of the build workflow — assembling the final plan, presenting it via ExitPlanMode, and post-approval execution.

## Assemble

The plan file must contain:

- Final text (or a precise diff) for every artifact, as settled through stages 1–3.
- Execution steps: the file writes; the before/after trigger test for any description change; and the repo's sync obligations — help-skill 3-sentence entry for every touched skill/agent, docs-site pages (scan `docs/views/` for pages referencing the affected functionality), CHANGELOG.json entry, version bump in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## Present and discuss

Call `ExitPlanMode`. Discuss and revise — edit the plan file and re-present after changes. Approval arrives only through plan-mode approval; don't poll for it.

## Execute

After approval, execute exactly the approved plan. Scope discovered mid-execution that touches artifacts not named in the plan → stop and surface it; never silently expand.
