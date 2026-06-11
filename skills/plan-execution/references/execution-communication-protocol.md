# Execution Communication Protocol

All task-team agents (Executor, Reviewer, Tester, PM) and Lead use this protocol for every inter-agent communication. It wraps SendMessage with a durable file-based signal layer so that no message is lost when SendMessage silently fails.

**Load this file during startup** — it is referenced from `task-team-startup.md` and your agent instructions.

## 1. CommunicateTeamMember(to, message, signal?, content_file?)

Send a message to one specific agent. Execute these steps in order:

1. **If `content_file` is provided** — write it to `$PLAN_DIR/tasks/task-$TASK_ID/` BEFORE the signal. The reader must never see a "content ready" flag before the content exists on disk.

2. **If `signal` is provided** — append one JSONL line to `$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl`:
   ```bash
   echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"YOUR_SIGNAL","author":"your-agent-name","note":"optional one-line payload"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
   ```
   Always use `echo >>` via Bash — never Edit or Write. This is atomic on local filesystems. `note` is optional — use it for small payloads such as a verdict (`APPROVED`, `AMEND: <one line>`); anything longer goes in a content file.

3. **Always** — call `SendMessage(to=..., message=...)`. This is the primary delivery path, but it is best-effort. It may silently fail, and that is OK — the signal file is the durable backup record.

The ordering is load-bearing: content before signal (reader never sees flag before data), signal before SendMessage (file record is authoritative even if SendMessage fails).

**Sender rule:** any signal that a receiver waits on via `WaitForTeamMember` MUST be sent through `CommunicateTeamMember`/`CommunicateTeam` (signal append + SendMessage) — never a raw SendMessage alone. A raw SendMessage leaves no durable record; if it is lost, the waiter has nothing to find.

## 2. CommunicateTeam(message, signal?, content_file?)

Broadcast to all active teammates AND Lead. Same 3-step ordering as `CommunicateTeamMember`:

1. **If `content_file`** — write it once (not per recipient).
2. **If `signal`** — append to `signals.jsonl` once (not per recipient).
3. **SendMessage** to each active teammate AND Lead individually (best-effort per recipient).

Active teammates are those listed in your spawn prompt that haven't exited. Tester joins mid-task (lazy-spawned) — include them in broadcasts only after `TESTER_SPAWNED` has been received.

## 3. WaitForTeamMember(signal, from?)

Wait to receive a specific signal. **SendMessage is the primary delivery path** — if a message matching the expected signal arrives, process it immediately and you are done. The signal file is the durable backup. The wait posture must keep the primary channel open: SendMessages are only delivered **between turns**, so a wait that holds your turn open makes you deaf to the primary channel.

**During productive wait states** (you have useful work to do while waiting — e.g., exploring codebase while waiting for REVIEWER_TAKE_READY): read `signals.jsonl` periodically between other actions. No sleep needed — just check the file every few tool calls. A SendMessage can also reach you between tool batches.

**During pure wait states** (you are blocked with nothing to do — e.g., waiting for review verdict, advice, exit confirmation): run **bounded wait rounds** with the Monitor tool. NEVER run an unbounded loop, and NEVER run the wait loop as a foreground Bash call — a foreground loop blocks your turn, which blocks SendMessage delivery; the backup channel would silence the primary one (this caused a real ~10-minute production stall when a reply arrived as SendMessage-only). Each round:

```
Monitor:
  SIG="$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
  until grep -q '"signal":"YOUR_EXPECTED_SIGNAL"' "$SIG" || [ "$SECONDS" -ge 240 ]; do sleep 5; done
  grep -q '"signal":"YOUR_EXPECTED_SIGNAL"' "$SIG"
```

Starting the Monitor **ends your turn — that is the point.** While you idle, an incoming SendMessage wakes you directly (primary channel live); otherwise the Monitor wakes you within ~4 minutes: exit 0 = signal found, exit 1 = round timed out, nothing yet.

*Fallback:* if `Monitor` is not in your tool set, run the identical command via `Bash` with `run_in_background: true` and end your turn. Never foreground.

**Wake checklist (every wake):**
1. **Signal found** → read the matching line from `signals.jsonl` (including its `note`), and the content file if the signal has one (from `$PLAN_DIR/tasks/task-$TASK_ID/`). Wait complete.
2. **A SendMessage woke you** and it matches the wait → process it; wait complete. Unrelated message (FILE-UPDATED, PAUSE, …) → handle it per your workflow, then start the next round.
3. **Round timed out** → increment this wait's round counter and apply the recovery ladder.

**Recovery ladder** (per wait; rounds ≈ 4 min):
- **After round 3 (~12 min):** re-send the originating request via `CommunicateTeamMember` (re-append its signal, re-send the message). A lost SendMessage is the common cause; a resend usually unblocks the counterparty.
- **After round 6 (~24 min):** escalate: `CommunicateTeamMember(to: "lead", message: "STALLED-WAIT task-$TASK_ID: waiting for {SIGNAL} from {agent} for ~24m; resent at ~12m, no response")`. Keep running rounds.
- **After round 10 (~40 min):** hard-fail **visibly**: append `{"signal":"WAIT_TIMEOUT","author":"...","note":"gave up waiting for {SIGNAL} from {agent}"}`, SendMessage Lead AND PM, stop the wait, and hold for instructions. Never hang silently.
- **Exceptions:** waiting for `SHUTDOWN` — no hard-fail; after round 3 re-send your completion report, then continue rounds indefinitely (shutdown is Lead's job). Waiting for `RESUME` while paused — no resends, no escalation, indefinite rounds (Lead is deliberately in hold state).

**Token cost** — each wake costs one small re-invocation (~a few hundred tokens); in the happy path the wait resolves in round 1. Periodic manual checks during productive waits cost ~100-200 tokens per read. Both are negligible compared to a stalled pipeline.

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
| `note` | string (optional) | One-line payload, e.g. a verdict (`APPROVED`, `AMEND: …`). Longer content belongs in a content file |

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

21 signal types. Agents use these as the `signal` parameter in `CommunicateTeamMember` and `CommunicateTeam` calls, and as the `signal` parameter in `WaitForTeamMember`.

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
| `PAUSE` | Lead | Usage limit control — go idle |
| `RESUME` | Lead | Usage limit control — continue work |
| `WAIT_TIMEOUT` | any waiter | A bounded wait exhausted its recovery ladder (§3); `note` says what was awaited |

## 6. Crash Recovery

On re-spawn, agents read `signals.jsonl` during startup to infer pipeline state:

| Signal pattern | Inferred state |
|---------------|----------------|
| `REVIEWER_TAKE_READY`, no `PLAN_READY` | Take sent, planning not started |
| `PLAN_READY`, no `REVIEW_REQUESTED` | Implementation in progress (check impl.md) |
| `CODE_COMPLETE`, no `REVIEW_REQUESTED` | Writing impl.md or waiting for tester |
| `REVIEW_REQUESTED`, no `REVIEW_PASS`/`REVIEW_FAIL` | Review in progress |
| `TEST_REQUESTED`, no `TEST_PASS`/`TEST_FAIL` | Test in progress |
| `REVIEW_FAIL`/`TEST_FAIL`, no `REREVIEW_REQUESTED`/`RETEST_REQUESTED` | Fix cycle interrupted |
| `REREVIEW_REQUESTED`/`RETEST_REQUESTED`, no subsequent verdict | Re-review/re-test in progress |
| `REVIEW_PASS` + `TEST_PASS` | Task complete, may need shutdown only |
| `EXIT_REQUESTED`, missing `*_READY_TO_EXIT` | Exit confirmation interrupted |
| `SHUTDOWN` | Team should have exited |
| `PAUSE`, no subsequent `RESUME` | Team paused |
| `WAIT_TIMEOUT` as latest entry | A wait was abandoned (§3 ladder exhausted) — confirm with Lead before resuming the pipeline |
