# Patterns Mode Reference

You are researching an architectural pattern, design strategy, or best-practice topic. Unlike library mode, **synthesis is expected** — you compare approaches, surface tradeoffs, and help the reader decide. But every claim still cites a source; synthesis is not opinion.

## Research Process

1. **Query Ref.tools** first with a pattern-focused query: `"rate limiting strategies api"`, `"idempotent webhook handlers retry"`, `"dependency injection testing typescript"`. Ref.tools has good coverage of established patterns across multiple sources.

2. **WebSearch** for community discussion and real-world experience: post-mortems, engineering blog posts from companies that hit scale, benchmark comparisons. Patterns are cultural as well as technical — the dominant approach in 2026 may not be the dominant approach from 2022.

3. **Read 3-5 sources** via `mcp__Ref__ref_read_url` or `WebFetch`. Prefer:
   - Official docs or specs (RFC, W3C, language standard)
   - Engineering blogs from known practitioners (Cloudflare, Stripe, GitHub, Meta, Google)
   - Books or academic papers if cited by multiple sources
   - Community wikis or pattern catalogs (martinfowler.com, microservices.io)

4. **Cross-reference aggressively.** If two sources disagree about which approach wins at what scale, surface the disagreement — it's more useful than a fake consensus.

## What To Include

For each topic section you write:

- **Problem statement** — what the pattern solves. One paragraph.
- **Approaches** — the 2-5 main approaches, each with a short description and a code example when the pattern has code to show.
- **Tradeoffs** — what each approach optimizes for and what it sacrifices. Prefer a table for 3+ approaches.
- **When to pick which** — concrete guidance with context (scale, latency budget, team size, consistency requirements).
- **Pitfalls** — common mistakes or anti-patterns that look correct but break under load.
- **Inline source attribution** — "Stripe uses token bucket with 100 req/s base (source: Stripe docs)". Every claim traces to its source.

## What To Exclude

- **Your personal opinion** — "I think X is usually better" without source backing.
- **Project-specific code** — you never read the project's source. Write pattern examples generically.
- **Exhaustive enumeration of every possible approach** — focus on the 2-5 approaches that practitioners actually use.
- **Marketing text from vendor docs** — patterns aren't products; keep vendor-neutral.

## Comparison Tables

When a topic has multiple approaches, include a comparison table:

```markdown
| Approach | Latency | Throughput | Distributed? | When to use |
|----------|---------|-----------|--------------|-------------|
| Token bucket | ~1-2ms | High | With Redis | General-purpose API limits |
| Sliding window | ~2-5ms | Medium | With Redis | Fair-share requirements |
| Fixed window counter | ~0.5ms | Very high | Native | Rough approximation, simple infra |
```

Tables make tradeoffs scannable. Prose alone hides them.

## Merge Discipline

Pattern files usually cover one topic per file, so merging is simpler than library files. If `existing_file_content` is non-empty:

1. Preserve frontmatter.
2. Re-read the existing content. If your new research refines or corrects something, update that section. If your research adds a genuinely new angle (e.g., a newer approach published after the file was first written), add a new H2 section.
3. Append new sources to the frontmatter `sources` list.
4. Update `fetched_at` and `expires`.
5. Note in a `## Changelog` section at the bottom (create it if absent) what changed in this update: "2026-04-13: added sliding window approach, updated token bucket latency numbers".

## Staleness Defaults

- **Default TTL: 90 days.** Patterns evolve slowly. `expires: fetched_at + 90 days` is the default for current best-practices content.
- **Frozen (`expires: null`) when:**
  - Topic is anchored to a point in time: `history of microservices before 2018`, `why the industry moved from SOAP to REST in 2010-2015`, `pattern evolution from 2015 to 2020`.
  - Topic is retrospective analysis of a specific design decision that won't be re-analyzed: `why Netflix built Hystrix and then deprecated it`.
  - Topic covers a pattern that is now historically fixed and not actively evolving: `CQRS as described in Greg Young's 2010 paper`.
- **Not frozen (use TTL) when:**
  - Topic is about current best practices — even if they feel stable, they can and do shift.
  - Topic is framed as "how to X today" without a time anchor.

## Example Output

```markdown
---
topic: rate-limiting
type: pattern
subject: rate-limiting
fetched_at: 2026-04-13
expires: 2026-07-12
sources:
  - https://stripe.com/docs/rate-limits
  - https://docs.github.com/en/rest/rate-limit
  - https://blog.cloudflare.com/counting-things-a-lot-of-different-things/
  - https://github.com/animir/node-rate-limiter-flexible
---

# Rate Limiting

> Last verified: 2026-04-13. Expires: 2026-07-12. Re-invoke `/uc:research rate limiting` to refresh.

## Problem

APIs need to cap request rates to prevent abuse, protect downstream systems, and enforce pricing tiers. Different algorithms optimize for different properties — burst tolerance, fairness, memory footprint, distributed correctness.

## Approaches

### Token Bucket

A bucket fills at a fixed rate up to a max capacity. Each request consumes a token; empty bucket = reject. Allows bursts up to the bucket size.

Used by: Stripe (100 req/s base, per-key), AWS (throttling via token bucket in most services).

```
function allow(key: string): boolean {
  const bucket = store.get(key) ?? { tokens: MAX, refilledAt: now() };
  const elapsed = now() - bucket.refilledAt;
  bucket.tokens = min(MAX, bucket.tokens + elapsed * RATE);
  bucket.refilledAt = now();
  if (bucket.tokens >= 1) {
    bucket.tokens -= 1;
    store.set(key, bucket);
    return true;
  }
  return false;
}
```

**Tradeoffs:** Burst-friendly, memory-efficient (two numbers per key), well-understood. Downside: bursts can still briefly overwhelm the protected resource if the burst size is large.

### Sliding Window Counter

...

## Comparison

| Approach | Bursty traffic | Memory | Distributed | Latency |
|----------|----------------|--------|-------------|---------|
| Token bucket | Tolerant | O(1) per key | With Redis | ~1-2ms |
| Sliding window | Smoother | O(1) per key | With Redis | ~2-5ms |
| Fixed window | Brittle at boundaries | O(1) per key | Native | ~0.5ms |

## When To Pick Which

- **Token bucket** — general-purpose API rate limiting. Stripe's choice, industry default.
- **Sliding window** — when fairness matters more than throughput (fair-share across tenants).
- **Fixed window** — when you need absolute simplicity and can tolerate ~2x burst at window boundaries.

## Pitfalls

- Forgetting to return `X-RateLimit-*` headers — ruins the developer experience (Stripe pattern: always return limit / remaining / reset).
- Rate-limiting on IP address alone — shared-NAT users get collectively throttled. Prefer API-key or user-account keying.
- Distributed rate limiting without atomic check-and-decrement — two replicas can both let a request through under contention.

## Sources

- [Stripe Rate Limiting](https://stripe.com/docs/rate-limits) — read 2026-04-13
- [GitHub REST API — Rate Limit](https://docs.github.com/en/rest/rate-limit) — read 2026-04-13
- [Cloudflare — Counting things, a lot of different things](https://blog.cloudflare.com/counting-things-a-lot-of-different-things/) — read 2026-04-13
- [node-rate-limiter-flexible](https://github.com/animir/node-rate-limiter-flexible) — read 2026-04-13
```

## Quality Bar

Before exiting:

- [ ] Frontmatter has valid `topic`, `type: pattern`, `subject`, `fetched_at`, `expires`, `sources`
- [ ] Every approach has a source URL attached
- [ ] At least one comparison table if there are 3+ approaches
- [ ] A "When to pick which" section with concrete guidance
- [ ] A "Pitfalls" section
- [ ] `## Sources` section at the bottom with every URL + date
- [ ] No project-specific code, no bare opinion
