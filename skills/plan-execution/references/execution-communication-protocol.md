# Execution Communication Protocol

All task-team agents (Executor, Reviewer, Tester, PM) and Lead use this protocol for every inter-agent communication. It wraps SendMessage with a durable file-based signal layer so that no message is lost when SendMessage silently fails.

**Load this file during startup** — it is referenced from `task-team-startup.md` and your agent instructions.

## 1. CommunicateTeamMember(to, message, signal?, content_file?)

Send a message to one specific agent. Execute these steps in order:

1. **If `content_file` is provided** — write it to `$PLAN_DIR/tasks/task-$TASK_ID/` BEFORE the signal. The reader must never see a "content ready" flag before the content exists on disk.

2. **If `signal` is provided** — append one JSONL line to `$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl`:
   ```bash
   echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"YOUR_SIGNAL","author":"your-agent-name"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
   ```
   Always use `echo >>` via Bash — never Edit or Write. This is atomic on local filesystems.

3. **Always** — call `SendMessage(to=..., message=...)`. This is best-effort. It may silently fail, and that is OK — the signal file is the durable record.

The ordering is load-bearing: content before signal (reader never sees flag before data), signal before SendMessage (file record is authoritative even if SendMessage fails).

## 2. CommunicateTeam(message, signal?, content_file?)

Broadcast to all active teammates AND Lead. Same 3-step ordering as `CommunicateTeamMember`:

1. **If `content_file`** — write it once (not per recipient).
2. **If `signal`** — append to `signals.jsonl` once (not per recipient).
3. **SendMessage** to each active teammate AND Lead individually (best-effort per recipient).

Active teammates are those listed in your spawn prompt that haven't exited. Tester joins mid-task (lazy-spawned) — include them in broadcasts only after `TESTER_SPAWNED` has been received.

## 3. WaitForTeamMember(signal, from?)

Wait to receive a specific signal. Two delivery paths, whichever fires first:

1. **SendMessage arrives** — if you receive a SendMessage whose content matches the expected signal, process it immediately. Done.

2. **Poll signals.jsonl** — every ~60 seconds, read the signal file:
   ```bash
   cat "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
   ```
   Scan for a line where `"signal"` matches the expected value (and optionally `"author"` matches `from`). If found and the signal has an associated `content_file`, read that file from the same directory.

**When NOT to poll** — during active work (writing code, running tests, reviewing files). Only poll during explicit wait states where you are blocked on another agent's output.

**Token cost** — ~100-200 tokens per poll (read a small file, check for a signal). Negligible compared to a stalled pipeline.

## 4. Signal File Format

**File:** `$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl` — one JSON object per line, append-only.

```json
{"ts":"2026-04-22T10:15:00Z","signal":"REVIEW_PASS","author":"reviewer-1"}
```

| Field | Type | Description |
|-------|------|-------------|
| `ts` | ISO 8601 UTC | Timestamp of the signal write |
| `signal` | SCREAMING_SNAKE | Signal name (see vocabulary below) |
| `author` | string | Agent name that wrote the signal |

**Initialization:** Lead creates the empty file before spawning the task team:
```bash
touch "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
```

**Content files** — companion data files written BEFORE the signal that flags them:

| File | Written by | Flagged by signal |
|------|-----------|-------------------|
| `take.md` | Reviewer | `REVIEWER_TAKE_READY` |
| `review-feedback.md` | Reviewer | `REVIEW_FAIL` |
| `test-feedback.md` | Tester | `TEST_FAIL` |

On re-review/re-test cycles, overwrite the feedback file with the new cycle's content. The signal log retains history (multiple entries); the content file always holds the latest.

## 5. Signal Vocabulary

19 signal types. Agents use these as the `signal` parameter in `CommunicateTeamMember` and `CommunicateTeam` calls, and as the `signal` parameter in `WaitForTeamMember`.

| Signal | Writer | Purpose |
|--------|--------|---------|
| `REVIEWER_TAKE_READY` | Reviewer | Take written to `take.md`, ready for Executor |
| `PLAN_READY` | Executor | `plan.md` written, entering implementation |
| `CODE_COMPLETE` | Executor | All source code done, requesting tester spawn |
| `REVIEW_REQUESTED` | Executor | Implementation done, requesting review |
| `TEST_REQUESTED` | Executor | Implementation done, requesting test |
| `REREVIEW_REQUESTED` | Executor | Fix applied, requesting re-review |
| `RETEST_REQUESTED` | Executor | Fix applied, requesting re-test |
| `REVIEW_PASS` | Reviewer | Code passes review |
| `REVIEW_FAIL` | Reviewer | Code fails review, feedback in `review-feedback.md` |
| `TEST_PASS` | Tester | Code passes testing |
| `TEST_FAIL` | Tester | Code fails testing, feedback in `test-feedback.md` |
| `EXIT_REQUESTED` | Executor | All stages passed, requesting exit confirmation |
| `REVIEWER_READY_TO_EXIT` | Reviewer | Confirms ready to exit |
| `TESTER_READY_TO_EXIT` | Tester | Confirms ready to exit |
| `TESTER_SPAWNED` | Lead | Tester has been lazy-spawned |
| `IMPL_APPROVED` | Lead | Pipeline predecessor passed, proceed to implement |
| `ADVICE_RESPONSE` | Lead | Response to an ADVICE REQUEST from Executor |
| `SHUTDOWN` | Lead | Team must exit |
| `PAUSE` / `RESUME` | Lead | Usage limit control |

## 6. Crash Recovery

On re-spawn, agents read `signals.jsonl` during startup to infer pipeline state:

| Signal pattern | Inferred state |
|---------------|----------------|
| `REVIEWER_TAKE_READY`, no `PLAN_READY` | Take sent, planning not started |
| `PLAN_READY`, no `REVIEW_REQUESTED` | Implementation in progress (check impl.md) |
| `CODE_COMPLETE`, no `REVIEW_REQUESTED` | Writing impl.md or waiting for tester |
| `REVIEW_REQUESTED`, no `REVIEW_PASS`/`REVIEW_FAIL` | Review in progress |
| `REVIEW_FAIL`, no `REREVIEW_REQUESTED` | Fix cycle interrupted |
| `REVIEW_PASS` + `TEST_PASS` | Task complete, may need shutdown only |
| `EXIT_REQUESTED`, missing `*_READY_TO_EXIT` | Exit confirmation interrupted |
| `SHUTDOWN` | Team should have exited |
| `PAUSE`, no subsequent `RESUME` | Team paused |
