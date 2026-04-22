# Signal Protocol

Per-task `signals.jsonl` provides durable, machine-readable pipeline state. It supplements SendMessage (which silently drops messages to executors 50–100% of the time) with an append-only file that every agent can read. SendMessage is demoted from "primary coordination mechanism" to "best-effort optimization."

## 1. JSONL Schema

Each signal is one JSON object per line, appended atomically via `echo >>`:

```json
{"ts":"2026-04-22T10:15:00Z","signal":"REVIEW_PASS","author":"reviewer-1"}
```

| Field | Type | Description |
|-------|------|-------------|
| `ts` | ISO 8601 UTC | Timestamp of the signal write |
| `signal` | SCREAMING_SNAKE | One of the 16 signal types below |
| `author` | string | Agent name that wrote the signal (e.g., `executor-1`, `reviewer-2`, `lead`) |

**Write mechanism — always `echo >>` via Bash, never Edit/Write:**

```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"REVIEW_PASS","author":"reviewer-1"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
```

This is atomic on local filesystems. If two agents append simultaneously, both lines land intact (POSIX guarantees for small writes to regular files). No locking needed.

**File location:** `$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl` — alongside task.md, plan.md, impl.md.

**Initialization:** Lead creates the empty file before spawning the task team (Pre-Spawn Checklist step 2.5 in `phase-2-spawn-prompts.md`):

```bash
touch "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
```

## 2. Signal Vocabulary

16 signal types organized by writer role.

### Executor signals

| Signal | Reader | Replaces | Content file |
|--------|--------|----------|--------------|
| `REVIEW_REQUESTED` | Reviewer | "Ready for review" SendMessage | — |
| `TEST_REQUESTED` | Tester | "Ready for test" SendMessage | — |
| `REREVIEW_REQUESTED` | Reviewer | "Ready for re-review" SendMessage | — |
| `RETEST_REQUESTED` | Tester | "Ready for re-test" SendMessage | — |
| `EXIT_REQUESTED` | Reviewer, Tester | "All stages passed — confirm..." SendMessage | — |

### Reviewer signals

| Signal | Reader | Replaces | Content file |
|--------|--------|----------|--------------|
| `REVIEWER_TAKE_READY` | Executor | "REVIEWER TAKE — task N: ..." SendMessage | `take.md` |
| `REVIEW_PASS` | Executor | Review PASS verdict SendMessage | — |
| `REVIEW_FAIL` | Executor | Review FAIL verdict SendMessage | `review-feedback.md` |
| `REVIEWER_READY_TO_EXIT` | Executor | "READY TO EXIT" SendMessage | — |

### Tester signals

| Signal | Reader | Replaces | Content file |
|--------|--------|----------|--------------|
| `TEST_PASS` | Executor | Test PASS verdict SendMessage | — |
| `TEST_FAIL` | Executor | Test FAIL verdict SendMessage | `test-feedback.md` |
| `TESTER_READY_TO_EXIT` | Executor | "READY TO EXIT" SendMessage | — |

### Lead signals

| Signal | Reader | Replaces | Content file |
|--------|--------|----------|--------------|
| `TESTER_SPAWNED` | Executor | "Tester spawned — proceed with impl report" SendMessage | — |
| `IMPL_APPROVED` | Executor (pipeline) | "Implementation approved — predecessor..." SendMessage | — |
| `SHUTDOWN` | All | shutdown_request | — |
| `PAUSE` / `RESUME` | All | "PAUSE: ..." / "RESUME: ..." SendMessage | — |

**What stays SendMessage-only** (non-executor recipients, already reliable):
- Executor → Lead: "code complete", "task done", ADVICE REQUEST, QUERY, "PLAN-INVALIDATING"
- Lead → PM: SPAWNED, SHUTDOWN, COMPLETED status updates
- PM → Lead: validated watchdog alerts
- Watchdog → PM: usage alerts
- FILE-UPDATED broadcasts (all directions)

## 3. Dual-Write Ordering

Every outbound signal follows this exact sequence:

1. **Write content file** (if the signal has an associated content file — see vocabulary table above)
2. **Append signal** to `signals.jsonl` via `echo >>`
3. **Attempt SendMessage** (best-effort — may silently fail, and that's OK)

The ordering is load-bearing:
- Content file before signal: the reader never sees a "content ready" flag before the content exists.
- Signal before SendMessage: the file-based record is authoritative; if SendMessage fails, the signal is still discoverable by polling.

**Example — Reviewer writing REVIEW_FAIL:**

```bash
# 1. Write content file
Write review-feedback.md to $PLAN_DIR/tasks/task-$TASK_ID/review-feedback.md

# 2. Append signal
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"REVIEW_FAIL","author":"reviewer-1"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"

# 3. Attempt SendMessage (best-effort)
SendMessage to executor-1: "REVIEW FAIL — Task 1: ..."
```

**Example — Executor writing REVIEW_REQUESTED (no content file):**

```bash
# 1. No content file for this signal
# 2. Append signal
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"REVIEW_REQUESTED","author":"executor-1"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"

# 3. Attempt SendMessage (best-effort)
SendMessage to reviewer-1: "Ready for review"
```

## 4. Content File Conventions

Three content files carry data too large for a signal line. They are written BEFORE the signal that flags them, so the signal acts as a "content ready" indicator.

| File | Purpose | Written by | Signal that flags it |
|------|---------|------------|---------------------|
| `take.md` | Full REVIEWER TAKE text | Reviewer | `REVIEWER_TAKE_READY` |
| `review-feedback.md` | Structured review failure details (same format as the existing REVIEW FAIL message) | Reviewer | `REVIEW_FAIL` |
| `test-feedback.md` | Structured test failure details (same format as the existing TEST FAIL message) | Tester | `TEST_FAIL` |

**Location:** `$PLAN_DIR/tasks/task-$TASK_ID/` — same directory as signals.jsonl.

**On re-review/re-test cycles:** overwrite the existing feedback file with the new cycle's feedback. The signal log retains the history (multiple REVIEW_FAIL entries); the content file always holds the latest feedback.

**On PASS:** no content file needed — the REVIEW_PASS or TEST_PASS signal line is sufficient. The structured PASS verdict is still sent via SendMessage (best-effort).

## 5. Executor Polling Discipline

Executors poll `signals.jsonl` **only during wait states** — never during active implementation. Polling checks for signals that SendMessage failed to deliver.

**When to poll (timer-based, ~60s between reads):**
- Step 3: waiting for REVIEWER_TAKE_READY (while exploring codebase)
- Step 3.5: waiting for IMPL_APPROVED (pipeline wait gate)
- Step 4.5: waiting for TESTER_SPAWNED
- Step 5: waiting for REVIEW_PASS/REVIEW_FAIL and TEST_PASS/TEST_FAIL verdicts
- Step 6: waiting for REVIEWER_READY_TO_EXIT, TESTER_READY_TO_EXIT, SHUTDOWN

**When NOT to poll:**
- Step 4 (active implementation) — the executor is writing code, not waiting for signals.

**Polling mechanism:**

```bash
cat "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
```

Read the entire file (~8-60 lines), scan for the expected signal. If found and the signal has an associated content file, read that file too. If not found, wait ~60s and poll again.

**If SendMessage arrives first:** process it immediately — no need to poll. The signal file is the fallback, not the primary path when messages do arrive.

**Token overhead:** ~100-200 tokens per poll (read a small file, check for a signal). With ~60s intervals during wait states, the overhead is negligible compared to the cost of a stalled pipeline.

## 6. Signal Reading Rules

### Startup (all agents)

During the task-team-startup protocol, read `signals.jsonl` after task.md and before plan.md (see `task-team-startup.md` §2). This is especially important for crash recovery — a re-spawned agent can infer precise pipeline state from the signal log.

### Crash Recovery State Inference

The signal log provides precise pipeline state that supplements file-presence inference from task.md/plan.md/impl.md:

| Signal pattern | Inferred state |
|---------------|----------------|
| `REVIEWER_TAKE_READY` present, no `plan.md` on disk | Take sent, planning not started — Executor should write plan.md |
| `REVIEWER_TAKE_READY` + `plan.md` exists, no implementation signals | Planning done, implementation not started |
| `REVIEW_REQUESTED` present, no `REVIEW_PASS` or `REVIEW_FAIL` | Review in progress (or reviewer crashed) |
| `REVIEW_FAIL` present, no subsequent `REREVIEW_REQUESTED` | Fix cycle interrupted — Executor should fix and re-request |
| `REVIEW_PASS` + `TEST_PASS` both present | Task was complete — may need shutdown only |
| `EXIT_REQUESTED` present, missing one or both `*_READY_TO_EXIT` | Exit confirmation interrupted |
| `SHUTDOWN` present | Team should have exited — re-spawn unnecessary |
| `PAUSE` present with no subsequent `RESUME` | Team was paused — wait for Lead |

### PM Stage Derivation

The PM reads `signals.jsonl` for each active task instead of receiving STAGE-DONE/RETRY messages from Executor. Derivation rules:

| Signal in file | PM action |
|---------------|-----------|
| `REVIEW_PASS` | Close review stage (set `ended_at`) |
| `TEST_PASS` | Close testing stage (set `ended_at`) |
| `REVIEW_FAIL` or `TEST_FAIL` followed by `REREVIEW_REQUESTED` or `RETEST_REQUESTED` | Increment `retry_count`, reset stage timers |

PM reads signals.jsonl on each incoming message from Lead (SPAWNED, COMPLETED, STAGE, etc.) — this keeps PM event-driven rather than adding a polling loop.

### Watchdog Stall Detection

The watchdog bash script checks `signals.jsonl` per in-progress task for the most recent signal timestamp. Uses the latest of `events.json` timestamps and `signals.jsonl` timestamps to determine staleness. Falls back to `events.json` alone for tasks without signals.jsonl.
