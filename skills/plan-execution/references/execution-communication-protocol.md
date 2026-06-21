# Execution Communication Protocol

All task-team agents (Executor, Reviewer, Tester, PM) and Lead use this protocol for every inter-agent communication.

`signals.jsonl` is a **durable, append-only shared state log — not merely a SendMessage backup.** It does three jobs, and only one of them overlaps with SendMessage:
1. **Crash recovery** (§6) — a re-spawned agent reconstructs pipeline state by reading the log. SendMessage cannot do this: there is no message replay across a process death.
2. **Observer state** — PM tracks stage transitions and the operational report derives its timeline from the log, without either having been in the message loop. SendMessage reaches only live recipients.
3. **Delivery backstop** — the one job that *does* overlap with SendMessage. It guards against Claude Code's documented, still-open name-addressing delivery bugs: `SendMessage(to:"name")` can return `success:true` yet never deliver, and a name that misses the polling target lands in an orphaned inbox and vanishes (see `.claude/ultra/research/claude-code-sendmessage.md`). This system addresses teammates by name, so it is exposed to exactly those bugs.

**SendMessage is the primary, immediate wake; the log is the durable record.** The two are complementary, not redundant — losing the log would forfeit jobs 1 and 2 entirely, which no amount of SendMessage reliability replaces.

> **`CommunicateTeamMember`, `CommunicateTeam`, and `WaitForTeamMember` are procedures defined in this file — not tools.** Do not look for a tool by these names; ToolSearch will not find them, and their absence does **not** mean the team feature is unavailable. Each is a fixed sequence built from real primitives: `SendMessage` (deferred — load via `ToolSearch` at startup), an `echo >>` append to `signals.jsonl` (Bash), and — for waits — `Monitor` (deferred, with a Bash fallback). Spawning teammates is done with the **`Agent` tool** (teammate mode: `name` + `run_in_background: true`), **not** a `TeamCreate` tool — no such tool exists.

**Load this file during startup** — it is referenced from `task-team-startup.md` and your agent instructions.

## 1. CommunicateTeamMember(to, message, signal?, content_file?)

Send a message to one specific agent. Execute these steps in order:

1. **If `content_file` is provided** — write it to `$PLAN_DIR/tasks/task-$TASK_ID/` BEFORE the signal. The reader must never see a "content ready" flag before the content exists on disk.

2. **If `signal` is provided** — append one JSONL line to `$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl`:
   ```bash
   echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","signal":"YOUR_SIGNAL","author":"your-agent-name","note":"optional one-line payload"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
   ```
   Always use `echo >>` via Bash — never Edit or Write. This is atomic on local filesystems. `note` is optional — use it for small payloads such as a verdict (`APPROVED`, `AMEND: <one line>`); anything longer goes in a content file.

3. **Always** — call `SendMessage(to=..., message=...)`. This is the primary, immediate delivery path, but it is best-effort. It may silently fail, and that is OK — the signal file is the durable state-log record and delivery backstop.

The ordering is load-bearing: content before signal (reader never sees flag before data), signal before SendMessage (file record is authoritative even if SendMessage fails).

**Sender rule:** any signal that a receiver waits on via `WaitForTeamMember` MUST be sent through `CommunicateTeamMember`/`CommunicateTeam` (signal append + SendMessage) — never a raw SendMessage alone. A raw SendMessage leaves no durable record; if it is lost, the waiter has nothing to find.

## 2. CommunicateTeam(message, signal?, content_file?)

Broadcast to all active teammates AND Lead. Same 3-step ordering as `CommunicateTeamMember`:

1. **If `content_file`** — write it once (not per recipient).
2. **If `signal`** — append to `signals.jsonl` once (not per recipient).
3. **SendMessage** to each active teammate AND Lead individually (best-effort per recipient).

Active teammates are those listed in your spawn prompt that haven't exited. Tester joins mid-task (lazy-spawned) — include them in broadcasts only after `TESTER_SPAWNED` has been received.

## 3. WaitForTeamMember(signal, from?)

Wait to receive a specific signal. **SendMessage is the primary delivery path** — if a message matching the expected signal arrives, process it immediately and you are done. The signal file is the durable backstop and crash-recovery record. The wait posture must keep the primary channel open: SendMessages are only delivered **between turns**, so a wait that holds your turn open makes you deaf to the primary channel.

**During productive wait states** (you have useful work to do while waiting — e.g., exploring codebase while waiting for REVIEWER_TAKE_READY): read `signals.jsonl` periodically between other actions. No sleep needed — just check the file every few tool calls. A SendMessage can also reach you between tool batches.

**During pure wait states** (you are blocked with nothing to do — e.g., waiting for review verdict, advice, exit confirmation): run **bounded wait rounds** with the Monitor tool. NEVER run an unbounded loop, and NEVER run the wait loop as a foreground Bash call — a foreground loop blocks your turn, which blocks SendMessage delivery; the backup channel would silence the primary one (this caused a real ~10-minute production stall when a reply arrived as SendMessage-only). Each round:

```
Monitor:
  SIG="$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl"
  until grep -q '"signal":"YOUR_EXPECTED_SIGNAL"' "$SIG" || [ "$SECONDS" -ge 300 ]; do sleep 10; done
  grep -q '"signal":"YOUR_EXPECTED_SIGNAL"' "$SIG"
```

Starting the Monitor **ends your turn — that is the point.** While you idle, an incoming SendMessage wakes you directly (primary channel live); otherwise the Monitor wakes you within ~5 minutes: exit 0 = signal found, exit 1 = round timed out, nothing yet. The round length only bounds the *backup* wake — the happy path is woken immediately by SendMessage, so a longer round costs nothing when delivery works and merely reduces idle-agent wake churn when it has nothing to do.

*Fallback:* if `Monitor` is not in your tool set, run the identical command via `Bash` with `run_in_background: true` and end your turn. Never foreground.

**Wake checklist (every wake):**
1. **Signal found** → read the matching line from `signals.jsonl` (including its `note`), and the content file if the signal has one (from `$PLAN_DIR/tasks/task-$TASK_ID/`). Wait complete.
2. **A SendMessage woke you** and it matches the wait → process it; wait complete. Unrelated message (FILE-UPDATED, PAUSE, …) → handle it per your workflow, then start the next round.
3. **Round timed out** → increment this wait's round counter and apply the recovery ladder.

**Comms telemetry (best-effort — one line when a wait completes).** This is how we measure whether the file backstop ever actually catches a dropped SendMessage. After case 1 or 2 resolves the wait, append:
```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","task":"'"$TASK_ID"'","wait_for":"YOUR_EXPECTED_SIGNAL","resolved_by":"sendmessage","round":N}' >> "$PLAN_DIR/tasks/task-$TASK_ID/comms-telemetry.jsonl"
```
Set `resolved_by` to: `sendmessage` (case 2 — a matching SendMessage woke you), or `file` (case 1 — you found the signal in `signals.jsonl` and **no matching SendMessage had arrived**: the backstop fired). This append is additive and must never delay processing the signal — skip it rather than block. It is a corroborating measure only; the authoritative channel-health metrics (resends, escalations, `WAIT_TIMEOUT`) are derived deterministically by PM from `signals.jsonl`.

**Recovery ladder.** The triggers below are **elapsed-wait targets in minutes, not round counts** — track how long you've been waiting (rounds are ~5 min each, so the targets fall at roughly rounds 3 / 5 / 8), so they stay stable if the round length changes:
- **After ~12 min waiting:** re-send the originating request via `CommunicateTeamMember` (re-append its signal, re-send the message). A lost SendMessage is the common cause; a resend usually unblocks the counterparty.
- **After ~24 min waiting:** escalate: `CommunicateTeamMember(to: "lead", message: "STALLED-WAIT task-$TASK_ID: waiting for {SIGNAL} from {agent} for ~24m; resent at ~12m, no response")`. Keep running rounds.
- **After ~40 min waiting:** hard-fail **visibly**: append `{"signal":"WAIT_TIMEOUT","author":"...","note":"gave up waiting for {SIGNAL} from {agent}"}`, SendMessage Lead AND PM, stop the wait, and hold for instructions. Never hang silently.
- **Exceptions:** waiting for `SHUTDOWN` — no hard-fail; after ~12 min re-send your completion report, then continue rounds indefinitely (shutdown is Lead's job). Waiting for `RESUME` while paused — no resends, no escalation, indefinite rounds (Lead is deliberately in hold state).

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

**Telemetry sidecar** — `comms-telemetry.jsonl` (same directory) holds best-effort per-wait resolution records written by the §3 wake checklist (`resolved_by: sendmessage|file`). It is *not* part of crash recovery or the signal vocabulary — PM reads it (if present) to compute the operational report's channel-health metrics. Absent file ⇒ no waits recorded telemetry; treat as empty, never an error.

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
