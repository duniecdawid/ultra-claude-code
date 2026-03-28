---
description: Manages the context/ directory for external system knowledge. Structures docs and code for each external system, manages git submodules, generates context index. Use when adding external API docs, SDK references, code samples, or git submodules. Triggers on "add context", "add external system", "update context", "add API docs".
user-invocable: true
argument-hint: "system name or action (e.g., 'add stripe', 'update auth0 docs')"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Context Management

You manage the `context/` directory — the project's knowledge base about external systems. This directory lives at the project root (not inside `documentation/`) because it contains reference material and code that informs the spec but is not the spec itself.

## Context Directory Structure

Each external system gets its own subdirectory with a consistent layout:

```
context/
├── README.md                     # Index of all external systems
├── {system-name}/
│   ├── docs/                     # API docs, specs, guides, protocols
│   └── code/                     # Git submodules, SDKs, code samples
```

## Actions

Parse `$ARGUMENTS` to determine what the user wants:

### Add a New External System

**Trigger:** "add stripe", "add context for auth0", "new external system"

1. Derive system name: lowercase, hyphenated (e.g., "Auth0" -> `auth0`, "Internal API" -> `internal-api`)
2. Create directory structure:
   ```
   context/{system-name}/
   ├── docs/
   └── code/
   ```
3. Ask the user what information to add:
   - API documentation URLs (fetch and save key sections)
   - SDK or code repository (add as git submodule)
   - Configuration guides or protocols
4. Update `context/README.md` index

### Add Documentation to Existing System

**Trigger:** "update stripe docs", "add API spec for internal-api"

1. Verify the system directory exists
2. Add documentation to `{system-name}/docs/`:
   - If URL provided: fetch key content and save as markdown
   - If file provided: organize into the docs directory
   - If description provided: create a structured reference file
3. Update `context/README.md` index

### Add Code Reference

**Trigger:** "add stripe SDK", "add code samples for auth0"

1. Verify the system directory exists
2. Add to `{system-name}/code/`:
   - **Git submodule:** `git submodule add {url} context/{system}/code/{repo-name}`
   - **Code samples:** Create files directly in `code/`
3. Update `context/README.md` index

### Update Git Submodules

**Trigger:** "update submodules", "update context code"

1. List existing submodules in `context/`
2. Update each: `git submodule update --remote context/{system}/code/{repo}`
3. Report what changed

### Generate Agent-Ready Summary

**Trigger:** "summarize context", "context overview"

1. Scan all systems in `context/`
2. For each system, extract:
   - What APIs/services it provides
   - What documentation is available
   - What code references exist
3. Update `context/README.md` with comprehensive index

## Index Format (context/README.md)

```markdown
# External System Context

Knowledge base for external systems this project integrates with.

## Systems

### {System Name}
- **What:** {One-line description of the system}
- **Docs:** {List of available documentation}
- **Code:** {List of code references/submodules}
- **Key APIs:** {Most commonly used APIs or endpoints}

### {System Name 2}
...
```

## Documentation File Naming

- API references: `api-reference.md`, `api-{version}.md`
- Guides: `{topic}-guide.md` (e.g., `webhook-guide.md`)
- Specs: `{topic}-spec.md` (e.g., `openapi-spec.md`)
- Config: `configuration.md`, `{topic}-config.md`
- Migration: `migration-{from}-to-{to}.md`

## Process for Adding Documentation from URLs

When the user provides a URL:

1. Use `mcp__ref__ref_search_documentation` to find relevant docs
2. Use `mcp__ref__ref_read_url` to get focused content
3. Save key information as structured markdown in `{system}/docs/`
4. Do NOT dump raw HTML — extract and organize key facts
5. Include source URL as reference at the top of each file

## Constraints

- Do NOT modify `documentation/` — that is managed by the docs-manager skill
- Do NOT create context entries without the standard `docs/` + `code/` subdirectories
- Do NOT add git submodules without user confirmation (they modify .gitmodules)
- Always update `context/README.md` after any structural change
- Keep documentation files focused — one topic per file, under 200 lines
- Reference source URLs in all documentation files

## Examples

**User:** `/uc:context-management add stripe`

Creates:
```
context/stripe/
├── docs/
└── code/
```
Then asks: "What Stripe information should I add? Options: API reference, webhook docs, SDK submodule, or all of the above?"

---

**User:** `/uc:context-management add auth0 OIDC flow documentation`

1. Searches Ref.tools for Auth0 OIDC docs
2. Reads and extracts key content
3. Writes to `context/auth0/docs/oidc-flow.md`
4. Updates `context/README.md`

---

**User:** `/uc:context-management add submodule https://github.com/stripe/stripe-node`

Asks for confirmation, then:
```bash
git submodule add https://github.com/stripe/stripe-node context/stripe/code/stripe-node
```
Updates `context/README.md`
