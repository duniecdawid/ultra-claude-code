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

Accumulated knowledge for building the harness — the skills, agents, hooks, and protocols that decide how Claude works. Knowledge questions pull the reference they need and answer directly. Build tasks — anything that creates or modifies a persistent harness artifact — walk the staged workflow below, editing in place on a clean git state; nothing committed before stage-5 approval.

## Non-negotiables

1. **Model floor: Opus.** Any session or agent doing harness-building work — writing or refactoring skills, agents, prompts, protocols — runs on Opus or better. The harness decides every downstream workflow; never build it with a small model.
2. **Engines are invoked, never copied — and invocation is commanded, not mentioned.** Building or refactoring a skill: **always invoke `/skill-creator:skill-creator`** (the official eval-driven engine). Compressing text: always through the caveman engine, via the `uc:caveman-compress` agent at stage 4. Never inline an engine's content into other skills, prompts, or docs — invoke it so upstream improvements propagate. This is also an authoring rule for every skill you write: when a skill delegates to another skill, phrase it as an explicit imperative ("always invoke /x:y"), never a passive mention ("built through", "via") — passive phrasing gets skipped.
3. **Descriptions are routers, not documentation.** Budgets: skill description 1–3 sentences (~20–50 words); agent description 1 sentence (~10–25 words). The body carries detail; the description pays an always-resident price in every session.
4. **Refactors require before/after evidence.** Never accept a skill/agent refactor that lowers trigger accuracy or eval pass-rate — brevity that breaks routing is a regression, not a win.
5. **Build tasks run the staged workflow.** Edits happen in place; git is the draft — target files clean at entry, nothing committed before stage-5 approval, rejection = `git restore`. Exempt: knowledge-only answers (nothing edited); meaning-preserving fixes (typo, formatting, broken path — if you would have to choose between wordings, it is not meaning-preserving: run the workflow); work already covered by a plan the user approved this session (`/uc:plan-execution` runs included). Precedence: if an Ultra Claude planning mode is active, its framework governs — serve as its knowledge base instead.
6. **Caveman rules apply during harness building.** Every artifact text authored or revised in this workflow follows the house style in `references/efficient-communication.md` from first draft — compressed register is the default writing mode, not something the stage-4 engine pass retrofits; the engine is mechanical finish. Human-facing exemption (help catalog entries, README/onboarding prose) per `references/stage-4-compression.md` still applies.
7. **Optimize by removing instructions.** Claude 5-generation models perform better with fewer instructions — default move is delete, not add. Never add verification/double-check instructions ("verify your answer", "re-check before responding", "use subagent to verify") — the model self-verifies; these compound into over-verification. No step-by-step process scaffolding for things the model already does — keep only genuine gotchas, constraints, and non-derivable facts. Editing an existing component: first pass = removal pass — ask "which lines exist only because an older model once failed?" and cut those before writing anything new. New component: start minimal — purpose, hard constraints, non-derivable facts; add a rule only after observed failure, never preemptively. Docs: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5

## Build workflow — stages

Persistent harness artifacts: skill descriptions, agent descriptions, prompt bodies, protocol message formats, CLAUDE.md sections, resident reference text.

**Entry:** confirm target files are clean in git (non-git target: backup copy to session scratchpad first), then read `references/stage-1-structural.md`. If the target is a skill, always invoke `/skill-creator:skill-creator` — its eval-driven flow runs inside this workflow. Each stage file names the next one — the table below is overview only.

| Stage | What happens | Reference |
|---|---|---|
| 1 — structural | catalogue check + payload-zone inventory; structural proposal; discuss until the user confirms it settled | `references/stage-1-structural.md` |
| 2 — lexical | hand pass — house style on bodies; discuss | `references/stage-2-lexical.md` |
| 3 — description & name | write description (and name) to match the confirmed body; discuss | `references/stage-3-description.md` |
| 4 — compression | spawn `uc:caveman-compress` per body artifact; adopt cuts item by item; discuss | `references/stage-4-compression.md` |
| 5 — present | present `git diff` + sync steps; explicit approval; sync + commit | `references/stage-5-present.md` |

## Routing — knowledge questions

For questions outside the build workflow (build tasks get their references through the stage chain). References live at `${CLAUDE_PLUGIN_ROOT}/skills/harness-builder/references/`.

| Need | Where |
|---|---|
| Structural/form optimisation — duplication catalogue, altitude cuts, payload zones | `references/structural-optimization.md` |
| Writing or trimming a skill/agent description | `references/description-writing.md` |
| Efficient communication style; compressing resident text; caveman usage | `references/efficient-communication.md` |
| Measuring session startup context cost | `references/context-audit.md` + `scripts/context_audit.py` |
| Testing a skill/agent before/after a refactor | `references/testing-refactors.md` |
| Building agents: tools, model choice, addressing, hard limits | `references/agent-building.md` |

## Accumulating knowledge here

This base will grow. Rules that keep it navigable:

- New knowledge lands in the **narrowest matching reference**; if none fits, add a new single-topic reference plus one routing row. SKILL.md stays thin — principles and routing only.
- Tag every claim with its evidence class: **[OFFICIAL]** (vendor docs), **[COMMUNITY]** (practitioner reports), **[MEASURED]** (measured in this environment — include the number and date), **[JUDGMENT]** (reasoned synthesis).
- When new evidence contradicts a stored claim, **replace** the claim (keep a one-line "superseded" note) rather than appending a contradiction.
- Every reference states its scope in its first line, so routing stays decidable as files multiply.
