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

> **Addressing (verified on Claude Code v2.1.201, tmux teammate mode).** Teammates are addressed by the names the Lead assigned at spawn: `executor-$TASK_ID`, `reviewer-$TASK_ID`, `tester-$TASK_ID`, `pm-$PLAN_NAME`. **The Lead / main conversation is addressed as `team-lead`** — the harness-reserved recipient name for the main agent. Do **not** use `lead` (unreachable — `SendMessage` returns `success:false`, "No agent named 'lead' is reachable") or `main` (a *self*-address usable only by anonymous background subagents, not named teammates — a named teammate sending to `main` is rejected). The Lead's signal `author` label in `signals.jsonl` is still `lead` — that is a durable-log label, not a `SendMessage` address. If a future Claude Code version changes the reserved leader name, this is the one line to update.

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

Wait to receive a signal. **SendMessage is the primary, immediate wake** — if a message matching the signal arrives, process it and you are done. But SendMessage is best-effort (documented silent-drop and orphaned-inbox bugs), so the durable, authoritative detection channel is a **single, persistent per-agent "inbox" monitor** that follows `signals.jsonl` and wakes you the instant any signal relevant to you is appended.

**One monitor per agent, armed once at startup — never re-armed.** After your startup crash-recovery read (§6), arm exactly one inbox monitor and leave it running for your whole lifetime. It replaces every per-wait Monitor round: from then on a "wait" is simply *yield your turn* — the armed inbox wakes you when something lands. A foreground Bash wait loop is still forbidden — it blocks your turn and makes you deaf to SendMessage (this caused a real ~10-minute production stall).

### Arming the inbox (startup)

`PROCESSED_LINES` is the number of `signals.jsonl` lines you have already consumed (after the §6 recovery read, that is the current line count). **Bake that number into the command** — do NOT recompute `wc -l` inside it, or a signal appended between your recovery read and the arm is skipped:

```
Monitor:
  command: tail -n +$((PROCESSED_LINES+1)) -F "$PLAN_DIR/tasks/task-$TASK_ID/signals.jsonl" | grep --line-buffered -E '"signal":"(<YOUR_ALTERNATION>)"'
  description: "task-$TASK_ID inbox: <your-role>"
  persistent: true
```

- `tail -n +K -F` replays lines K..EOF at attach time *and then* follows new appends, so any signal that landed during the arm is caught by the replay — the arm gap is closed by `tail` itself.
- Use `-F` (not `-f`) so a re-created file (crash recovery may `touch` it) keeps being followed.
- End every alternation branch at the closing quote — match `"signal":"NAME"` — so `TEST_REQUESTED` does not match inside `RETEST_REQUESTED`.
- `persistent: true` means no timeout and no self-termination; it runs until you `TaskStop` it at exit. There is therefore exactly **one wake kind: an event wake.** You never wake on your own timer.

**Per-role alternations** — the **union of every signal your role receives** (never the ones you write):

| Role | `<YOUR_ALTERNATION>` |
|------|----------------------|
| Executor | `REVIEWER_TAKE_READY\|ADVICE_RESPONSE\|IMPL_APPROVED\|TESTER_SPAWNED\|REVIEW_PASS\|REVIEW_FAIL\|TEST_PASS\|TEST_FAIL\|REVIEWER_READY_TO_EXIT\|TESTER_READY_TO_EXIT\|SHUTDOWN\|PAUSE\|RESUME` |
| Reviewer | `REVIEW_REQUESTED\|REREVIEW_REQUESTED\|EXIT_REQUESTED\|SHUTDOWN\|PAUSE\|RESUME` |
| Tester | `TEST_REQUESTED\|RETEST_REQUESTED\|EXIT_REQUESTED\|SHUTDOWN\|PAUSE\|RESUME` |

Always include `SHUTDOWN|PAUSE|RESUME` — a missing control signal plus a dropped SendMessage would hang you forever ("silence is not success"). Raw non-signal traffic (`QUERY`/`ANSWER`, `FILE-UPDATED`, `ADVICE`, `PLAN-INVALIDATING`) has no `signal` field and is not in the file; you handle it via normal inbox processing on any wake — none of it is a hard blocking gate.

### On every wake (event wake)

1. Read `signals.jsonl` lines from `PROCESSED_LINES+1` to EOF (`tail -n +$((PROCESSED_LINES+1))`).
2. Dispatch each relevant line per your workflow (its `note`, and the content file if the signal flags one).
3. Advance `PROCESSED_LINES` to the new line count.
4. If you are still blocked on something that hasn't arrived, **yield your turn** — the inbox is still armed and will wake you again. Do NOT arm another monitor.

The monotonic cursor guarantees each line is dispatched once even though `tail`'s replay and your catch-up read can overlap: on the next wake you read from the already-advanced cursor and find nothing new. `echo >>` appends are atomic (single sub-`PIPE_BUF` write), so the cursor never lands mid-record.

**Waiting on several signals at once is free.** Because the one inbox follows *all* your signals, an agent blocked on two producers (e.g. the Executor awaiting both a review verdict and a test verdict) does **not** arm two monitors — each verdict arrives as its own event on the same armed inbox. Track the outstanding conditions in your own state and evaluate the gate after each event.

**Comms telemetry (best-effort — one line per resolved wait).** When something you were blocked on resolves, append (never block on it — skip rather than delay):
```bash
echo '{"ts":"'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'","task":"'"$TASK_ID"'","wait_for":"SIGNAL","resolved_by":"sendmessage"}' >> "$PLAN_DIR/tasks/task-$TASK_ID/comms-telemetry.jsonl"
```
`resolved_by: sendmessage` if a matching SendMessage woke you first; `file` if the inbox follow caught the append with no matching SendMessage (the backstop fired).

### Teardown

`TaskStop` your inbox monitor when you exit (after `SHUTDOWN`).

### Stall detection — delegated to PM

With a persistent inbox there is no per-agent timer, so a **counterparty that dies and never appends the signal you are blocked on** is not detected by you. That case is owned entirely by the **PM's independent stall watch** (`scripts/usage-monitor.sh check_stalls`, keyed off the latest signal ts per `in_progress` task), which emits `STALL` to Lead; Lead investigates, records a visible `WAIT_TIMEOUT` (§5), and/or re-spawns. That is the system-level "never hang silently" guarantee. **Do not** add your own timeout loop — one persistent inbox per agent, PM is the sole stall net.

*Fallback — `Monitor` not in your tool set.* A persistent `tail -F` cannot run as a background `Bash` job (it never exits, so it never notifies). Degrade to **bounded background rounds that do exit**, re-armed per round (the only place re-arming reappears):

```
until tail -n +$((PROCESSED_LINES+1)) "$SIG" 2>/dev/null \
        | grep -Eq '"signal":"(<YOUR_ALTERNATION>)"' \
     || [ "$SECONDS" -ge 1800 ]; do sleep 5; done
```

Run via `Bash` with `run_in_background: true`, then end your turn. The cursor slice is essential — a whole-file `grep -q REVIEW_PASS` would match a stale prior-cycle pass and exit instantly. On a SendMessage wake, `TaskStop`/kill the stale background loop before relaunching from the advanced cursor. Never foreground.

**Token cost** — while parked you burn zero tokens; each relevant event costs one small re-invocation (~a few hundred tokens). No idle re-arm churn (the inbox never self-terminates).

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

**Telemetry sidecar** — `comms-telemetry.jsonl` (same directory) holds best-effort per-wait resolution records written by the §3 wake handler (`resolved_by: sendmessage|file`). It is *not* part of crash recovery or the signal vocabulary — PM reads it (if present) to compute the operational report's channel-health metrics. Absent file ⇒ no waits recorded telemetry; treat as empty, never an error.

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
| `WAIT_TIMEOUT` | Lead | Lead abandoned a stalled wait after an unresolved PM `STALL` (§3); `note` says what was awaited |

## 6. Crash Recovery

On re-spawn, agents read `signals.jsonl` during startup to infer pipeline state, **then set `PROCESSED_LINES=$(wc -l < "$SIG")` (EOF) and arm the one persistent inbox monitor (§3)** — history is not replayed, and every subsequent append wakes you. When inferring verdict state, use the **latest** verdict of each kind (`REVIEW_*`, `TEST_*`) that occurs **after the last code-change request** (`REREVIEW_REQUESTED`/`RETEST_REQUESTED`) — an earlier `REVIEW_PASS` followed by a later `REVIEW_FAIL` is *not* a pass. Reset a verdict to pending whenever a later request supersedes it.

| Signal pattern | Inferred state |
|---------------|----------------|
| `REVIEWER_TAKE_READY`, no `PLAN_READY` | Take sent, planning not started |
| `PLAN_READY`, no `REVIEW_REQUESTED` | Implementation in progress (check impl.md) |
| `CODE_COMPLETE`, no `REVIEW_REQUESTED` | Writing impl.md or waiting for tester |
| `REVIEW_REQUESTED`, no `REVIEW_PASS`/`REVIEW_FAIL` | Review in progress |
| `TEST_REQUESTED`, no `TEST_PASS`/`TEST_FAIL` | Test in progress |
| `REVIEW_FAIL`/`TEST_FAIL`, no `REREVIEW_REQUESTED`/`RETEST_REQUESTED` | Fix cycle interrupted |
| `REREVIEW_REQUESTED`/`RETEST_REQUESTED`, no subsequent verdict | Re-review/re-test in progress |
| latest `REVIEW_PASS` + latest `TEST_PASS`, both after the last request | Task complete, may need shutdown only |
| `EXIT_REQUESTED`, missing `*_READY_TO_EXIT` | Exit confirmation interrupted |
| `SHUTDOWN` | Team should have exited |
| `PAUSE`, no subsequent `RESUME` | Team paused |
| `WAIT_TIMEOUT` as latest entry | Lead abandoned a stalled wait (§3) — confirm with Lead before resuming the pipeline |
