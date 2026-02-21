# Decisions

Architectural decisions that have been made, and open questions still to resolve.

## Decided

Key assumptions the design is built on. If any of these prove wrong, the affected parts of the architecture need revisiting.

| # | Decision | Rationale |
|---|----------|-----------|
| D1 | **Agent teams are the primary coordination mechanism.** | Enables direct teammate communication, shared task lists, and self-claiming. This is the foundational coordination choice — all execution patterns are designed for agent teams. |
| D2 | **Documentation structure is consistent across all projects.** | Every project using Ultra Claude follows the same `documentation/` layout. This is non-negotiable — it's how specs govern code. |
| D3 | **CLAUDE.md is the entry point, not a replacement target.** | The plugin augments but does not replace project CLAUDE.md. Project-specific rules live in CLAUDE.md; Ultra Claude provides the framework. |
| D4 | **Token cost is acceptable.** | Agent teams are expensive (~200K tokens per teammate). The user has accepted this trade-off for the coordination benefits. |
| D5 | **The plugin is personal.** | Built for one developer's workflow. May be shared later, but the primary user is the author. |
| D6 | **Hooks are the enforcement layer.** | CLAUDE.md rules can be forgotten under context pressure. Hooks cannot be overridden. Critical governance rules go in hooks. |
| D7 | **Ref.tools MCP is a prerequisite.** | The tech-research skill is bundled in the plugin, but it depends on Ref.tools MCP being configured in the environment. The plugin owns the skill; the user owns the MCP server setup. |
| D8 | **The init script handles project setup.** | When Ultra Claude is installed in a new project, `init-docs.sh` creates the `documentation/` directory structure with templates. The user then fills in project-specific content. |
| D9 | **Dynamic team composition over fixed roster.** | Lead decides team size based on plan characteristics. A 3-task plan doesn't need 5 teammates. See [Execution](execution.md) for sizing heuristics. |
| D10 | **Per-role shared files as persistent memory.** | Teammates don't get conversation history. Per-role files in `shared/` directory bridge the context gap and survive session death. Each role writes only to their own file — no write conflicts. |
| D11 | **Role-separated task lists (4 lists).** | Lead manages 4 task lists (research, impl, review, test) and promotes between them. Leverages Claude Code's 3 built-in states cleanly within each list rather than fighting the system with metadata hacks. |
| D12 | **SendMessage for urgent only, files for persistent.** | SendMessage interrupts teammates (costs tokens). Per-role files in `shared/` are read-at-own-pace. Reserve SendMessage for: (1) test/review failure feedback to Lead, (2) Researcher discovering plan-invalidating information, (3) any teammate hitting a blocker that affects other roles. |
| D13 | **Agent teams only, no subagent fallback.** | Execution layer designed purely for agent teams per D1. No dual-path complexity. |
| D14 | **Code Review as pipeline stage between Executor and Tester.** | Catches quality/pattern issues before functional testing. Read-only, uses its own task list. Prevents compounding failures where bad patterns pass tests but violate architecture. |
| D15 | **Skills replace commands as the invocation mechanism.** | The official Claude Code plugin spec has no `commands/` concept. User-invocable skills (with `user-invocable: true` in YAML frontmatter) ARE slash commands. The `commands/` directory is legacy and removed. |
| D16 | **`SKILL.md` with YAML frontmatter is the canonical skill format.** | Each skill lives in `skills/{name}/SKILL.md`. YAML frontmatter declares metadata (name, description, tools, model, agent, hooks). The body is the system prompt, injected into context when the skill activates. |
| D17 | **Agent definitions use flat `.md` files with YAML frontmatter.** | Each agent is `agents/{name}.md`. YAML frontmatter declares model, tools, constraints, permissions. The body is the agent system prompt. This replaces any programmatic agent config. |

## Open Questions

To resolve before implementation begins.

| # | Question | Options / Notes |
|---|----------|-----------------|
| Q1 | ~~**Command prefix**: Is `/uc:` the right namespace?~~ | **Resolved** — Plugin name is `uc` (set in `plugin.json` `name` field). All user-invocable skills are namespaced as `/uc:skill-name` (e.g., `/uc:feature-plan-mode`, `/uc:execute-plan`). See [Components](components.md) and D15. |
| Q2 | ~~**Team persistence**: When a plan spans multiple sessions, how do we handle team recreation?~~ | **Resolved** — checkpoint architecture (D9-D11). Lead saves 4 task list states + `shared/` directory + research files. On resume, Lead reads latest checkpoint, rebuilds team from scratch, skips completed work. See [Execution](execution.md). |
| Q3 | **Discovery mode enforcement**: Should coding be disabled via hooks (hard) or CLAUDE.md instructions (soft)? | Hook is more reliable but requires careful implementation. |
| Q4 | ~~**Docs format flexibility**: Should the plugin mandate a specific documentation format (Confluence-style, GitBook-style) or be format-agnostic?~~ | **Resolved** — `.claude/docs-format` file controls output format. Docs-manager skill adapts to the specified format. See [Components](components.md). |
| Q5 | ~~**Existing documentation**: How does the plugin interact with projects that already have documentation?~~ | **Resolved** — migrate-docs skill (`/uc:migrate`) handles existing projects. Surveys current docs, maps to canonical structure, produces migration plan. See [Architecture](architecture.md#migrate-docs-skill). |
| Q6 | ~~**Help: skill or command?**~~ | **Resolved** — Help is a skill with `user-invocable: true` in its SKILL.md frontmatter. Per D15, there is no separate "command" concept — user-invocable skills ARE slash commands. Invoked as `/uc:help`. |
| Q7 | **Bundled MCP servers**: Should the plugin bundle any MCP servers? | Current thinking: no — rely on globally configured MCP servers (Ref.tools, Atlassian). |
