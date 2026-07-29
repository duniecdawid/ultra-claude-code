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

Accumulated knowledge for building the harness — the skills, agents, hooks, and protocols that decide how Claude works. **Knowledge, not process:** there is no universal build workflow here. Each reference holds what we know about one topic; you pull what the task needs.

## Non-negotiables

1. **Model floor: Opus.** Any session or agent doing harness-building work — writing or refactoring skills, agents, prompts, protocols — runs on Opus or better. The harness decides every downstream workflow; never build it with a small model. This includes reviewer agents that touch harness text.
2. **Engines are invoked, never copied.** Skills are built through `/skill-creator:skill-creator` (the official eval-driven engine); text compression goes through the installed caveman plugin. Do not inline either engine's content into other skills, prompts, or docs — invoke them so upstream improvements propagate.
3. **Descriptions are routers, not documentation.** Budgets: skill description 1–3 sentences (~20–50 words); agent description 1 sentence (~10–25 words). The body carries detail; the description pays an always-resident price in every session.
4. **Refactors require before/after evidence.** Never accept a skill/agent refactor that lowers trigger accuracy or eval pass-rate — brevity that breaks routing is a regression, not a win.
5. **Review is a two-stage gate, not an option.** Structural first, lexical second — see below; it runs on every persistent artifact this skill touches.

## Mandatory gate — two-stage review of every artifact

Every persistent harness artifact you write or rewrite while this skill is active goes through both stages **before the work ships**: skill `description`, agent `description`, agent prompt body, protocol message format, CLAUDE.md section, resident reference text.

**Timing:** never spawn reviews on intermediate revisions while the user is still iterating — early spawns get killed by the next change. Batch when the change set settles (end of the working session / before commit). One spawn per artifact per stage; several artifacts → all spawns in one message, concurrently.

**Stage 1 — structural.** Spawn `uc:caveman-reviewer` with `Stage: structural`. It checks the artifact against the catalogue in `references/structural-optimization.md` (duplication, altitude, form, payload zones — including cross-file duplication). Apply the findings you accept, then **get the user's confirmation that structural work is done** before moving on.

**Stage 2 — lexical.** Spawn with `Stage: lexical` on the structurally-settled artifacts. The reviewer runs the compression engine and returns an itemized cut list, each cut tagged `clean` / `fixable` (with the repaired wording) / `harmful`. Work through it item by item: adopt clean cuts, adopt fixable ones in their repaired form, skip harmful ones. **Never accept or reject a review wholesale — yield percentage is diagnostic information, not a decision rule.**

```
Agent(
  subagent_type: "uc:caveman-reviewer",
  run_in_background: false,          # it is a gate — you need the result before shipping
  description: "review <artifact> (<stage>)",
  prompt: "Artifact: <absolute path, or the inline text>.
           Kind: skill-description | agent-description | prompt-body | protocol-format | doc-section.
           Stage: structural | lexical.
           Payload zones: <text emitted verbatim into user output — template blocks, payload table columns; or none>.
           Prior review: <stage-1 findings already applied / earlier rounds; or none>.
           Siblings it must stay distinguishable from: <paths, or none>."
)
```

Rules that make this deterministic:

- **No self-assessment substitutes for the spawn.** "Already terse", "only a small edit", "I applied the rules myself", "the text is short" are not exemptions. A reviewer stage returning no findings is the only sanctioned no-op — it is cheap and it is the escape valve.
- **Out of scope:** ephemeral text — chat answers, one-off analysis, commit messages, code comments, anything not loaded into future sessions.
- **You decide, the reviewer proposes.** Item-by-item, both stages; accepted description changes additionally require the before/after trigger test (`references/testing-refactors.md`).
- **If the agent cannot be spawned** (not installed in this session), say so explicitly, then apply `references/structural-optimization.md` and the house rules in `references/efficient-communication.md` by hand — never silently skip the step.

## Routing

References live at `${CLAUDE_PLUGIN_ROOT}/skills/harness-builder/references/`.

| Need | Where |
|---|---|
| Structural/form optimisation — duplication catalogue, altitude cuts, payload zones (stage 1 of the gate) | `references/structural-optimization.md` |
| Writing or trimming a skill/agent description | `references/description-writing.md` |
| Efficient communication style; compressing resident text; caveman usage | `references/efficient-communication.md` |
| Measuring session startup context cost | `references/context-audit.md` + `scripts/context_audit.py` |
| Testing a skill/agent before/after a refactor | `references/testing-refactors.md` |
| Building agents: tools, model choice, addressing, hard limits | `references/agent-building.md` |

## Companion tools

- `/skill-creator:skill-creator` — creation + eval engine for skills (official plugin; includes a description-trigger optimizer).
- caveman plugin — compression engine, installed dormant (`defaultMode: off`), enabled selectively; see `references/efficient-communication.md`.
- `uc:caveman-reviewer` agent (this plugin) — proposition-only two-stage review of persistent harness text (structural findings, then itemized compression cuts); spawned per the mandatory gate above, not at discretion.

## Accumulating knowledge here

This base will grow. Rules that keep it navigable:

- New knowledge lands in the **narrowest matching reference**; if none fits, add a new single-topic reference plus one routing row. SKILL.md stays thin — principles and routing only.
- Tag every claim with its evidence class: **[OFFICIAL]** (vendor docs), **[COMMUNITY]** (practitioner reports), **[MEASURED]** (measured in this environment — include the number and date), **[JUDGMENT]** (reasoned synthesis).
- When new evidence contradicts a stored claim, **replace** the claim (keep a one-line "superseded" note) rather than appending a contradiction.
- Every reference states its scope in its first line, so routing stays decidable as files multiply.
