---
topic: Claude Code SendMessage tool — failure modes, workarounds, and inter-agent communication
type: library
subject: claude-code-sendmessage
fetched_at: 2026-05-01
expires: 2026-05-11
sources:
  - https://code.claude.com/docs/en/agent-teams
  - https://code.claude.com/docs/en/agent-sdk/overview
  - https://code.claude.com/docs/en/agent-sdk/subagents
  - https://github.com/anthropics/claude-code/issues/42999
  - https://github.com/anthropics/claude-code/issues/42737
  - https://github.com/anthropics/claude-code/issues/47021
  - https://github.com/anthropics/claude-code/issues/48160
  - https://github.com/anthropics/claude-code/issues/25135
  - https://github.com/anthropics/claude-code/issues/36196
  - https://github.com/anthropics/claude-code/issues/4993
  - https://github.com/anthropics/claude-code/issues/30140
  - https://code.claude.com/docs/en/changelog
---

# Claude Code SendMessage Tool

> Last verified: 2026-05-01. Expires: 2026-05-11. Re-invoke `/uc:research Claude Code SendMessage tool reliability` to refresh.

## Official Documentation Status

The `SendMessage` tool is documented exclusively in the **Agent Teams** section of the Claude Code docs. It is **not** documented in the standard subagents or Claude Agent SDK pages.

Source: https://code.claude.com/docs/en/agent-teams

From the official agent teams docs (verbatim):

> **Automatic message delivery**: when teammates send messages, they're delivered automatically to recipients. The lead doesn't need to poll for updates.

> **Idle notifications**: when a teammate finishes and stops, they automatically notify the lead.

> **Teammate messaging**: send a message to one specific teammate by name. To reach everyone, send one message per recipient.

The mailbox system is described as:

> **Mailbox** — Messaging system for communication between agents

Team/task files are stored at:

- **Team config**: `~/.claude/teams/{team-name}/config.json`
- **Task list**: `~/.claude/tasks/{team-name}/`
- **Inbox files**: `~/.claude/teams/{team-name}/inboxes/{agent-name}.json` (inferred from issue #25135)

The Agent SDK subagents documentation makes **no mention** of `SendMessage`. Subagent-to-parent communication in SDK mode is documented as strictly one-directional: the subagent's final message returns to the parent as the Agent tool result, nothing more.

Source: https://code.claude.com/docs/en/agent-sdk/subagents

> The parent receives the subagent's final message verbatim as the Agent tool result, but may summarize it in its own response.

The subagents doc also explicitly states:

> Subagents cannot spawn their own subagents. Don't include `Agent` in a subagent's `tools` array.

**Critical distinction:** `SendMessage` is an **Agent Teams** primitive only. The Agent SDK and standard subagent system have no `SendMessage` equivalent. The Agent Tool's result text reportedly instructs users to "use SendMessage with to: '' to continue this agent" — but this instruction is only actionable if Agent Teams is enabled.

## Feature Gate: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS

`SendMessage` is gated behind the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` environment variable.

From the official docs (verbatim):

> Agent teams are experimental and disabled by default. Enable them by adding `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` to your settings.json or environment. Agent teams have known limitations around session resumption, task coordination, and shutdown behavior.

Enabling via `settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

**Issue #42737** (filed April 2, 2026, Claude Code 2.1.104) confirms:

> The `SendMessage` tool, which is required to resume/continue conversations with previously spawned subagents, is gated behind the "agent teams" feature. This prevents basic agent communication for users without access to this feature.
>
> The `Agent` tool's result text still instructs users to "use SendMessage with to: '' to continue this agent," but the tool is unavailable.

This issue was closed as **duplicate** — indicating the same regression is tracked elsewhere but Anthropic has not publicly committed to separating `SendMessage` availability from the Agent Teams feature flag.

Source: https://github.com/anthropics/claude-code/issues/42737

## Known Failure Modes

### Failure Mode 1: Tool Not Available (No Feature Flag)

Without `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, `SendMessage` does not appear in Claude's toolset at all.

From issue #47021 (Claude Code 2.1.104, closed as duplicate):

> `SendMessage` tool is **not available** at runtime (neither as direct nor deferred tool)
>
> `ToolSearch` query `select:SendMessage` returns: `"No matching deferred tools found"`

Affected: any session without the feature flag set.

Source: https://github.com/anthropics/claude-code/issues/47021

### Failure Mode 2: Tool Not Available in Subagents (Asymmetric Access)

Even with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and `SendMessage(*)` granted in permissions, subagents spawned as teammates cannot originate `SendMessage` calls.

From issue #48160 (Claude Code Opus 4.6, closed as duplicate):

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

The tool's own documentation/schema says to use agent **names**, but only agent **IDs** work reliably for completed/resumed agents.

From issue #42999 (Claude Code 2.1.92, status: OPEN):

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

This is an **open bug** as of Claude Code 2.1.92, May 2026.

Source: https://github.com/anthropics/claude-code/issues/42999

### Failure Mode 4: Orphaned Inbox Files

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

Issue #36196 (Claude Code 2.1.79):

> Claude states: "I don't see a to field or SendMessage function exposed in any of my available tools."
>
> Version 2.1.77 removed the `resume` parameter from the Agent tool, breaking the ability to resume agents. Without `SendMessage` exposed, there is no alternative way to resume agents.

This was the original regression that triggered multiple downstream issues. Status: closed (assumed fixed in later versions by tool being re-exposed under Agent Teams flag).

Source: https://github.com/anthropics/claude-code/issues/36196

## Anthropic Response and Timeline

As of May 1, 2026, Anthropic has:

- **Not fixed** the name-vs-ID mismatch (issue #42999, OPEN)
- **Closed as duplicate** the feature-flag gating issue (#42737) — indicates tracking exists but no public timeline
- **Closed as duplicate** the subagent asymmetric access (#48160)
- **Closed as not planned** the orphaned inbox validation (#25135)
- **Not documented** SendMessage outside the experimental Agent Teams page

The only confirmed `SendMessage`-related fix in the changelog:

> **v2.1.118 (April 23, 2026)**: Fixed subagents resumed via `SendMessage` not restoring the explicit `cwd` they were spawned with.

Source: https://code.claude.com/docs/en/changelog

No public statement from Anthropic on when (or whether) `SendMessage` will be made available outside the Agent Teams feature flag, or when subagents will be able to originate messages.

## Subagent Resume via Agent ID (Official SDK Pattern)

The official Agent SDK docs show that subagent resumption does **not** use `SendMessage` in SDK mode — it uses the `resume` option on `query()` with the captured session ID, plus passing the agent ID in the prompt.

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
            allowed_tools=["Read", "Grep", "Glob", "Agent"], resume=session_id
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

Since subagents cannot originate `SendMessage`, the parent agent manually relays messages on behalf of subagents.

Pattern:
1. Subagent includes an "intended-to-send" section in its result text
2. Parent agent reads the result and calls `SendMessage` on behalf of the subagent
3. Parent acts as a message router for all peer-to-peer communication

Limitation: eliminates parallelism benefit; forces sequential parent involvement in every subagent-originated communication.

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

From official agent-teams docs (verbatim):

> Task claiming uses file locking to prevent race conditions when multiple teammates try to claim the same task simultaneously.

Limitation from issue #30140: the Edit tool's string-matching append can still clobber under concurrent writes; no concurrent-write safety guarantee.

Sources: https://github.com/anthropics/claude-code/issues/30140, https://github.com/anthropics/claude-code/issues/4993

### Workaround 4: Dual-Write Pattern

Write the communication payload to a file **first**, then call `SendMessage` as a best-effort wake-up signal.

Pattern:
1. Write message content to `~/.claude/teams/{team}/shared/{sender}-to-{recipient}-{timestamp}.json`
2. Call `SendMessage(to=recipientId, message="Check shared/{filename} for my update")`
3. Recipient reads the file on wake-up; if `SendMessage` was silently lost, file still exists for next poll

This ensures no content is lost even if `SendMessage` silently fails delivery.

### Workaround 5: SDK Session Resume (Non-Agent-Teams Path)

For workflows using the Claude Agent SDK (not interactive CLI agent teams), the `resume` option on `query()` with explicit agent ID passing in the prompt is the official, supported path for continuing subagent work. See the code examples in the "Subagent Resume via Agent ID" section above.

This path does **not** use `SendMessage` and does **not** require `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

Source: https://code.claude.com/docs/en/agent-sdk/subagents

## Agent Teams Official Limitations (Verbatim)

From https://code.claude.com/docs/en/agent-teams:

> Agent teams are experimental. Current limitations to be aware of:
>
> - **No session resumption with in-process teammates**: `/resume` and `/rewind` do not restore in-process teammates. After resuming a session, the lead may attempt to message teammates that no longer exist. If this happens, tell the lead to spawn new teammates.
> - **Task status can lag**: teammates sometimes fail to mark tasks as completed, which blocks dependent tasks. If a task appears stuck, check whether the work is actually done and update the task status manually or tell the lead to nudge the teammate.
> - **Shutdown can be slow**: teammates finish their current request or tool call before shutting down, which can take time.
> - **One team per session**: a lead can only manage one team at a time. Clean up the current team before starting a new one.
> - **No nested teams**: teammates cannot spawn their own teams or teammates. Only the lead can manage the team.
> - **Lead is fixed**: the session that creates the team is the lead for its lifetime. You can't promote a teammate to lead or transfer leadership.
> - **Permissions set at spawn**: all teammates start with the lead's permission mode. You can change individual teammate modes after spawning, but you can't set per-teammate modes at spawn time.

## Best Practices for Reliable Multi-Agent Communication

Given the above failure modes:

1. **Prefer SDK session resume over SendMessage for subagent continuation.** The `resume` + `agentId-in-prompt` pattern is the documented, feature-flag-free path. `SendMessage`-based resume requires Agent Teams to be enabled and has known name-resolution bugs.

2. **When using Agent Teams, always use agent IDs (not names) in the `to` field.** The schema says use names; the implementation requires IDs for reliable delivery. Extract the agent ID from the Agent tool result or `subagents/*.meta.json` at spawn time and store it.

3. **Implement a `PreToolUse` hook to intercept `SendMessage` and resolve names to IDs.** This makes the workaround transparent to the orchestrating agent's prompts.

4. **Dual-write critical communication payloads.** Write to a shared file first; use `SendMessage` only as a best-effort wake signal. Poll shared files at each turn start.

5. **Do not rely on subagents originating `SendMessage`.** The asymmetric access bug (#48160) means only parent/lead agents can send messages. Design all communication as parent-to-child or use the file-based protocol for peer coordination.

6. **Test `ToolSearch("select:SendMessage")` at session start.** If it returns no results, the feature flag is not active or the tool is unavailable in this environment. Fall back to file-based protocols immediately rather than discovering the failure at first use.

7. **For the CLAUDE.md global instruction "Never use tmux to send messages between agents — always use SendMessage"**: this instruction is valid when Agent Teams is enabled and agent IDs are known. It should be supplemented with the ID-resolution workaround and dual-write pattern until the name-resolution bug (#42999) is fixed.

## Sources

- [Agent Teams — Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams) — read 2026-05-01
- [Agent SDK Overview](https://code.claude.com/docs/en/agent-sdk/overview) — read 2026-05-01
- [Subagents in the SDK](https://code.claude.com/docs/en/agent-sdk/subagents) — read 2026-05-01
- [Issue #42999 — SendMessage silently fails when using agent name; only agent ID works](https://github.com/anthropics/claude-code/issues/42999) — read 2026-05-01
- [Issue #42737 — SendMessage gated behind AGENT_TEAMS feature flag](https://github.com/anthropics/claude-code/issues/42737) — read 2026-05-01
- [Issue #47021 — SendMessage referenced in docs but not available at runtime](https://github.com/anthropics/claude-code/issues/47021) — read 2026-05-01
- [Issue #48160 — Subagents cannot originate SendMessage despite AGENT_TEAMS=1](https://github.com/anthropics/claude-code/issues/48160) — read 2026-05-01
- [Issue #25135 — SendMessage silently succeeds when recipient name doesn't match polling target](https://github.com/anthropics/claude-code/issues/25135) — read 2026-05-01
- [Issue #36196 — SendMessage tool not exposed to Claude](https://github.com/anthropics/claude-code/issues/36196) — read 2026-05-01
- [Issue #4993 — Feature Request: Enable Agent-to-Agent Communication](https://github.com/anthropics/claude-code/issues/4993) — read 2026-05-01
- [Issue #30140 — Shared channel for agent teams](https://github.com/anthropics/claude-code/issues/30140) — read 2026-05-01
- [Claude Code Changelog](https://code.claude.com/docs/en/changelog) — read 2026-05-01
