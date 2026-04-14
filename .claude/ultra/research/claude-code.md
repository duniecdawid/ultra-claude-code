---
topic: claude code hooks
type: library
subject: claude-code
fetched_at: 2026-04-13
expires: 2026-04-23
sources:
  - https://docs.claude.com/en/docs/claude-code/hooks
  - https://code.claude.com/docs/en/hooks
  - https://docs.claude.com/en/docs/claude-code/hooks-guide
  - https://code.claude.com/docs/en/hooks-guide
---

# Claude Code Hooks

> Last verified: 2026-04-13. Expires: 2026-04-23. Re-invoke `/uc:research claude code hooks` to refresh.

## Overview

Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that execute automatically at specific points in Claude Code's lifecycle. They provide deterministic control over Claude Code's behavior, ensuring certain actions always happen rather than relying on the LLM to choose to run them.

Source: https://code.claude.com/docs/en/hooks

## Hook Events Reference

Hooks fire at three cadences:
- **Once per session**: `SessionStart`, `SessionEnd`
- **Once per turn**: `UserPromptSubmit`, `Stop`, `StopFailure`
- **On every tool call**: `PreToolUse`, `PostToolUse`, `SubagentStart/Stop`, `TaskCreated/Completed`, etc.

### Complete Event Table

| Event | When it fires | Can Block? |
|-------|---------------|------------|
| `SessionStart` | When a session begins or resumes | No |
| `InstructionsLoaded` | When CLAUDE.md or `.claude/rules/*.md` loaded | No (async) |
| `UserPromptSubmit` | Before Claude processes a prompt | Yes |
| `PreToolUse` | Before a tool call executes | Yes |
| `PermissionRequest` | When a permission dialog appears | Yes |
| `PermissionDenied` | When auto mode denies a tool call | No |
| `PostToolUse` | After a tool call succeeds | No (tool already ran) |
| `PostToolUseFailure` | After a tool call fails | No |
| `Notification` | When Claude Code sends a notification | No |
| `SubagentStart` | When a subagent is spawned | No |
| `SubagentStop` | When a subagent finishes | Yes |
| `TaskCreated` | When a task is being created via TaskCreate | Yes |
| `TaskCompleted` | When a task is marked completed | Yes |
| `Stop` | When Claude finishes responding | Yes |
| `StopFailure` | When turn ends due to API error (output/exit code ignored) | No |
| `TeammateIdle` | When an agent team teammate is about to go idle | Yes |
| `ConfigChange` | When a configuration file changes during a session | Yes (except policy_settings) |
| `CwdChanged` | When the working directory changes | No |
| `FileChanged` | When a watched file changes on disk | No |
| `WorktreeCreate` | When a worktree is being created | Yes |
| `WorktreeRemove` | When a worktree is being removed | No |
| `PreCompact` | Before context compaction | No |
| `PostCompact` | After context compaction completes | No |
| `Elicitation` | When an MCP server requests user input during a tool call | Yes |
| `ElicitationResult` | After user responds to MCP elicitation | Yes |
| `SessionEnd` | When a session terminates | No |

Source: https://code.claude.com/docs/en/hooks

## Configuration

### Hook Locations and Scope

| Location | Scope | Shareable |
|----------|-------|-----------|
| `~/.claude/settings.json` | All projects | No |
| `.claude/settings.json` | Single project | Yes (commit to repo) |
| `.claude/settings.local.json` | Single project | No (gitignored) |
| Managed policy settings | Organization-wide | Yes (admin-controlled) |
| Plugin `hooks/hooks.json` | When plugin enabled | Yes |
| Skill/agent frontmatter | While component active | Yes |

### Configuration Structure

Three levels of nesting:
1. **Hook event** (e.g., `PreToolUse`)
2. **Matcher group** (filter to specific tool names or event subtypes)
3. **Hook handlers** (shell command, HTTP endpoint, or prompt)

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(rm *)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-rm.sh"
          }
        ]
      }
    ]
  }
}
```

To disable all hooks at once:

```json
{
  "disableAllHooks": true
}
```

Source: https://code.claude.com/docs/en/hooks

### Matcher Patterns

| Pattern | Evaluation |
|---------|-----------|
| `"*"`, `""`, or omitted | Match all |
| Letters, digits, `_`, `\|` | Exact string or `\|`-separated list |
| Other characters | JavaScript regex |

**What the matcher filters per event type:**

| Event | What the matcher filters | Example values |
|-------|--------------------------|----------------|
| `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, `PermissionDenied` | tool name | `Bash`, `Edit\|Write`, `mcp__.*` |
| `SessionStart` | how the session started | `startup`, `resume`, `clear`, `compact` |
| `SessionEnd` | why the session ended | `clear`, `resume`, `logout`, `prompt_input_exit`, `bypass_permissions_disabled`, `other` |
| `Notification` | notification type | `permission_prompt`, `idle_prompt`, `auth_success`, `elicitation_dialog` |
| `SubagentStart`, `SubagentStop` | agent type | `Bash`, `Explore`, `Plan`, or custom names |
| `PreCompact`, `PostCompact` | what triggered compaction | `manual`, `auto` |
| `ConfigChange` | configuration source | `user_settings`, `project_settings`, `local_settings`, `policy_settings`, `skills` |
| `StopFailure` | error type | `rate_limit`, `authentication_failed`, `billing_error`, `invalid_request`, `server_error`, `max_output_tokens`, `unknown` |
| `InstructionsLoaded` | load reason | `session_start`, `nested_traversal`, `path_glob_match`, `include`, `compact` |
| `Elicitation`, `ElicitationResult` | MCP server name | your configured MCP server names |
| `FileChanged` | literal filenames to watch | `.envrc\|.env` |
| `UserPromptSubmit`, `Stop`, `TeammateIdle`, `TaskCreated`, `TaskCompleted`, `WorktreeCreate`, `WorktreeRemove`, `CwdChanged` | no matcher support | always fires |

**MCP Tool Matching:** MCP tools follow naming pattern `mcp__<server>__<tool>`. Examples:
- `mcp__memory__create_entities` — specific tool
- `mcp__memory__.*` — all tools from a server
- `mcp__.*__write.*` — write tools across all servers

Source: https://code.claude.com/docs/en/hooks

### The `if` Field (requires v2.1.85+)

The `if` field uses permission rule syntax to filter hooks by tool name and arguments together. The hook process only spawns when the tool call matches. Goes beyond `matcher`, which filters at the group level by tool name only.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "if": "Bash(git *)",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/check-git-policy.sh"
          }
        ]
      }
    ]
  }
}
```

`if` only works on tool events: `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PermissionRequest`, and `PermissionDenied`. Adding it to any other event prevents the hook from running.

Source: https://code.claude.com/docs/en/hooks-guide

## Hook Handler Types

### Common Fields (all types)

| Field | Required | Description |
|-------|----------|-------------|
| `type` | yes | `"command"`, `"http"`, `"prompt"`, or `"agent"` |
| `if` | no | Permission rule syntax: `"Bash(git *)"` or `"Edit(*.ts)"`. Tool events only |
| `timeout` | no | Seconds before canceling. Defaults: 600 (command), 30 (prompt), 60 (agent) |
| `statusMessage` | no | Custom spinner message |
| `once` | no | If `true`, runs once per session then removed. Skills only |

### Command Hook

```json
{
  "type": "command",
  "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/script.sh",
  "async": false,
  "asyncRewake": false,
  "shell": "bash"
}
```

| Field | Description |
|-------|-------------|
| `command` | Shell command to execute |
| `async` | If `true`, runs in background without blocking |
| `asyncRewake` | If `true`, runs in background and wakes Claude on exit code 2 |
| `shell` | `"bash"` (default) or `"powershell"` |

### HTTP Hook

```json
{
  "type": "http",
  "url": "http://localhost:8080/hooks/pre-tool-use",
  "timeout": 30,
  "headers": {
    "Authorization": "Bearer $MY_TOKEN"
  },
  "allowedEnvVars": ["MY_TOKEN"]
}
```

| Field | Description |
|-------|-------------|
| `url` | POST endpoint URL |
| `headers` | Additional HTTP headers (supports `$VAR_NAME` interpolation) |
| `allowedEnvVars` | List of env vars allowed in header interpolation |

Only variables listed in `allowedEnvVars` are resolved; all other `$VAR` references remain empty.

Non-2xx responses, connection failures, and timeouts are non-blocking. Return 2xx with JSON containing `decision: "block"` or `permissionDecision: "deny"` to block.

### Prompt Hook

```json
{
  "type": "prompt",
  "prompt": "Check if all tasks are complete. If not, respond with {\"ok\": false, \"reason\": \"what remains to be done\"}.",
  "model": "fast-model"
}
```

| Field | Description |
|-------|-------------|
| `prompt` | Prompt text (use `$ARGUMENTS` for JSON input) |
| `model` | Model to use. Defaults to fast model |

The model returns `"ok": true` (allow) or `"ok": false` (block) with a `"reason"`.

### Agent Hook

```json
{
  "type": "agent",
  "prompt": "Verify that all unit tests pass. Run the test suite and check the results. $ARGUMENTS",
  "timeout": 120
}
```

Agent hooks spawn a subagent that can read files, search code, and use other tools to verify conditions. Default timeout: 60 seconds, up to 50 tool-use turns. Uses the same `"ok"` / `"reason"` response format as prompt hooks.

Source: https://code.claude.com/docs/en/hooks

## Hook Input and Output

### Common Input Fields

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "PreToolUse",
  "agent_id": "agent-123",
  "agent_type": "Explore"
}
```

(`agent_id` and `agent_type` only present in subagents)

### Exit Codes

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success | Parse JSON from stdout if present |
| 2 | Blocking error | Block action, use stderr as error message |
| Other | Non-blocking error | Show first line of stderr, continue execution |

**Critical:** For most events, only exit code 2 blocks. Exit 1 is treated as non-blocking and execution continues. For `PostToolUse`, `PostToolUseFailure`, `PermissionDenied`, `Notification`, `SubagentStart`, `SessionStart/End`: exit 2 does not block (shows to user only or logs).

### JSON Output Schema

Exit 0 and print to stdout for structured control:

```json
{
  "continue": true,
  "stopReason": "optional stop reason",
  "suppressOutput": false,
  "systemMessage": "optional warning",
  "decision": "block|none",
  "reason": "explanation",
  "hookSpecificOutput": {
    "hookEventName": "EventName"
  }
}
```

| Field | Default | Description |
|-------|---------|-------------|
| `continue` | `true` | If `false`, Claude stops entirely |
| `stopReason` | — | Message shown when `continue: false` |
| `suppressOutput` | `false` | If `true`, omit from debug log |
| `systemMessage` | — | Warning shown to user |

Max output: 10,000 characters.

**Do not mix exit 2 and JSON output.** Claude Code ignores JSON when you exit 2.

Source: https://code.claude.com/docs/en/hooks

## Event-Specific Input and Decision Schemas

### PreToolUse

```json
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash|Edit|Write|Read|Glob|Grep|Agent|WebFetch|WebSearch|AskUserQuestion",
  "tool_input": { },
  "tool_use_id": "toolu_01ABC..."
}
```

**Decision output:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "explanation",
    "updatedInput": { },
    "additionalContext": "context for Claude"
  }
}
```

`permissionDecision` values:
- `"allow"` — skip interactive permission prompt (deny/ask rules still apply)
- `"deny"` — cancel tool call, feed reason to Claude
- `"ask"` — show permission prompt to user
- `"defer"` — non-interactive mode only; exits with `stop_reason: "tool_deferred"` for Agent SDK wrapper

**Precedence when multiple hooks return different decisions:** `deny` > `defer` > `ask` > `allow`

**Tool input schemas (verbatim):**

```json
// Bash
{ "command": "npm test", "description": "Run test suite", "timeout": 120000, "run_in_background": false }

// Write
{ "file_path": "/path/to/file.txt", "content": "file content" }

// Edit
{ "file_path": "/path/to/file.txt", "old_string": "original", "new_string": "replacement", "replace_all": false }

// Read
{ "file_path": "/path/to/file.txt", "offset": 10, "limit": 50 }

// Glob
{ "pattern": "**/*.ts", "path": "/path/to/dir" }

// Grep
{ "pattern": "TODO.*fix", "path": "/path/to/dir", "glob": "*.ts", "output_mode": "content|files_with_matches|count", "-i": true, "multiline": false }

// WebFetch
{ "url": "https://example.com", "prompt": "Extract API endpoints" }

// WebSearch
{ "query": "react hooks", "allowed_domains": ["docs.example.com"], "blocked_domains": ["spam.com"] }

// Agent
{ "prompt": "Find API endpoints", "description": "Find endpoints", "subagent_type": "Explore|Bash|Plan", "model": "sonnet" }
```

Source: https://code.claude.com/docs/en/hooks

### PostToolUse

```json
{
  "hook_event_name": "PostToolUse",
  "tool_name": "Write",
  "tool_input": { },
  "tool_response": { },
  "tool_use_id": "toolu_01ABC..."
}
```

**Decision output (does not block — tool already ran):**
```json
{
  "decision": "block",
  "reason": "explanation",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "context",
    "updatedMCPToolOutput": "new output (MCP tools only)"
  }
}
```

### UserPromptSubmit

```json
{
  "hook_event_name": "UserPromptSubmit",
  "prompt": "User's prompt text"
}
```

**Decision output:**
```json
{
  "decision": "block",
  "reason": "Explanation",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "Context to add",
    "sessionTitle": "Auto-generated title"
  }
}
```

Plain stdout also adds as context (no JSON needed).

### SessionStart

```json
{
  "hook_event_name": "SessionStart",
  "source": "startup|resume|clear|compact",
  "model": "claude-sonnet-4-6"
}
```

**Persist environment variables via `CLAUDE_ENV_FILE`:**
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  echo 'export NODE_ENV=production' >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

**Inject additional context:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Context string"
  }
}
```

### Stop

```json
{
  "hook_event_name": "Stop",
  "stop_hook_active": false
}
```

**Decision output:**
```json
{
  "decision": "block",
  "reason": "Explanation"
}
```

**Infinite loop prevention:** parse `stop_hook_active` and exit 0 if `true`:
```bash
#!/bin/bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0
fi
# ... rest of your hook logic
```

### PermissionRequest

```json
{
  "hook_event_name": "PermissionRequest",
  "tool_name": "Bash",
  "tool_input": { },
  "permission_suggestions": [
    {
      "type": "addRules|replaceRules|removeRules|setMode|addDirectories|removeDirectories",
      "rules": [{ "toolName": "Bash", "ruleContent": "rm -rf node_modules" }],
      "behavior": "allow|deny|ask",
      "destination": "localSettings|projectSettings|userSettings|session",
      "mode": "default|acceptEdits|dontAsk|bypassPermissions|plan",
      "directories": ["/path"]
    }
  ]
}
```

**Decision output:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": {
      "behavior": "allow|deny",
      "updatedInput": { },
      "updatedPermissions": [ ]
    },
    "message": "explanation for deny"
  }
}
```

Does not fire in non-interactive mode (`-p`). Use `PreToolUse` for automated permission decisions in headless mode.

### PermissionDenied

```json
{
  "hook_event_name": "PermissionDenied",
  "permission_mode": "auto",
  "tool_name": "Bash",
  "tool_input": { },
  "tool_use_id": "toolu_01ABC...",
  "reason": "Auto mode denied: command targets path outside project"
}
```

**Decision output — tell model it may retry:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionDenied",
    "retry": true
  }
}
```

### CwdChanged

```json
{
  "hook_event_name": "CwdChanged",
  "cwd": "/new/working/directory"
}
```

Write env vars to `CLAUDE_ENV_FILE` to reload direnv:
```bash
#!/bin/bash
if [ -n "$CLAUDE_ENV_FILE" ]; then
  direnv export bash >> "$CLAUDE_ENV_FILE"
fi
exit 0
```

### FileChanged

```json
{
  "hook_event_name": "FileChanged",
  "file_path": "/path/to/changed/file",
  "file_name": ".envrc"
}
```

Matcher for `FileChanged` is split into literal filenames (not regex): `".envrc|.env|package.json"`.

### WorktreeCreate

```json
{ "hook_event_name": "WorktreeCreate" }
```

**Decision output — return worktree path:**
```bash
echo "/path/to/worktree"
exit 0
```

Non-zero exit or missing path fails creation.

### WorktreeRemove

```json
{
  "hook_event_name": "WorktreeRemove",
  "worktree_path": "/path/to/worktree"
}
```

### TaskCreated / TaskCompleted

```json
{
  "hook_event_name": "TaskCreated",
  "task_id": "task-001",
  "task_subject": "Implement authentication",
  "task_description": "Add login endpoints",
  "teammate_name": "implementer",
  "team_name": "my-project"
}
```

**Decision output:**
```json
{ "decision": "block", "reason": "explanation" }
```

Or stop teammate entirely:
```json
{ "continue": false, "stopReason": "Build failed, fix first" }
```

### SubagentStop

```json
{
  "hook_event_name": "SubagentStop",
  "stop_hook_active": false,
  "agent_id": "def456",
  "agent_type": "Explore",
  "agent_transcript_path": "~/.claude/projects/.../subagents/agent-def456.jsonl",
  "last_assistant_message": "Analysis complete..."
}
```

### InstructionsLoaded

```json
{
  "hook_event_name": "InstructionsLoaded",
  "file_path": "/path/to/CLAUDE.md",
  "memory_type": "User|Project|Local|Managed",
  "load_reason": "session_start|nested_traversal|path_glob_match|include|compact",
  "globs": ["path/patterns"],
  "trigger_file_path": "/path/that/triggered/load",
  "parent_file_path": "/path/to/including/file"
}
```

Source: https://code.claude.com/docs/en/hooks

## Environment Variables for Script References

```json
"$CLAUDE_PROJECT_DIR"        // Project root
"${CLAUDE_PLUGIN_ROOT}"      // Plugin installation directory
"${CLAUDE_PLUGIN_DATA}"      // Plugin persistent data directory
```

`CLAUDE_ENV_FILE` — a writable file path available in hook scripts. Append `export KEY=value` lines to it; Claude Code applies those variables before each Bash command.

## Hooks and Permission Modes

PreToolUse hooks fire before any permission-mode check. A hook returning `permissionDecision: "deny"` blocks the tool even in `bypassPermissions` mode or with `--dangerously-skip-permissions`. This lets you enforce policy that users cannot bypass by changing their permission mode.

The reverse is not true: a hook returning `"allow"` does not bypass deny rules from settings. Hooks can tighten restrictions but not loosen them past what permission rules allow.

Source: https://code.claude.com/docs/en/hooks-guide

## Complete Examples

### Notify on idle (macOS)

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "osascript -e 'display notification \"Claude Code needs your attention\" with title \"Claude Code\"'"
          }
        ]
      }
    ]
  }
}
```

### Auto-format after edits

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path' | xargs npx prettier --write"
          }
        ]
      }
    ]
  }
}
```

### Block edits to protected files

`.claude/hooks/protect-files.sh`:
```bash
#!/bin/bash
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

PROTECTED_PATTERNS=(".env" "package-lock.json" ".git/")

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    echo "Blocked: $FILE_PATH matches protected pattern '$pattern'" >&2
    exit 2
  fi
done

exit 0
```

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/protect-files.sh"
          }
        ]
      }
    ]
  }
}
```

### Re-inject context after compaction

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Reminder: use Bun, not npm. Run bun test before committing. Current sprint: auth refactor.'"
          }
        ]
      }
    ]
  }
}
```

### Auto-approve ExitPlanMode

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"hookSpecificOutput\": {\"hookEventName\": \"PermissionRequest\", \"decision\": {\"behavior\": \"allow\"}}}'"
          }
        ]
      }
    ]
  }
}
```

### Bash command validator (block dangerous commands)

```bash
#!/bin/bash
COMMAND=$(jq -r '.tool_input.command')

if echo "$COMMAND" | grep -q 'rm -rf'; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: "Destructive command blocked"
    }
  }'
else
  exit 0
fi
```

### direnv reload on cwd change

```json
{
  "hooks": {
    "CwdChanged": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "direnv export bash >> \"$CLAUDE_ENV_FILE\""
          }
        ]
      }
    ]
  }
}
```

Source: https://code.claude.com/docs/en/hooks-guide

## Troubleshooting

### Shell profile pollution causing JSON parse errors

When Claude Code spawns a hook, it sources `~/.zshrc` or `~/.bashrc`. Unconditional `echo` statements in the profile get prepended to the hook's JSON output. Fix:

```bash
# In ~/.zshrc or ~/.bashrc
if [[ $- == *i* ]]; then
  echo "Shell ready"
fi
```

### Stop hook infinite loop

Parse `stop_hook_active` from stdin and exit 0 if `true` (see Stop event schema above).

### Hook not firing

- Run `/hooks` in Claude Code — all configured hooks are listed grouped by event
- Matchers are case-sensitive
- `PermissionRequest` does not fire in non-interactive mode (`-p`); use `PreToolUse` instead
- `if` field requires v2.1.85+; earlier versions ignore it

### Debug hooks

Start with `claude --debug-file /tmp/claude.log` and `tail -f /tmp/claude.log`, or run `/debug` mid-session to enable logging.

Source: https://code.claude.com/docs/en/hooks-guide

## Sources

- [Hooks reference — code.claude.com](https://code.claude.com/docs/en/hooks) — read 2026-04-13
- [Automate workflows with hooks (guide) — code.claude.com](https://code.claude.com/docs/en/hooks-guide) — read 2026-04-13
- [Hooks reference — docs.claude.com (redirects to code.claude.com)](https://docs.claude.com/en/docs/claude-code/hooks) — read 2026-04-13
- [Hooks guide — docs.claude.com (redirects to code.claude.com)](https://docs.claude.com/en/docs/claude-code/hooks-guide) — read 2026-04-13
