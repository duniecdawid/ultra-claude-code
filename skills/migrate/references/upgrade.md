# Upgrade Mode

The project has a version marker — you know exactly where it stands. Your job is to apply only the migrations needed to bring it current.

## Why this matters

Running the full init flow on an existing project is disruptive and slow. Most Ultra Claude updates don't change project structure at all. When they do, the changes are small and specific — a renamed directory, a new required file, a config path change. This mode applies just those targeted changes without re-exploring the entire codebase.

Migrations may depend on previous ones (e.g., "create tracker" must happen before "rename tracker to backlog"), which is why they're always applied in seq order.

---

## Process

### Step 1: Determine pending migrations

```bash
# Read the project's current state
LAST_SEQ=$(jq -r '.lastMigratedSeq' .claude/ultra/version.json)
CURRENT_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
CURRENT_SEQ=$(jq '.[0].seq' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")

echo "Project at seq $LAST_SEQ, Ultra at seq $CURRENT_SEQ ($CURRENT_VERSION)"

# Get pending migrations (only entries with migration blocks, ordered oldest-first)
jq --argjson last "$LAST_SEQ" '[.[] | select(.seq > $last and .migration != null)] | reverse' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

If no pending migrations exist, tell the user: "Project is up to date at v{version} (seq {seq})." Then stop — no version stamp update needed.

### Step 2: Evaluate preconditions

For each pending migration, check its precondition against the project's filesystem. Preconditions tell you whether a migration is relevant to this particular project:

- `{"exists": "path"}` — check if the file/directory exists
- `{"not_exists": "path"}` — check if it does NOT exist
- `{"file_contains": {"path": "...", "pattern": "..."}}` — grep the file for the pattern
- `{"any": [...]}` — at least one sub-condition must be true (OR)
- `{"all": [...]}` — all sub-conditions must be true (AND)
- String preconditions — evaluate the prose description against the filesystem

Skip migrations whose preconditions aren't met. A project that never had a `documentation/tracker/` directory doesn't need the tracker-to-backlog rename. This is expected and normal — note it in the report but don't warn.

### Step 3: Present migration plan

Show the user what will happen. For each applicable migration:

> **Pending migrations: {project version} → {current version}**
>
> **1. v2026.03.31-6 — Rename Tracker to Backlog**
> - Rename `documentation/tracker/` → `documentation/backlog/`
> - Split tracker.json into 4 category files
> - Update CLAUDE.md references
>
> **2. v2026.04.03-2 — Consolidate Ultra Config**
> - Move `.claude/docs-format` → `.claude/ultra/docs-format`
> - Move `.claude/app-context-for-research.md` → `.claude/ultra/app-context.md`
>
> **Skipped** (precondition not met):
> - v2026.03.28-1 — Testing Config Multi-file (no `.claude/system-test.md`)

Flag any conflicts — files that might have user customizations. Ask the user:

Options: "Apply all" / "Review each" / "Skip"

### Step 4: Execute

Apply approved migrations in seq order (oldest first). For each action in a migration:

**Typed actions** — execute directly:
- `rename-file`: `mv` the file, creating target directory if needed
- `rename-directory`: `mv` the directory
- `create-directory`: `mkdir -p`
- `create-file`: write from template only if the file doesn't exist
- `delete-file`: remove after confirming the migration succeeded
- `split-file`: read the source, divide content logically, write target files
- `set-default`: write content only if file doesn't already exist
- `ensure-files`: create from template any files matching the pattern that don't exist

**String actions** — these are instructions that require your judgment. Read the instruction, understand what it asks, and carry it out. Before modifying any file the user may have customized, show what will change and get confirmation.

### Step 5: Stamp version

Update `.claude/ultra/version.json` — only the `lastMigrated` fields change:

```bash
CURRENT_VERSION=$(jq -r '.version' "${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json")
CURRENT_SEQ=$(jq '.[0].seq' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json")

jq --arg v "$CURRENT_VERSION" --argjson s "$CURRENT_SEQ" --arg t "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)" \
  '.lastMigrated = $v | .lastMigratedSeq = $s | .migratedAt = $t' \
  .claude/ultra/version.json > .claude/ultra/version.json.tmp && mv .claude/ultra/version.json.tmp .claude/ultra/version.json
```

### Step 6: Report — What Changed + What's New

Print two sections, formatted nicely for the human:

**Migration Report:**
- Applied: list each migration with a brief summary of what was done
- Skipped: list each with why (precondition not met — name the missing file/directory)
- Conflicts: note any that were resolved and how

**What's New in Ultra Claude:**

```bash
# Get ALL entries between old and new seq (not just migrations)
LAST_SEQ=$(jq -r '.lastMigratedSeq' .claude/ultra/version.json.bak 2>/dev/null || echo 0)
jq --argjson last "$LAST_SEQ" '[.[] | select(.seq > $last)] | reverse | .[] | "\(.version) — \(.summary)"' "${CLAUDE_PLUGIN_ROOT}/CHANGELOG.json"
```

Format this as a readable highlight reel — group entries by theme when there are many (new skills, dashboard improvements, bug fixes, etc.). This is the user's release notes. Include tips if new features are relevant to their project.
