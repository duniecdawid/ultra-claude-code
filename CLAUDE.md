# Ultra Claude

## Versioning — MANDATORY

Single version format everywhere: `YYYY.MM.DD-N` where N starts at 1 and increments for multiple commits on the same day.

On every commit:
1. Update `skills/help/VERSION_HISTORY.md` — add a new row at the top with the current date and a short description
2. Bump the version in **both** files (keep them in sync):
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
3. Check the latest existing entry to determine the correct build number for today

## Dashboard Restart — MANDATORY

When editing any file under `scripts/ultra-dashboard/`, restart the dashboard after committing so the changes take effect. Use: `pkill -f "node.*ultra-dashboard"; sleep 1; node scripts/ultra-dashboard/server.js &`

## Help Skill Sync — MANDATORY

When editing any skill (`skills/*/SKILL.md`) or agent (`agents/*.md`), update the corresponding 3-sentence description in `skills/help/SKILL.md`.

Rule: each skill and agent gets exactly 3 sentences in the help knowledge base:
1. What it does (capability)
2. When to use it (trigger/context)
3. What it produces or enables (outcome)
