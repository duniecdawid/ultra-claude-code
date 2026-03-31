---
description: >-
  Manage project tracker — lightweight backlog for ideas, dependencies, and bugs.
  Add, list, update, and close items. Works from any project directory.
  Use this skill whenever the user wants to track something for later, note a future
  consideration, log a bug they noticed, record an external dependency, check what's
  on the backlog, or ask "what should we work on next". Also use when other skills or
  agents discover follow-up work, out-of-scope ideas, or issues worth remembering.
  Triggers on "tracker", "track", "add idea", "add bug", "add dependency",
  "what should we do", "backlog", "open items", "track this", "note for later",
  "remember to", "follow up on".
argument-hint: "command + details (e.g., 'add idea: cache API responses', 'list bugs', 'done T-003')"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Tracker

Manage the project's tracker — a lightweight backlog of ideas, dependencies, and bugs stored in `documentation/tracker.json`.

**Command:** `$ARGUMENTS`

## Step 1: Locate the Tracker

Find the project's `documentation/` directory by searching upward from `$CWD`. The tracker file lives at `documentation/tracker.json`.

If the file doesn't exist yet, that's fine — create it on the first `add` operation with an empty `{ "items": [] }` structure.

## Step 2: Parse the Command

Interpret `$ARGUMENTS` as one of these operations. Be flexible with natural language — the user shouldn't need to memorize exact syntax.

### Add an Item

**Triggers:** `add`, `track`, or any phrase that implies recording something new (e.g., "consider X", "bug: Y", "dep: Z", "note for later: W").

Detect the item type from context:
- **idea** — considerations, improvements, "we should", "consider", "maybe", "it would be nice"
- **bug** — defects, crashes, errors, "broken", "fails", "doesn't work", "wrong"
- **dependency** — external blockers, waiting on something, "blocked by", "need X from", "waiting for", "depends on"

If the type is ambiguous, default to `idea`.

Detect priority from context:
- **high** — "urgent", "critical", "important", "blocking", "asap"
- **low** — "minor", "nice to have", "someday", "low priority"
- **medium** — default when not specified

Create the item:

```json
{
  "id": "T-NNN",
  "type": "idea|dependency|bug",
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

If the user mentions a relationship to an existing item (e.g., "related to T-002", "this blocks T-005", "spawned from T-001"), add the referenced ID to `related` and also add the new item's ID to the referenced item's `related` array (bidirectional link).

If the user references documentation files (e.g., "see compliance.md:88-95", "ref: payments.md", "documented in architecture/api-spec.md", or bare paths like `fees.md:42-55`), extract them into the `doc_refs` array. Each entry is a path relative to `documentation/` with an optional `:line-range` suffix. Multiple refs can be provided in one add command.

The `id` is auto-incremented: read existing items, find the highest `T-NNN` number, and use `N+1` (zero-padded to 3 digits). If the tracker is empty, start at `T-001`.

The `source` field captures who created the item. If invoked directly by the user, use `"user"`. If invoked by another skill or agent, use that skill's name (e.g., `"debug-mode"`, `"plan-execution"`). Check the conversation context to determine this — if the tracker skill was invoked via `Skill(skill: 'uc:tracker', ...)` from within another skill, the caller is the source.

After adding, confirm with a one-line summary:

```
Added T-004 [idea] "Consider caching layer for API responses" (medium priority)
```

### List Items

**Triggers:** `list`, `show`, `what's open`, `what should we do`, `status`, or no arguments at all.

Read the tracker file and display items in a markdown table. Apply filters if the user specified any:

- Filter by type: `list bugs`, `list ideas`, `list dependencies`
- Filter by status: `list done`, `list open`
- Filter by priority: `list high priority`
- Combine filters: `list open bugs`

Default filter (when no arguments or just `list`): show **open** and **in-progress** items only.

Output format:

```
## Project Tracker — {project name}

| ID | Type | Priority | Title | Status | Related |
|----|------|----------|-------|--------|---------|
| T-001 | idea | medium | Consider caching layer | open | T-003 |
| T-002 | bug | high | Dashboard crashes on empty state | open | |
| T-003 | dependency | medium | Waiting on API v2 | in-progress | T-001 |

**Summary:** 3 open, 1 in-progress, 2 done | 1 high priority
```

Show the `Related` column only when at least one item has connections. Show a `Docs` column only when at least one item has `doc_refs`. Display each ref as an inline code span (e.g., `` `compliance.md:88-95` ``). This keeps the output clean for simple backlogs.

If the tracker is empty or no items match the filter, say so clearly.

### Update an Item

**Triggers:** `update`, `change`, `set`, `edit` followed by an item ID.

Parse which fields to update from the user's input:

- `update T-003 priority high` — change priority
- `update T-003 status in-progress` — change status
- `update T-003 type bug` — reclassify type
- `update T-003 notes: added more context here` — set notes
- `update T-003 plan: 001-feature-name` — link to a plan
- `update T-003 ref: compliance.md:88-95` — add a documentation reference

Update the `updated_at` timestamp. Confirm the change:

```
Updated T-003: priority medium → high
```

### Mark as Done

**Triggers:** `done`, `close`, `resolve`, `complete` followed by an item ID.

Set the item's `status` to `"done"` and update `updated_at`. Confirm:

```
Closed T-003 [dependency] "Waiting on API v2"
```

### Mark as Won't Fix

**Triggers:** `wontfix`, `won't fix`, `skip`, `dismiss` followed by an item ID.

Set the item's `status` to `"wontfix"` and update `updated_at`. Confirm:

```
Dismissed T-005 [idea] "Add dark mode toggle"
```

### Remove an Item

**Triggers:** `remove`, `delete` followed by an item ID.

Remove the item from the array entirely. This is destructive — use `done` or `wontfix` to preserve history instead. Confirm:

```
Removed T-003 from tracker.
```

### Link Items

**Triggers:** `link` followed by two item IDs, or natural language like "T-003 is related to T-001".

Create a bidirectional link between two items. Add each ID to the other's `related` array (skip if already linked). Confirm:

```
Linked T-003 ↔ T-001
```

### Unlink Items

**Triggers:** `unlink` followed by two item IDs.

Remove the bidirectional link. Confirm:

```
Unlinked T-003 ↔ T-001
```

### Migrate from Dependencies

**Triggers:** `migrate`

Convert the old `documentation/dependencies/` system into tracker items. This is a one-time migration:

1. Scan `documentation/dependencies/*.md` (skip README.md)
2. For each file, extract open items by finding `###` headings and their **Priority:** and **Blocks:** fields
3. Create a tracker item for each open item:
   - `type`: `"dependency"`
   - `title`: the heading text (e.g., "Synthetic Connector Sync")
   - `priority`: mapped from the **Priority:** field (default medium)
   - `notes`: what it blocks (from **Blocks:** field)
   - `source`: `"migrated"`
   - `created_at`: from **Added:** field if present, otherwise now
4. Write all items to `documentation/tracker.json`
5. Move `documentation/dependencies/` to `documentation_archive/dependencies/`
6. Report what was migrated

If `documentation/dependencies/` doesn't exist, inform the user there's nothing to migrate.

### Summary (no arguments)

When invoked with no arguments or just `/tracker`, show a quick overview:

```
## Tracker Summary — {project name}

Open: 5 (2 ideas, 2 bugs, 1 dependency)
In Progress: 1
High Priority: 2

### High Priority Items
| ID | Type | Title |
|----|------|-------|
| T-002 | bug | Dashboard crashes on empty state |
| T-007 | dependency | Blocked on auth provider migration |

Use `/tracker list` for full list or `/tracker add ...` to add items.
```

## Step 3: Write Changes

After any mutation (add, update, done, wontfix, remove), write the updated JSON back to `documentation/tracker.json`. Use the Write tool — the entire file is small enough to overwrite each time.

Keep items sorted by ID in the JSON file for readability.

## Notes for Agent Callers

Other Ultra Claude skills and agents can invoke this skill to track follow-up work:

```
Skill(skill: 'uc:tracker', args: 'add bug: users can bypass rate limit by switching accounts')
Skill(skill: 'uc:tracker', args: 'add idea: consider splitting this into microservices')
Skill(skill: 'uc:tracker', args: 'add dependency: waiting on payment provider webhook docs')
```

When invoked programmatically by another agent, the `source` field automatically captures the calling agent's identity. This makes it easy to trace where items came from in the dashboard.
