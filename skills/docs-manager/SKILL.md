---
description: Guards documentation/ canonical structure. Activated by .claude/ultra/docs-format file. Routes documents to correct directories, enforces layout, generates documentation index. Use proactively when any mode or agent creates documentation.
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

You are the guardian of the project's documentation structure. Your role is to ensure all documentation lands in the correct directory, follows the canonical layout, and maintains a navigable index.

## Activation

This skill only activates in projects that have a `.claude/ultra/docs-format` file. Before acting, verify this file exists. If it does not exist, do nothing — documentation management is not enabled for this project.

Read `.claude/ultra/docs-format` to determine the output format:
- `docsify` — Docsify-compatible markdown with directory-as-page convention (default)
- `markdown` — Plain markdown, no special markers
- `confluence` — Confluence-compatible markdown with space/title markers
- `gitbook` — GitBook-compatible markdown with SUMMARY.md navigation

## Canonical Documentation Layout

This is the non-negotiable structure. All documentation MUST fit within it:

```
documentation/
├── README.md                          # Navigable index (auto-generated)
├── technology/
│   ├── README.md                      # Technology overview (docsify)
│   ├── architecture/
│   │   ├── README.md                  # Architecture overview (docsify)
│   │   └── ...
│   ├── standards/
│   │   ├── README.md                  # Standards overview (docsify)
│   │   └── ...
│   ├── testing/
│   │   ├── README.md                  # Testing overview (docsify)
│   │   └── ...
│   ├── rfcs/
│   │   ├── README.md                  # RFCs overview (docsify)
│   │   └── ...
│   └── research/
│       ├── README.md                  # Technology research overview (docsify)
│       ├── index.json                 # Machine-maintained research index (researcher agent)
│       ├── libraries/
│       │   ├── README.md              # Library/API research (docsify)
│       │   └── ...                    # One file per library, multiple H2 topics
│       └── patterns/
│           ├── README.md              # Patterns / best-practices research (docsify)
│           └── ...                    # One file per pattern topic
├── product/
│   ├── README.md                      # Product overview (docsify)
│   ├── description/
│   │   ├── README.md                  # Description overview (docsify)
│   │   └── ...
│   ├── research/
│   │   ├── README.md                  # Research overview (docsify)
│   │   └── ...
│   ├── requirements/
│   │   ├── README.md                  # Requirements overview (docsify)
│   │   └── ...
│   └── personas/
│       ├── README.md                  # Personas overview (docsify)
│       └── ...
├── plans/
│   └── {plan-name}/
│       ├── README.md                  # Plan document (task list embedded)
│       ├── shared/                    # Lead-level shared notes (execution)
│       └── tasks/                     # Per-task pipeline artifacts (execution)
└── backlog/                           # Lightweight backlog (bugs, questions, ideas, debt)
    ├── bugs.json
    ├── questions.json
    ├── ideas.json
    └── debt.json
```

**No top-level files** inside `documentation/` except `README.md`. Every document belongs in a subdirectory.

> **Docsify convention:** When format is `docsify`, every category directory MUST contain a `README.md`. In Docsify, clicking a directory in the sidebar loads its `README.md` as the directory's page. Without it, the user gets a 404.

## Routing Rules

When any mode, agent, or user creates documentation, route it to the correct location:

| Content Type | Correct Location | Signals |
|-------------|-----------------|---------|
| System design, component diagrams, data flow | `technology/architecture/` | Contains: architecture, design, component, system, data flow, tech stack |
| Coding conventions, API standards, patterns | `technology/standards/` | Contains: convention, standard, pattern, style guide, coding rules |
| Test strategy, commands, tester agent rules, security testing | `technology/testing/` | Contains: test strategy, test commands, tester rules, security testing, final gate, test infrastructure |
| Decision reviews (problem, options, outcome) | `technology/rfcs/` | Contains: RFC, decision review, trade-off analysis, options evaluation |
| Library / API research (Ref.tools excerpts, verbatim docs) | `technology/research/libraries/` | Contains: API signatures, library docs, SDK reference, package documentation. Written by the `researcher` agent via `/uc:research`. |
| Pattern / best-practices research | `technology/research/patterns/` | Contains: architectural patterns, strategy comparisons, tradeoff analyses. Written by the `researcher` agent via `/uc:research`. |
| Product vision, positioning, product briefs | `product/description/` | Contains: vision, positioning, product brief, description |
| Market research, competitor analysis, technology landscape | `product/research/` | Contains: competitor, market, research, technology landscape, trends. Written by Discovery Mode or the `researcher` agent via `/uc:research --mode=market`. |
| Formal requirements, user stories | `product/requirements/` | Contains: requirement, FR-, NFR-, acceptance criteria, user story, must have, should have |
| User personas, audience profiles | `product/personas/` | Contains: persona, user profile, demographics, pain points, user archetype |
| Plans, task lists, execution context | `plans/{name}/` | Contains: plan, task list, implementation steps |
| Blocking questions, deps, ideas, bugs | **Project backlog** | Contains: blocker, dependency, waiting on, open question, idea, bug, follow-up. Route via `/uc:backlog add ...` — do NOT create standalone documents for these |

### Routing Process

When you see a document being created:

1. **Classify** — Determine the content type from the document's content and filename
2. **Route** — Map to the correct subdirectory using the routing table
3. **Apply reference** — For new documents, read the matching reference guide from `references/` and use the embedded template
4. **Reject violations** — If a write targets the wrong location, redirect it
5. **Create directory** — If the target subdirectory doesn't exist, create it

### Common Violations to Catch

- `documentation/auth-notes.md` — Wrong: no top-level files. Route to `technology/architecture/auth.md`
- `documentation/api-spec.md` — Wrong: no top-level files. Route to `technology/architecture/api-spec.md`
- `documentation/todo.md` — Wrong: not documentation. Plans go to `plans/`
- `docs/` or `doc/` — Wrong directory name. Must be `documentation/`
- Architecture content in `product/` — Wrong category. Route to `technology/architecture/`

## Document Type References

Each document type has a reference guide that explains how to create it — purpose, perspective, guidance on what to include, common pitfalls, and a template. References live at `${CLAUDE_PLUGIN_ROOT}/skills/docs-manager/references/`.

Before creating any new document, read the reference for the target content type:

| Content Type | Reference | Target Directory |
|-------------|----------|-----------------|
| System design, components, data flow | `references/architecture.md` | `technology/architecture/` |
| Coding conventions, patterns | `references/standard.md` | `technology/standards/` |
| Test strategy, commands, agent rules | `references/testing.md` | `technology/testing/` |
| Decision reviews | `references/rfc.md` | `technology/rfcs/` |
| Library / API / pattern research | `references/technology-research.md` | `technology/research/libraries/`, `technology/research/patterns/` |
| Product vision, positioning | `references/product-description.md` | `product/description/` |
| Market research, competitor analysis | `references/research.md` | `product/research/` |
| Formal requirements, user stories | `references/requirement.md` | `product/requirements/` |
| User personas | `references/persona.md` | `product/personas/` |
| Blocking questions, deps, ideas, bugs, tech debt | *(use `/uc:backlog add ...`)* | `documentation/backlog/` |

Reference paths are relative to this skill's directory (`skills/docs-manager/`).

### Rules

1. **New documents** — Read the reference guide for that doc type. Follow the guidance and use the embedded template as a starting point. Remove sections that genuinely don't apply.
2. **Existing documents** — Do not reformat to match the template. Use the reference as a guide for what sections might be missing or what content belongs elsewhere.
3. **Plans** — Plan documents use a separate template (`${CLAUDE_PLUGIN_ROOT}/templates/plan.md`), not managed by this skill.

## Document Relationships

Each document type has a distinct perspective. Content must not be duplicated across types — instead, documents cross-reference each other.

| Doc Type | Perspective | Contains | Does NOT contain |
|----------|------------|----------|-----------------|
| Product description | **User** — how the platform works | Capabilities, user experience, workflows | Technical implementation, market data |
| Requirements | **Goals** — what problems to solve | Success criteria, acceptance criteria, priorities | How it's built, market context |
| Research | **Market** — external context and data | Competitors, trends, evidence, implications | Platform behavior, architecture details |
| Architecture | **Builder** — how the platform is built | Components, data flow, tech stack, interfaces | User experience, market analysis |
| Standards | **Quality** — how code should be written | Conventions, patterns, anti-patterns | Product behavior, market data |
| Testing | **Verification** — how to prove it works | Strategy, commands, coverage, agent rules | Product behavior, architecture design |

### Cross-Reference Pattern

Documents link to related docs of other types rather than restating their content:

- **Product description** → links to architecture (how it's built), research (why these capabilities matter), requirements (what must be achieved)
- **Architecture** → links to product description (what it enables), requirements (what it must achieve), standards (how to build it)
- **Requirements** → links to product description (what's being required), research (evidence for priorities), personas (who needs this)
- **Research** → links to product description (what it informs), requirements (implications for priorities)
- **Personas** → links to product description (what they use), requirements (what's built for them)

Each template includes a "Related" section with these cross-reference slots. When creating or updating a document, populate the Related section with actual links — not placeholders.

## Structure Enforcement

### On Document Creation

Before writing any document to `documentation/`:

1. **Check the target path** — does it match the canonical structure?
2. **If wrong** — determine the correct path and redirect
3. **If ambiguous** — ask the user which category the document belongs to
4. **Create parent directories** as needed
5. **If format is docsify** — ensure the target category directory has a `README.md`. If missing, create one from the category README template (see Docsify section below)

### Docsify README.md Audit

When format is `docsify`, during any audit or document creation, verify that every existing category directory contains a `README.md`. Category directories to check: `technology/`, `technology/architecture/`, `technology/standards/`, `technology/testing/`, `technology/rfcs/`, `technology/research/`, `technology/research/libraries/`, `technology/research/patterns/`, `product/`, `product/description/`, `product/research/`, `product/requirements/`, `product/personas/`.

If a category directory exists without a `README.md`, create one using the category README template.

### On Document Modification

When modifying existing documents:

1. **Verify the document is in the correct location** — if not, suggest moving it
2. **Do not restructure** while editing — suggest restructuring as a separate step

## Format Awareness

Apply format-specific rules based on `.claude/ultra/docs-format`:

### Docsify (default)

- Standard markdown with Docsify directory-as-page convention
- Use relative links: `[Link](../path/to/file.md)`
- **Directory README.md files are mandatory** — every category directory must contain a `README.md` that serves as the directory's landing page
- Each category README.md contains:
  1. H1 heading matching the category display name
  2. One-paragraph description of what the category covers
  3. Auto-maintained list of documents in the directory (linked name + one-line description)
- Do NOT create `_sidebar.md`, `index.html`, or `.nojekyll` — the Ultra Dashboard generates the sidebar on the fly and handles Docsify serving

#### Category README.md Template

```markdown
# {Category Display Name}

{Description}

## Documents

- [Doc Name](filename.md) — One-line description
```

Category descriptions:

| Directory | Display Name | Description |
|-----------|-------------|-------------|
| `technology/` | Technology | Technical documentation covering architecture, standards, testing, and decisions. |
| `technology/architecture/` | Architecture | System design — components, data flow, tech stack, interfaces. |
| `technology/standards/` | Standards | Coding conventions, patterns, quality bars, style guides. |
| `technology/testing/` | Testing | Test strategy, commands, agent rules, coverage standards. |
| `technology/rfcs/` | RFCs | Structured decision reviews for ambiguous/high-risk decisions. |
| `technology/research/` | Research | External library, API, and pattern research. Machine-maintained by the `researcher` agent via `/uc:research`. |
| `technology/research/libraries/` | Libraries | Per-library research — API signatures, code examples, breaking changes. One file per library. |
| `technology/research/patterns/` | Patterns | Architectural pattern and best-practices research. One file per topic. |
| `product/` | Product | Product documentation — vision, research, requirements, personas. |
| `product/description/` | Description | Product briefs, vision, positioning. |
| `product/research/` | Research | Market research, competitor analysis, technology landscape. |
| `product/requirements/` | Requirements | Formal requirements, user stories, acceptance criteria. |
| `product/personas/` | Personas | Evidence-based user personas and audience profiles. |

### Markdown

- Standard markdown, no special markers
- Use relative links: `[Link](../path/to/file.md)`
- Tables, code blocks, and standard markdown features

### Confluence

- Add space/title markers at top of each file:
  ```
  <!-- Space: PROJECT -->
  <!-- Title: Document Title -->
  ```
- Flatten deep nesting (Confluence handles hierarchy differently)
- Tables render well; avoid deeply nested lists

### GitBook

- Maintain `documentation/SUMMARY.md` for navigation
- Use relative links: `[Link](path/to/file.md)`
- Use asterisks for list items, 2-space indentation

## Index Generation

Maintain `documentation/README.md` as a navigable project onboarding document. Regenerate it whenever documentation is added, removed, or restructured. The index should read as a coherent introduction to the project — not a file listing.

### Index Update Process

1. **Scan** all markdown files under `documentation/` (excluding README.md files themselves)
2. **Categorize** each by its parent directory
3. **Skip empty categories** — if a category directory has no documents (other than its own README.md), omit that category entirely from the index. Never render an empty section header.
4. **Extract** the first heading or filename as the document name
5. **Write the product intro** — read doc(s) in `product/description/` and write a ~5 sentence summary that explains what the project is, what problem it solves, and its purpose. If no product description exists, write: *"This project does not yet have a product description. Run `/uc:discovery-mode` to create one."*
6. **Generate** the index following the format below
7. **Write** to `documentation/README.md`
8. **If format is docsify** — also update each category `README.md` with its current document list

### Index Format

The index follows a product-first structure. Every section is **conditional** — only include it if matching documents exist.

```markdown
# {Project Name}

{~5 sentence product summary derived from product/description/ docs.
Covers: what the project is, the problem it solves, who it's for, and its core approach.}

## Product
- [Doc Name](product/description/filename.md) — One-line description
- [Doc Name](product/requirements/filename.md) — One-line description
- [Doc Name](product/personas/filename.md) — One-line description

## Research
- [Doc Name](product/research/filename.md) — One-line description

## Technology

### Architecture
- [Doc Name](technology/architecture/filename.md) — One-line description

### Standards
- [Doc Name](technology/standards/filename.md) — One-line description

### Testing
- [Doc Name](technology/testing/filename.md) — One-line description

### RFCs
- [Doc Name](technology/rfcs/filename.md) — One-line description

### Research
- [Library name](technology/research/libraries/filename.md) — One-line description
- [Pattern name](technology/research/patterns/filename.md) — One-line description

## Plans
See [Plans](plans/) for implementation plans and execution status.
```

### Section Rules

- **Product** — flat list combining description, requirements, and personas docs. Only include subcategories that have docs.
- **Research** (top-level) — flat list of **market** research docs from `product/research/`. Omit entire section if `product/research/` is empty.
- **Technology** — subsections for architecture, standards, testing, RFCs, research. Only include subsections that have docs. If no technology docs exist at all, omit the entire Technology section. The Research subsection merges files from `technology/research/libraries/` and `technology/research/patterns/`.
- **Index.json** — never rendered in the index; it's a machine file.
- **Plans** — check if `documentation/plans/` contains at least one subdirectory with a `README.md`. If yes, render the single-line link. If no, omit entirely.
- **Backlog** — never included in the index. Backlog is managed separately.

## File Naming

- Lowercase with hyphens: `api-design.md`, `auth-architecture.md`
- RFCs: `{NNN}-{descriptive-name}.md` (e.g., `001-auth-strategy.md`)
- Requirements: `FR-{NNN}-{name}.md` or `NFR-{NNN}-{name}.md`
- Plans: directory name is the plan name, main file is always `README.md`

## Constraints

- Do NOT create documentation outside `documentation/` (exception: `context/` is managed by context-management skill)
- Do NOT create top-level files inside `documentation/` except `README.md`
- Do NOT delete documentation without user confirmation
- Do NOT restructure documentation during an edit — suggest it as a separate step
- Do NOT modify `context/` — that is managed by the context-management skill
- Always regenerate the index after structural changes
