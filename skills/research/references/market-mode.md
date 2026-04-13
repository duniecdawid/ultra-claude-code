# Market Mode Reference

You are researching external market context — competitors, alternatives, technology landscape, industry trends. Unlike library or patterns mode, your output writes to `documentation/product/research/` and follows the existing market research format. Synthesis is required, but every claim carries a source and facts are distinguished from opinions.

## Research Process

1. **WebSearch** is your primary tool. Market research needs community discussion, pricing pages, product changelogs, and engineering blog posts — all of which are better served by web search than Ref.tools.

2. **Ref.tools** is useful when the topic touches a specific technology category (e.g., "current state of vector databases" pulls both market analysis AND Ref.tools-indexed product docs).

3. **WebFetch** the top results. Prefer:
   - Direct product pricing and feature pages
   - G2, Capterra, or similar structured comparison sources (but verify against the products' own sites)
   - Engineering blog posts describing real-world use and switching stories
   - Analyst reports (Gartner, Forrester) when cited by multiple sources
   - The products' own docs for verified feature claims

4. **Cross-reference product claims.** If one source says "Vendor X supports SSO on the free tier" and the vendor's own site says otherwise, trust the vendor's page and note the discrepancy. Review sites and aggregators get out of date.

## What To Include

- **Key findings** — 3-7 bullet points, each with a source. Lead with evidence, not opinion.
- **Competitor table** — when 3+ competitors apply. Columns: competitor / approach / strengths / weaknesses. Every cell citable.
- **Technology landscape table** — when the topic is technology choices rather than competitors. Columns: option / maturity / community / fit for use case.
- **Market trends** — bullet list of directional shifts with evidence (e.g., "Pricing shift from per-seat to usage-based observed in 3 of 5 observed vendors in 2024-2026").
- **Implications** — what the findings mean for product decisions. This is where synthesis lives. It states *implications*, not decisions.
- **Sources** — every URL with read date, formatted as a table or bullet list at the bottom.

## What To Exclude

- **Product description content** — market research says what the *market* does, not what *our product* does.
- **Requirements** — what we should build goes in `documentation/product/requirements/`, not here. Implications can say "this suggests X is table stakes" but cannot say "we should build X."
- **Architectural recommendations** — tech stack decisions for our product belong in architecture docs.
- **Unsourced claims** — "SSO is becoming table stakes" without a source is opinion.

## File Format

Market research files live in `documentation/product/research/` and follow the existing research reference at `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/research.md` for structure and template. You do NOT need to read that file — the template below is self-contained.

Frontmatter for market research matches the technology research schema (`topic`, `type: market`, `subject`, `fetched_at`, `expires`, `sources`). The `type: market` distinguishes it from library/pattern entries in the shared `index.json`.

## Merge Discipline

Market research files usually cover one topic and are overwritten more aggressively than library or pattern files — market conditions shift fast. If `existing_file_content` is non-empty:

1. Preserve frontmatter keys but update `fetched_at`, `expires`, and `sources`.
2. Rewrite the body fresh if the existing content is older than 30 days — don't try to patch stale market observations.
3. If the existing content is fresh (within the last few days) and your research just adds a new angle, append to existing sections instead.

## Staleness Defaults

- **Default TTL: 30 days.** Market conditions shift monthly. `expires: fetched_at + 30 days`.
- **Frozen (`expires: null`) when:**
  - Topic is a point-in-time snapshot: `competitive landscape in Q1 2023`, `state of vector databases at GA of pgvector`.
  - Topic is a retrospective: `why the CRM market consolidated between 2018 and 2022`.
  - Topic references a historical market shift already concluded.
- **Not frozen (use TTL) when:**
  - Topic asks about the *current* state of any market. Markets move.

Market research frozen should be rare — most queries are about "current" conditions.

## Example Output

```markdown
---
topic: ai-coding-assistant-landscape
type: market
subject: ai-coding-assistants
fetched_at: 2026-04-13
expires: 2026-05-13
sources:
  - https://www.cursor.com/pricing
  - https://github.com/features/copilot
  - https://www.anthropic.com/news/claude-code
  - https://a16z.com/ai-coding-report-2026
---

# AI Coding Assistant Landscape

> Researched: 2026-04-13. Expires: 2026-05-13.

## Objective

Snapshot of the AI coding assistant market — major players, pricing models, differentiation axes — to inform positioning decisions for Ultra Claude Dashboard.

## Key Findings

1. Three dominant IDE-native assistants: Cursor, GitHub Copilot, Claude Code. All converged on chat + inline suggestions + agentic task execution by early 2026. (Sources: each vendor's product pages.)
2. Pricing is bifurcating — Cursor $20/mo flat, Copilot $10/mo individual + $39/mo business tier, Claude API usage-based. Flat pricing dominates for individuals; usage-based dominates for teams. (Sources: pricing pages.)
3. Agentic execution (multi-file edits, test runs, long-running tasks) is the new competitive frontier; all three vendors shipped autonomous agent features in Q1 2026. (Sources: product changelogs.)

## Competitor Analysis

| Vendor | Approach | Strengths | Weaknesses |
|--------|----------|-----------|------------|
| Cursor | IDE fork of VS Code + chat + agents | Tight IDE integration, fast | Locked into Cursor UI |
| GitHub Copilot | VS Code extension + Copilot Chat + Workspace | Massive install base, integrated with GitHub | Least autonomous of the three |
| Claude Code | CLI + IDE extensions + web | Strong on multi-file agentic tasks | No single dominant UI |

## Market Trends

- Shift from "autocomplete" framing to "agent" framing in marketing copy across all three vendors.
- Flat pricing losing ground to usage-based pricing for team plans as costs become visible.
- IDE-agnostic CLIs gaining traction (Claude Code, Aider) as a hedge against editor lock-in.

## Implications

- **For product positioning:** "dashboard for agent-based coding workflows" is a defensible niche — none of the dominant vendors ship a standalone plan/execution dashboard.
- **For pricing:** flat-pricing individual + usage-based team tier matches the observed market split.

## Sources

| Source | Type | Date |
|--------|------|------|
| [Cursor pricing](https://www.cursor.com/pricing) | Product page | 2026-04-13 |
| [GitHub Copilot features](https://github.com/features/copilot) | Product page | 2026-04-13 |
| [Claude Code announcement](https://www.anthropic.com/news/claude-code) | Vendor post | 2026-04-13 |
| [a16z AI Coding Report 2026](https://a16z.com/ai-coding-report-2026) | Analyst report | 2026-04-13 |

## Related

- Product description: `documentation/product/description/` (what this market context informs)
- Requirements: `documentation/product/requirements/` (which priorities this evidence supports)
```

## Quality Bar

Before exiting:

- [ ] Frontmatter has valid `topic`, `type: market`, `subject`, `fetched_at`, `expires`, `sources`
- [ ] At least 3 key findings, each with a source
- [ ] Competitor or technology landscape table when applicable
- [ ] Market trends section with directional claims + evidence
- [ ] Implications section stating what the findings suggest (not what we should build)
- [ ] Sources section at the bottom with every URL + date + type
- [ ] No product behavior described, no architectural recommendations, no unsourced claims
