---
description: >-
  Manage project tracker — lightweight backlog split into four categories:
  bugs, external blockers, ideas, and technical debt. Each category has its own
  file in documentation/tracker/. Add, list, update, close, and link items.
  Use whenever the user wants to track something for later, note a future
  consideration, log a bug, record an external dependency, flag tech debt,
  check what's on the backlog, or ask "what should we work on next". Also use
  when other skills or agents discover follow-up work or issues worth remembering.
  Triggers on "tracker", "track", "add idea", "add bug", "add dependency",
  "tech debt", "what should we do", "backlog", "open items", "track this",
  "note for later", "remember to", "follow up on".
argument-hint: "command + details (e.g., 'add idea: cache API responses', 'list bugs', 'done B-003')"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Tracker

Manage the project's tracker — a lightweight backlog split across four category files in `documentation/tracker/`.

**Command:** `$ARGUMENTS`

## Categories and Files

| Category | File | ID Prefix | Signals |
|----------|------|-----------|---------|
| **Bugs** | `documentation/tracker/bugs.json` | `B-NNN` | defects, crashes, errors, "broken", "fails", "doesn't work", "wrong" |
| **External** | `documentation/tracker/external.json` | `E-NNN` | external blockers, waiting on third parties, "blocked by", "need X from", "waiting for", "depends on" |
| **Ideas** | `documentation/tracker/ideas.json` | `I-NNN` | considerations, improvements, "we should", "consider", "maybe", "it would be nice", future features |
| **Tech Debt** | `documentation/tracker/technical-debt.json` | `D-NNN` | refactoring, cleanup, code quality, "should refactor", "tech debt", "needs cleanup", "workaround" |

Each file has the same structure: `{ "items": [...] }`. If ambiguous, default to **ideas**.

## Step 1: Locate the Tracker

Find the project's `documentation/` directory by searching upward from `$CWD`. The tracker directory is `documentation/tracker/`.

If the directory or a category file doesn't exist yet, create it on the first `add` to that category.

## Step 2: Parse the Command

Interpret `$ARGUMENTS` as one of these operations. Be flexible with natural language.

### Add an Item

**Triggers:** `add`, `track`, or any phrase that implies recording something new (e.g., "consider X", "bug: Y", "dep: Z", "debt: W").

1. Detect the category from context using the signals in the table above
2. Read the corresponding category file
3. Generate the next ID using the category prefix (e.g., `B-001`, `I-003`)
4. Create the item and write back

Item schema:

```json
{
  "id": "B-001",
  "title": "Short description extracted from the user's input",
  "status": "open",
  "priority": "low|medium|high",
  "created_at": "ISO 8601 timestamp",
  "updated_at": "ISO 8601 timestamp",
  "source": "user or agent-name",
  "notes": "",
  "related_plan": "",
  "related": [],
  "doc_refs": []
}
```

**Priority detection:**
- **high** — "urgent", "critical", "important", "blocking", "asap"
- **low** — "minor", "nice to have", "someday", "low priority"
- **medium** — default when not specified

**Related items:** If the user mentions a relationship (e.g., "related to B-002", "this blocks I-005"), add the referenced ID to `related` and update the referenced item's `related` array too (bidirectional). Related items can cross category files — when linking B-003 to I-001, update both `bugs.json` and `ideas.json`.

**Doc refs:** If the user references documentation files (e.g., "see compliance.md:88-95", "ref: payments.md"), extract them into `doc_refs`. Each entry is a path relative to `documentation/` with optional `:line-range`.

**Source:** If invoked by the user, use `"user"`. If invoked by another skill, use that skill's name (e.g., `"debug-mode"`).

After adding, confirm:

```
Added B-004 [bug] "Dashboard crashes on empty state" (high priority)
```

### List Items

**Triggers:** `list`, `show`, `what's open`, `what should we do`, `status`, or no arguments at all.

Read all four category files and merge items. Apply filters:

- Filter by category: `list bugs`, `list ideas`, `list external`, `list debt`
- Filter by status: `list done`, `list open`
- Filter by priority: `list high priority`
- Combine: `list open bugs`

Default: show **open** and **in-progress** items from **all categories**, sorted by priority (high first).

Output format:

```
## Project Tracker — {project name}

| ID | Category | Priority | Title | Status |
|----|----------|----------|-------|--------|
| B-001 | bug | high | Dashboard crashes on empty state | open |
| E-002 | external | high | Waiting on API v2 credentials | open |
| I-003 | idea | medium | Consider caching layer | open |
| D-001 | debt | low | Refactor auth middleware | open |

**Summary:** 4 open, 1 in-progress, 2 done | 2 high priority
```

Show `Related` and `Docs` columns only when items have those fields populated.

### Update an Item

**Triggers:** `update`, `change`, `set`, `edit` followed by an item ID.

The ID prefix determines which file to read/write:
- `B-*` → `bugs.json`
- `E-*` → `external.json`
- `I-*` → `ideas.json`
- `D-*` → `technical-debt.json`

Updatable fields:
- `update B-003 priority high` — change priority
- `update B-003 status in-progress` — change status
- `update B-003 notes: added context` — set notes
- `update B-003 plan: 001-feature-name` — link to a plan
- `update B-003 ref: compliance.md:88-95` — add a doc reference

**Reclassifying type:** If the user wants to move an item between categories (e.g., "move I-005 to debt"), remove it from the source file, reassign the ID with the new prefix (next available in target), add it to the target file, and update any cross-references in other files.

Update `updated_at`. Confirm: `Updated B-003: priority medium → high`

### Mark as Done

**Triggers:** `done`, `close`, `resolve`, `complete` followed by an item ID.

Set status to `"done"`, update `updated_at`. Confirm: `Closed B-003 "Dashboard crashes on empty state"`

### Mark as Won't Fix

**Triggers:** `wontfix`, `won't fix`, `skip`, `dismiss` followed by an item ID.

Set status to `"wontfix"`, update `updated_at`. Confirm: `Dismissed I-005 "Add dark mode toggle"`

### Remove an Item

**Triggers:** `remove`, `delete` followed by an item ID.

Remove from the array. Destructive — prefer `done` or `wontfix`. Confirm: `Removed B-003 from tracker.`

### Link Items

**Triggers:** `link` followed by two item IDs.

Create bidirectional link. Items can be in different category files. Confirm: `Linked B-003 ↔ I-001`

### Unlink Items

**Triggers:** `unlink` followed by two item IDs.

Remove bidirectional link. Confirm: `Unlinked B-003 ↔ I-001`

### Migrate from Dependencies

**Triggers:** `migrate`

Convert old `documentation/dependencies/` or `documentation/tracker.json` into the new multi-file format:

**From `documentation/tracker.json`** (single-file format):
1. Read all items
2. Route each to the correct category file based on `type` field: `bug` → `bugs.json`, `dependency` → `external.json`, `idea` → `ideas.json`
3. Reassign IDs with new prefixes (B-/E-/I-/D-)
4. Write category files to `documentation/tracker/`
5. Remove old `documentation/tracker.json`

**From `documentation/dependencies/`** (legacy markdown format):
1. Scan `*.md` files (skip README.md)
2. Extract open items from `###` headings with **Priority:** and **Blocks:** fields
3. Create items in `external.json` with `E-NNN` IDs
4. Move `documentation/dependencies/` to `documentation_archive/dependencies/`

Report what was migrated.

### Summary (no arguments)

When invoked with no arguments, show a quick overview:

```
## Tracker Summary — {project name}

| Category | Open | In Progress | Done |
|----------|------|-------------|------|
| Bugs | 2 | 1 | 3 |
| External | 1 | 0 | 0 |
| Ideas | 5 | 0 | 2 |
| Tech Debt | 3 | 1 | 0 |

### High Priority (3)
| ID | Category | Title |
|----|----------|-------|
| B-002 | bug | Dashboard crashes on empty state |
| E-001 | external | Blocked on auth provider migration |
| D-003 | debt | Replace deprecated crypto module |

Use `/tracker list` for full list or `/tracker add ...` to add items.
```

## Step 3: Write Changes

After any mutation, write the updated JSON back to the relevant category file. Keep items sorted by ID within each file.

## Notes for Agent Callers

Other skills and agents invoke this skill to track follow-up work:

```
Skill(skill: 'uc:tracker', args: 'add bug: users can bypass rate limit by switching accounts')
Skill(skill: 'uc:tracker', args: 'add idea: consider splitting this into microservices')
Skill(skill: 'uc:tracker', args: 'add external: waiting on payment provider webhook docs')
Skill(skill: 'uc:tracker', args: 'add debt: auth middleware needs refactoring')
```

The `source` field automatically captures the calling agent's identity.
