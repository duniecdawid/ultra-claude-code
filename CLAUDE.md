# Ultra Claude

## Version History

On every commit, update `skills/help/VERSION_HISTORY.md`:

1. Add a new row at the top of the table with the current date and a short description of the changes
2. Version format: `YYYY.MM.DD-N` where N starts at 1 and increments if there are multiple commits on the same day
3. Check the latest existing entry to determine the correct build number for today

## Version Consistency — MANDATORY

On every commit that modifies plugin content, bump the version in **both** files and keep them in sync:
- `.claude-plugin/plugin.json` — the plugin's own version
- `.claude-plugin/marketplace.json` — the marketplace's version for the `uc` plugin

Use semver: patch for typos/docs, minor for new capabilities, major for breaking changes.

## Help Skill Sync — MANDATORY

When editing any skill (`skills/*/SKILL.md`) or agent (`agents/*.md`), update the corresponding 3-sentence description in `skills/help/SKILL.md`.

Rule: each skill and agent gets exactly 3 sentences in the help knowledge base:
1. What it does (capability)
2. When to use it (trigger/context)
3. What it produces or enables (outcome)
