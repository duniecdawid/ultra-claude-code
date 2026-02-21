# Decisions

Architectural decisions that have been made, and open questions still to resolve.

## Decided

Key assumptions the design is built on. If any of these prove wrong, the affected parts of the architecture need revisiting.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Agent teams are the primary coordination mechanism.** | Enables direct teammate communication, shared task lists, and self-claiming. If agent teams destabilize, we fall back to subagents (the execute-plan skill already supports this via Task tool). |
| D2 | **Documentation structure is consistent across all projects.** | Every project using Ultra Claude follows the same `documentation/` layout. This is non-negotiable — it's how specs govern code. |
| D3 | **CLAUDE.md is the entry point, not a replacement target.** | The plugin augments but does not replace project CLAUDE.md. Project-specific rules live in CLAUDE.md; Ultra Claude provides the framework. |
| D4 | **Token cost is acceptable.** | Agent teams are expensive (~200K tokens per teammate). The user has accepted this trade-off for the coordination benefits. |
| D5 | **The plugin is personal.** | Built for one developer's workflow. May be shared later, but the primary user is the author. |
| D6 | **Hooks are the enforcement layer.** | CLAUDE.md rules can be forgotten under context pressure. Hooks cannot be overridden. Critical governance rules go in hooks. |
| D7 | **Ref.tools MCP is a prerequisite.** | The tech-research skill is bundled in the plugin, but it depends on Ref.tools MCP being configured in the environment. The plugin owns the skill; the user owns the MCP server setup. |
| D8 | **The init script handles project setup.** | When Ultra Claude is installed in a new project, `init-docs.sh` creates the `documentation/` directory structure with templates. The user then fills in project-specific content. |

## Open Questions

To resolve before implementation begins.

| # | Question | Options / Notes |
|---|----------|-----------------|
| Q1 | **Command prefix**: Is `/uc:` the right namespace? | Alternatives: `/ultra:`, no prefix (just `/execute`, `/verify`, etc.) |
| Q2 | **Team persistence**: When a plan spans multiple sessions, how do we handle team recreation? | Current approach: checkpoint everything to files, recreate team on resume. |
| Q3 | **Discovery mode enforcement**: Should coding be disabled via hooks (hard) or CLAUDE.md instructions (soft)? | Hook is more reliable but requires careful implementation. |
| Q4 | **Docs format flexibility**: Should the plugin mandate a specific documentation format (Confluence-style, GitBook-style) or be format-agnostic? | — |
| Q5 | **Existing documentation**: How does the plugin interact with projects that already have documentation? | Does it adapt to existing structure or require migration to the Ultra Claude layout? |
| Q6 | **Help: skill or command?** | Skills auto-activate based on triggers; commands require explicit invocation. Help might benefit from explicit invocation to avoid unwanted activation. |
| Q7 | **Bundled MCP servers**: Should the plugin bundle any MCP servers? | Current thinking: no — rely on globally configured MCP servers (Ref.tools, Atlassian). |
