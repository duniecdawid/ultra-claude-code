# Agent building — tools, models, addressing, hard limits

Scope: knowledge specific to building subagents (`agents/*.md`). Description budgets live in `description-writing.md`; testing in `testing-refactors.md`.

## Skill vs agent — decide first

- **Subagents cannot spawn subagents.** [OFFICIAL] Anything that orchestrates other agents must be a skill running in the main conversation, not an agent.
- An agent buys you: isolated context (fan-out research, noisy tool output), a different model, a restricted tool allowlist, parallelism. If none of those is needed, a skill (or nothing) is cheaper — every agent's description joins the always-resident roster.

## Model selection

- **Opus floor for anything that builds or edits harness text** (non-negotiable #1) — including compression/review agents whose output becomes harness text.
- Sonnet for mechanical leaf work: monitoring, log tailing, structured extraction, running a fixed checklist.
- Haiku only for high-volume, low-judgment loops where a wrong call is cheap and detectable.
- Omit `model:` to inherit the parent's — right default for general-purpose helpers.

## Tools list — a hard allowlist

- `tools:` is a hard allowlist; grant the minimum. Read-only agents get `Read, Grep, Glob` (+ `Bash` only if they must run read-only commands).
- **Always include `SendMessage` in any agent that may need to reply or report mid-run.** [MEASURED, this environment] An agent without it can be messaged but can never answer — it silently never receives the sibling roster either. Adding it grants no file/shell/network reach, so a read-only agent stays read-only. Omit it only for a fire-and-forget agent whose completion notification is its entire return path.
- An agent that must invoke an installed skill needs `Skill` in its tools.

## Addressing (agent teams)

[MEASURED, this environment] A **named teammate** replies to the main conversation as `team-lead`; an **anonymous background subagent** replies as `main`. `lead` is unreachable and returns `success:false`. Never shell out to tmux to talk between agents — SendMessage only.

## Prompt-body shape that works

- State the role in one line, then the **input contract** (what the spawner passes), then the **output contract** (exact shape of what it returns/sends). Contracts first — behavior prose after.
- Proposition-only agents (reviewers, advisors): say explicitly "never edits files; parent decides" and enumerate what the proposition must contain. Ambiguity here is how advisory agents start actuating.
- Recyclable/long-running agents: journal-first design — a fresh instance must be able to boot from the journal alone. State where the journal lives and what each entry must contain.
- Don't restate harness mechanics the agent gets for free (how tools work, how sessions end). Every line of prompt body is per-spawn input cost.

## Registration reminders (this plugin)

New agent = one file in `agents/`; its description joins every session's roster — budget one sentence. Update the help catalog + docs reference page, CHANGELOG entry, version bump in both `plugin.json` and `marketplace.json`.
