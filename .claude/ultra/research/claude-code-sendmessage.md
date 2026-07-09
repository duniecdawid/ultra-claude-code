---
topic: Claude Code SendMessage tool — failure modes, workarounds, and inter-agent communication
type: library
subject: claude-code-sendmessage
fetched_at: 2026-07-06
expires: 2026-07-16
sources:
  - https://code.claude.com/docs/en/agent-teams
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

> Last verified: 2026-07-06. Expires: 2026-07-16. Re-invoke `/uc:research Claude Code SendMessage tool reliability` to refresh.

## Addressing the Team Leader / Main Agent

This section directly answers "how does a teammate address the lead" — current as of Claude Code **v2.1.201** (July 3, 2026) and the agent-teams docs revision explicitly dated **"as of v2.1.178"** (June 15, 2026).

### 1. Leader addressability — is there a canonical name?

The **official docs do not document an address for the lead at all.** The agent-teams page describes only teammate-to-teammate addressing:

> "The lead assigns every teammate a name when it spawns them, and any teammate can message any other by that name." — verbatim, https://code.claude.com/docs/en/agent-teams

It never states what a teammate should put in `to` to reach the lead itself. That's a real documentation gap, not an oversight on this research's part.

In practice, the reserved/working literal is the string **`"team-lead"`** — not because Anthropic documents it, but because it's the hardcoded fallback baked into the harness's `InboxPoller`, reverse-engineered from internal code by the reporter of issue #25135:

```javascript
function getPollingTarget(state) {
  if (isTeamLead(state.teamContext)) {
    return state.teamContext.teammates[leadId]?.name || "team-lead";
  }
}
```

Source: https://github.com/anthropics/claude-code/issues/25135 (Claude Code 2.1.39, closed as **not planned**)

This means the lead only gets a *custom* addressable name if something explicitly registers one under `teamContext.teammates[leadId]`; absent that registration — which nothing in the documented API surface performs for you — `"team-lead"` is the fallback inbox file: `~/.claude/teams/{team}/inboxes/team-lead.json`. Two independent community write-ups from 2026 corroborate this as the only literal that reliably resolves, and both explicitly warn against using nicknames or character names instead:

> "Always specify `"team-lead"` as the `recipient`... never substitute actual member identities or nicknames for the reserved `"team-lead"` literal." — https://zenn.dev/rhythmcan/articles/b090f1bfe029e8

> "The proper convention is to use `recipient: "team-lead"`. Arbitrary names (such as team member nicknames) will not work." — https://claudefa.st/blog/guide/agents/agent-teams-best-practices

These are third-party sources, cited here specifically because the official docs are silent on this exact question — treat as community corroboration, not an Anthropic-guaranteed contract.

**Does addressing a name that doesn't match a registered polling target still silently orphan?** Yes, confirmed unresolved. Issue #25135 was **closed as "not planned"** — Anthropic declined to add recipient-existence validation. Re-checked on 2026-07-06: no reopening, no new comments, no changelog entry addressing it since the original May 2026 research pass.

**Does the name-vs-ID mismatch (#42999) still silently false-succeed?** Partially addressed, not fixed. Re-checked 2026-07-06: issue #42999 remains **closed as "not planned"** (filed against Claude Code 2.1.92), with no new activity. However, changelog **v2.1.196 (June 29, 2026)** shipped a narrower, related fix:

> "Fixed `SendMessage` silently misrouting when a re-spawned agent reuses a previous agent's name — the tool now detects the mismatch and asks the caller to retarget." — https://code.claude.com/docs/en/changelog

This closes only the "a new agent reused a stale name" sub-case. It does **not** address the original bug's broader claim — that any name-based `to` value can silently report success against a recipient whose polling target doesn't match, including `"team-lead"` when no lead name was ever registered (exactly the leader-addressing scenario in this question).

### 2. Directionality — can teammates originate SendMessage to the leader?

**Confirmed still broken for the leader-addressing case, specifically for background teammates, with no fix landed as of July 2026.**

Issue #48160 ("Spawned subagents cannot originate SendMessage despite CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 and explicit name= parameter," Claude Code + Opus 4.6, **closed as duplicate**, re-checked 2026-07-06 — no change) originally reported total asymmetry: subagents had no `SendMessage` in their toolset at all (`ToolSearch("select:SendMessage")` → no match), so they could not originate messages in either direction, though they could receive.

A newer, more specific issue narrows this to the exact spawn topology this research asked about — `Agent()` called with a `name` and `run_in_background: true`:

> **Issue #43706** ("SendMessage from background teammate to team-lead is silently dropped (one-way only)," filed April 5, 2026, **closed as duplicate**): team-lead → teammate delivery works; teammate → team-lead delivery via `SendMessage({ to: "team-lead" })` returns `{"success": true}` on the sender's side, but the message never reaches the lead's conversation — no error, no notification. The reporter used exactly the correct literal (`"team-lead"`), ruling out a naming mistake. This is a structural delivery failure specific to the background-spawn path, not a resolvable name-typo.
>
> Source: https://github.com/anthropics/claude-code/issues/43706

So: **the tool is present in-session for teammates today** (unlike the original total lockout #48160 first reported), **but delivery from a background teammate to the lead remains unreliable-to-broken.** Both #48160 and #43706 are closed as duplicates, meaning Anthropic tracks the class of bug internally but has not shipped a public fix through Claude Code v2.1.201 (July 3, 2026) — none of the July changelog entries (2.1.196, 2.1.199, 2.1.200, 2.1.201) mention teammate→lead delivery specifically.

The same asymmetry also affects the Claude Agent SDK path, via a different mechanism:

> **Issue #577** (anthropics/claude-agent-sdk-python, filed Feb 15, 2026, **still OPEN** as of 2026-07-06, Claude Code 2.1.42 / SDK 0.1.36 at filing): in SDK mode there is no "next turn" for the lead to receive a teammate's message before `receive_response()` yields a `ResultMessage` and the session terminates — so teammate-originated messages are lost even when the `SendMessage` call itself succeeds. Anthropic's own suggested workarounds in that thread are non-`SendMessage` fallbacks: sleep-and-poll a file, or write to a secondary store and have the lead poll it in a loop.
>
> Source: https://github.com/anthropics/claude-agent-sdk-python/issues/577

Net: **directionality is nominally symmetric today** (the tool exists for teammates, contrasted with the earlier full lockout in #48160), **but delivery to the lead specifically is unreliable** for background teammates in the CLI and broken outright for all teammates in SDK-driven sessions. Treat any teammate→lead `SendMessage` as best-effort, never as guaranteed delivery.

### 3. Reliable leader-addressing pattern — what actually works today?

Evaluating the four candidate patterns against the mid-2026 evidence:

- **(a) Leader injects its own name/ID into each spawn prompt.** Not documented, not necessary, and not how the CLI path works — see (c). There is no documented API for a lead session to query its own agent ID or team-role name; the docs describe only how the lead assigns names to *teammates*, never how the lead learns or exposes its own identity. If you wanted a *custom* lead name registered at `teamContext.teammates[leadId].name`, nothing in the public tool surface performs that registration for you. **Not the supported path.**
- **(b) A fixed reserved name for the lead.** This is what exists in practice: **`"team-lead"`** is the hardcoded fallback literal in the harness's inbox-polling logic (see question 1). It's the closest thing to a "supported" answer, but it's an emergent convention reverse-engineered from source, not a documented contract — and delivery through it is confirmed unreliable for background teammates (#43706) and broken in SDK sessions (#577).
- **(c) The harness auto-registers the spawner so a child can always reach its parent.** Partially true, and is the actual addressing mechanism: the lead doesn't need to inject anything into spawn prompts — every team automatically gets a lead entry reachable at `"team-lead"` with zero prompt engineering. This matches the docs' architecture description: "Team config: `~/.claude/teams/{team-name}/config.json`... The team config contains a `members` array with each teammate's name, agent ID, and agent type. Teammates can read this file to discover other team members." (source: https://code.claude.com/docs/en/agent-teams), auto-created "when the first teammate is spawned." So *discovery/addressing* is auto-registered; it's *delivery* that's unreliable, not the addressing mechanism itself.
- **(d) File-based back-channel because direct child→parent messaging is unreliable.** **This is the pattern actually recommended in practice today**, including by Anthropic's own SDK-repo maintainers in the #577 thread ("teammate writes output to secondary store... lead polls store in a loop") and by every community troubleshooting guide surveyed for this research. Given #43706 and #577 are both open/unresolved as of July 2026, this is the only pattern with no known silent-failure mode: write the payload to a shared file first, use `SendMessage(to="team-lead", ...)` only as a best-effort wake signal, and have the lead poll the file if no message arrives within a reasonable number of turns. See "Workaround 4: Dual-Write Pattern" below — that guidance stands unchanged and is now doubly corroborated by #43706 and #577.

**Bottom line:** address the lead as `"team-lead"` (options b/c — it's auto-registered, not something you inject), but do not trust it as the sole delivery path for anything you can't afford to lose. Pair it with the file-based dual-write pattern (option d) for any background teammate, and always for SDK-driven sessions.

As an aside, one Anthropic-authored plugin example sidesteps native `SendMessage` addressing entirely: the `multi-agent-swarm` plugin's real-world example uses a `coordinator_session: team-leader` field and raw `tmux send-keys` to notify a coordinator session directly, rather than the mailbox system described here. This is a different mechanism (tmux session targeting, not `SendMessage`/mailbox), included here only because it shows plugin authors independently converging on a `"leader"`-style literal name for the coordinating session — further circumstantial evidence that "the lead has a fixed, well-known slot" is the mental model Anthropic's own examples reach for, even where the native tool doesn't formalize it. Source: https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-settings/references/real-world-examples.md

### Confidence level

Agent teams remain an **experimental feature gated by `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`**, and the leader-addressing mechanics above are **not stated in the official docs page**. The docs page itself has matured substantially since the original May 2026 research pass — it now documents architecture, task claiming, permission-request bubbling to the lead, and a team-config `members` array (as of v2.1.178) — but it still carries the same class of caveat it always has:

> "Agent teams are experimental and disabled by default... Agent teams have [known limitations](#limitations) around session resumption, task coordination, and shutdown behavior." — https://code.claude.com/docs/en/agent-teams

Everything about the `"team-lead"` literal, the auto-registration mechanism, and the delivery failure modes in this section is reconstructed from GitHub issue reports, one leaked internal code fragment (#25135), and third-party community troubleshooting content — not from an Anthropic API reference. Treat it as "best evidence available," not "Anthropic-guaranteed behavior," and re-verify against the docs page and issue tracker on the next refresh.

## Official Documentation Status

The `SendMessage` tool is documented exclusively in the **Agent Teams** section of the Claude Code docs, which has grown substantially since the last research pass. It is still **not** documented in the standard subagents or Claude Agent SDK pages.

Source: https://code.claude.com/docs/en/agent-teams

Updated verbatim excerpts (page now explicitly versioned "as of v2.1.178", June 15, 2026):

> "This page describes agent teams as of v2.1.178. With `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` set, spawning a teammate no longer needs a setup step, and cleanup happens automatically when the session exits. Before v2.1.178, you asked Claude to create and name a team first, and Claude used the `TeamCreate` and `TeamDelete` tools to set it up and remove it. Both tools no longer exist."

> "Unlike [subagents](/en/sub-agents), which run within a single session and can only report back to the main agent, you can also interact with individual teammates directly without going through the lead."

> "**Automatic message delivery**: when teammates send messages, they're delivered automatically to recipients. The lead doesn't need to poll for updates."

> "**Idle notifications**: when a teammate finishes and stops, it automatically notifies the lead. As of v2.1.198, a teammate whose turn ends on an API error notifies the lead that it failed and includes the error text, instead of appearing to finish normally."

> "**Teammate messaging**: send a message to one specific teammate by name. To reach everyone, send one message per recipient."

The mailbox system is described as:

> "**Mailbox** — Messaging system for communication between agents"

Team/task files are stored at (unchanged, now confirmed non-experimental storage layout for v2.1.178+):

- **Team config**: `~/.claude/teams/{team-name}/config.json`
- **Task list**: `~/.claude/tasks/{team-name}/`
- **Inbox files**: `~/.claude/teams/{team-name}/inboxes/{agent-name}.json` (confirmed by issue #25135's code trace and corroborated by issue #50310's inbox path: `~/.claude/teams/{team}/inboxes/team-lead.json`)

New in this revision — the team config's `members` array:

> "The team config contains a `members` array with each teammate's name, agent ID, and agent type. Teammates can read this file to discover other team members."
>
> "There is no project-level equivalent of the team config. A file like `.claude/teams/teams.json` in your project directory is not recognized as configuration; Claude treats it as an ordinary file."

New security hardening (v2.1.178, corroborated by changelog):

> "When one agent sends another a message over `SendMessage`, the receiving agent is told it came from another Claude session, not from you. A teammate cannot approve a permission prompt or supply consent on your behalf, and a teammate that was denied an action cannot relay it to another teammate to bypass the check. In [auto mode](/en/permission-modes#eliminate-prompts-with-auto-mode), the classifier treats an approval claim relayed from another agent as untrusted input rather than confirmation from you. Teammate permission prompts bubble up to the lead session, so approve them there yourself."

The Agent SDK subagents documentation still makes **no mention** of `SendMessage`. Subagent-to-parent communication in SDK mode is documented as strictly one-directional: the subagent's final message returns to the parent as the Agent tool result, nothing more.

Source: https://code.claude.com/docs/en/agent-sdk/subagents

> "The parent receives the subagent's final message verbatim as the Agent tool result, but may summarize it in its own response."

The subagents doc also explicitly states:

> "Subagents cannot spawn their own subagents. Don't include `Agent` in a subagent's `tools` array."

**Correction to a prior claim in this file:** the original May 2026 pass stated the Agent tool's result text instructs users to `"use SendMessage with to: '' to continue this agent"` (empty string). Fresh evidence from issue #61248 (filed against `claude-opus-4-7`, closed as duplicate) shows the actual trailer substitutes the real agent ID, not an empty string:

> `agentId: af9219c00828602bd (use SendMessage with to: 'af9219c00828602bd' to continue this agent)`

Treat the "empty string" detail from the prior pass as unconfirmed/likely inaccurate; the ID-substitution form above is the version corroborated by direct reproduction in #61248.

**Critical distinction, still valid:** `SendMessage` is an **Agent Teams** primitive only. The Agent SDK and standard subagent system have no `SendMessage` equivalent for the general public API.

## Feature Gate: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

`SendMessage` is still gated behind the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable. The docs warning text has been updated with more operational detail:

> "Agent teams are experimental and disabled by default. Enable them by adding `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your [settings.json](/en/settings) or environment. **Without that variable, no team is set up at session start, no team directories are written, and Claude does not spawn or propose teammates.** Agent teams have [known limitations](#limitations) around session resumption, task coordination, and shutdown behavior." — https://code.claude.com/docs/en/agent-teams (bold = new wording vs. May 2026 pass)

Enabling via `settings.json` (unchanged):

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Issue #42737** (filed April 2, 2026, Claude Code 2.1.104, closed as duplicate) — status unchanged on re-check 2026-07-06:

> "The `SendMessage` tool, which is required to resume/continue conversations with previously spawned subagents, is gated behind the 'agent teams' feature. This prevents basic agent communication for users without access to this feature."

No public statement separating `SendMessage` availability from the Agent Teams flag has appeared in the two months since the last research pass.

Source: https://github.com/anthropics/claude-code/issues/42737

## Known Failure Modes

### Failure Mode 1: Tool Not Available (No Feature Flag)

Unchanged. Without `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `SendMessage` does not appear in Claude's toolset at all. The current docs now state this explicitly rather than leaving it implicit: "Without that variable, no team is set up at session start, no team directories are written, and Claude does not spawn or propose teammates." (source: https://code.claude.com/docs/en/agent-teams)

From issue #47021 (Claude Code 2.1.104, closed as duplicate, no change on re-check):

> `SendMessage` tool is **not available** at runtime (neither as direct nor deferred tool)
>
> `ToolSearch` query `select:SendMessage` returns: `"No matching deferred tools found"`

Source: https://github.com/anthropics/claude-code/issues/47021

### Failure Mode 2: Tool Not Available in Subagents (Asymmetric Access)

**Status update (2026-07-06):** Issue #48160 remains **closed as duplicate**, no new activity. A more specific follow-on, issue **#43706**, confirms the asymmetry persists in the exact "named + `run_in_background: true`" topology as of April 2026, with no fix through Claude Code v2.1.201 (July 2026). See the new dedicated "Addressing the Team Leader / Main Agent" section above for full detail, and issue **#577** for the SDK-mode variant of the same directional problem (still open).

Original finding, unchanged: from issue #48160 (Claude Code Opus 4.6, closed as duplicate):

> **Asymmetric messaging:**
> - **Parent agent**: Successfully calls `SendMessage(to="indexes", ...)` → `{"success":true,"message":"Message queued for delivery to indexes at its next tool round."}`
> - **Subagents**: Cannot originate `SendMessage`
>
> **Subagent reports:**
> - `query`: "SendMessage tool not available in this environment (verified via ToolSearch — no match)"
>
> `ToolSearch("select:SendMessage")` in subagents returns **no match**.
>
> Subagents *can* **receive** messages (parent messages resume them with content in context), but cannot **send** them.

Workaround reported in issue #48160: parent manually relays all subagent-intended messages via its own `SendMessage` calls. This defeats parallel design and adds orchestration burden.

Source: https://github.com/anthropics/claude-code/issues/48160

### Failure Mode 3: Name vs ID Mismatch — Silent False Success

**Status update (2026-07-06):** Issue #42999 remains **OPEN → re-checked and now shows closed as "not planned"** (status changed since the original May 2026 note, which had recorded it as OPEN; it is now resolved-by-non-fix rather than still pending triage). Changelog **v2.1.196 (June 29, 2026)** shipped a narrower related fix — "Fixed `SendMessage` silently misrouting when a re-spawned agent reuses a previous agent's name — the tool now detects the mismatch and asks the caller to retarget" — but this covers only the "stale name reused by a new agent" sub-case, not the general name-resolution bug described below. Treat the core bug as still live for any name that was never registered as a name→ID mapping at all (see the leader-addressing section above for why this matters for `"team-lead"` specifically).

The tool's own documentation/schema says to use agent **names**, but only agent **IDs** work reliably for completed/resumed agents.

From issue #42999 (Claude Code 2.1.92):

> The schema and documentation state:
> > **`to`**: Recipient: teammate name. Refer to teammates by name, never by UUID.
>
> However, when calling `SendMessage(to="my-reviewer")`, the tool returns:
> ```json
> {"success":true,"message":"Message sent to my-reviewer's inbox"}
> ```
> ...but the agent never actually receives it.
>
> Using the agent ID instead works:
> ```json
> {"success":true,"message":"Agent \"a83ccf8943ca82483\" had no active task; resumed from transcript..."}
> ```

Real session evidence from issue #42999:

> **Session 1 (1251203f-04ed-4f5a-ab34-4ed08091b0ca):**
> - 13:24:39: `SendMessage(to="tech-lead-po13526")` → `"success":true` — **silent failure**
> - 14:12:46: `SendMessage(to="a83ccf8943ca82483")` → **actually worked**
>
> **Session 2 (c7fe2749-d39c-4db8-882a-95910ca4af7d):**
> - 19:24:10: `SendMessage(to="tech-lead-po13509")` → `"success":true` — **silent failure**
> - 19:24:42: Spawned redundant new Agent (because SendMessage appeared to fail)
> - 19:27:23: `SendMessage(to="ac7b27b139eb5759a")` → **worked**

Source: https://github.com/anthropics/claude-code/issues/42999

### Failure Mode 4: Orphaned Inbox Files

**Status update (2026-07-06):** Still **closed as not planned**, no reopening, no changelog fix. This is directly relevant to leader addressing: the code trace below is the source of the `"team-lead"` fallback literal documented in the new section above, and is now corroborated by two independent community troubleshooting guides published after the original May 2026 research pass (https://zenn.dev/rhythmcan/articles/b090f1bfe029e8, https://claudefa.st/blog/guide/agents/agent-teams-best-practices), both converging on the same "always use `team-lead`, never a nickname" recommendation.

When the `recipient` value in `SendMessage` does not match any registered team member's polling name, the message is written to a new inbox file that no agent polls — silently disappearing.

From issue #25135 (Claude Code 2.1.39, closed as **not planned**):

Root cause trace (verbatim internal code analysis from reporter):

```javascript
// validateInput — no recipient existence check
async validateInput(input) {
  if ("recipient" in input && typeof input.recipient === "string"
      && input.recipient.trim().length === 0)
    return { result: false, message: "recipient must not be empty" };
  return { result: true };  // Any non-empty string passes
}

// getInboxPath — uses recipient as-is for file path
function getInboxPath(agent, team) {
  let sanitizedAgent = sanitize(agent);  // "alice" → alice
  return join(dir, `${sanitizedAgent}.json`);  // → alice.json
}

// writeToMailbox — creates new inbox file without validation
function writeToMailbox(recipient, message, team) {
  let path = getInboxPath(recipient, team);
  if (!fileExists(path))
    writeFileSync(path, "[]", "utf-8");  // Creates orphaned inbox
  // ... writes message to file
}

// InboxPoller — reads from a different path
function getPollingTarget(state) {
  if (isTeamLead(state.teamContext)) {
    return state.teamContext.teammates[leadId]?.name || "team-lead";
  }
}
// Disconnect: team lead polls "team-lead.json" while message was written to "alice.json"
```

The fix proposed (but not merged): validate `recipient` against the actual team member list and return an error with available names if no match.

Closed as **not planned** — Anthropic will not fix this.

Source: https://github.com/anthropics/claude-code/issues/25135

### Failure Mode 5: Tool Not Exposed Pre-v2.1.77

Unchanged, historical. Issue #36196 (Claude Code 2.1.79), closed:

> Claude states: "I don't see a to field or SendMessage function exposed in any of my available tools."
>
> Version 2.1.77 removed the `resume` parameter from the Agent tool, breaking the ability to resume agents. Without `SendMessage` exposed, there is no alternative way to resume agents.

This was the original regression that triggered multiple downstream issues.

Source: https://github.com/anthropics/claude-code/issues/36196

### Failure Mode 6: Background-Teammate and SDK-Mode Delivery Failures (new since May 2026)

Two new failure modes surfaced since the last research pass, both bearing directly on teammate→lead addressing:

**#43706 — Background teammate → lead is one-way (CLI):** filed April 5, 2026, closed as duplicate. A teammate spawned via `Agent({ name, team_name, run_in_background: true })` can receive messages from the lead but its own `SendMessage(to="team-lead", ...)` calls report success while never reaching the lead. No workaround exists other than external polling (e.g., watching git commits) — see the issue's own conclusion: "Workaround: None available. Team lead must poll git repos/external trackers for teammate progress instead of relying on team messaging."

**#577 — Teammate → lead delivery impossible in SDK mode:** anthropics/claude-agent-sdk-python, filed Feb 15, 2026, **still OPEN**. In SDK-driven sessions, the lead's `receive_response()` loop ends at the first `ResultMessage`, before a teammate's asynchronously-arriving `SendMessage` can ever be delivered — there is no "next turn" to receive it in. Anthropic's own suggested workarounds are non-`SendMessage`: sleep-and-poll a file, or a secondary store polled in a loop.

Related but narrower: **#50310** ("teammate permission requests reach lead's inbox but lead has no SendMessage response variant to approve them," opened April 18, 2026) shows the inbox delivery mechanism itself (teammate → lead, for permission requests specifically) does work in the affected environment — the request reaches `~/.claude/teams/{team}/inboxes/team-lead.json` — but the lead's own `SendMessage` schema lacks a `permission_response` message-type variant to reply with, so plain-text replies are delivered but ineffective. This confirms the inbox-write path can succeed even when #43706's scenario fails, suggesting the bug in #43706 is specific to the background-spawn + result-message delivery path, not the mailbox file-write mechanism in general.

Sources: https://github.com/anthropics/claude-code/issues/43706, https://github.com/anthropics/claude-agent-sdk-python/issues/577, https://github.com/anthropics/claude-code/issues/50310

## Anthropic Response and Timeline

As of 2026-07-06 (Claude Code v2.1.201), Anthropic has:

- **Not fixed** the general name-vs-ID mismatch (issue #42999) — closed as "not planned"; only the narrower "re-spawned agent reuses a stale name" sub-case was fixed, in v2.1.196 (June 29, 2026)
- **Closed as duplicate** the feature-flag gating issue (#42737) — no change, no public timeline
- **Closed as duplicate** the subagent asymmetric access issue (#48160) — and its more specific successor **#43706** (background teammate → lead one-way delivery), also closed as duplicate, also unfixed
- **Left open** the SDK-mode teammate→lead delivery gap (**#577**) — no fix as of 2026-07-06
- **Closed as not planned** the orphaned inbox validation (#25135) — the root cause of the undocumented `"team-lead"` fallback convention
- **Not documented**, anywhere in the official docs, how a teammate should address the lead

Confirmed `SendMessage`-related changelog entries since the last pass (newest first):

> **v2.1.199 (July 2, 2026)**: Fixed subagents cut off by a rate limit or server error silently failing instead of returning their partial work to the parent.
>
> **v2.1.196 (June 29, 2026)**: Fixed `SendMessage` silently misrouting when a re-spawned agent reuses a previous agent's name — the tool now detects the mismatch and asks the caller to retarget.
>
> **v2.1.186 (June 22, 2026)**: Changed background subagents to surface permission prompts in the main session instead of auto-denying; the dialog shows which agent is asking, and Esc denies just that tool.
>
> **v2.1.178 (June 15, 2026)**: Hardened cross-session messaging: messages relayed via `SendMessage` from other Claude sessions no longer carry user authority — receivers refuse relayed permission requests, and auto mode blocks them. (Same release that rewrote the agent-teams docs page and removed `TeamCreate`/`TeamDelete`.)
>
> **v2.1.161 (June 2, 2026)**: Fixed cross-session messaging (`SendMessage`) silently breaking when `CLAUDE_CODE_TMPDIR` or `$TMPDIR` points at a deep directory.

Source: https://code.claude.com/docs/en/changelog

The earlier-recorded fix remains accurate and unduplicated by the above:

> **v2.1.118 (April 23, 2026)**: Fixed subagents resumed via `SendMessage` not restoring the explicit `cwd` they were spawned with.

No public statement from Anthropic on when (or whether) teammate→lead `SendMessage` delivery will be made reliable, or when the leader-addressing convention (`"team-lead"`) will be formally documented rather than left as an emergent, reverse-engineered convention.

## Subagent Resume via Agent ID (Official SDK Pattern)

Unchanged since May 2026 — the official Agent SDK docs show that subagent resumption does **not** use `SendMessage` in SDK mode; it uses the `resume` option on `query()` with the captured session ID, plus passing the agent ID in the prompt.

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

Python equivalent:

```python
import re, json
from claude_agent_sdk import query, ClaudeAgentOptions

def extract_agent_id(text: str) -> str | None:
    match = re.search(r"agentId:\s*([a-f0-9-]+)", text)
    return match.group(1) if match else None

agent_id = None
session_id = None

async for message in query(
    prompt="Use the Explore agent to find all API endpoints",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Grep", "Glob", "Agent"]),
):
    if hasattr(message, "session_id"):
        session_id = message.session_id
    if hasattr(message, "content"):
        content_str = json.dumps(message.content, default=str)
        extracted = extract_agent_id(content_str)
        if extracted:
            agent_id = extracted

if agent_id and session_id:
    async for message in query(
        prompt=f"Resume agent {agent_id} and list the top 3 most complex endpoints",
        options=ClaudeAgentOptions(
            allowed_tools=["Read", "Glob", "Grep"], resume=session_id
        ),
    ):
        if hasattr(message, "result"):
            print(message.result)
```

**Key note from the docs**: "You must resume the same session to access the subagent's transcript."

Source: https://code.claude.com/docs/en/agent-sdk/subagents

## Community Workarounds

### Workaround 1: Use Agent IDs Instead of Names

For Agent Teams sessions where `SendMessage` is available but name resolution fails, use the raw agent ID in the `to` field instead of the agent's name.

Agent IDs can be obtained from:
- The Agent tool result (contains `agentId: <hex-string>`)
- Scanning `subagents/*.meta.json` files in the session directory

From issue #42999 (reporter-implemented workaround):

> A `PreToolUse` hook intercepts `SendMessage` calls, detects when `to` is a name (not an agent ID), resolves it by scanning `subagents/*.meta.json`, and returns `updatedInput` with the resolved agent ID.

This hook fires before the tool executes, transparently replacing the name-based `to` field with the correct ID.

Source: https://github.com/anthropics/claude-code/issues/42999

### Workaround 2: Parent-Relayed Messages

Since subagents cannot reliably deliver `SendMessage` to the lead (see Failure Modes 2 and 6), the parent agent manually relays messages on behalf of subagents.

Pattern:
1. Subagent includes an "intended-to-send" section in its result text
2. Parent agent reads the result and calls `SendMessage` on behalf of the subagent
3. Parent acts as a message router for all peer-to-peer communication

Limitation: eliminates parallelism benefit; forces sequential parent involvement in every subagent-originated communication. This is fundamentally incompatible with `run_in_background: true` teammates, since the parent has no synchronous checkpoint at which to read the subagent's "intended-to-send" content before the subagent goes idle.

Source: https://github.com/anthropics/claude-code/issues/48160

### Workaround 3: File-Based Signal Protocol

The most reliable workaround for any Agent Teams communication problem — and the only option without the feature flag — is a file-based protocol.

From the community (issue #30140 and issue #4993):

> Teams use a shared `channel.md` file (or JSONL log) that agents append to. Agents read the file, append entries, then use a side-channel (idle notification or next-turn observation) to discover updates.

Implementation notes from the community:

- Use append-only JSONL, not overwrite, to avoid concurrent-write clobber
- Use `Edit` tool's string-match append rather than `Write` (Write clobbers the file)
- Include a per-agent "lock" file pattern: write `current_tasks/{task-name}.txt` to signal task ownership
- Poll the shared file at the start of each turn instead of relying on push delivery

From official agent-teams docs (verbatim, unchanged):

> "Task claiming uses file locking to prevent race conditions when multiple teammates try to claim the same task simultaneously."

Limitation from issue #30140: the Edit tool's string-matching append can still clobber under concurrent writes; no concurrent-write safety guarantee.

Sources: https://github.com/anthropics/claude-code/issues/30140, https://github.com/anthropics/claude-code/issues/4993

### Workaround 4: Dual-Write Pattern

Write the communication payload to a file **first**, then call `SendMessage` as a best-effort wake-up signal. As of this refresh (2026-07-06), this pattern is doubly corroborated: it's the exact fix Anthropic's own SDK maintainers proposed in issue #577's thread, and it's the only pattern with no known silent-failure mode against #43706.

Pattern:
1. Write message content to `~/.claude/teams/{team}/shared/{sender}-to-{recipient}-{timestamp}.json`
2. Call `SendMessage(to="team-lead", message="Check shared/{filename} for my update")` as a best-effort nudge
3. Recipient reads the file on wake-up or at next poll; if `SendMessage` was silently lost (as in #43706), the file still exists for the next poll

This ensures no content is lost even if `SendMessage` silently fails delivery.

### Workaround 5: SDK Session Resume (Non-Agent-Teams Path)

For workflows using the Claude Agent SDK (not interactive CLI agent teams), the `resume` option on `query()` with explicit agent ID passing in the prompt is the official, supported path for continuing subagent work. See the code examples in the "Subagent Resume via Agent ID" section above.

This path does **not** use `SendMessage` and does **not** require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. For SDK users who do need Agent Teams' peer-to-peer model, see Failure Mode 6 / issue #577 above — this resume pattern doesn't help there, since it addresses subagents, not teammates.

Source: https://code.claude.com/docs/en/agent-sdk/subagents

## Agent Teams Official Limitations (Verbatim)

Updated from https://code.claude.com/docs/en/agent-teams (v2.1.178 revision — several bullets reworded or added since May 2026):

> Agent teams are experimental. Current limitations to be aware of:
>
> - **No session resumption with in-process teammates**: `/resume` and `/rewind` do not restore in-process teammates. After resuming a session, the lead may attempt to message teammates that no longer exist. If this happens, tell the lead to spawn new teammates.
> - **Task status can lag**: teammates sometimes fail to mark tasks as completed, which blocks dependent tasks. If a task appears stuck, check whether the work is actually done and update the task status manually or tell the lead to nudge the teammate.
> - **Shutdown can be slow**: teammates finish their current request or tool call before shutting down, which can take time.
> - **One team per session**: a session has exactly one team, scoped to that session. You can't create additional named teams or share a team across sessions. *(Reworded from the prior "Clean up the current team before starting a new one" — teams are no longer manually created/deleted since `TeamCreate`/`TeamDelete` were removed.)*
> - **No nested teams**: teammates cannot spawn their own teammates. Only the lead can manage the team.
> - **No background subagents from in-process teammates**: an in-process teammate's own subagents run in the foreground. Asking for a background one, whether with `run_in_background` or a subagent definition that sets `background: true`, returns an error, because a teammate's background work can't outlive the lead's process. *(New bullet since May 2026 — directly relevant: teammates themselves CAN be spawned with `run_in_background: true` by the lead, per issue #43706's repro, but a teammate cannot in turn spawn its own background subagents.)*
> - **Lead is fixed**: the main session is the lead for its lifetime. You can't promote a teammate to lead or transfer leadership.
> - **Permissions set at spawn**: all teammates start with the lead's permission mode. You can change individual teammate modes after spawning, but you can't set per-teammate modes at spawn time.
> - **Split panes require tmux or iTerm2**: the default in-process mode works in any terminal. Split-pane mode isn't supported in VS Code's integrated terminal, Windows Terminal, or Ghostty.

Note the docs still do not list "teammate messages to the lead can be silently dropped" as a known limitation — despite #43706 and #577 both being unresolved as of this writing. This gap between documented limitations and actual GitHub-tracked bugs is itself worth flagging to any executor relying on this feature.

## Best Practices for Reliable Multi-Agent Communication

Given the above failure modes:

1. **Address the lead as `"team-lead"`, but never rely on it alone.** It's the auto-registered, harness-fallback literal (see "Addressing the Team Leader" above) — not documented, but the only literal confirmed to work when delivery succeeds at all. Pair every use with Workaround 4 (dual-write).

2. **Never trust background-teammate → lead `SendMessage` for anything critical.** Issue #43706 shows this fails silently even with the correct recipient literal. Use file-based reporting (Workaround 3/4) for any teammate spawned with `run_in_background: true`.

3. **In SDK-driven sessions, don't use `SendMessage` for teammate→lead at all.** Issue #577 shows there's no reliable turn boundary to receive it. Use sleep-and-poll or a secondary store as Anthropic's own maintainers recommend in that thread.

4. **Prefer SDK session resume over SendMessage for subagent (not teammate) continuation.** The `resume` + `agentId-in-prompt` pattern is the documented, feature-flag-free path for subagents. It does not apply to Agent Teams teammates.

5. **When using Agent Teams, always use agent IDs (not names) in the `to` field when addressing a teammate.** The schema says use names; the implementation requires IDs for reliable delivery to non-lead recipients. Extract the agent ID from the Agent tool result or `subagents/*.meta.json` at spawn time and store it.

6. **Implement a `PreToolUse` hook to intercept `SendMessage` and resolve names to IDs.** This makes the workaround transparent to the orchestrating agent's prompts.

7. **Dual-write critical communication payloads.** Write to a shared file first; use `SendMessage` only as a best-effort wake signal. Poll shared files at each turn start.

8. **Do not rely on subagents or background teammates originating `SendMessage` reliably.** Design all communication as parent-to-child, or use the file-based protocol for peer/teammate-to-lead coordination.

9. **Test `ToolSearch("select:SendMessage")` at session start.** If it returns no results, the feature flag is not active or the tool is unavailable in this environment. Fall back to file-based protocols immediately rather than discovering the failure at first use.

10. **For the CLAUDE.md global instruction "Never use tmux to send messages between agents — always use SendMessage"**: this instruction is valid when Agent Teams is enabled, agent IDs are known for teammate-directed messages, and `"team-lead"` is used for lead-directed messages — but it should be supplemented with the ID-resolution workaround and dual-write pattern given the unresolved delivery bugs (#42999, #43706, #577) documented here.

## Sources

- [Agent Teams — Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams) — read 2026-07-06
- [Agent SDK Overview](https://code.claude.com/docs/en/agent-sdk/overview) — read 2026-05-01
- [Subagents in the SDK](https://code.claude.com/docs/en/agent-sdk/subagents) — read 2026-05-01
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog) — read 2026-07-06
- [Issue #42999 — SendMessage silently fails when using agent name; only agent ID works](https://github.com/anthropics/claude-code/issues/42999) — read 2026-07-06
- [Issue #42737 — SendMessage gated behind AGENT_TEAMS feature flag](https://github.com/anthropics/claude-code/issues/42737) — read 2026-05-01
- [Issue #47021 — SendMessage referenced in docs but not available at runtime](https://github.com/anthropics/claude-code/issues/47021) — read 2026-05-01
- [Issue #48160 — Subagents cannot originate SendMessage despite AGENT_TEAMS=1](https://github.com/anthropics/claude-code/issues/48160) — read 2026-07-06
- [Issue #25135 — SendMessage silently succeeds when recipient name doesn't match polling target](https://github.com/anthropics/claude-code/issues/25135) — read 2026-07-06
- [Issue #36196 — SendMessage tool not exposed to Claude](https://github.com/anthropics/claude-code/issues/36196) — read 2026-05-01
- [Issue #4993 — Feature Request: Enable Agent-to-Agent Communication](https://github.com/anthropics/claude-code/issues/4993) — read 2026-05-01
- [Issue #30140 — Shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140) — read 2026-05-01
- [Issue #43706 — SendMessage from background teammate to team-lead is silently dropped (one-way only)](https://github.com/anthropics/claude-code/issues/43706) — read 2026-07-06
- [Issue #50310 — Teammate permission requests reach lead's inbox but lead has no SendMessage response variant to approve them](https://github.com/anthropics/claude-code/issues/50310) — read 2026-07-06
- [Issue #61248 — SendMessage for continuing spawned sub-agents is documented but not callable](https://github.com/anthropics/claude-code/issues/61248) — read 2026-07-06
- [claude-agent-sdk-python Issue #577 — Subagent SendMessage not delivered to team lead in SDK mode](https://github.com/anthropics/claude-agent-sdk-python/issues/577) — read 2026-07-06
- [plugin-dev real-world-examples.md — multi-agent-swarm coordinator_session pattern](https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/plugin-settings/references/real-world-examples.md) — read 2026-07-06
- [Troubleshooting Missing SendMessage Content in Claude Code Agent Teams (community)](https://zenn.dev/rhythmcan/articles/b090f1bfe029e8) — read 2026-07-06
- [Claude Code Agent Teams Best Practices & Troubleshooting (community)](https://claudefa.st/blog/guide/agents/agent-teams-best-practices) — read 2026-07-06
