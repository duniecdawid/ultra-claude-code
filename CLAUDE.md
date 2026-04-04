# Ultra Claude

## Versioning — MANDATORY

Single version format everywhere: `YYYY.MM.DD-N` where N starts at 1 and increments for multiple commits on the same day.

On every commit:
1. Update `CHANGELOG.json` — add a new entry at the **top** of the array with:
   - `seq`: previous highest seq + 1 (always increments, never reused — check `jq '.[0].seq' CHANGELOG.json` for current highest)
   - `version`: today's date-based version
   - `date`: today's date
   - `summary`: concise description of the change
   - `migration`: `null` unless this commit changes project-level file structure (see Migration Registry below)
2. Bump the version in **both** files (keep them in sync):
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
3. Check the latest existing entry to determine the correct build number for today

## Migration Registry — MANDATORY

When a commit changes files that exist in projects using Ultra Claude (anything under `documentation/`, `.claude/ultra/`, or the CLAUDE.md template), add a `migration` block to that commit's CHANGELOG.json entry. Include precondition, actions, and conflict guidance. Actions can be typed objects for mechanical operations or plain strings for instructions that require judgment. See existing migration entries in CHANGELOG.json for the format.

Not every commit needs a migration entry — only those that affect what files exist in projects that use Ultra Claude.

## Help Skill Sync — MANDATORY

When editing any skill (`skills/*/SKILL.md`) or agent (`agents/*.md`), update the corresponding 3-sentence description in `skills/help/SKILL.md`.

Rule: each skill and agent gets exactly 3 sentences in the help knowledge base:
1. What it does (capability)
2. When to use it (trigger/context)
3. What it produces or enables (outcome)
