# Agent Spawn Modes

Canonical reference for every `Agent` tool call in Ultra Claude. Skills and agents reference this file by mode letter (e.g. "spawn as Mode F per `references/agent-spawn-modes.md`") instead of restating mechanics.

## Harness fact — background is the default

Since Claude Code v2.1.198 (2026-07-01), `Agent` spawns run in the **background by default**: the caller keeps working and receives a completion notification. Before that, unspecified spawns ran foreground and blocked until the result returned.

**Therefore: every `Agent` call in this repo states `run_in_background` explicitly.** Never rely on the default — a silent default change is exactly what this rule exists to absorb.

## Mode T — Teammate (persistent, addressable)

```
Agent(subagent_type=..., name="{role}-{N}", run_in_background: true, model=..., mode=...)
```

- `name` makes the agent addressable via `SendMessage({to: name})`. Names remain addressable after the agent completes — a send resumes it from its transcript. If a newer agent takes the same name, the latest holder wins.
- Never pass `team_name` — deprecated and ignored; every session has exactly one implicit team.
- All inter-agent communication and waiting follows `skills/plan-execution/references/execution-communication-protocol.md` (SendMessage + `signals.jsonl` dual-write; bounded Monitor waits per §3).
- Use for execution pipeline roles (Executor, Reviewer, Tester, PM) and any agent that must hold a multi-turn conversation with peers or the Lead.

## Mode S — One-shot sync (result gates the next step)

```
Agent(subagent_type=..., run_in_background: false, ...)   # no name
```

- The caller blocks; the agent's final message returns as the `Agent` tool result.
- Use when the caller **cannot proceed without the answer** — e.g. the research skill relaying a researcher's findings to its caller.

## Mode F — One-shot background fan-out (parallel workers)

```
Agent(subagent_type=..., run_in_background: true, ...)    # no name, issued in one message for parallel batches
```

- Independent parallel workers; the caller receives one completion notification per agent.
- **Collect every completion notification before synthesizing.** Do not assume completion order; do not proceed on a partial set.
- **Never instruct a one-shot worker to SendMessage its results back** — background-agent → lead delivery can be silently dropped (see the delivery bugs in `.claude/ultra/research/claude-code-sendmessage.md`). The completion notification *is* the collection mechanism.
- Batch size: cap parallel spawns per the calling skill's guidance (typically ≤5; batch if more).

## Addressing rule (pointer)

Named teammates address the main conversation as `team-lead`; anonymous background subagents are the only agents that may address `main`. The canonical statement of this rule — with the verified failure cases — lives in `skills/plan-execution/references/execution-communication-protocol.md` §1. Do not restate it elsewhere.

## Nesting

Subagents may spawn their own subagents (up to 5 levels, since v2.1.172). An in-process teammate's subagents always run **foreground** — asking for a background one returns an error, because a teammate's background work can't outlive the lead's process.

## Hard rule

Never use Mode S or Mode F for execution pipeline roles — per-task pipeline teams (Executor/Reviewer/Tester/PM) are always Mode T under the execution communication protocol.
