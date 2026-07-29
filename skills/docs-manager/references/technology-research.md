# Reference: Technology Research

## Purpose

Technology research documents capture external library, API, and pattern knowledge — Ref.tools excerpts, API signatures, best-practices writeups, tradeoff analyses. They are the project's durable memory of what's been verified and when. The `researcher` agent writes them; humans read them; the `/uc:research` skill uses them as a cache.

## Perspective

**Verified reference material, not opinion.** Write as a snapshot of external truth captured at a specific point in time, with sources cited and a freshness window.

- DO include: API signatures, code examples, verbatim doc excerpts, comparison tables, source URLs, last-verified date
- DO NOT include: project-specific code (→ architecture), synthesized recommendations for the product (→ architecture or RFCs), market/competitor analysis (→ `product/research/` instead)

## Location

Two typed subdirectories under `documentation/technology/research/`:

- **`technology/research/libraries/{library-slug}.md`** — one file per library or API. Topics go in H2 sections inside the file. Re-researching a topic updates the relevant H2 section and bumps the file-level `fetched_at` / `expires`.
- **`technology/research/patterns/{topic-slug}.md`** — one file per architectural pattern or best-practices topic. Contains synthesis across sources, comparison tables, tradeoff framing.

Market research continues to live at `documentation/product/research/` — the `researcher` agent writes there when invoked in market mode. Use the existing `references/research.md` guide for market-research format.

## Frontmatter Schema

Every technology research file carries YAML frontmatter that drives staleness detection and index lookup:

```yaml
---
topic: zod
type: library            # library | pattern
subject: zod             # short identifier used for index matching
fetched_at: 2026-04-13   # ISO date — when this file was last verified
expires: 2026-04-23      # ISO date OR null — null means frozen, never expires
sources:
  - https://zod.dev/api/object
  - https://zod.dev/error-handling
---
```

**`expires` semantics:**
- **ISO date** → entry is fresh when `now < expires`.
- **`null`** → **frozen**. Entry never auto-expires. Used for historical / retrospective / version-locked research that can't go out of date (e.g., "Node 14 deprecation notes", "pattern evolution timeline").

TTL selection at write time (mode defaults, when to freeze) is the `researcher` agent's behaviour — defined in `agents/researcher.md`, not here. Humans can hand-edit `expires` if the agent's judgment is wrong — flip a fast-moving entry to `null` to pin it, or set a past date to force a refresh.

## File Naming

- **Libraries** — kebab-case slug matching the package/service name: `zod.md`, `nats.md`, `prisma.md`, `nats-jetstream.md` when disambiguation matters. One file per library, not per topic.
- **Patterns** — kebab-case slug of the pattern or topic: `rate-limiting.md`, `dependency-injection.md`, `idempotent-handlers.md`.
- **Market** — see `references/research.md`.

## Section Structure

```markdown
---
{frontmatter}
---

# {Library or Topic Name}

> Last verified: {fetched_at}. Expires: {expires or "never (frozen)"}. Re-invoke `/uc:research {topic}` to refresh.

## {Topic Section 1}

{verbatim content for library mode, synthesized content for patterns mode}

## {Topic Section 2}

...

## Sources

- [{source title}]({url}) — read {date}
- [{source title}]({url}) — read {date}
```

**Library files** use one H2 per researched topic (e.g., `## Schema Validation`, `## Error Maps`, `## Parsing`). Each topic section holds verbatim excerpts with inline source attribution.

**Pattern files** use H2 sections for structure (e.g., `## Problem`, `## Approaches`, `## Tradeoffs`, `## Recommendations`). Synthesis is allowed and expected — cite sources inline.

**The `## Sources` section** at the bottom is always present, listing every URL consulted with the date it was read. This is the citation bar humans use when auditing.

## Index File

`documentation/technology/research/index.json` is a machine-maintained lookup table used by the `/uc:research` skill for fast cache hits. **Do not hand-edit it.** It is owned by the `researcher` agent and rewritten atomically on every write.

Schema:

```json
{
  "version": 1,
  "updated_at": "2026-04-13T10:30:00Z",
  "entries": {
    "libraries/zod.md": {
      "type": "library",
      "subject": "zod",
      "fetched_at": "2026-04-13",
      "expires": "2026-04-23",
      "topics": ["schema validation", "error maps", "parsing"],
      "summary": "TypeScript-first schema validation with runtime + static type inference.",
      "sources": ["https://zod.dev/api/object"]
    },
  }
}
```

Pattern and market entries use the same shape (`"type": "pattern"` / `"market"`); market-mode keys are repo-root-relative paths like `documentation/product/research/ai-coding-landscape.md`. Frozen entries use `"expires": null`.

If the index gets out of sync with actual files (manual edit, file deletion), the skill falls back to spawning the researcher agent, which rebuilds the entry on next call. If an entry is wrong, delete the file and re-run `/uc:research` — or edit the file's frontmatter and the agent will reconcile.

## Cross-References

- Links TO: architecture docs (which use the research as evidence), RFCs (which cite research when explaining decisions)
- Links FROM: plan docs (via Tech Stack section — the Lead's knowledge brief points to these files), architecture docs
