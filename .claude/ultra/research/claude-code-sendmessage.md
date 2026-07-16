---
topic: Claude Code SendMessage tool — failure modes, workarounds, and inter-agent communication
type: library
subject: claude-code-sendmessage
fetched_at: 2026-07-16
expires: 2026-07-26
sources:
  - https://code.claude.com/docs/en/agent-teams
  - https://code.claude.com/docs/en/sub-agents
  - https://code.claude.com/docs/en/tools-reference
  - https://code.claude.com/docs/en/agent-sdk/overview
  - https://code.claude.com/docs/en/agent-sdk/subagents
  - https://code.claude.com/docs/en/changelog
  - https://github.com/anthropics/claude-code/issues/42999
  - https://github.com/anthropics/claude-code/issues/42737
  - https://github.com/anthropics/claude-code/issues/47021
  - https://github.com/anthropics/claude-code/issues/48160
  - https://github.com/anthropics/claude-code/issues/25135
  - https://github.com/anthropics/claude-code/issues/36196
  - https://github.com/anthropics/claude-code/issues/4993
  - https://github.com/anthropics/claude-code/issues/30140
  - https://github.com/anthropics/claude-code/issues/43706
  - https://github.com/anthropics/claude-code/issues/50310
  - https://github.com/anthropics/claude-code/issues/61248
  - https://github.com/anthropics/claude-agent-sdk-python/issues/577
  - https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-settings/references/real-world-examples.md
  - https://zenn.dev/rhythmcan/articles/b090f1bfe029e8
  - https://claudefa.st/blog/guide/agents/agent-teams-best-practices
---

# Claude Code SendMessage Tool

> Last verified: 2026-07-16. Expires: 2026-07-26. Re-invoke `/uc:research Claude Code SendMessage tool reliability` to refresh.

## Executive Summary — What Changed Since 2026-07-06

This refresh landed on Claude Code **v2.1.211** (July 15, 2026), ten builds after the previous pass (v2.1.201, July 3). Several load-bearing facts changed or were newly documented — read this section before the detail below:

1. **`SendMessage` is now officially documented as its own tool** in `https://code.claude.com/docs/en/tools-reference`, and the tool **no longer requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`** for its core resume/addressing use. The docs state plainly: *"`SendMessage` doesn't require [agent teams] to be enabled; only structured team-protocol messages such as `shutdown_request` and `plan_approval_response` do."* This corrects the prior pass's framing (Feature Gate section) that `SendMessage` was "still gated behind" the flag — see the rewritten Feature Gate section below.
2. **Subagents run in the background by default as of v2.1.198** (July 1, 2026). Omitting `run_in_background` on an `Agent` call now launches a background subagent; Claude sets `run_in_background: false` when it needs the result before continuing. This inverts the prior default and invalidates any "one-shot subagent = foreground" assumption baked into earlier research or orchestration code.
3. **A subagent's addressing is now partly documented**, via a new "sibling roster" mechanism (**requires v2.1.206**, July 9): a subagent whose tools include `SendMessage`, running alongside at least one other named agent, receives a system reminder listing `main` and every other named agent in the session as valid `to` values. **`"main"` is the documented literal for a subagent reaching the parent conversation** — this is new; it did not exist in the docs as of the last pass. Addressing the **agent-teams lead** as `"team-lead"` from a named **teammate** remains undocumented (see the addressing section below for the full split).
4. **Subagent nesting is confirmed unchanged at 5 levels**, shipped in v2.1.172 (June 10) — not new since the last pass, but now cross-verified directly against the current `sub-agents` doc page with full depth-tracking semantics (depth fixed at spawn, doesn't change on resume, as of v2.1.187).
5. **The stale-name-reuse fix version is now definitively v2.1.199** (July 2, 2026), corroborated by both the changelog and the `sub-agents` and `tools-reference` docs pages. The prior pass recorded two conflicting versions (v2.1.162 and v2.1.196) for this fix — both were wrong; see "Failure Mode 3" below for the correction.
6. **Mailbox files now validate entries individually on read** (agent-teams docs, effective "before v2.1.207" per the docs' own wording): a malformed entry is reported and dropped, valid messages in the same file still deliver. Previously one malformed entry could block delivery for that whole mailbox until manually deleted.
7. **The Agent tool was hardened against indirect prompt injection via subagent-read content twice** — once in v2.1.187 (June 23) and again in v2.1.211 (July 15), same changelog wording both times, suggesting either a second distinct injection vector or a re-hardening pass.
8. **In-process teammates still cannot background their own subagents** — confirmed unchanged, now with clearer docs wording: *"an in-process teammate's own subagents run in the foreground... because a teammate's background work can't outlive the lead's process. Subagents launched from the main conversation follow the background default."*
9. **All previously tracked GitHub issues are unchanged in status** on re-check (2026-07-16): #43706 (background teammate → lead one-way, closed duplicate), #577 (SDK-mode teammate → lead delivery, still OPEN), #42999 (name-vs-ID silent failure, closed not planned), #25135 (orphaned inbox, closed not planned), #48160 (subagent asymmetric SendMessage access, closed duplicate). No new comments, no reopenings, no changelog entries resolving any of them by name.

## Addressing the Team Leader vs. the Main Conversation (Split Rule)

There are now **two distinct addressing mechanisms** in play, and conflating them is the most common source of confusion. As of this refresh, one of them is officially documented; the other still is not.

### 1. Subagent → main conversation: `"main"` (now documented, v2.1.206+)

From `https://code.claude.com/docs/en/sub-agents` (What loads at startup → Sibling roster):

> "**Sibling roster**: a system reminder listing `main` and every other named agent in the session, each a valid `to` value for [`SendMessage`](#resume-subagents). Requires Claude Code v2.1.206 or later. The roster appears only when the subagent's tools include `SendMessage` and at least one other agent has a name, whether Claude named it when spawning it or it runs as an [agent team](/en/agent-teams) teammate. It is a snapshot taken when the subagent starts, so agents named later don't appear."

This is new relative to the 2026-07-06 pass — the docs did not previously state any literal for a subagent to reach its parent. `"main"` is now the confirmed, documented address, but with three gating conditions worth flagging to any executor: (a) requires v2.1.206+, (b) requires `SendMessage` to be in the subagent's `tools`, and (c) requires at least one *other* named agent to exist in the session — a lone anonymous subagent with no named siblings never receives the roster at all, so it has no documented way to learn `"main"` is even a valid target unless the calling prompt tells it explicitly. Treat "tell the spawned agent explicitly how to reach you" as still necessary belt-and-suspenders practice, not optional, until that gap is closed.

### 2. Named teammate → lead: `"team-lead"` (still undocumented, unchanged)

The **agent-teams** page (`https://code.claude.com/docs/en/agent-teams`), re-fetched in full on 2026-07-16, still contains **no literal for addressing the lead**. It documents only teammate-to-teammate addressing:

> "The lead assigns every teammate a name when it spawns them, and any teammate can message any other by that name. To get predictable names you can reference in later prompts, tell the lead what to call each teammate in your spawn instruction."

The reserved/working literal remains **`"team-lead"`** — still the hardcoded `InboxPoller` fallback reverse-engineered in issue #25135 (closed as not planned, unchanged), still corroborated by the same two community write-ups as the last pass:

> "Always specify `"team-lead"` as the `recipient`... never substitute actual member identities or nicknames for the reserved `"team-lead"` literal." — https://zenn.dev/rhythmcan/articles/b090f1bfe029e8

> "The proper convention is to use `recipient: "team-lead"`. Arbitrary names (such as team member nicknames) will not work." — https://claudefa.st/blog/guide/agents/agent-teams-best-practices

**Delivery from a background teammate to the lead via `"team-lead"` remains confirmed broken** — issue #43706 re-checked 2026-07-16, still closed as duplicate, no new activity, no fix landed through v2.1.211. See Failure Mode 6 below.

### Why the split exists

These are two different code paths. `"main"` is the sibling-roster literal for **subagents spawned via the `Agent` tool** (the `/en/sub-agents` model — background-by-default since v2.1.198, nested up to 5 levels, report back to whoever spawned them). `"team-lead"` is the emergent fallback for **agent-teams teammates** (the `/en/agent-teams` model — full peer sessions with their own mailbox, task list, and no conversation-history inheritance). A teammate is not a subagent in this architecture and does not get the sibling roster's `main` entry documented for it; conversely, a subagent addressed via `Agent(name=...)` is not a teammate and has no `"team-lead"` concept unless the session also happens to have agent teams enabled and a lead entry registered. **Do not use `"main"` to reach an agent-teams lead, and do not use `"team-lead"` to reach the parent of a plain background subagent** — neither is guaranteed to resolve in the other's code path, and nothing in the current docs states they're interchangeable.

### Bottom line

- Reaching your own spawner from a **background subagent**: use `"main"` if the sibling roster is present (v2.1.206+, `SendMessage` in tools, at least one named sibling); otherwise there is no documented literal — restate the caller's identity in the spawn prompt as a fallback.
- Reaching the **lead from a named teammate**: use `"team-lead"`, but treat it as best-effort only — pair with the file-based dual-write pattern (Workaround 4 below), especially for any teammate spawned with `run_in_background: true`, per the still-unresolved #43706.
- Both addressing conventions coexist with the file-based fallback pattern; neither should be trusted alone for anything you can't afford to lose.

### Confidence level

The `"main"` sibling-roster mechanism is now first-party documented — treat it as reliable within its stated gating conditions. The `"team-lead"` literal remains reverse-engineered from source and community corroboration, not an Anthropic-guaranteed contract, and delivery through it is confirmed unreliable for background teammates. Agent teams overall remain **experimental**, gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`, with the same class of caveat as prior passes:

> "Agent teams are experimental and disabled by default... Agent teams have [known limitations](#limitations) around session resumption, task coordination, and shutdown behavior." — https://code.claude.com/docs/en/agent-teams

## Official Documentation Status

**Corrected from prior passes**: `SendMessage` is no longer documented *exclusively* under Agent Teams. It now has its own row in the canonical tools reference:

> "**SendMessage** | Sends a message to an [agent team](/en/agent-teams) teammate, or [resumes a subagent](/en/sub-agents#resume-subagents) by its agent ID or name. A completed subagent auto-resumes in the background; a subagent you stopped from `/tasks` doesn't and the call returns a refusal. Structured team-protocol messages require agent teams. A receiver never treats a message from another agent as your consent or approval. As of v2.1.198, a subagent treats a message from the agent that launched it as normal task direction rather than as a peer request. As of v2.1.199, a send to a name that now resolves to a different agent than it did earlier in the conversation is refused instead of delivered; see [Resume subagents](/en/sub-agents#resume-subagents)." — https://code.claude.com/docs/en/tools-reference

And from `https://code.claude.com/docs/en/sub-agents` (Resume subagents section), the plain-subagent resume path is now spelled out with `SendMessage` as the documented mechanism, not merely inferred:

> "Claude uses the `SendMessage` tool with the agent's ID or name as the `to` field to resume it. `SendMessage` doesn't require [agent teams](/en/agent-teams) to be enabled; only structured team-protocol messages such as `shutdown_request` and `plan_approval_response` do."

> "A completed subagent that receives a `SendMessage` auto-resumes in the background without a new `Agent` invocation. The same applies to a subagent that Claude stopped with the `TaskStop` tool."

> "As of v2.1.191, a subagent you stopped yourself, with `x` in `/tasks` or an SDK `stop_task` request, doesn't auto-resume. The `SendMessage` call returns a refusal telling Claude the agent was cancelled. Type into that subagent's transcript in the subagent panel to resume it yourself, which clears the stop so later `SendMessage` calls can auto-resume it again."

> "Resuming starts a new run of the agent under the same ID, so a subagent that had already failed or completed shows as running again in the task list and in the Agent SDK's task events. Before v2.1.205, it kept showing its earlier failed or completed status while the resumed run was working."

The **Agent SDK subagents documentation** (`https://code.claude.com/docs/en/agent-sdk/subagents`) still makes no mention of `SendMessage` for SDK-mode resumption — that page's resume pattern uses `resume` on `query()` plus the `agentId` trailer, unchanged (see "Subagent Resume via Agent ID" below). It does, however, now explicitly document the background-default flip:

> "Two subagent behaviors changed in Claude Code v2.1.198: Subagents run in the background by default. An Agent tool call that omits the [`run_in_background`](/en/agent-sdk/typescript) input launches a background subagent, and Claude sets `run_in_background: false` when it needs the result before continuing. Before v2.1.198, omitting `run_in_background` ran the subagent synchronously. Set the `background` field to `true` to force background execution for a specific agent regardless of what Claude requests."

> "As of Claude Code v2.1.172, subagents can spawn their own subagents. A subagent five levels below the main agent can't spawn further subagents, regardless of whether it runs in the foreground or background."

**Critical distinction, revised:** `SendMessage` itself is now a general-purpose tool documented independent of Agent Teams — it's the mechanism for resuming *any* subagent and for addressing `main`/named siblings via the roster. Only the **structured team-protocol message subtypes** (`shutdown_request`, `shutdown_response`, `plan_approval_response`, and similar) require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`. Treat any prior claim that "`SendMessage` requires the Agent Teams flag" as outdated as of this pass.

## Feature Gate: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` (Corrected Scope)

**This section reverses the prior pass's framing.** The May/July 2026 passes both stated `SendMessage` was "still gated behind" this flag. As of this refresh, the docs draw a narrower line: the flag gates **Agent Teams** (teammates, shared task lists, mailboxes-as-a-peer-system, `shutdown_request`/`plan_approval_response` message types) — not `SendMessage` itself, which now also serves as the documented resume/addressing mechanism for ordinary subagents regardless of the flag.

Agent Teams itself remains disabled by default:

> "Agent teams are experimental and disabled by default. Enable them by adding `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your [settings.json](/en/settings) or environment. Without that variable, no team is set up at session start, no team directories are written, and Claude does not spawn or propose teammates. Agent teams have [known limitations](#limitations) around session resumption, task coordination, and shutdown behavior." — https://code.claude.com/docs/en/agent-teams

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Issue #42737** ("`SendMessage` gated behind AGENT_TEAMS flag," filed April 2, 2026, closed as duplicate) — re-checked 2026-07-16, still closed, no new activity, no explicit reopening or comment acknowledging the docs' scope narrowing. Given the current `tools-reference` and `sub-agents` docs now directly state `SendMessage` "doesn't require agent teams to be enabled," the underlying complaint in #42737 appears to be resolved **by documentation and by the v2.1.198+ background-default rollout**, even though the issue itself carries no comment saying so. Treat this as resolved-in-practice, not formally closed-as-fixed.

Source: https://github.com/anthropics/claude-code/issues/42737

## Background-by-Default Spawning (New Section)

The single largest behavioral change since the 2026-07-06 pass. As of **v2.1.198 (July 1, 2026)**:

> "Subagents now run in the background by default, so Claude keeps working while they run and is notified when they finish (previously a gradual rollout)." — https://code.claude.com/docs/en/changelog

The `sub-agents` docs page states the mechanics precisely:

> "As of v2.1.198, subagents run in the background by default. Claude runs a subagent in the foreground when it needs the result before continuing. The default changes where a subagent runs, not what it's allowed to do: background subagents still surface every permission prompt in your main session. Before v2.1.198, Claude chose between foreground and background based on the task." — https://code.claude.com/docs/en/sub-agents

And from the Agent SDK docs, the parameter-level mechanic:

> "An Agent tool call that omits the `run_in_background` input launches a background subagent, and Claude sets `run_in_background: false` when it needs the result before continuing." — https://code.claude.com/docs/en/agent-sdk/subagents

**Practical implications for any orchestration built before July 2026:**

- **Do not assume a spawned subagent blocks the caller's turn.** Prior designs that relied on "the Agent tool call doesn't return until the subagent is done" are only correct today when `run_in_background: false` is explicitly set (or Claude infers it needs the result immediately).
- **Forcing behavior**: the `background` frontmatter/`AgentDefinition` field (`boolean`) overrides Claude's choice — `background: true` always backgrounds a specific subagent definition regardless of what the caller requests at invocation time; there is no documented equivalent flag to force foreground unconditionally other than the per-invocation `run_in_background: false`.
- **Completion notification**: background subagents/agents notify the caller on completion via idle notifications; in `claude agents`, this fires the `Notification` hook with `agent_needs_input` / `agent_completed` subtypes (v2.1.198).
- **Result fabrication was a real risk, now mitigated**: v2.1.210 (July 14) — "Improved background agent result reporting — Claude now reports the status of still-running agents and waits for the real completion instead of fabricating results." This directly targets a failure mode where the main agent could hallucinate a background agent's outcome before it actually finished; if you're on an older build, treat any background-agent "result" text with suspicion until you confirm this fix is present.
- **Disabling entirely**: `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` turns off all background task functionality, forcing synchronous spawns everywhere.
- **Interaction with forking**: `CLAUDE_CODE_FORK_SUBAGENT=1` forces every subagent spawn to background regardless of the `background` frontmatter field, "because fork mode removes the `run_in_background` parameter from the `Agent` tool." `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS` takes precedence over fork mode.
- **Agent Teams exception, unchanged and now more explicitly worded**: "an in-process teammate's own subagents run in the foreground. Asking for a background one, whether with `run_in_background` or a subagent definition that sets `background: true`, returns an error, because a teammate's background work can't outlive the lead's process. Subagents launched from the main conversation follow the background default." A teammate cannot background its own subagents no matter what flag is set; only the lead's directly-spawned subagents get the v2.1.198 background-by-default behavior.

Source: https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/agent-sdk/subagents, https://code.claude.com/docs/en/changelog, https://code.claude.com/docs/en/agent-teams (Limitations)

## Subagent Nesting (Up to 5 Levels)

Confirmed unchanged from v2.1.172 (June 10, 2026), cross-verified against the current docs page on this pass:

> "Sub-agents can now spawn their own sub-agents (up to 5 levels deep)." — https://code.claude.com/docs/en/changelog (v2.1.172)

> "As of Claude Code v2.1.172, a subagent can spawn its own subagents. Use this when a delegated task itself splits into parallel subtasks, such as a reviewer subagent that dispatches a verifier per finding, so the intermediate output never reaches your main conversation. Only the top-level subagent's summary returns to you." — https://code.claude.com/docs/en/sub-agents

> "Depth is counted as the number of subagent levels below the main conversation, regardless of whether each level runs in the [foreground or background](#run-subagents-in-foreground-or-background). A subagent at depth five doesn't receive the Agent tool and can't spawn further. The limit is fixed and not configurable."

> "As of Claude Code v2.1.187, a background subagent's depth is fixed when it is first spawned, and [resuming](#resume-subagents) it later doesn't change that depth. For example, if your main conversation spawns subagent A, and A spawns a background subagent B at depth two, B is still at depth two when you resume it directly from the main conversation. Resuming a subagent from a shallower context doesn't let it spawn additional levels that the depth limit already prevented."

To prevent a subagent from spawning others: "omit `Agent` from its [`tools`](#available-tools) list or add it to `disallowedTools`." A [fork](/en/sub-agents#fork-the-current-conversation) can spawn other subagent types (counting toward depth), but "still can't spawn another fork."

**Agent-teams contrast, unchanged**: "No nested teams: teammates cannot spawn their own teammates. Only the lead can manage the team." — the 5-level nesting applies to `Agent`-tool subagents, not to agent-teams teammates, which have a flat, lead-only spawn model.

Source: https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/changelog, https://code.claude.com/docs/en/agent-teams

## Known Failure Modes

### Failure Mode 1: Tool Not Available (No Feature Flag) — Narrowed Scope

**Revised in light of the Feature Gate correction above.** Without `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, the **Agent Teams** system (teammates, mailboxes-as-peer-messaging, shared task claiming) is not set up — but `SendMessage` itself remains available for ordinary subagent resume/addressing via the sibling roster, per the current docs. The historical report below (issue #47021, unchanged, closed as duplicate, filed against Claude Code 2.1.104) predates this scope narrowing and should be read as evidence of the *old* all-or-nothing behavior, not necessarily current behavior:

> `SendMessage` tool is **not available** at runtime (neither as direct nor deferred tool)
>
> `ToolSearch` query `select:SendMessage` returns: `"No matching deferred tools found"`

Source: https://github.com/anthropics/claude-code/issues/47021

### Failure Mode 2: Tool Not Available in Subagents (Asymmetric Access) — Status Unchanged, Now Contradicted by Current Docs

Issue #48160 remains **closed as duplicate** on re-check 2026-07-16, no new activity since the original report (Claude Code 2.1.104-era). Its narrower successor, **#43706**, also remains closed as duplicate with no fix landed through v2.1.211. **However**, the current `sub-agents` docs page directly documents subagents originating `SendMessage` (the sibling-roster mechanism, resume-by-name/ID) as a first-party, working feature as of v2.1.206+ — meaning the *general* claim in #48160 ("subagents cannot originate SendMessage at all") is now clearly outdated for `Agent`-tool subagents, even though the *narrower* teammate-specific delivery bug in #43706 is confirmed still live. Treat #48160 as historical/superseded by the v2.1.198–2.1.206 rollout; treat #43706 as the current, accurate description of what's still broken (teammate → lead specifically, not subagent → main generally).

Original finding, retained for context: from issue #48160 (Claude Code Opus 4.6, closed as duplicate):

> **Asymmetric messaging:**
> - **Parent agent**: Successfully calls `SendMessage(to="indexes", ...)` → `{"success":true,"message":"Message queued for delivery to indexes at its next tool round."}`
> - **Subagents**: Cannot originate `SendMessage`
>
> `ToolSearch("select:SendMessage")` in subagents returns **no match**.

Source: https://github.com/anthropics/claude-code/issues/48160

### Failure Mode 3: Name vs ID Mismatch — Silent False Success — Fix Version CORRECTED

**Prior-pass discrepancy resolved.** The 2026-07-06 pass recorded the stale-name-reuse fix at **v2.1.196** in one place and the original May 2026 pass had recorded **v2.1.162** — both are wrong. Cross-referencing the changelog against the `sub-agents` and `tools-reference` docs pages on this pass confirms the fix shipped in **v2.1.199 (July 2, 2026)**:

> "Fixed `SendMessage` silently misrouting when a re-spawned agent reuses a previous agent's name — the tool now detects the mismatch and asks the caller to retarget." — https://code.claude.com/docs/en/changelog (v2.1.199)

Corroborated verbatim in the docs body text:

> "As of v2.1.199, `SendMessage` checks that a name still refers to the same agent it reached earlier in the conversation. If a newer agent has taken the name, such as a re-spawned background agent that reused it, Claude Code refuses the send rather than delivering it to the wrong agent, and the error reports which agent the name now reaches so Claude can retarget. To reach the earlier agent while it's still running, Claude addresses it by the agent ID from its spawn result. The check is scoped to the current conversation and resets on `/clear`." — https://code.claude.com/docs/en/sub-agents

And the `tools-reference` SendMessage row: "As of v2.1.199, a send to a name that now resolves to a different agent than it did earlier in the conversation is refused instead of delivered." — https://code.claude.com/docs/en/tools-reference

This still covers only the **"stale name reused by a re-spawned agent"** sub-case. The broader claim in issue #42999 — that a name which was *never* registered as a name→ID mapping at all can silently report success — remains unaddressed. Issue #42999 re-checked 2026-07-16: still **closed as "not planned,"** no new activity.

The tool's own reference now states the mapping explicitly (see Official Documentation Status above), but the underlying orphaned-recipient problem (#25135, below) is what actually causes the silent-success failure mode when no name→ID mapping exists at all.

Source: https://github.com/anthropics/claude-code/issues/42999, https://code.claude.com/docs/en/changelog, https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/tools-reference

### Failure Mode 4: Orphaned Inbox Files — Status Unchanged, Root Cause Directly Addressed by Mailbox Validation (Partial Mitigation)

Issue #25135 re-checked 2026-07-16: still **closed as not planned**, no reopening, no changelog entry closing the loop on recipient-existence validation as such. However, a **related** mailbox robustness improvement did land, addressing a different (but adjacent) failure mode — malformed *entries*, not unregistered *recipients*:

> "Each agent's mailbox is a JSON file at `~/.claude/teams/{team-name}/inboxes/{agent-name}.json`. Claude Code validates every entry when it reads a mailbox file. Entries that don't match the message format are reported as errors and removed from the file; the valid messages are still delivered. Before v2.1.207, a single malformed mailbox entry caused a repeated error every second and blocked delivery for that mailbox until you deleted the file manually." — https://code.claude.com/docs/en/agent-teams

Note this does **not** fix the #25135 scenario: a message sent to an unregistered/misspelled recipient still writes to a *new*, valid-format orphaned inbox file that nothing polls — the entry itself is well-formed, so the v2.1.207 per-entry validation has nothing to reject. The fix proposed in #25135 (validate `recipient` against the actual team member list) is still **not implemented**. A separate, earlier changelog entry describes what looks like the same "malformed message" symptom at an earlier version:

> "Fixed a crash loop in agent teams where a malformed teammate mailbox message caused repeated errors every second until the mailbox file was manually deleted." — https://code.claude.com/docs/en/changelog (v2.1.178, June 15, 2026)

The relationship between the v2.1.178 fix and the "Before v2.1.207" docs wording is not fully reconciled by the available sources — it's plausible the v2.1.178 fix addressed a full-crash-loop variant while v2.1.207 refined this into graceful per-entry validation instead of a blocking error state, but this is inference, not a confirmed changelog entry naming v2.1.207 specifically for this fix. Treat "malformed individual mailbox entries are now handled gracefully" as true as of current builds, sourced primarily from the docs page's own wording rather than a single dated changelog bullet.

Source: https://github.com/anthropics/claude-code/issues/25135, https://code.claude.com/docs/en/agent-teams, https://code.claude.com/docs/en/changelog

### Failure Mode 5: Tool Not Exposed Pre-v2.1.77

Unchanged, historical. No new evidence surfaced. See prior passes; not re-verified in depth this cycle since it predates every currently-relevant behavior by over a year of version numbers.

Source: https://github.com/anthropics/claude-code/issues/36196

### Failure Mode 6: Background-Teammate and SDK-Mode Delivery Failures — Both Confirmed Still Unresolved

Re-checked directly on 2026-07-16, both issues unchanged:

**#43706 — Background teammate → lead is one-way (CLI):** still **closed as duplicate**. Title and summary unchanged: `SendMessage({ to: "team-lead" })` from a background teammate reports `{"success": true}` but the message never reaches the lead. No workaround beyond external polling. No fix through v2.1.211.

**#577 — Teammate → lead delivery impossible in SDK mode:** still **OPEN** (anthropics/claude-agent-sdk-python). Root cause unchanged: `receive_response()` ends at the first `ResultMessage`, before there's a "next turn" to deliver an asynchronously-arriving teammate message. No merged fix, no maintainer commitment to a timeline visible in the fetched issue content.

**#50310** (teammate permission requests reach the lead's inbox but the lead has no `SendMessage` response variant to approve them) — not re-fetched this cycle; treat as unchanged from the 2026-07-06 status (open, narrower scope, shows the mailbox write path itself functions even where #43706's broader scenario fails).

Sources: https://github.com/anthropics/claude-code/issues/43706, https://github.com/anthropics/claude-agent-sdk-python/issues/577, https://github.com/anthropics/claude-code/issues/50310

## Anthropic Response and Timeline

As of 2026-07-16 (Claude Code v2.1.211), Anthropic has:

- **Fixed** the narrow stale-name-reuse sub-case of the name-vs-ID mismatch — in **v2.1.199** (corrected from prior passes' incorrect v2.1.162/v2.1.196 attributions). The broader case (name never registered at all) remains **not planned** (#42999).
- **Narrowed the scope** of the `SendMessage`-requires-Agent-Teams claim via documentation — `SendMessage` itself works without the flag as of this pass; only structured team-protocol message types require it. Issue #42737 remains formally closed as duplicate with no comment acknowledging this, but the underlying complaint appears resolved in practice.
- **Shipped background-by-default subagent spawning** in v2.1.199, with a documented `main`-addressing sibling roster following in v2.1.206, and background-agent result-fabrication mitigation in v2.1.210.
- **Left #43706 and #577 unresolved** — background teammate → lead delivery (CLI) and teammate → lead delivery (SDK mode) are both still broken as of v2.1.211, both still closed/open with no comment activity on re-check.
- **Left #25135 (orphaned inbox / no recipient validation) not planned**, though a related mailbox-entry-validation hardening did land (see Failure Mode 4).
- **Hardened prompt-injection defenses for the Agent tool twice** (v2.1.187 and v2.1.211), same changelog wording both times.
- **Still has not documented** anywhere in the official docs how a named agent-teams teammate should address the lead. The `"main"` literal is now documented, but only for the `Agent`-tool subagent/sibling-roster path, not the agent-teams teammate/lead path.

Confirmed `SendMessage`- and subagent-relevant changelog entries since the last pass (newest first, v2.1.202 through v2.1.211; entries below v2.1.202 were already recorded in the prior pass and are reproduced only where corrected or newly load-bearing):

> **v2.1.211 (July 15, 2026)**: Fixed subagents spawned with an explicit model override reverting to the parent's model when resumed or sent a follow-up message. Hardened the Agent tool against indirect prompt injection via content a subagent read.
>
> **v2.1.210 (July 14, 2026)**: Improved background agent result reporting — Claude now reports the status of still-running agents and waits for the real completion instead of fabricating results.
>
> **v2.1.208 (July 14, 2026)**: Fixed the Agent tool launching with no tools when a subagent's `tools` list resolves to nothing — it now returns a clear error naming the unrecognized entries.
>
> **v2.1.206 (July 9, 2026)**: Background agents now upgrade to a new version in the background right after a Claude Code update. (Also the minimum version for the sibling-roster `main`-addressing mechanism, per the `sub-agents` docs page.)
>
> **v2.1.205 (July 8, 2026)**: Fixed background agents staying shown as "failed" or "completed" in the agent list after being resumed with `SendMessage`.
>
> **v2.1.203 (July 7, 2026)**: Fixed `TaskStop` and `TaskOutput` failing to find background agents spawned by another agent — errors now list running agents by id and description.
>
> **v2.1.200 (July 3, 2026)**: Fixed subagents cut off by a rate limit before producing any text output returning an empty result instead of failing cleanly.
>
> **v2.1.199 (July 2, 2026)**: Fixed subagents cut off by a rate limit or server error silently failing instead of returning their partial work to the parent. Fixed subagents reporting API errors (e.g. usage limit reached) as successful results — the error is now reported to the parent agent. Fixed idle subagents vanishing from the agent panel while other subagents were still working. Fixed `SendMessage` silently misrouting when a re-spawned agent reuses a previous agent's name — the tool now detects the mismatch and asks the caller to retarget. **(This is the corrected version for the stale-name-reuse fix — see Failure Mode 3.)**
>
> **v2.1.198 (July 1, 2026)**: Subagents now run in the background by default, so Claude keeps working while they run and is notified when they finish (previously a gradual rollout). Added background agent notifications (`agent_needs_input` / `agent_completed`). Fixed agent teams: a teammate that dies on an API error now reports "failed" to the lead, and messaging a stuck teammate wakes it to retry immediately. Subagents now treat messages from the agent that launched them as normal task direction; an agent's message is still never treated as the user's approval.
>
> **v2.1.196 (June 29, 2026)**: (Multiple `claude agents` panel fixes — subagent types lost on reopen, incorrect status display. **Does not** contain the stale-name-reuse fix; that attribution in prior passes was incorrect.)
>
> **v2.1.193 (June 25, 2026)**: Fixed backgrounding the main turn spawning a phantom "general-purpose (resumed)" subagent that re-ran the main conversation. Improved background agents: the launch result no longer instructs Claude to "end your response" — it keeps working on other tasks while the agent runs.
>
> **v2.1.191 (June 24, 2026)**: Fixed background agents resurrecting after being stopped — stopping an agent from the tasks panel is now permanent.
>
> **v2.1.187 (June 23, 2026)**: Hardened the Agent tool against indirect prompt injection via content a subagent read. (Same wording repeats at v2.1.211.)
>
> **v2.1.186 (June 22, 2026)**: Changed background subagents to surface permission prompts in the main session instead of auto-denying.
>
> **v2.1.178 (June 15, 2026)**: Agent teams: removed the `TeamCreate` and `TeamDelete` tools; every session now has one implicit team, `team_name` accepted but ignored. Fixed a crash loop in agent teams where a malformed teammate mailbox message caused repeated errors every second until the mailbox file was manually deleted. Fixed several subagent issues: messages sent while a subagent finishes its turn are no longer dropped, and backgrounding a running subagent (Ctrl+B) no longer restarts it from scratch.
>
> **v2.1.172 (June 10, 2026)**: Sub-agents can now spawn their own sub-agents (up to 5 levels deep).
>
> **v2.1.161 (June 2, 2026)**: Fixed cross-session messaging (`SendMessage`) silently breaking when `CLAUDE_CODE_TMPDIR` or `$TMPDIR` points at a deep directory.

Source: https://code.claude.com/docs/en/changelog

The earlier-recorded fix remains accurate and unduplicated by the above:

> **v2.1.118 (April 23, 2026)**: Fixed subagents resumed via `SendMessage` not restoring the explicit `cwd` they were spawned with.

No public statement from Anthropic on when (or whether) named-teammate → lead `SendMessage` delivery will be made reliable, or when the `"team-lead"` addressing convention will be formally documented rather than left as an emergent, reverse-engineered convention. In contrast, the parallel `"main"`-for-subagents convention **has** now been formally documented (v2.1.206), which is the single clearest sign of directional intent since these bugs were first tracked: Anthropic appears to be solving addressing on the `Agent`-tool subagent side first, leaving the agent-teams teammate side unaddressed.

## Subagent Resume via Agent ID (Official SDK Pattern)

Unchanged since prior passes — the official Agent SDK docs show that subagent resumption does **not** use `SendMessage` in SDK mode; it uses the `resume` option on `query()` with the captured session ID, plus passing the agent ID in the prompt. This remains the correct, documented, non-`SendMessage` path for SDK-driven subagent continuation, and it is unaffected by any of the corrections above.

Verbatim from https://code.claude.com/docs/en/agent-sdk/subagents:

```typescript
// Helper to extract agentId from message content
function extractAgentId(message: SDKMessage): string | undefined {
  if (!("message" in message)) return undefined;
  const content = JSON.stringify(message.message.content);
  const match = content.match(/agentId:\s*([a-f0-9-]+)/);
  return match?.[1];
}

let agentId: string | undefined;
let sessionId: string | undefined;

// First invocation
for await (const message of query({
  prompt: "Use the Explore agent to find all API endpoints in this codebase",
  options: { allowedTools: ["Read", "Grep", "Glob", "Agent"] }
})) {
  if ("session_id" in message) sessionId = message.session_id;
  const extractedId = extractAgentId(message);
  if (extractedId) agentId = extractedId;
  if ("result" in message) console.log(message.result);
}

// Second invocation — resume the same session and reference the agent ID in the prompt
if (agentId && sessionId) {
  for await (const message of query({
    prompt: `Resume agent ${agentId} and list the top 3 most complex endpoints`,
    options: { allowedTools: ["Read", "Grep", "Glob", "Agent"], resume: sessionId }
  })) {
    if ("result" in message) console.log(message.result);
  }
}
```

**Key note from the docs**: "You must resume the same session to access the subagent's transcript."

## Community Workarounds

### Workaround 1: Use Agent IDs Instead of Names

Still relevant for the residual case in Failure Mode 3 (a name that was never registered at all — #42999, still not planned). For Agent Teams sessions where `SendMessage` name resolution fails, use the raw agent ID in the `to` field instead of the agent's name. Agent IDs are obtainable from the Agent tool result's `agentId:` trailer, or by scanning `subagents/*.meta.json` / `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl` files. A `PreToolUse` hook can intercept `SendMessage` calls and transparently resolve a name-based `to` to the correct ID before the tool executes.

Source: https://github.com/anthropics/claude-code/issues/42999

### Workaround 2: Parent-Relayed Messages

Largely superseded for the general case by the now-documented sibling roster (`main` addressing) and the v2.1.198+ background-default rollout, but still the only option for **agent-teams teammates** given #43706 remains unresolved. Pattern: subagent/teammate includes an "intended-to-send" section in its result text; parent reads and relays via its own `SendMessage`. Fundamentally incompatible with `run_in_background: true` teammates, since the parent has no synchronous checkpoint at which to read the teammate's content before it goes idle.

Source: https://github.com/anthropics/claude-code/issues/48160

### Workaround 3: File-Based Signal Protocol

Still the most reliable workaround for any Agent Teams communication problem. Teams use a shared `channel.md` or JSONL log that agents append to; agents read the file, append entries, then use a side-channel (idle notification or next-turn observation) to discover updates. Use append-only writes, not `Write` (which clobbers), to avoid concurrent-write clobber.

Sources: https://github.com/anthropics/claude-code/issues/30140, https://github.com/anthropics/claude-code/issues/4993

### Workaround 4: Dual-Write Pattern

Write the communication payload to a file **first**, then call `SendMessage` as a best-effort wake-up signal. Still the only pattern with no known silent-failure mode against #43706 (background teammate → lead) and #577 (SDK-mode teammate → lead). This is unaffected by the `"main"`-addressing documentation update, since that update covers a different code path (subagent → parent, not teammate → lead).

Pattern:
1. Write message content to `~/.claude/teams/{team}/shared/{sender}-to-{recipient}-{timestamp}.json`
2. Call `SendMessage(to="team-lead", message="Check shared/{filename} for my update")` as a best-effort nudge
3. Recipient reads the file on wake-up or at next poll; if `SendMessage` was silently lost, the file still exists

### Workaround 5: SDK Session Resume (Non-Agent-Teams Path)

For workflows using the Claude Agent SDK (not interactive CLI agent teams), the `resume` option on `query()` with explicit agent ID passing in the prompt remains the official, supported path for continuing subagent work. Does not use `SendMessage`, does not require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. See "Subagent Resume via Agent ID" above.

## Agent Teams Official Limitations (Verbatim)

Re-fetched in full from https://code.claude.com/docs/en/agent-teams on 2026-07-16 — unchanged from the June 15 (v2.1.178) revision except for minor prose tightening on the background-subagent bullet:

> Agent teams are experimental. Current limitations to be aware of:
>
> - **No session resumption with in-process teammates**: `/resume` and `/rewind` do not restore in-process teammates. After resuming a session, the lead may attempt to message teammates that no longer exist. If this happens, tell the lead to spawn new teammates.
> - **Task status can lag**: teammates sometimes fail to mark tasks as completed, which blocks dependent tasks. If a task appears stuck, check whether the work is actually done and update the task status manually or tell the lead to nudge the teammate.
> - **Shutdown can be slow**: teammates finish their current request or tool call before shutting down, which can take time.
> - **One team per session**: a session has exactly one team, scoped to that session. You can't create additional named teams or share a team across sessions.
> - **No nested teams**: teammates cannot spawn their own teammates. Only the lead can manage the team.
> - **No background subagents from in-process teammates**: an in-process teammate's own subagents run in the foreground. Asking for a background one, whether with `run_in_background` or a subagent definition that sets `background: true`, returns an error, because a teammate's background work can't outlive the lead's process. **Subagents launched from the main conversation follow the background default.** *(Last sentence is new phrasing since the prior pass — makes explicit that the background-by-default rule applies to the lead's own subagents, not to teammate-spawned ones.)*
> - **Lead is fixed**: the main session is the lead for its lifetime. You can't promote a teammate to lead or transfer leadership.
> - **Permissions set at spawn**: all teammates start with the lead's permission mode. You can change individual teammate modes after spawning, but you can't set per-teammate modes at spawn time.
> - **Split panes require tmux or iTerm2**: the default in-process mode works in any terminal. Split-pane mode isn't supported in VS Code's integrated terminal, Windows Terminal, or Ghostty.

The docs still do not list "teammate messages to the lead can be silently dropped" as a known limitation, despite #43706 and #577 both being unresolved as of v2.1.211. This gap between documented limitations and actual GitHub-tracked bugs persists unchanged from every prior pass.

## Best Practices for Reliable Multi-Agent Communication

Given the above, updated for this pass's findings:

1. **Distinguish the two addressing paths.** Use `"main"` when a background `Agent`-tool subagent needs to reach its spawner (documented, v2.1.206+, requires `SendMessage` in tools + at least one named sibling). Use `"team-lead"` when a named agent-teams teammate needs to reach the lead (undocumented, unreliable for background teammates per #43706). Do not cross-wire the two.

2. **Never trust background-teammate → lead `SendMessage` for anything critical.** Issue #43706 shows this fails silently even with the correct recipient literal, unchanged through v2.1.211. Use file-based reporting (Workaround 3/4) for any teammate spawned with `run_in_background: true`.

3. **In SDK-driven agent-teams sessions, don't use `SendMessage` for teammate→lead at all.** Issue #577 shows there's no reliable turn boundary to receive it, still open. Use sleep-and-poll or a secondary store.

4. **Assume subagents run in the background unless you explicitly force foreground.** Since v2.1.198, omitting `run_in_background` defaults to background. If your orchestration logic needs synchronous behavior, set `run_in_background: false` explicitly, or set `background: true`/`false` in the subagent definition as appropriate. Don't rely on the old "omit it and it's synchronous" assumption.

5. **Prefer SDK session resume over `SendMessage` for subagent (not teammate) continuation in SDK mode.** The `resume` + `agentId-in-prompt` pattern is the documented, feature-flag-free path for subagents. It does not apply to Agent Teams teammates.

6. **When using Agent Teams, always use agent IDs (not names) in the `to` field when addressing a teammate whose name-to-ID mapping might not be registered.** The v2.1.199 fix only covers stale-name reuse by a re-spawned agent; a genuinely unregistered name still silently fails per #42999/#25135.

7. **Dual-write critical communication payloads.** Write to a shared file first; use `SendMessage` only as a best-effort wake signal. Poll shared files at each turn start.

8. **Nesting is capped at 5 levels; design accordingly.** A subagent at depth 5 has no `Agent` tool and cannot spawn further, regardless of foreground/background. Depth is fixed at spawn time and doesn't change on resume (v2.1.187) — don't expect a resumed subagent to gain more headroom.

9. **In-process agent-teams teammates cannot background their own subagents — ever.** This is a hard architectural limit, not a bug: "a teammate's background work can't outlive the lead's process." Design teammate-internal delegation as foreground-only.

10. **Test `ToolSearch("select:SendMessage")` at session start if you need to confirm availability**, but note this is now less diagnostic than before the Feature Gate correction — `SendMessage` availability no longer implies Agent Teams is enabled, and its absence is now a narrower signal than it used to be.

11. **For the CLAUDE.md global instruction "Never use tmux to send messages between agents — always use SendMessage"**: this instruction is now on firmer documented ground for `Agent`-tool subagent → main addressing (the `"main"` literal is now first-party documented) but remains only best-effort for named-teammate → lead addressing given #43706 and #577. Supplement teammate-directed sends with the dual-write pattern; subagent-directed sends via the sibling roster can be trusted more than before, within its stated gating conditions (v2.1.206+, `SendMessage` in tools, at least one named sibling present).

## Sources

- [Agent Teams — Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams) — read 2026-07-16
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents) — read 2026-07-16
- [Tools reference](https://code.claude.com/docs/en/tools-reference) — read 2026-07-16
- [Agent SDK Overview](https://code.claude.com/docs/en/agent-sdk/overview) — read 2026-05-01
- [Subagents in the SDK](https://code.claude.com/docs/en/agent-sdk/subagents) — read 2026-07-16
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog) — read 2026-07-16
- [Issue #42999 — SendMessage silently fails when using agent name; only agent ID works](https://github.com/anthropics/claude-code/issues/42999) — read 2026-07-16
- [Issue #42737 — SendMessage gated behind AGENT_TEAMS feature flag](https://github.com/anthropics/claude-code/issues/42737) — read 2026-07-16
- [Issue #47021 — SendMessage referenced in docs but not available at runtime](https://github.com/anthropics/claude-code/issues/47021) — read 2026-05-01
- [Issue #48160 — Subagents cannot originate SendMessage despite AGENT_TEAMS=1](https://github.com/anthropics/claude-code/issues/48160) — read 2026-07-16
- [Issue #25135 — SendMessage silently succeeds when recipient name doesn't match polling target](https://github.com/anthropics/claude-code/issues/25135) — read 2026-07-16
- [Issue #36196 — SendMessage tool not exposed to Claude](https://github.com/anthropics/claude-code/issues/36196) — read 2026-05-01
- [Issue #4993 — Feature Request: Enable Agent-to-Agent Communication](https://github.com/anthropics/claude-code/issues/4993) — read 2026-05-01
- [Issue #30140 — Shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140) — read 2026-05-01
- [Issue #43706 — SendMessage from background teammate to team-lead is silently dropped (one-way only)](https://github.com/anthropics/claude-code/issues/43706) — read 2026-07-16
- [Issue #50310 — Teammate permission requests reach lead's inbox but lead has no SendMessage response variant to approve them](https://github.com/anthropics/claude-code/issues/50310) — read 2026-07-06
- [Issue #61248 — SendMessage for continuing spawned sub-agents is documented but not callable](https://github.com/anthropics/claude-code/issues/61248) — read 2026-07-06
- [claude-agent-sdk-python Issue #577 — Subagent SendMessage not delivered to team lead in SDK mode](https://github.com/anthropics/claude-agent-sdk-python/issues/577) — read 2026-07-16
- [plugin-dev real-world-examples.md — multi-agent-swarm coordinator_session pattern](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-settings/references/real-world-examples.md) — read 2026-07-06
- [Troubleshooting Missing SendMessage Content in Claude Code Agent Teams (community)](https://zenn.dev/rhythmcan/articles/b090f1bfe029e8) — read 2026-07-06
- [Claude Code Agent Teams Best Practices & Troubleshooting (community)](https://claudefa.st/blog/guide/agents/agent-teams-best-practices) — read 2026-07-16
