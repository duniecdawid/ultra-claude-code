# Explore Agent Prompts (Phase 3 — Stage B)

Spawn these as parallel Explore agents (subagent_type `Explore`, thoroughness: `very thorough`). Run up to 5 agents in parallel; batch if more.

## Standards Explore Agent

One per approved standard topic:

> Research coding standards for {topic} in this project.
>
> Context:
> - Project: {name}, Tech stack: {stack}
> - Code Surveyor findings: {relevant standards signals for this topic}
> - User-provided context: {if any, from "I'll add context" responses}
>
> Focus on:
> 0. Invoke the `/uc:research` skill with args "{topic} best practices {stack}" to get external documentation and established conventions for this topic (auto-classified as patterns mode). The skill is cache-first — if this topic was already researched in this project, you'll get an immediate hit. Incorporate these findings alongside codebase patterns.
> 1. Read all files identified in survey signals for this topic
> 2. Grep for additional patterns related to {topic}
> 3. Catalogue findings: file path, line, pattern description, whether it's a good pattern (-> rule) or bad pattern (-> FORBIDDEN)
> 4. Cross-reference architecture docs in `documentation/technology/architecture/`
> 5. Check for existing conventions files
>
> Return findings in this format:
> ## External Best Practices (from /uc:research)
> - {best practice}: {source}
>
> ## Good Patterns Found
> - {pattern}: {file:line} — {description}
>
> ## Anti-Patterns Found
> - {anti-pattern}: {file:line} — {what's wrong, what to use instead}
>
> ## Technology-Specific Conventions
> - {convention}: {evidence}
>
> ## Gaps / Missing Information
> - {what couldn't be determined}

## Testing Config Explore Agent

One agent for the entire testing config:

> Research test infrastructure for this project.
>
> Context:
> - Project: {name}, Tech stack: {stack}, Domain: {domain}
> - Test infra findings: {from Code Surveyor's Test Infrastructure section}
>
> Focus on:
> 1. Read all test config files, CI pipelines, existing test files
> 2. Catalog every test command (package.json scripts, Makefile targets, CI steps)
> 3. Assess domain security needs (payment system -> all categories; CRUD app -> auth + validation)
> 4. Document the test pyramid as it currently exists
>
> Return: test commands, frameworks, infra, security concerns, domain-specific risks, existing test patterns.
