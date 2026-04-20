---
description: >-
  Manage project backlog — lightweight backlog split into four categories:
  bugs, questions, ideas, and debt. Each category has its own
  file in documentation/backlog/. Add, list, update, close, link, and block items.
  Use whenever the user wants to track something for later, note a future
  consideration, log a bug, record a question or blocker, flag tech debt,
  check what's on the backlog, or ask "what should we work on next". Also use
  when other skills or agents discover follow-up work or issues worth remembering.
  Triggers on "backlog", "tracker", "track", "add idea", "add bug", "add question",
  "tech debt", "what should we do", "open items", "track this",
  "note for later", "remember to", "follow up on",
  "label", "unlabel", "tag", "untag", "#".
argument-hint: "command + details (e.g., 'add idea: cache API responses #frontend', 'list bugs #api', 'label I-003 frontend', 'done B-003')"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Backlog

Manage the project's backlog — a lightweight backlog split across four category files in `documentation/backlog/`.

**Command:** `$ARGUMENTS`

## Categories and Files

| Category | File | ID Prefix | Signals |
|----------|------|-----------|---------|
| **Bugs** | `documentation/backlog/bugs.json` | `B-NNN` | defects, crashes, errors, "broken", "fails", "doesn't work", "wrong" |
| **Questions** | `documentation/backlog/questions.json` | `Q-NNN` | questions, decisions, blocked, waiting on, need clarification, unclear, need to find out, how does X work |
| **Ideas** | `documentation/backlog/ideas.json` | `I-NNN` | considerations, improvements, "we should", "consider", "maybe", "it would be nice", future features |
| **Debt** | `documentation/backlog/debt.json` | `D-NNN` | refactoring, cleanup, code quality, "should refactor", "tech debt", "needs cleanup", "workaround" |

Each file has the same structure: `{ "items": [...] }`. If ambiguous, default to **ideas**.

## Step 1: Locate the Backlog

Find the project's `documentation/` directory by searching upward from `$CWD`. The backlog directory is `documentation/backlog/`.

If the directory or a category file doesn't exist yet, create it on the first `add` to that category.

## Step 2: Parse the Command

Interpret `$ARGUMENTS` as one of these operations. Be flexible with natural language.

### Add an Item

**Triggers:** `add`, `track`, or any phrase that implies recording something new (e.g., "consider X", "bug: Y", "question: Z", "debt: W").

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
  "blocks": [],
  "doc_refs": [],
  "labels": []
}
```

**Priority detection:**
- **high** — "urgent", "critical", "important", "blocking", "asap"
- **low** — "minor", "nice to have", "someday", "low priority"
- **medium** — default when not specified

**Related items:** If the user mentions a relationship (e.g., "related to B-002", "this blocks I-005"), add the referenced ID to `related` and update the referenced item's `related` array too (bidirectional). Related items can cross category files — when linking B-003 to I-001, update both `bugs.json` and `ideas.json`.

**Blocks:** If the user mentions that an item blocks another (e.g., "this blocks I-005", "Q-001 blocks I-003"), add the target ID to the `blocks` array on the blocking item. The `blocks` field is directional — only stored on the blocking item. `blocked_by` is computed at read time by scanning all items' `blocks` arrays. Do NOT store a `blocked_by` field.

**Doc refs:** If the user references documentation files (e.g., "see compliance.md:88-95", "ref: payments.md"), extract them into `doc_refs`. Each entry is a path relative to `documentation/` with optional `:line-range`.

**Source:** If invoked by the user, use `"user"`. If invoked by another skill, use that skill's name (e.g., `"debug-mode"`).

**Labels (inline `#tag` parsing):** Extract any `#word` tokens from the input as labels. Strip the `#tag` tokens from the title. Normalize each label (see **Label normalization** under the Label command). Examples:

- `add idea: cache responses #frontend #performance` → title: `"cache responses"`, labels: `["frontend", "performance"]`
- `add bug: login broken #auth #urgent` → title: `"login broken"`, labels: `["auth", "urgent"]`, priority: high (from "urgent" signal)
- `add debt: cleanup utils` → title: `"cleanup utils"`, labels: `[]` (no tags)

After adding, confirm (include labels when present):

```
Added B-004 [bug] "Dashboard crashes on empty state" (high priority)
Added I-007 [idea] "cache responses" (medium priority) labels: frontend, performance
```

### List Items

**Triggers:** `list`, `show`, `what's open`, `what should we do`, `status`, or no arguments at all.

Read all four category files and merge items. Apply filters:

- Filter by category: `list bugs`, `list ideas`, `list questions`, `list debt`
- Filter by status: `list done`, `list open`
- Filter by priority: `list high priority`
- Filter by label: `list #frontend`, `list #api`
- Multiple labels (AND): `list #frontend #urgent` — shows items with **both** labels
- Combine: `list open bugs #frontend`

Default: show **open** and **in-progress** items from **all categories**, sorted by priority (high first).

**Computing blocked_by:** When listing, scan all items' `blocks` arrays. For each item X that appears in another item's `blocks`, X is blocked by that item. Show this in the output.

Output format:

```
## Project Backlog — {project name}

| ID | Category | Priority | Title | Status | Blocks | Blocked By |
|----|----------|----------|-------|--------|--------|------------|
| Q-001 | question | high | Confirm deposit matching needed | open | I-003 | |
| I-003 | idea | medium | Title-based deposit matching | open | | Q-001 |
| B-001 | bug | high | Dashboard crashes on empty state | open | | |
| D-001 | debt | low | Refactor auth middleware | open | | |

**Summary:** 4 open, 1 in-progress, 2 done | 2 high priority
```

Show `Related`, `Blocks`, `Blocked By`, `Docs`, and `Labels` columns only when items have those fields populated.

### Update an Item

**Triggers:** `update`, `change`, `set`, `edit` followed by an item ID.

The ID prefix determines which file to read/write:
- `B-*` → `bugs.json`
- `Q-*` → `questions.json`
- `I-*` → `ideas.json`
- `D-*` → `debt.json`

Updatable fields:
- `update B-003 priority high` — change priority
- `update B-003 status in-progress` — change status
- `update B-003 notes: added context` — set notes
- `update B-003 plan: 001-feature-name` — link to a plan
- `update B-003 ref: compliance.md:88-95` — add a doc reference

**Reclassifying type:** If the user wants to move an item between categories (e.g., "move I-005 to debt"), remove it from the source file, reassign the ID with the new prefix (next available in target), add it to the target file, and update any cross-references in other files (both `related` and `blocks` arrays).

Update `updated_at`. Confirm: `Updated B-003: priority medium → high`

### Mark as Done

**Triggers:** `done`, `close`, `resolve`, `complete` followed by an item ID.

Set status to `"done"`, update `updated_at`. Confirm: `Closed B-003 "Dashboard crashes on empty state"`

### Mark as Won't Fix

**Triggers:** `wontfix`, `won't fix`, `skip`, `dismiss` followed by an item ID.

Set status to `"wontfix"`, update `updated_at`. Confirm: `Dismissed I-005 "Add dark mode toggle"`

### Remove an Item

**Triggers:** `remove`, `delete` followed by an item ID.

Remove from the array. Also remove this item's ID from any `related` or `blocks` arrays in other items across all category files. Destructive — prefer `done` or `wontfix`. Confirm: `Removed B-003 from backlog.`

### Link Items

**Triggers:** `link` followed by two item IDs.

Create bidirectional link in `related` arrays. Items can be in different category files. Confirm: `Linked B-003 ↔ I-001`

### Unlink Items

**Triggers:** `unlink` followed by two item IDs.

Remove bidirectional link from `related` arrays. Confirm: `Unlinked B-003 ↔ I-001`

### Block

**Triggers:** `block` followed by two item IDs (blocker first, blocked second).

Add the blocked item's ID to the blocker's `blocks` array. Confirm: `Q-001 now blocks I-003`

### Unblock

**Triggers:** `unblock` followed by two item IDs (blocker first, blocked second).

Remove the blocked item's ID from the blocker's `blocks` array. Confirm: `Q-001 no longer blocks I-003`

### Label an Item

**Triggers:** `label`, `tag` followed by an item ID and one or more label names.

Add the given labels to the item's `labels` array. Deduplicate — if a label already exists on the item, skip it. Normalize each label before storing (see **Label normalization** below).

Examples:
- `label I-015 ultra-plugin` — adds one label
- `tag B-003 frontend api-cache` — adds two labels (natural alias)
- `label I-015 Front End` — normalized to `front-end`

Confirm: `Labeled I-015 with "ultra-plugin"` or `Labeled B-003 with "frontend", "api-cache"`

### Unlabel an Item

**Triggers:** `unlabel`, `untag` followed by an item ID and one or more label names.

Remove the given labels from the item's `labels` array. If a label is not present, skip it silently.

Examples:
- `unlabel I-015 ultra-plugin` — removes one label
- `untag B-003 frontend api-cache` — removes two labels (natural alias)

Confirm: `Removed label "ultra-plugin" from I-015` or `Removed labels "frontend", "api-cache" from B-003`

### List Labels

**Triggers:** `labels`, `tags`, `show labels`, `show tags`.

Read all four category files and collect every unique label across all items. Display a table with per-category counts and a total.

Output format:

```
## Labels — {project name}

| Label | Bugs | Questions | Ideas | Debt | Total |
|-------|------|-----------|-------|------|-------|
| frontend | 1 | 0 | 3 | 0 | 4 |
| api-cache | 0 | 0 | 1 | 1 | 2 |
| auth | 2 | 1 | 0 | 0 | 3 |

3 labels across 9 items
```

If no items have labels: `No labels in use. Add labels with \`label <ID> <name>\` or inline \`#tag\` when adding items.`

### Label Normalization

All labels are normalized at write time (applies to `label`, `tag`, inline `#tag` parsing, and any other label input):

1. Lowercase all characters
2. Replace spaces and underscores with hyphens
3. Strip characters not matching `[a-z0-9-]`
4. Collapse multiple consecutive hyphens into one
5. Trim leading and trailing hyphens

Examples: `"Front End"` → `"front-end"`, `"API_Cache"` → `"api-cache"`, `"v2.0"` → `"v20"`, `"  my--label  "` → `"my-label"`

Reject empty strings after normalization (skip silently).

### Migrate from Legacy Formats

**Triggers:** `migrate`

Convert old formats into the current backlog structure:

**From `documentation/tracker/`** (old tracker directory):
1. Rename directory to `documentation/backlog/`
2. Rename `external.json` → `questions.json`, re-prefix `E-NNN` → `Q-NNN`
3. Rename `technical-debt.json` → `debt.json`
4. Update all `related` and `blocks` arrays across all files to use new prefixes
5. Report what was migrated

**From `documentation/tracker.json`** (single-file format):
1. Read all items
2. Route each to the correct category file based on `type` field: `bug` → `bugs.json`, `dependency` → `questions.json`, `idea` → `ideas.json`
3. Reassign IDs with new prefixes (B-/Q-/I-/D-)
4. Write category files to `documentation/backlog/`
5. Remove old `documentation/tracker.json`

**From `documentation/dependencies/`** (legacy markdown format):
1. Scan `*.md` files (skip README.md)
2. Extract open items from `###` headings with **Priority:** and **Blocks:** fields
3. Create items in `questions.json` with `Q-NNN` IDs
4. Move `documentation/dependencies/` to `documentation_archive/dependencies/`

Report what was migrated.

### Summary (no arguments)

When invoked with no arguments, show a quick overview:

```
## Backlog Summary — {project name}

| Category | Open | In Progress | Done |
|----------|------|-------------|------|
| Bugs | 2 | 1 | 3 |
| Questions | 1 | 0 | 0 |
| Ideas | 5 | 0 | 2 |
| Debt | 3 | 1 | 0 |

### High Priority (3)
| ID | Category | Title |
|----|----------|-------|
| B-002 | bug | Dashboard crashes on empty state |
| Q-001 | question | Blocked on auth provider migration |
| D-003 | debt | Replace deprecated crypto module |

Use `/backlog list` for full list or `/backlog add ...` to add items.
```

## Step 3: Write Changes

After any mutation, write the updated JSON back to the relevant category file. Keep items sorted by ID within each file.

## Notes for Agent Callers

Skills and agents MUST NOT add items to the backlog without user consent. When a skill surfaces something potentially backlog-worthy, it follows the triage protocol in `${CLAUDE_PLUGIN_ROOT}/references/backlog-triage.md` — presenting the user with options (do immediately / include in plan / add to backlog / ignore) before taking action.

When the user chooses "Add to backlog" during triage, invoke:

```
Skill(skill: 'uc:backlog', args: 'add bug: users can bypass rate limit by switching accounts')
Skill(skill: 'uc:backlog', args: 'add idea: consider splitting this into microservices')
Skill(skill: 'uc:backlog', args: 'add question: waiting on payment provider webhook docs')
Skill(skill: 'uc:backlog', args: 'add debt: auth middleware needs refactoring')
```

Category is inferred from the item's nature — `bug` for defects, `question` for blockers/unknowns, `idea` for enhancements, `debt` for refactoring needs. The `source` field automatically captures the calling agent's identity.
