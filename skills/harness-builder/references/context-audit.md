# Context audit — measuring session startup cost

Scope: diagnosing what burns tokens in the resident context a session starts with, and deciding what to trim.

## Two measurement layers

1. **Ground truth: `/context`** (built-in Claude Code command, run by the user). Shows the actual token breakdown of the current session — system prompt, system tools, MCP tools, memory files, custom agents, messages. Authoritative; use it for the total and the per-category split.
2. **Attribution: `scripts/context_audit.py`** (this skill). `/context` tells you the categories; the script tells you **which items inside a category** cost what — per-skill description, per-agent description, per-CLAUDE.md file — estimated at chars/4 (±20%; label it as an estimate). Run:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/skills/harness-builder/scripts/context_audit.py" [project-dir]
```

## The audit method

1. Run the script; get the ranked table (blocks ranked by estimated tokens, top items within each block).
2. Cross-check the total shape against `/context` — if the script's biggest block doesn't match `/context`'s, trust `/context` and investigate.
3. Classify each block:
   - **Harness-fixed** — core tool schemas, harness instructions. Not yours to trim.
   - **Controllable-static** — skill/agent descriptions, CLAUDE.md files, MCP server selection. Trim or detach.
   - **Recurring-dynamic** — mandatory bootstrap skill invocations, hooks emitting context every session. Often the largest *controllable* cost; question every "invoke X at every session start" rule.
4. Hunt duplication: identical MCP instruction blocks across server instances (e.g. a dev+prod pair), description sentences duplicated from bodies, the same fact in global + project CLAUDE.md.
5. Rank offenders by `tokens × sessions-per-week`; trim from the top using `description-writing.md` budgets and the `caveman-reviewer` flow.
6. Re-run script + `/context` after trimming; record before/after totals with dates.

## When to run

- Before and after any description-trimming pass (the before run is the baseline).
- When onboarding a project or installing new plugins/MCP servers.
- When sessions feel context-starved or compaction triggers early.

## Known cost profile [MEASURED 2026-07, this environment]

A heavily-tooled session started at ~35–40k fixed tokens: skills catalog ~8–10k (10 verbose descriptions ≈ a third of it), agent roster ~5–6k, deferred MCP tool-name listing ~4–5k, CLAUDE.md files ~7–8k, harness fixed ~8–10k, MCP instructions ~1.2k (with a verbatim-duplicated dev/prod pair). Update this paragraph when a new audit materially changes the picture.
