---
description: Research external library/framework documentation efficiently using Ref.tools MCP. Use when adding new libraries, debugging external dependencies, finding best practices, researching breaking changes, or any task involving unfamiliar technology. Triggers on "how does X work", "why is X failing", "best practice for X", "what changed in X", "research library", "look up docs", "check documentation".
user-invocable: true
argument-hint: "library or topic to research"
---

# Tech Research

Research external libraries, frameworks, and services using Ref.tools MCP with session-aware token optimization.

## Why This Skill

Web search for library documentation wastes 50,000+ tokens on raw docs, often returns outdated info. Ref.tools MCP returns focused ~500-5k tokens with session-aware filtering, always up-to-date.

## Process

### Step 1: Load Domain Context

Read `.claude/app-context-for-research.md` if it exists. This provides project-specific context that helps frame research queries accurately.

### Step 2: Parse the Query

From `$ARGUMENTS`, identify:
- **Library/framework name** (e.g., "zod", "NATS", "BigQuery")
- **Specific topic** (e.g., "schema validation", "consumer config", "batch inserts")
- **Use case** (e.g., "adding to project", "debugging", "migration")

### Step 3: Search Documentation

Use `mcp__ref__ref_search_documentation` to find relevant docs:

```
Query format: "{library} {topic} {language/framework context}"
Example: "zod object schema validation typescript"
```

Include programming language and framework names in the query for better results. If the app context mentions specific technologies, include them.

### Step 4: Read Specific Content

Use `mcp__ref__ref_read_url` to get focused content from the most relevant results:

- Read the top 1-3 results
- Focus on API reference and examples
- Skip marketing/overview pages

### Step 5: Search Codebase

Find existing usage patterns in the project:

- Use Glob to find files importing the library
- Use Grep to find usage patterns
- Cross-reference with documentation findings

### Step 6: Output Findings

Structure findings in the standard format below.

## Output Format

```markdown
## Research: {topic}

### Documentation (Ref.tools)
- {key finding 1}
- {key finding 2}
- {key finding 3}

Sources: {URLs consulted}

### Codebase Patterns
- Found in `{file}:{line}`: {description}
- Similar to: {existing pattern}

### Recommendation
{actionable guidance based on docs + codebase context}

### Discrepancies (if any)
| Source | Says |
|--------|------|
| Docs | {X} |
| Code | {Y} |
```

## Examples

### New Library Research

**User:** `/uc:tech-research zod schema validation`

1. Search: `mcp__ref__ref_search_documentation(query="zod object schema validation typescript")`
2. Read: top results via `mcp__ref__ref_read_url`
3. Codebase: `Grep(pattern="z\\.object|from.*zod")` to find existing usage
4. Output structured findings

### Debugging External Service

**User:** `/uc:tech-research NATS JetStream consumer not receiving`

1. Search: `mcp__ref__ref_search_documentation(query="NATS JetStream consumer configuration troubleshooting")`
2. Read: relevant troubleshooting pages
3. Codebase: `Grep(pattern="JetStream|consumer")` to find config
4. Compare documented config requirements with actual code

### Breaking Changes / Migration

**User:** `/uc:tech-research breaking changes Node.js 22`

1. Search: `mcp__ref__ref_search_documentation(query="Node.js 22 migration breaking changes")`
2. Read: changelog and migration guide
3. Codebase: check `package.json` for current version, scan for deprecated APIs
4. Output migration-specific findings

## Error Handling

If Ref.tools MCP is unavailable:

1. Inform user: "Ref.tools unavailable — using web search fallback (higher token cost)"
2. Use `WebSearch(query="official documentation {library} {topic}")` as fallback
3. Use `WebFetch` to read the official docs page
4. Prefer official documentation sites over blog posts or tutorials

## Guidelines

- **Always search first** — do not assume you know the answer; docs may have changed
- **Read multiple pages** — complex topics may span several documentation pages
- **Check codebase** — always cross-reference with existing patterns in the project
- **Note discrepancies** — if docs differ from codebase usage, highlight it
- **Link sources** — include URLs of documentation pages consulted
- **Be concise** — focus on actionable information, not comprehensive summaries
- **Respect domain context** — frame findings in terms of the project's tech stack from `.claude/app-context-for-research.md`
