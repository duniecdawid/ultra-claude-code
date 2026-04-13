# Research: Detailed token tracking for Ultra Claude plan executions

**Status:** Research only — no implementation planned. Saved for possible resume.
**Date:** 2026-04-13
**Question:** Can we track token usage per plan execution, broken down by tasks and agents?
**Answer:** Yes, feasible. All data exists. Blocker is that Ultra Claude doesn't currently capture the links needed to aggregate it.

---

## What Claude Code exposes today

### Session transcripts
Path: `~/.claude/projects/<encoded-cwd>/<session-id>.jsonl`

Every assistant message line carries a `usage` block with exact fields:
- `input_tokens`, `output_tokens`
- `cache_creation_input_tokens`, `cache_read_input_tokens`
- `cache_creation.ephemeral_5m_input_tokens`, `ephemeral_1h_input_tokens`
- `service_tier`
- `total_cost_usd` (only on the final `result` message — authoritative)

**Dedup rule** (official docs): messages sharing the same `id` report identical usage — charge once per unique message ID per step.

### Subagent transcripts
Each spawned subagent writes to its **own** jsonl, typically under `<parent-session-dir>/subagents/agent-<agent-id>.jsonl`. Linked via `agent_id` and `agent_transcript_path`, surfaced in the `SubagentStop` hook payload.

⚠️ **Not yet verified on this machine** — docs say this path but should be confirmed by inspecting a real recent session before committing to it in code.

### Hooks — no live usage data
No hook (SessionStart/End, Stop, SubagentStart/Stop, PostToolUse) carries token counts in its payload. Usage must be extracted by **parsing the jsonl files** after the fact.

`SubagentStop` is still useful: it gives `agent_id` + `agent_transcript_path` at the moment each subagent finishes — perfect capture point for linking.

### CLI / SDK
- `/cost` — session totals only, no breakdown.
- SDK `ResultMessage.total_cost_usd` and `modelUsage` dict — only applies when driving via SDK, not interactive runs.

---

## What Ultra Claude has today

- **Plan state** — `documentation/plans/<name>/plan.json` has per-task `stages` timing and per-member spawn/end timestamps. **No token fields. No session_id.**
- **PM agent** (`agents/project-manager.md:487-616`) produces an operational report post-execution with a qualitative "Token Efficiency Analysis" section — designed to be replaced with real numbers.
- **Session files** in `.claude/ultra/sessions/*.json` — metadata only (pid, tmux pane, last activity). No usage data. No jsonl parsing anywhere in the codebase.
- **No parent→child session_id linking.** When the Lead spawns `executor-1` via TeamCreate/Agent, the child's session_id is never captured.

---

## The gap (and the fix shape)

Three pieces needed for per-plan / per-task / per-agent token history:

### 1. Capture session_id per member
Add `session_id` field to `plan.json` members as they spawn. Two options:
- **(a) SubagentStart/Stop hook** writing into plan.json — cleanest, but requires a plugin hook.
- **(b) Self-reporting** — spawn prompts instruct each member to emit `session_id = $session_id` as first action into `tasks/task-N/shared/usage.md`. Works today without hooks, but adds a turn of overhead per member.

### 2. Parse jsonl at task completion
On each stage transition to `completed`, walk the member's jsonl, dedup by message id, sum the five usage fields. Store in:
- `plan.json > tasks[].members[].usage`
- `plan.json > tasks[].usage` (rollup)
- `plan.json > plan.usage` (grand total)

### 3. Render
Extend PM operational report with real numbers. Optionally a new `/uc:token-report` skill that produces a per-plan table. Possibly dashboard sync.

---

## Key files that would change

- `skills/plan-execution/references/plan-status-format.md` — add `usage` object schema to members/tasks/plan
- `skills/plan-execution/references/phase-2-spawn-prompts.md` — session_id capture instruction
- `agents/project-manager.md` — jsonl parsing + real token report generation (replace qualitative section at lines 487-616)
- New: jsonl-parsing helper (could be inlined into PM, or `scripts/parse-usage.sh`)
- Possibly `hooks/` — SubagentStop hook if going route (a)

---

## Three possible execution paths (for when resuming)

### MVP (fastest useful output)
Post-hoc jsonl parser + `/uc:token-report` skill that reads current plan.json members and produces a per-task/agent table. No hooks, no schema changes. Only works if session_ids can be recovered retroactively (they can't without capture) — so this path **still needs self-reporting** to be added to spawn prompts first.

### Full integration
SubagentStop hook + session_id capture during spawn + extended plan.json schema + PM operational report rewrite + dashboard sync. Bigger blast radius but cleanest result.

### Verify-first
Before planning anything, inspect an existing session on this machine to confirm the exact path/naming of subagent transcripts. ~15 min investigation. Recommended before either path above.

---

## Sources

- `docs.claude.com/en/docs/claude-code/sdk/sdk-cost-tracking` — authoritative on usage field schema, dedup rules, ResultMessage
- `code.claude.com/docs/en/agent-sdk/hooks.md` — hook payload contents (confirmed no usage data)
- `code.claude.com/docs/en/agent-sdk/sessions.md` — session jsonl structure
- claude-code-guide agent research (2026-04-13) — cross-referenced above
- Ultra Claude codebase exploration (2026-04-13) — file paths verified

---

## Confidence notes

- **High confidence:** jsonl schema, hook payloads, lack of live usage data in hooks.
- **Medium confidence:** exact on-disk path for subagent jsonls (docs say `<parent>/subagents/agent-<id>.jsonl` but not verified locally).
- **High confidence:** Ultra Claude plan.json schema and current PM report structure.
