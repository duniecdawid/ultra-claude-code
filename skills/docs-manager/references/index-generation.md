# Index Generation

Scope: how to regenerate `documentation/README.md` (the navigable project index). Read when documentation is added, removed, or restructured.

The index reads as a coherent introduction to the project — not a file listing.

## Update Process

1. **Scan** all markdown files under `documentation/` (excluding README.md files themselves)
2. **Categorize** each by its parent directory
3. **Extract** the first heading or filename as the document name
5. **Write the product intro** — read doc(s) in `product/description/` and write a ~5 sentence summary: what the project is, what problem it solves, its purpose. If no product description exists, write: *"This project does not yet have a product description. Run `/uc:discovery-mode` to create one."*
6. **Generate** the index following the format below
7. **Write** to `documentation/README.md`
8. **Update category READMEs** — refresh each category `README.md` with its current document list

## Index Format

Product-first structure. **Empty ⇒ omit, at every level**: a section, subsection, or category with no matching documents (a category's own README.md doesn't count) is left out entirely — never render an empty header.

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

## Section Rules

- **Product** — flat list combining description, requirements, and personas docs.
- **Research** (top-level) — flat list of **market** research docs from `product/research/`.
- **Technology** — subsections for architecture, standards, testing, RFCs, research. The Research subsection merges files from `technology/research/libraries/` and `technology/research/patterns/`.
- **Index.json** — never rendered; it's a machine file.
- **Plans** — counts as non-empty only when `documentation/plans/` contains at least one subdirectory with a `README.md`; renders as the single-line link.
- **Backlog** — never included. Backlog is managed separately.
