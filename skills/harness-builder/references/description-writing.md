# Description writing — skills, agents, tools

Scope: how to write the `description` frontmatter of skills, agents, and tool definitions so they route reliably at minimum resident-token cost. (For compressing other persistent text, see `efficient-communication.md`.)

## Why this matters

Every skill description, agent description, and MCP tool description is loaded verbatim into the system prompt of **every** session. A 400-token description costs those tokens every conversation forever. Descriptions exist for **routing** — deciding when to invoke — not for documentation; the body loads only on trigger.

## The five rules

1. **Description = router, not docs. Two clauses only: what it does + when to use it.** [OFFICIAL] Anthropic's canonical shape is one sentence of capability + one "Use when…" sentence of triggers. Everything beyond that is fixed-overhead tax.

2. **Third person, concrete key terms, specific nouns.** [OFFICIAL] "Processes Excel files… Use when analyzing .xlsx files" beats "helps with spreadsheets." The literal terms a task would contain (file extensions, proper nouns, verbs) ARE the triggers. No first/second person.

3. **Spend words on disambiguation, not exposition.** [OFFICIAL] "Small refinements to tool descriptions can yield dramatic improvements" (Anthropic, writing-tools-for-agents). The high-value words separate this skill from its neighbours — not re-explain what the model already knows.

4. **Assume the model is smart — delete anything it knows.** [OFFICIAL] Cut definitions of common concepts, background, marketing adjectives. "Does this paragraph justify its token cost?" applies doubly to always-resident text.

5. **Kill description/body duplication.** [JUDGMENT] Any sentence in both pays the always-on price for on-demand content. Push detail down into the body or references.

## Length budgets

| Artifact | Budget | Hard limit |
|---|---|---|
| Skill description | 1–3 sentences, ~20–50 words (~150–350 chars) | 1,024 chars [OFFICIAL] — a guardrail, not a target |
| Agent description | 1 sentence, ~10–25 words (pipeline/leaf agents) | broad-surface router agents (codebase analysts, research routers) may need up to 3 sentences / ~50 words — justify each extra key term |

**Precedence rule:** when a budget conflicts with preserving discriminating key terms, key-term preservation wins — routing correctness beats brevity. The overshoot is flagged explicitly, not hidden.
| Skill body (SKILL.md) | < 500 lines [OFFICIAL]; long-form → one-level-deep reference files | — |

Anthropic's own reference skills (pdf, xlsx, git-commit) land in the small band; their subagent examples are one-liners ("Expert code reviewer. Use proactively after code changes.").

## Trigger-phrase lists: the verdict

- [OFFICIAL] guidance says include **key terms** and specific contexts — it does not endorse enumerated trigger banks.
- [COMMUNITY] Anthropic's xlsx skill uses "DO trigger when… / do NOT trigger when…" — 1–2 boundary clauses for a confusable neighbour, not a 15-item list.
- [RESEARCH] Tool-selection accuracy degrades as the catalogue grows (one study: 78% → ~14% from 10 → 100+ tools; measured on flat tool catalogues — treat as directional) and improves with fewer, cleaner options. Reliability comes from **semantic separation between siblings**, not phrase-stuffing; long lists add false-positive overlap.
- [JUDGMENT] **Verdict: 3–6 representative key terms > a 20-item phrase bank.** Keep an explicit do/don't clause only where two of your own skills genuinely collide.

## Before / after example

BEFORE (~950 chars — capability buried under a trigger bank; duplicates the body):

> Research the AXB trading-system codebase and locate/load AXB code… Use for: finding and reading any AXB repo, tracing order/market-data flow… **ALWAYS use this agent when:** [10 bullets] … **Trigger phrases:** [~12 quoted phrases]

AFTER (~280 chars — capability + key terms + one discriminator):

> Researches and loads the AXB trading-system codebase (GitLab group `axb`): finds/reads repos, traces order and market-data flow strategy→exchange→ClickHouse, locates SBE/protobuf schemas and config defaults, verifies docs against code. Use for questions about how the live trading system works or where its data comes from. Knows which repos are legacy.

Why it still routes: the key terms survive ("order flow", "ClickHouse", "schema", "repo", "legacy"); the discriminator ("how the live trading system works") sets the boundary. ~70% smaller, same semantic trigger surface.

## Checklist before shipping a description

- [ ] Two clauses: capability + "Use when…"
- [ ] Within budget for its artifact type
- [ ] 3–6 discriminating key terms present; no enumerated phrase bank
- [ ] No sentence duplicated from the body
- [ ] No first/second person, no marketing adjectives
- [ ] If a sibling skill could be confused: one do/don't boundary clause
- [ ] Refactoring an existing description? Run the before/after trigger test — `testing-refactors.md`
- [ ] Description hand-passed at stage 2 of the build workflow (`stage-2-lexical.md`) — descriptions never go through the compression engine

## Sources

Official:
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- https://www.anthropic.com/engineering/writing-tools-for-agents
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- https://code.claude.com/docs/en/sub-agents
- https://github.com/anthropics/skills

Research (function calling / tool selection):
- https://arxiv.org/html/2605.24660v1 (How Many Tools Should an LLM Agent See?)
- https://arxiv.org/pdf/2410.14594 (Toolshed)
- https://arxiv.org/pdf/2411.15399 (Less is More: Optimizing Function Calling)
