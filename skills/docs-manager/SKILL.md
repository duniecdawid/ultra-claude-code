---
description: Guards documentation/ canonical structure. Routes documents to correct directories, enforces layout, generates documentation index. Use proactively when any mode or agent creates documentation.
argument-hint: "audit, reorganize, or regenerate index"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Docs Manager

Guardian of the project's documentation structure: every document lands in the correct directory, follows the canonical layout, and stays reachable through a navigable index. Always enabled.

## Canonical Layout

- Everything lives under `documentation/` — never `docs/` or `doc/`. The top level holds only `README.md` (the auto-generated navigable index); every document belongs in a subdirectory from the table below (todo/task files are plans, not documentation).
- **Category README.md files are mandatory** — the dashboard renders a directory through its `README.md`; without it the user gets a 404. Create missing ones on sight.

## Directory Table

Single source for structure, routing, and category READMEs. Classify content by the **Description** column; the Description is also the literal `{Description}` payload for the category's README.

Read the **Reference** guide (paths relative to `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/`) before creating any new document of that type — purpose, perspective, pitfalls, and an embedded template to start from (drop sections that genuinely don't apply). Do not reformat existing documents to match the template — use the reference as a guide for what's missing or misplaced.

| Directory | Description | Reference |
|-----------|-------------|-----------|
| `technology/` | Technical documentation covering architecture, standards, testing, and decisions. | — |
| `technology/architecture/` | System design — components, data flow, tech stack, interfaces. | `references/architecture.md` |
| `technology/standards/` | Coding conventions, API standards, patterns, quality bars, style guides. | `references/standard.md` |
| `technology/testing/` | Test strategy, test commands, tester agent rules, security testing, final gate, coverage standards. | `references/testing.md` |
| `technology/rfcs/` | Structured decision reviews (problem, options, trade-offs, outcome) for ambiguous/high-risk decisions. | `references/rfc.md` |
| `technology/research/` | External library, API, and pattern research. Machine-maintained by the `researcher` agent via `/uc:research`; holds `index.json`, the machine research index. | — |
| `technology/research/libraries/` | Per-library research — API signatures, code examples, breaking changes, verbatim Ref.tools excerpts. One file per library. | `references/technology-research.md` |
| `technology/research/patterns/` | Architectural pattern and best-practices research — strategy comparisons, tradeoff analyses. One file per topic. | `references/technology-research.md` |
| `product/` | Product documentation — vision, research, requirements, personas. | — |
| `product/description/` | Product briefs, vision, positioning. | `references/product-description.md` |
| `product/research/` | Market research, competitor analysis, technology landscape. Written by Discovery Mode or `/uc:research --mode=market`. | `references/research.md` |
| `product/requirements/` | Formal requirements (FR-/NFR-), user stories, acceptance criteria. | `references/requirement.md` |
| `product/personas/` | Evidence-based user personas — demographics, pain points, goals. | `references/persona.md` |
| `plans/{name}/` | Implementation plans and execution context. Each plan: `README.md` (plan + task list), `shared/` (lead notes), `tasks/` (per-task artifacts). | `${CLAUDE_PLUGIN_ROOT}/templates/plan.md` — plans are not managed by this skill |
| `backlog/` | Blocking questions, dependencies, ideas, bugs, tech debt — `bugs.json`, `questions.json`, `ideas.json`, `debt.json`. Never standalone documents; route via `/uc:backlog add ...`. | `/uc:backlog` skill |

## Document Standard

- Standard markdown with relative links: `[Link](../path/to/file.md)`
- Category README template — display name is the directory name capitalized (`rfcs/` renders as RFCs), Description from the table:

```markdown
# {Category Display Name}

{Description}

## Documents

- [Doc Name](filename.md) — One-line description
```

**README audit:** during any audit or document creation, verify every existing category directory in the table contains a `README.md`. If one exists without it, create it from the template.

## One Canonical Home Per Fact

**Every fact lives in exactly one document; others link to it.** Applies hardest to drift-prone content — schemas, config values, versions, definitions, procedures, acceptance criteria, contract shapes — because copies silently diverge. A 1–2 sentence orienting summary beside the link is fine.

Content belongs to the doc type whose perspective it matches — each type has a distinct one: product description = **User** (how it works) · requirements = **Goals** (what it must achieve, measurable) · product research = **Market** (external evidence) · architecture = **Builder** (how it's built) · standards = **Quality** (how code is written) · testing = **Verification** (how to prove it works) · personas = **Audience** (who it serves) · RFCs = **Decisions** (why it is this way). The commonest tension is description vs requirements: the description says *how it works* for the user, requirements say *what it must achieve* with measurable criteria — they reference each other heavily, never duplicate.

Link forms (paths always relative):

- **Section pointer** — `[doc §Section](../path.md#heading-anchor)` — preferred for drift-prone content; anchor required, matching a real heading slug, so the section is jumpable without reading the whole file. Keep target headings stable; renaming one means updating its inbound anchors.
- **Whole-doc** — `[Name](../path.md)`; **prose pointer** — "defined in `file` §N".
- **Decision record** — an RFC lists each decision in a table whose last column links to the canonical home of the settled state.

Rules:

- Before writing drift-prone content, Grep for an existing home; link instead of copying.
- Decision rationale and history live in RFCs, which link forward to the settled state; design/architecture/product docs carry only the current design — no decision residue (dates, attributions, superseded-option framing).
- Every template ends with a "Related" section — populate it with real links, not placeholders.

## Index

Maintain `documentation/README.md` as a navigable project onboarding document. Regenerate it whenever documentation is added, removed, or restructured — process, format, and section rules in `references/index-generation.md`.

## File Naming

- Lowercase with hyphens: `api-design.md`, `auth-architecture.md`
- RFCs: `{NNN}-{descriptive-name}.md` (e.g., `001-auth-strategy.md`)
- Requirements: `FR-{NNN}-{name}.md` or `NFR-{NNN}-{name}.md`
- Plans: directory name is the plan name, main file is always `README.md`

## Constraints

- Do NOT create documentation outside `documentation/` (exception: `context/` is managed by the context-management skill — never modify it)
- Do NOT delete documentation without user confirmation
- Do NOT restructure documentation during an edit — suggest it as a separate step
