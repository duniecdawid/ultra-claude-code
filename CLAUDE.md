# Ultra Claude

## Versioning — MANDATORY

Single version format everywhere: `YYYY.MM.DD-N` where N starts at 1 and increments for multiple commits on the same day.

On every commit:
1. Update `CHANGELOG.json` — add a new entry at the **top** of the array with:
   - `seq`: previous highest seq + 1 (always increments, never reused — check `jq '.[0].seq' CHANGELOG.json` for current highest)
   - `version`: today's date-based version
   - `date`: today's date
   - `summary`: concise description of the change
   - `migration`: `null` unless this commit changes project-level file structure (see Migration Registry below)
2. Bump the version in **both** files (keep them in sync):
   - `.claude-plugin/plugin.json`
   - `.claude-plugin/marketplace.json`
3. Check the latest existing entry to determine the correct build number for today

## Migration Registry — MANDATORY

When a commit changes files that exist in projects using Ultra Claude (anything under `documentation/`, `.claude/ultra/`, or the CLAUDE.md template), add a `migration` block to that commit's CHANGELOG.json entry. Include precondition, actions, and conflict guidance. Actions can be typed objects for mechanical operations or plain strings for instructions that require judgment. See existing migration entries in CHANGELOG.json for the format.

Not every commit needs a migration entry — only those that affect what files exist in projects that use Ultra Claude.

## Help Skill Sync — MANDATORY

When editing any skill (`skills/*/SKILL.md`) or agent (`agents/*.md`), update the corresponding 3-sentence description in `skills/help/SKILL.md`.

Rule: each skill and agent gets exactly 3 sentences in the help knowledge base:
1. What it does (capability)
2. When to use it (trigger/context)
3. What it produces or enables (outcome)

## Agent-Team Communication Protocol — MANDATORY

Any skill or agent built on Claude Code agent teams MUST use the execution communication protocol at `skills/plan-execution/references/execution-communication-protocol.md` for inter-agent communication and waiting.

1. **SendMessage is the primary (immediate) channel; `signals.jsonl` is the durable shared state log — crash recovery + observability — *and* a delivery backstop, not merely a backup.** Any signal a receiver waits on must be sent via `CommunicateTeamMember`/`CommunicateTeam` (signal + SendMessage) — never raw SendMessage alone. The log carries jobs SendMessage architecturally cannot (re-spawn state inference, PM/report state), so it stays even where SendMessage is reliable; see the protocol preamble.
2. **Never wait in a foreground Bash loop.** SendMessages are delivered only between turns, so a foreground wait makes the agent deaf to the primary channel. Pure waits use bounded Monitor rounds per protocol §3.
3. **Reference, don't copy.** Skills and agents point to the protocol file by function and section (e.g. "wait per protocol §3") instead of restating mechanics. The protocol file is the single source of truth — when behavior needs to change, change it there.
4. **Agents that perform pure waits need the `Monitor` tool** in their frontmatter (see `agents/task-executor.md` for the pattern).

## No Machine-Specific Code — MANDATORY

This repo is the **portable** half of a two-layer system. It must not contain any hardcoded paths, usernames, hostnames, IPs, VM/host topology, Chrome install locations, extension IDs, account identities, or other values that are specific to one machine. Anything machine-local lives in the user's `~/.claude/skills/machine-context/` skill — a separate, user-scoped skill that other skills read at runtime.

**The pattern**:

1. **Skills read machine context opt-in, never required.** At the start of a skill that might need per-machine values, check for the relevant topic file (e.g. `~/.claude/skills/machine-context/network.md`). If present, use its values. If absent, fall back to pure runtime detection (`$HOME`, `whoami`, `jq` over known config files) and still complete the task. Never hard-fail because machine-context is missing.
2. **Files are the API.** Skills read the topic files directly. Do not invoke `/machine-context` as a skill call. Topic files are scoped by concern: `environment.md`, `claude-profiles.md`, `development.md`, `network.md`, `limit-sentinel.md`, `warnings.md`. Add a new topic file when introducing a new class of machine-local values — don't cram everything into one file.
3. **`/uc:setup` is the producer.** The setup skill scaffolds `~/.claude/skills/machine-context/` via the interview at `skills/setup/references/machine-context-interview.md`. Detection-first: the interview only asks what can't be auto-detected. Rerun-safe: never clobber user edits without explicit confirmation.
4. **When extending**: if a new skill or agent needs a machine-specific value, (a) add a question to the setup interview that writes it to the appropriate topic file, (b) have the consuming skill read that file with a runtime-detection fallback, and (c) reference the topic file by path in the consuming skill's documentation. Never inline the value here.

Before committing, scan your changes for anything that only works on your own machine. If you find it, move it to `machine-context` and read it from there.

See the limit-sentinel wiring in `skills/setup/SKILL.md` (§ "Machine-context topic (optional but recommended)") for the canonical consumer-side implementation: read the topic file when present, fall back to runtime detection when absent.

## Documentation Site Sync — MANDATORY

The public documentation site lives in `docs/` (Express + EJS, served at ultra-claude.dev). When any logic change is made to skills or agents, the docs site must be updated as part of the same plan.

Process:
1. When planning a change that modifies skill behavior, agent roles, execution flow, or any user-facing capability — spawn an Explore agent to scan `docs/views/` for pages that reference the affected functionality
2. Include doc page updates as part of the implementation tasks (not as a separate doc-only task)
3. Pages most likely to need updates: `docs/views/docs/plan-execution.ejs` (execution flow), `docs/views/docs/reference.ejs` (skill/agent tables), `docs/views/docs/standards.ejs` (enforcement loop), `docs/views/docs/token-efficiency.ejs` (cost/usage changes)
4. If a new skill or agent is added, add it to the Reference page and consider whether it needs its own documentation page
