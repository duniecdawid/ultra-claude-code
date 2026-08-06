# Stage 5 — Present

Scope: stage 5 of the build workflow — presenting the finished build as a `git diff`, the explicit approval gate, and post-approval sync + commit.

## Assemble

Present:

- The `git diff` of the build (non-git target: diff against the scratchpad backup).
- Remaining execution steps: the before/after trigger test for any description change; and the repo's sync obligations — help-skill 3-sentence entry for every touched skill/agent, docs-site pages (scan `docs/views/` for pages referencing the affected functionality), CHANGELOG.json entry, version bump in both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`.

## Present and discuss — approval gate

Same rule as earlier stages: explicit approval only ("approved", "ship it"); conversational acknowledgements don't count. Discuss and revise — edit the files and re-present after changes. Rejection = `git restore` (non-git target: restore the scratchpad backup).

## Execute

After approval, run the trigger test and sync steps, then commit. Scope discovered mid-execution that touches artifacts not named in the presented diff → stop and surface it; never silently expand.
