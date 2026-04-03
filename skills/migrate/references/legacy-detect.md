# Legacy Project Detection

This project has Ultra Claude documentation structure but no version marker — it was set up before version tracking existed. Your job is to figure out what's already in place, offer to apply anything that's missing, and stamp a version marker so future upgrades work cleanly.

## Why this mode exists

Early Ultra Claude projects were initialized without version tracking. They may have some migrations applied (e.g., the tracker-to-backlog rename happened manually) but not others (e.g., docsify READMEs were never added). Rather than guessing, we check the filesystem to determine what's already done.

---

## Process

### Step 1: Read all migrations

```bash
# Get all migration entries from the changelog
jq '[.[] | select(.migration != null)]' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

### Step 2: Classify each migration

For each migration entry, evaluate its precondition against the project's current filesystem. The precondition describes the state that *triggers* the migration — if the precondition is met, the old state still exists and the migration hasn't been applied yet.

Classify each as:

- **Already applied** — precondition is NOT met (the trigger state is gone, meaning the migration was already done). For example, if the precondition checks for `documentation/tracker/` and that directory doesn't exist but `documentation/backlog/` does, the rename was already applied.

- **May need applying** — precondition IS met (the old state still exists). For example, `.claude/docs-format` exists at the old path instead of `.claude/ultra/docs-format`.

- **Not applicable** — neither old nor new state exists (the project never used this feature). For example, no `.claude/system-test.md` and no `documentation/technology/testing/` — the project was set up after the testing migration and simply never had the old format.

### Step 3: Present findings

Show the user a clear summary:

> **Legacy project detected** — no version marker found.
>
> I've checked your project against all known Ultra Claude migrations:
>
> **Already applied:**
> - v2026.03.31-6 Rename Tracker to Backlog — `documentation/backlog/` exists
> - v2026.03.28-1 Testing Config Multi-file — `documentation/technology/testing/` exists
>
> **May need applying:**
> - v2026.03.31-1 Docsify READMEs — 3 category directories missing README.md
> - v2026.04.03-2 Consolidate Ultra Config — `.claude/docs-format` at old path
>
> **Not applicable:**
> - v2026.03.31-2 Tracker Introduction — project never had tracker or dependencies

Options: "Apply all pending" / "Review each" / "Just stamp current version"

### Step 4: Apply chosen migrations

Follow the same execution logic as upgrade mode (see `references/upgrade.md` Step 4). Apply in seq order.

If the user chooses "Just stamp current version" — skip all migrations and go directly to stamping. The user is saying "my project is fine as-is, just start tracking from here."

### Step 5: Stamp version marker

Write `.claude/ultra/version.json` with `initialized` set to `"unknown"` (since we don't know which version originally set up the project):

```json
{
  "initialized": "unknown",
  "initializedSeq": 0,
  "lastMigrated": "{current version}",
  "lastMigratedSeq": {current seq},
  "migratedAt": "{ISO timestamp}"
}
```

### Step 6: Report

Print the migration report and "What's New" summary (see upgrade.md Step 6). For legacy projects, show the last 10 changelog entries rather than a diff since there's no previous version to diff from.
