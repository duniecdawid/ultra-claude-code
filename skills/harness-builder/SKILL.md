---
description: Knowledge base for building harness components — skills, agents, hooks, protocols. Use when creating or refactoring a skill or agent, writing a description or agent prompt, auditing session context cost, or compressing resident text.
user-invocable: true
argument-hint: "topic: descriptions | communication | context-audit | testing | agents"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# Harness Builder

Accumulated knowledge for building the harness — the skills, agents, hooks, and protocols that decide how Claude works. **Knowledge, not process:** there is no universal build workflow here. Each reference holds what we know about one topic; you pull what the task needs.

## Non-negotiables

1. **Model floor: Opus.** Any session or agent doing harness-building work — writing or refactoring skills, agents, prompts, protocols — runs on Opus or better. The harness decides every downstream workflow; never build it with a small model. This includes reviewer agents that touch harness text.
2. **Engines are invoked, never copied.** Skills are built through `/skill-creator:skill-creator` (the official eval-driven engine); text compression goes through the installed caveman plugin. Do not inline either engine's content into other skills, prompts, or docs — invoke them so upstream improvements propagate.
3. **Descriptions are routers, not documentation.** Budgets: skill description 1–3 sentences (~20–50 words); agent description 1 sentence (~10–25 words). The body carries detail; the description pays an always-resident price in every session.
4. **Refactors require before/after evidence.** Never accept a skill/agent refactor that lowers trigger accuracy or eval pass-rate — brevity that breaks routing is a regression, not a win.

## Routing

References live at `${CLAUDE_PLUGIN_ROOT}/skills/harness-builder/references/`.

| Need | Where |
|---|---|
| Writing or trimming a skill/agent description | `references/description-writing.md` |
| Efficient communication style; compressing resident text; caveman usage | `references/efficient-communication.md` |
| Measuring session startup context cost | `references/context-audit.md` + `scripts/context_audit.py` |
| Testing a skill/agent before/after a refactor | `references/testing-refactors.md` |
| Building agents: tools, model choice, addressing, hard limits | `references/agent-building.md` |

## Companion tools

- `/skill-creator:skill-creator` — creation + eval engine for skills (official plugin; includes a description-trigger optimizer).
- caveman plugin — compression engine, installed dormant (`defaultMode: off`), enabled selectively; see `references/efficient-communication.md`.
- `caveman-reviewer` agent (this plugin) — proposition-only compression review of persistent harness text.

## Accumulating knowledge here

This base will grow. Rules that keep it navigable:

- New knowledge lands in the **narrowest matching reference**; if none fits, add a new single-topic reference plus one routing row. SKILL.md stays thin — principles and routing only.
- Tag every claim with its evidence class: **[OFFICIAL]** (vendor docs), **[COMMUNITY]** (practitioner reports), **[MEASURED]** (measured in this environment — include the number and date), **[JUDGMENT]** (reasoned synthesis).
- When new evidence contradicts a stored claim, **replace** the claim (keep a one-line "superseded" note) rather than appending a contradiction.
- Every reference states its scope in its first line, so routing stays decidable as files multiply.
