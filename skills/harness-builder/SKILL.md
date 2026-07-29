---
description: Knowledge base for building harness components — skills, agents, hooks, protocols. Use when creating or refactoring a skill or agent, writing a description or agent prompt, auditing session context cost, or compressing resident text.
user-invocable: true
argument-hint: "topic: descriptions | communication | context-audit | testing | agents"
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
---

# Harness Builder

Accumulated knowledge for building the harness — the skills, agents, hooks, and protocols that decide how Claude works. Knowledge questions pull the reference they need and answer directly. Build tasks — anything that creates or modifies a persistent harness artifact — walk the staged workflow below inside Claude Code's native plan mode; no edits before plan approval.

## Non-negotiables

1. **Model floor: Opus.** Any session or agent doing harness-building work — writing or refactoring skills, agents, prompts, protocols — runs on Opus or better. The harness decides every downstream workflow; never build it with a small model.
2. **Engines are invoked, never copied — and invocation is commanded, not mentioned.** Building or refactoring a skill: **always invoke `/skill-creator:skill-creator`** (the official eval-driven engine). Compressing text: always through the caveman engine, via the `uc:caveman-compress` agent at stage 3. Never inline an engine's content into other skills, prompts, or docs — invoke it so upstream improvements propagate. This is also an authoring rule for every skill you write: when a skill delegates to another skill, phrase it as an explicit imperative ("always invoke /x:y"), never a passive mention ("built through", "via") — passive phrasing gets skipped.
3. **Descriptions are routers, not documentation.** Budgets: skill description 1–3 sentences (~20–50 words); agent description 1 sentence (~10–25 words). The body carries detail; the description pays an always-resident price in every session.
4. **Refactors require before/after evidence.** Never accept a skill/agent refactor that lowers trigger accuracy or eval pass-rate — brevity that breaks routing is a regression, not a win.
5. **Build tasks run the staged workflow in native plan mode.** No edit to a persistent harness artifact before plan approval — see the workflow below. Exempt: knowledge-only answers (nothing edited); meaning-preserving fixes (typo, formatting, broken path — if you would have to choose between wordings, it is not meaning-preserving: run the workflow); work already covered by a plan the user approved this session (`/uc:plan-execution` runs included — never re-enter plan mode mid-execution). Precedence: if an Ultra Claude planning mode is active, its framework governs and prohibits native plan mode — serve as its knowledge base instead.

## Build workflow — stages

Persistent harness artifacts: skill descriptions, agent descriptions, prompt bodies, protocol message formats, CLAUDE.md sections, resident reference text.

**Entry:** call `EnterPlanMode` (if the tool is deferred, load it first — `ToolSearch` `select:EnterPlanMode,ExitPlanMode`). If the target is a skill, always invoke `/skill-creator:skill-creator` — its eval-driven flow runs inside this workflow. Read each stage's reference only when entering that stage.

| Stage | What happens | Reference |
|---|---|---|
| 1 — structural | catalogue check + payload-zone inventory; structural proposal; discuss until the user confirms it settled | `references/stage-1-structural.md` |
| 2 — lexical | hand pass — house style on bodies, descriptions (only here); discuss | `references/stage-2-lexical.md` |
| 3 — compression | spawn `uc:caveman-compress` per body artifact; adopt cuts item by item | `references/stage-3-compression.md` |
| 4 — present | assemble final plan + sync steps; ExitPlanMode; discuss; execute after approval | `references/stage-4-present.md` |

## Routing — knowledge references

References live at `${CLAUDE_PLUGIN_ROOT}/skills/harness-builder/references/`.

| Need | Where |
|---|---|
| Structural/form optimisation — duplication catalogue, altitude cuts, payload zones | `references/structural-optimization.md` |
| Writing or trimming a skill/agent description | `references/description-writing.md` |
| Efficient communication style; compressing resident text; caveman usage | `references/efficient-communication.md` |
| Measuring session startup context cost | `references/context-audit.md` + `scripts/context_audit.py` |
| Testing a skill/agent before/after a refactor | `references/testing-refactors.md` |
| Building agents: tools, model choice, addressing, hard limits | `references/agent-building.md` |

## Companion tools

- `/skill-creator:skill-creator` — always invoke when creating or refactoring a skill (official plugin; eval-driven, includes a description-trigger optimizer).
- caveman plugin — compression engine, installed dormant (`defaultMode: off`), enabled selectively; see `references/efficient-communication.md`.
- `uc:caveman-compress` agent (this plugin) — compression engine wrapper: runs the caveman-compress CLI on a scratch copy, returns the compressed version plus a classified cut list. Spawned at stage 3, proposition-only.

## Accumulating knowledge here

This base will grow. Rules that keep it navigable:

- New knowledge lands in the **narrowest matching reference**; if none fits, add a new single-topic reference plus one routing row. SKILL.md stays thin — principles and routing only.
- Tag every claim with its evidence class: **[OFFICIAL]** (vendor docs), **[COMMUNITY]** (practitioner reports), **[MEASURED]** (measured in this environment — include the number and date), **[JUDGMENT]** (reasoned synthesis).
- When new evidence contradicts a stored claim, **replace** the claim (keep a one-line "superseded" note) rather than appending a contradiction.
- Every reference states its scope in its first line, so routing stays decidable as files multiply.
