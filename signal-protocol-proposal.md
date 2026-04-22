# Signal Protocol: Fixing Agent Message Delivery in Plan Execution

## Problem Statement

Claude Code's `SendMessage` tool silently drops messages to Executor agents. During Plan 028 execution, this caused 100% peer-to-peer message failure (reviewer/tester to executor) and ~50-70% failure from Lead to executors. Messages return `success: true` but never arrive at the recipient's inbox. The pipeline stalls, Lead must manually relay every message, and executors can't receive shutdown requests.

### Observed Failure Pattern (Plan 028)

| Sender to Recipient | Failure Rate | Notes |
|---|---|---|
| reviewer-2 to executor-2 | 100% (5+ attempts) | Never delivered a single message |
| reviewer-1 to executor-1 | 100% (3+ attempts) | Same pattern |
| tester-2 to executor-2 | 100% | Verdict never received |
| tester-1 to executor-1 | 100% | Verdict never received |
| Lead to executor-1 | ~50% | Some messages got through, shutdown_request never did |
| Lead to executor-2 | ~70% | Earlier messages delayed, later ones delivered |
| Lead to reviewer/tester/PM | ~95% success | Mostly worked |

Key pattern: **Executors are the black hole.** Non-executor agents (reviewer, tester, PM, watchdog) communicate with each other and with Lead reliably. The problem is directional and role-specific.

### Impact

- ~15 minutes of wasted wall-clock time per execution waiting for messages that never arrive
- Lead forced to relay every reviewer take and every verdict manually (doubling context cost)
- Lead forced to "assert" verdicts since executors couldn't hear teammates directly
- Executor-1 never received shutdown_request -- required manual tmux kill
- Total overhead: significant token waste, human intervention required, pipeline throughput halved

---

## Root Cause: Known Claude Code Platform Bugs

This is not a bug in our code. Web research identified four known Claude Code issues that explain the symptoms:

### 1. Inbox Polling Failure (#23415)

**Status:** Closed as "not planned"

When using agent teams with the tmux backend, spawned teammates launch correctly but never read from their inbox files. Messages sent via SendMessage are written to inbox JSON files at `~/.claude/teams/{name}/inboxes/{name}.json` but remain `"read": false` indefinitely. The spawned process never initiates polling of its own inbox file despite being launched with correct team membership flags.

Evidence from the bug report:
```json
{
  "from": "team-lead",
  "text": "Hello world!",
  "timestamp": "2026-02-05T18:56:10.615Z",
  "read": false  // Never consumed
}
```

Teammates respond: *"I haven't received any instructions from a team lead. I'm currently working as a standalone agent."*

**Relevance to our system:** This directly explains why executor agents never receive peer messages. The tmux-spawned agent process starts correctly but its inbox polling mechanism never activates.

### 2. Silent Name Mismatch (#25135)

**Status:** Closed as "not planned"

SendMessage silently succeeds when the recipient name doesn't match the target agent's registered inbox polling name. The message is written to an orphaned inbox file that no agent reads.

The root cause spans five unvalidated functions in `cli.js`:
1. `validateInput` -- no recipient existence check (any non-empty string passes)
2. `normalizeRecipient` -- passes through arbitrary names unchanged
3. `getInboxPath` -- uses recipient as-is for file path (creates orphaned files)
4. `writeToMailbox` -- creates new inbox files without validation
5. `InboxPoller` -- reads from a different file than where the message was written

Result: `SendMessage` returns `{ success: true, message: "Message sent to alice's inbox" }` but the team lead's InboxPoller reads from `team-lead.json` while the message sits in `alice.json`. Permanently lost.

**Relevance to our system:** If any agent uses a slightly different name form (e.g., role-based name vs. registered name), messages silently vanish. This may explain the intermittent Lead-to-executor failures -- some messages hit the right name, others don't.

### 3. Subagents Cannot Originate SendMessage (#48160)

**Status:** Closed as duplicate

Spawned subagents cannot originate SendMessage calls. `ToolSearch("select:SendMessage")` returns no match in subagent context. Parent agents can send TO subagents, but subagents cannot send back.

From the bug report: three of four subagents reported variants of "SendMessage tool not available in this environment." The tool is missing from subagent toolsets despite explicit permission grants and `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enabled.

**Relevance to our system:** This explains asymmetric communication -- executors may be able to send (to Lead, which works) but cannot receive from peers that are themselves subagents. The tool availability differs by agent context.

### 4. No Shared Channel Primitive (#30140)

**Status:** Closed as duplicate

Feature request for persistent, ordered group communication. The current SendMessage primitives (point-to-point and broadcast) are insufficient for reliable team coordination:
- No shared ground truth -- each agent has a different view of what was communicated
- Broadcast doesn't scale -- N agents get N x M context injections in random order
- Late joiners lose context -- agents waking from idle or after context compression can't catch up

The proposed solution was a shared channel file with `Append(message)` and `Read()` operations, total ordering, persistence across compression/idle cycles, and concurrent safety.

**Relevance to our system:** This is essentially what we need to build. The proposed signal protocol is a scoped version of this feature request.

### Summary of Platform State

Agent Teams are explicitly **experimental** in Claude Code. The official documentation states:

> Agent teams are experimental and disabled by default. Enable them by adding `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your settings.json or environment. Agent teams have known limitations around session resumption, task coordination, and shutdown behavior.

The bugs above are closed as "not planned" or "duplicate" -- Anthropic is not prioritizing fixes for these issues. We cannot wait for platform fixes; we need an application-level workaround.

---

## Current Architecture (What Already Works)

The plan execution system already uses files as source of truth:

| File | Purpose | Written by | Read by |
|---|---|---|---|
| `task.md` | Task description, files, criteria, research | Planning mode / Lead | All agents |
| `plan.md` | Executor's implementation plan | Executor | Reviewer, Tester |
| `impl.md` | Implementation delta (what changed) | Executor | Reviewer, Tester |

Messages in the current design are **triggers, not data carriers**. When an executor sends "Ready for review," it's saying "go read impl.md" -- the message itself carries no substantive content. The actual data is in the files.

The problem is that **critical stage transitions depend on these triggers arriving**, and they don't. The system's file-based architecture is sound; it just doesn't extend to the stage transitions themselves.

---

## Proposed Solution: Per-Task Signal File Protocol

### Core Concept

Add an append-only `signals.md` file per task. All agents write their stage transitions to this file AND attempt SendMessage. Agents (especially executors) read this file to discover transitions that SendMessage failed to deliver. SendMessage is demoted from "primary coordination mechanism" to "best-effort optimization."

### Signal File Format

**Location:** `tasks/task-N/signals.md` (alongside task.md, plan.md, impl.md)

```markdown
## Signals

- [2026-04-22T10:15:00Z] REVIEWER_TAKE_READY reviewer-1
- [2026-04-22T10:20:00Z] TESTER_SPAWNED lead
- [2026-04-22T10:25:00Z] REVIEW_REQUESTED executor-1
- [2026-04-22T10:26:00Z] TEST_REQUESTED executor-1
- [2026-04-22T10:30:00Z] REVIEW_PASS reviewer-1
- [2026-04-22T10:35:00Z] TEST_PASS tester-1
- [2026-04-22T10:38:00Z] TASK_COMPLETE executor-1
- [2026-04-22T10:40:00Z] SHUTDOWN lead
```

Design decisions:
- **Append-only markdown** -- no JSON, no mutations. Agents already read/write .md files natively.
- **One line per signal** -- `- [ISO timestamp] SIGNAL_NAME author-name`
- **Timestamps for debugging, not logic** -- ordering is positional (later line = later event)
- **SCREAMING_SNAKE_CASE** -- visually distinct from FILE-UPDATED broadcasts and prose

### Signal Vocabulary

| Signal | Written by | Read by | Replaces |
|---|---|---|---|
| `REVIEWER_TAKE_READY` | Reviewer | Executor | "REVIEWER TAKE -- task N: ..." SendMessage |
| `TESTER_SPAWNED` | Lead | Executor | "Tester spawned -- proceed with impl report" |
| `IMPL_APPROVED` | Lead | Executor (pipeline) | "Implementation approved -- predecessor..." |
| `REVIEW_REQUESTED` | Executor | Reviewer | "Ready for review" |
| `TEST_REQUESTED` | Executor | Tester | "Ready for test" |
| `REREVIEW_REQUESTED` | Executor | Reviewer | "Ready for re-review" |
| `RETEST_REQUESTED` | Executor | Tester | "Ready for re-test" |
| `REVIEW_PASS` | Reviewer | Executor | Review PASS verdict SendMessage |
| `REVIEW_FAIL` | Reviewer | Executor | Review FAIL verdict SendMessage |
| `TEST_PASS` | Tester | Executor | Test PASS verdict SendMessage |
| `TEST_FAIL` | Tester | Executor | Test FAIL verdict SendMessage |
| `EXIT_REQUESTED` | Executor | Reviewer, Tester | "All stages passed -- confirm..." |
| `REVIEWER_READY_TO_EXIT` | Reviewer | Executor | "READY TO EXIT" |
| `TESTER_READY_TO_EXIT` | Tester | Executor | "READY TO EXIT" |
| `SHUTDOWN` | Lead | All | shutdown_request |
| `PAUSE` / `RESUME` | Lead | All | PAUSE/RESUME messages |

**What stays SendMessage-only** (non-executor recipients, already reliable):
- Executor to Lead: "code complete", "task done", ADVICE REQUEST, QUERY, "PLAN-INVALIDATING"
- Lead to PM: SPAWNED, SHUTDOWN, COMPLETED status updates
- PM to Lead: validated watchdog alerts
- Watchdog to PM: usage alerts

### Content Files (for signals with substantive data)

Some signals have associated content too large for a single signal line. This content goes in dedicated files, written BEFORE the signal (so the signal acts as a "content ready" flag):

| File | Purpose | Written by | Triggered by signal |
|---|---|---|---|
| `tasks/task-N/take.md` | Full REVIEWER TAKE text | Reviewer | `REVIEWER_TAKE_READY` |
| `tasks/task-N/review-feedback.md` | Structured review failure details | Reviewer | `REVIEW_FAIL` |
| `tasks/task-N/test-feedback.md` | Structured test failure details | Tester | `TEST_FAIL` |

### Dual-Write Protocol

Every critical signal follows this exact order:

1. **Write content file** (if signal has associated content -- e.g., take.md, review-feedback.md)
2. **Append signal line** to `signals.md`
3. **Attempt SendMessage** (best-effort -- may silently fail, and that's OK)

The ordering is critical: content file before signal (so the reader never sees a "content ready" flag before the content exists), signal before SendMessage (so the file-based record is authoritative).

### Executor Polling Discipline

Executors read `signals.md` between tool calls **only during wait states**:
- Waiting for REVIEWER TAKE (while exploring codebase)
- Waiting for "Tester spawned" confirmation
- Waiting for "Implementation approved" (pipeline gate)
- Waiting for review/test verdicts
- Waiting for "READY TO EXIT" confirmations
- Waiting for shutdown

During active implementation (step 4), the executor is writing code and does NOT poll. Polling resumes when it enters the next wait state.

If a SendMessage arrives first, process it immediately -- no need to wait for the signal file. The signal file is the fallback, not the primary path when messages do arrive.

### PM Stage Tracking Consolidation

Currently, the Project Manager receives `STAGE-DONE task-N review` and `RETRY task-N` messages from executors via SendMessage, duplicating information that signals.md already captures. With signals.md as the authoritative stage record:

- **Remove** executor-to-PM `STAGE-DONE` and `RETRY` messages
- **PM reads signals.md** for all active tasks to derive dashboard state
- PM still receives Lead messages (SPAWNED, SHUTDOWN, COMPLETED) and watchdog alerts via SendMessage -- those work fine since PM is not an executor

This eliminates redundant messages, reduces token cost, and gives PM a more reliable data source than SendMessage.

---

## Why This Solution

### It's not a new pattern -- it formalizes what already works

The system already uses files as source of truth. FILE-UPDATED broadcasts already say "a file changed, go read it." The signal file extends this to stage transitions. Every agent already knows how to read and append to markdown files.

### It's additive, not replacing

SendMessage stays. When it works (~95% for non-executor recipients), it's faster than polling. The signal file is the fallback for the ~5-100% of cases where messages to executors vanish. No existing working flow is disrupted.

### It solves crash recovery for free

A re-spawned agent reads signals.md and knows exactly where the pipeline was:
- `REVIEWER_TAKE_READY` present + `plan.md` exists = take was incorporated
- `REVIEW_FAIL` with no subsequent `REREVIEW_REQUESTED` = fix cycle was interrupted
- `REVIEW_PASS` + `TEST_PASS` both present = task was complete

Today, re-spawned agents infer stage from file presence alone, which is imprecise.

### It's minimal

~8-12 lines per task in the happy path. ~60 lines worst case (10 fix cycles). One Read call per tool call during wait states (~100-200 tokens overhead). Negligible compared to the cost of a stalled pipeline (thousands of wasted tokens across multiple idle agents).

### Alternatives considered and rejected

**Lead relay for everything:** The workaround used in Plan 028. Works but doubles Lead's context cost, makes Lead a single bottleneck, and doesn't scale to concurrent tasks.

**Poll for file changes instead of signals:** Executors could re-read plan.md/impl.md looking for embedded state markers. Brittle -- conflates content with signaling, requires conventions for encoding "review passed" inside existing files.

**Wait for Anthropic to fix it:** Relevant bugs are closed as "not planned." Agent Teams are experimental. Timeline unknown.

---

## Edge Cases

### Concurrent writes to signals.md

Two agents may append at the same instant (e.g., reviewer and tester both writing verdicts). Each write is a single-line append. If Edit fails, the agent re-reads the file and retries once. Concurrent single-line appends are extremely unlikely to conflict and naturally resolve on retry.

### Signal before content file (race condition)

Prevented by protocol: content file is written FIRST, signal appended SECOND. The signal is the "content ready" flag. An executor that sees `REVIEWER_TAKE_READY` can safely read `take.md` because the reviewer wrote it before appending the signal.

### Signal file growth

Bounded by pipeline structure. A task with 1 review pass and 1 test pass has ~8 signal lines. Even with 10 fix cycles (the configured maximum), it's ~60 lines. This file is trivially small.

### Re-spawn recovery

Re-spawned agents read signals.md during startup alongside task.md/plan.md/impl.md. The signal log provides precise pipeline state that supplements file-presence inference. No special "resume" signal is needed -- the existing startup protocol handles it.

---

## Files That Change

| File | Change |
|---|---|
| `skills/plan-execution/references/task-team-startup.md` | Add Section 5b (Signal File Protocol), update wait rules table |
| `agents/code-review.md` | Add take.md writing, signal appending, review-feedback.md for FAILs |
| `agents/task-tester.md` | Add signal appending, test-feedback.md for FAILs |
| `agents/task-executor.md` | Add Signal File Polling section, update all wait states with signal fallbacks |
| `skills/plan-execution/SKILL.md` | Add signal file initialization, Lead signal writes, update message handlers |
| `skills/plan-execution/references/phase-2-spawn-prompts.md` | Add signals.md initialization to Pre-Spawn Checklist |
| `skills/plan-execution/references/phase-4-failure-handling.md` | Add signals.md crash recovery notes |
| `agents/project-manager.md` | Remove STAGE-DONE/RETRY message handling, add signals.md reading |

---

## References

- [#23415 - Teammates don't poll inbox (tmux backend)](https://github.com/anthropics/claude-code/issues/23415) -- closed, not planned
- [#25135 - SendMessage silently succeeds with wrong recipient name](https://github.com/anthropics/claude-code/issues/25135) -- closed, not planned
- [#48160 - Spawned subagents cannot originate SendMessage](https://github.com/anthropics/claude-code/issues/48160) -- closed, duplicate
- [#30140 - Feature request: shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140) -- closed, duplicate
- [#42999 - SendMessage silently fails with agent name (only ID works)](https://github.com/anthropics/claude-code/issues/42999)
- [#42737 - SendMessage unavailable without agent teams feature](https://github.com/anthropics/claude-code/issues/42737)
- [Agent Teams official docs](https://code.claude.com/docs/en/agent-teams) -- confirms experimental status, known limitations
