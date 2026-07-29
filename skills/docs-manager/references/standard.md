# Reference: Standards

## Purpose

A standards document defines how code should be written — conventions, patterns, and anti-patterns. It's the document a developer or code reviewer checks to ensure consistency across the codebase.

## Perspective

**Quality-focused.** Write for someone who needs to know the right way to do things in this project and why.

- DO include: conventions, patterns, anti-patterns, code examples, review checklists
- DO NOT include: system design (→ architecture), product behavior (→ product description), market context (→ research)

## How to Write One

Start with the principle (see template). If a rule doesn't connect to the principle, it might not belong here.

The FORBIDDEN table is the most actionable part. List specific anti-patterns alongside the correct approach. These should be concrete enough for mechanical code review — "don't use `any` type" not "avoid loose typing."

Include real code examples from the codebase when possible. A rule that says "use the repository pattern" is weaker than one that shows how the project's repository pattern actually looks.

**Common pitfalls:**
- Rules too vague to enforce ("write clean code")
- Standards disconnected from the codebase's actual patterns
- No examples — developers need to see what right looks like
- Forgetting to link to sibling standards that interact with this one

## Template

```markdown
# {Title} Standard

> Established: {date}
> Applies to: {scope}
> Related: {sibling standards}

## Principle

{One paragraph — the core belief grounding this standard. Every rule below traces back to this principle.}

## FORBIDDEN

| Forbidden | Use instead |
|---|---|
| {anti-pattern} | {correct approach} |

## {Topic-specific sections}

{Tables, code examples, numbered rules, checklists — using the project's actual language, framework, and naming conventions.}

## Related

- {Links to sibling standards and architecture docs}
```

## Cross-References

- Links TO: architecture (what system these standards apply to), sibling standards
- Links FROM: architecture (how to build it), plans (task Patterns field)
