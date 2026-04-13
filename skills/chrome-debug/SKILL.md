---
name: chrome-debug
description: >
  Diagnose and fix Claude-in-Chrome browser connection issues. Use this skill whenever
  browser automation fails, times out, or behaves unexpectedly. Triggers on: "connect
  to chrome", "browser not responding", "chrome not working", "switch browser failed",
  "no browser responded", "chrome timeout", "debug chrome", "fix chrome", "browser
  extension not detected", "tabs_context failed", or any mcp__claude-in-chrome__* tool
  error. Also use proactively before browser automation sessions to verify health.
  Supports single-browser and dual-browser setups. Reads machine-specific paths and
  preferences from ~/.claude/skills/machine-context/chrome-debug.md when present;
  falls back to runtime detection via $HOME, whoami, and jq otherwise.
---

# Chrome Debug — Claude-in-Chrome Diagnostics

## Operating Mode: Autonomous Auto-Recovery

This skill is designed to run autonomously as part of automated testing cycles. When invoked:

1. **Fix first, ask later.** Run the diagnostic procedure and apply fixes (kill stale processes, retry connections) without waiting for user confirmation. These are safe, reversible actions.
2. **Retry `tabs_context_mcp` aggressively** (up to 3 times) — the bridge can be slow. But **never blindly retry `switch_browser`** — it triggers a naming prompt that blocks until the user responds. Always warn the user first and wait for them to be ready before calling `switch_browser`.
3. **Only escalate to the user** when the full procedure including Step 6 (full restart) has been attempted and failed, OR when you need the user to physically interact with the browser (reload extension, click Connect).
4. **Log unresolved failures** (Step 8) before escalating — capture the diagnostic state into `$HOME/.claude/skills/chrome-debug/logs/` so patterns can be analyzed across incidents.
5. **After fixing, return control** to the caller so the original browser action can be retried. State clearly which browser is now active and its tab group ID.

Connection issues are almost always one of: stale native host (auto-fixable), service worker idle (needs user to reload extension), or bridge race (retry fixes it). **Never give up on the first failure.**

**Critical rule: Never call `switch_browser` autonomously in automated flows.** Each call triggers a blocking naming prompt. The only time `switch_browser` is acceptable is when the user explicitly requests it during manual diagnostics or when Step 5 (test alternate browser in a dual-browser setup) is warranted and the user has been warned.

## Communication: PM Agent vs Main Context

When you need the user to take action (e.g., reload extension, click Connect):

- **If a PM agent is running** (Ultra Claude plan-execution pipeline with a Project Manager): send the message to the PM agent via `SendMessage` so it can relay to the user and track the blocker. The PM agent coordinates between agents and the user — use it as the communication channel.
- **If running in main context** (no PM agent, direct conversation): communicate directly with the user as normal.

---

You are debugging Claude-in-Chrome connections. Claude in Chrome only works with Chrome and Chromium — there is no Firefox/Safari/Edge extension. The architecture has multiple hops where failures can occur; symptoms overlap so use the diagnostic procedure to isolate the cause.

## Architecture

```
Claude Code CLI (local)
    |
    v  WebSocket
Remote Bridge (wss://bridge.claudeusercontent.com)
    |
    v  WebSocket
Native Messaging Host (local binary per machine)
    |
    v  Chrome Native Messaging API (stdio)
Claude in Chrome Extension
    |
    v  Chrome Extension APIs
Browser (Chrome or Chromium)
```

The bridge is the pairing mechanism — Claude Code and each browser extension both connect outward to the bridge, which matches them. There is no direct connection between Claude Code and the browser. Failures can happen at any hop.

## Step 0: Load Machine Context

Before running the diagnostic, check for machine-specific context:

```bash
MACHINE_CTX="$HOME/.claude/skills/machine-context/chrome-debug.md"
if [ -f "$MACHINE_CTX" ]; then
  # Read the file for this machine's specific values: primary Chrome install,
  # dual-browser setup, VM-to-host routing, extension ID, diagnostic shortcuts
  cat "$MACHINE_CTX"
fi
```

If the machine-context file exists, use its values throughout the diagnostic. Common values it provides:

- **Primary browser**: which Chrome/Chromium install is the default target for automation (e.g., "Mac Chrome" for a Parallels-VM setup where Claude Code runs in the VM and the host's Chrome is the default automation target)
- **Dual-browser setup**: whether multiple Chrome instances are paired to the same Anthropic account via the cloud bridge (enables Step 5)
- **Key paths**: OS-specific native messaging host config path, wrapper script path, Claude binaries directory
- **VM-to-host routing**: if Claude Code runs in a VM and the primary browser runs on the host, the VM's external IP and port conventions (e.g., "never use localhost, always VM_IP:PORT")
- **Extension ID**: the current Claude-in-Chrome extension ID (otherwise detect at runtime via `jq` over the native messaging config)

If the machine-context file does NOT exist, fall back to pure runtime detection. All subsequent steps use `$HOME`, `whoami`, and `jq`-based extraction to find paths and IDs. Advise the user that running `/uc:setup` will scaffold `~/.claude/skills/machine-context/` with their machine-specific answers, making future `/uc:chrome-debug` runs more targeted.

## Diagnostic Procedure

Run these steps in order. Stop as soon as you find and fix the issue, then verify the fix worked.

### Step 1: Detect native host paths

Resolve the paths for this machine. Prefer values from `machine-context/chrome-debug.md` if present; otherwise use `$HOME`-relative defaults:

```bash
CHROMIUM_NMH="$HOME/.config/chromium/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json"
CHROME_NMH="$HOME/.config/google-chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json"
WRAPPER="$HOME/.claude/chrome/chrome-native-host"
```

On macOS, the equivalent paths are under `$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/`. On Windows under `%LOCALAPPDATA%\Google\Chrome\User Data\NativeMessagingHosts\`. Adjust for the host OS if the host-side browser is being diagnosed from a shell that can see those paths.

### Step 2: Check native host process health

```bash
# What's running?
ps aux | grep "chrome-native-host" | grep -v grep

# What should be running?
cat "$WRAPPER"
```

Compare the version referenced by the running process against the version in the wrapper script. If they differ, this is the most common cause of connection issues — the native host is stale after a Claude Code update. The wrapper gets rewritten on update; the already-running native host process stays alive on the old version.

**Fix**: Kill the stale process by PID immediately (this is always safe). Then tell the user to reload the extension at `chrome://extensions` — toggle Claude in Chrome off then on. Chrome will spawn a fresh native host using the updated wrapper. Wait for the user to confirm, then verify the new process version matches.

### Step 3: Verify extension config

```bash
# Check whichever config file(s) exist for the target browser
[ -f "$CHROMIUM_NMH" ] && cat "$CHROMIUM_NMH"
[ -f "$CHROME_NMH" ] && cat "$CHROME_NMH"
```

Confirm:
- `path` points to the wrapper script at `$WRAPPER` (the canonical location — NOT a profile-scoped path; see "Native messaging manifest pointing to profile path" below)
- `allowed_origins` includes an entry like `chrome-extension://{EXTENSION_ID}/`
- The file is readable by the chromium/chrome process

**Runtime extension ID detection** (if you need it and machine-context doesn't provide it):

```bash
EXT_ID=$(jq -r '.allowed_origins[0]' "$CHROMIUM_NMH" 2>/dev/null \
  | sed 's|chrome-extension://||;s|/.*||')
```

### Step 4: Test primary browser connection

Call `mcp__claude-in-chrome__tabs_context_mcp` (with `createIfEmpty: true` if needed).

- **Success**: The primary browser is connected. Note the tab IDs and proceed to Step 7 (report).
- **Timeout/error**: Retry up to 3 times (the bridge can be slow). If all 3 fail, proceed to Step 6 (full restart).

### Step 5: Test alternate browser (dual-browser setups only)

**Skip this step** unless `machine-context/chrome-debug.md` indicates a dual-browser setup. Most users have a single Chrome install and don't need this step.

**Important**: `switch_browser` triggers a "Name this browser" prompt that blocks until the user responds. Always warn the user before calling it.

1. Tell the user: "I'm about to switch browsers. Watch for the 'Name this browser' prompt in the other browser and confirm it quickly."
2. Wait for the user to acknowledge they're ready.
3. Call `mcp__claude-in-chrome__switch_browser`.

Interpreting the result:
- **"No browser responded within the timeout"**: The user likely didn't see or respond to the naming prompt in time. Ask if they saw the prompt, then try again.
- **Connected to wrong browser**: Call `switch_browser` again (warn user to watch the OTHER browser this time).
- **Success**: Both browsers are reachable. Warn user again before switching back to the primary browser to confirm bidirectional works.

### Step 6: Full restart (when Steps 1-5 don't resolve it)

1. Kill all native host processes:
   ```bash
   pkill -f "chrome-native-host"
   ```
2. Ask user to reload the extension at `chrome://extensions` in the primary browser.
3. In a dual-browser setup, also ask user to reload the extension in the alternate browser.
4. Wait a few seconds for the native host to respawn.
5. Retry from Step 4.

### Step 7: Report status

After diagnostics succeed, report a clear status table:

```
| Browser        | Status      | Tab Group | Notes |
|----------------|-------------|-----------|-------|
| Primary        | Connected   | 12345     |       |
| Alternate (if) | Connected   | 67890     |       |
```

### Step 8: Log incident if unresolved

If the full diagnostic procedure (Steps 1–6) fails to restore the connection, **log the incident** before escalating to the user. This creates a persistent record for pattern analysis.

**Log directory:** `$HOME/.claude/skills/chrome-debug/logs/`
**File naming:** `YYYY-MM-DD_HH-MM-SS.md` (timestamp of the incident)

Write one file per incident with this structure:

```markdown
# Chrome Connection Failure — {YYYY-MM-DD HH:MM:SS}

## Summary
{One-line description: what failed and at which step}

## Environment Snapshot
- Claude Code version: {output of `claude --version`}
- Native host wrapper version: {version from chrome-native-host script}
- Native host process: {running PID + version, or "not running"}
- Native host process count: {count of chrome-native-host processes}
- Chrome/Chromium process count: {count of chrome/chromium processes}
- Extension config valid: {yes/no + any issues}
- Machine context present: {yes/no}

## Diagnostic Steps Attempted
{For each step attempted, record: what was done, what was observed, pass/fail}

### Step 2: Native host health
- Running process: {details or "none"}
- Wrapper script version: {version}
- Version match: {yes/no/N/A}
- Action taken: {e.g., "killed stale PID 12345" or "no action needed"}

### Step 3: Extension config
- Config valid: {yes/no}
- Issues: {any problems found}

### Step 4: tabs_context_mcp
- Attempt 1: {result or error message}
- Attempt 2: {result or error message}
- Attempt 3: {result or error message}

### Step 6: Full restart
- Processes killed: {PIDs}
- User actions requested: {what was asked}
- Result after restart: {still failing — details}

## Error Messages
{Exact error messages from failed tool calls, copy-pasted verbatim}

## Context
- Invoked from: {main context / agent name if known}
- Trigger: {what original action failed that led to /uc:chrome-debug}
- Time of day: {useful for correlating with system load}
- Recent Claude Code update: {yes/no — if wrapper version differs from running process}

## Hypothesis
{Best guess at root cause based on the evidence — e.g., "Bridge appears down, both browsers unreachable despite valid local config" or "Extension service worker likely suspended, user reload may not have fully restarted it"}
```

Create this log by running:
```bash
mkdir -p "$HOME/.claude/skills/chrome-debug/logs"
LOG_FILE="$HOME/.claude/skills/chrome-debug/logs/$(date +%Y-%m-%d_%H-%M-%S).md"
```

Then write the file using the Write tool. **Always log before escalating** — the log captures ephemeral state (process lists, error messages) that will be lost once the session ends.

## Known Failure Modes

### Stale native host (most common)
**Symptom**: Intermittent timeouts, works sometimes but not reliably.
**Cause**: Claude Code updated but the native host process still runs the old version. The old binary may have subtle incompatibilities with the current extension protocol.
**Frequency**: Every time Claude Code auto-updates (check with `claude --version`).

### Service worker idle
**Symptom**: "No browser responded within the timeout" after the browser has been open but idle for a while.
**Cause**: Chrome suspends inactive extension service workers to save resources. When suspended, the extension can't respond to bridge messages.
**Fix**: Reload extension or click the Claude in Chrome extension icon in the browser toolbar to wake it up.

### Bridge pairing race
**Symptom**: `switch_browser` connects to the wrong browser (dual-browser setups only).
**Cause**: Two browsers compete to respond to the broadcast. The first responder wins, which is non-deterministic.
**Fix**: Call `switch_browser` again — the other browser will usually respond next.

### switch_browser naming prompt timeout (very common)
**Symptom**: `switch_browser` times out with "No browser responded within the timeout".
**Cause**: `switch_browser` triggers a "Name this browser" prompt in the extension. The connection BLOCKS until the user types a name and confirms. If the user doesn't respond in time, it times out. This is NOT a bridge race — retrying without warning the user will just timeout again.
**Fix**: Before calling `switch_browser`, always warn the user: "I'm about to switch browsers. Please watch for the 'Name this browser' prompt in [target browser] and confirm it quickly." Then call `switch_browser`.

### Native messaging manifest pointing to a profile path (multi-account setups)
**Symptom**: Chrome can't launch the native host. Extension appears disconnected. `tabs_context_mcp` fails consistently — not intermittently like a stale native host.
**Cause**: Multi-account Claude Code setups that use `CLAUDE_CONFIG_DIR` with per-profile directories (e.g., `~/.claude-profiles/{name}/`) where `chrome/` is symlinked back to `~/.claude/chrome/` may have had the native messaging manifest rewritten by `claude auth login` with the profile's path instead of the canonical `~/.claude/chrome/chrome-native-host`. If that profile is later renamed/deleted, the manifest breaks.
**Check**: In Step 3, verify the manifest `path` field points to the canonical `$HOME/.claude/chrome/chrome-native-host`, not a profile directory.
**Fix**: Update the manifest path to the canonical location:
```bash
python3 -c "
import json, os
home = os.environ['HOME']
for p in [
    f'{home}/.config/google-chrome/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json',
    f'{home}/.config/chromium/NativeMessagingHosts/com.anthropic.claude_code_browser_extension.json'
]:
    try:
        with open(p) as f: d = json.load(f)
        d['path'] = f'{home}/.claude/chrome/chrome-native-host'
        with open(p, 'w') as f: json.dump(d, f, indent=2)
    except FileNotFoundError: pass
"
```

### Chrome/Chromium process bloat
**Symptom**: Sluggish browser, extension unresponsive.
**Cause**: Chromium-based browsers accumulate renderer processes over long uptimes.
**Check**: `ps aux | grep -c chromium` (or `chrome`). If over 30 processes, consider restarting the browser.

## Browser Naming Prompt

The extension asks the user to name the browser every time the native host reconnects. There is **no way to persist or pre-configure browser names** — this is a known upstream limitation. Open feature requests:

- [anthropics/claude-code#15125](https://github.com/anthropics/claude-code/issues/15125) — Target specific Chrome instances
- [anthropics/claude-code#14536](https://github.com/anthropics/claude-code/issues/14536) — Browser selection options

The naming prompt fires on: **every `switch_browser` call**, native host restart, extension reload, or bridge reconnection. There is no bypass, no pre-configuration, and no auto-accept. The prompt blocks the connection until the user responds — if they don't respond in time, it times out.

**Strategic implications for automation:**
- **Minimize browser switches.** Plan your testing to batch work by browser rather than switching back and forth.
- **Never retry `switch_browser` autonomously** — each retry triggers a new naming prompt that blocks again. Warn the user and wait.
- **Don't kill the native host or reload the extension unnecessarily** — each triggers the naming prompt.

## Known Upstream Issues

- [anthropics/claude-code#21299](https://github.com/anthropics/claude-code/issues/21299) — Remote/SSH browser control not officially supported
- [anthropics/claude-code#25551](https://github.com/anthropics/claude-code/issues/25551) — Wrong browser connection with multiple instances
- [anthropics/claude-code#15125](https://github.com/anthropics/claude-code/issues/15125) — No persistent browser naming
- [anthropics/claude-code#14536](https://github.com/anthropics/claude-code/issues/14536) — No browser selection options

## VM/Host Deployments — Port Convention

If Claude Code runs inside a VM and the primary Chrome install runs on a host machine that reaches the VM over a shared network, dev servers must bind `0.0.0.0` (not loopback) and be reached via the VM's external IP (not `localhost`/`127.0.0.1`). From the host's perspective, `localhost` resolves to the host itself, not the VM.

If Chrome gets connection refused on `VM_IP:PORT`, check the binding from inside the VM:

```bash
ss -tlnp | grep :PORT
```

If the binding is `127.0.0.1`, fix the dev server to bind `0.0.0.0`. Don't work around the problem by using `localhost` in the browser — that's treating the symptom, not the cause.

This convention is machine-specific. Users with VM setups should capture the VM IP and port rule in `~/.claude/skills/machine-context/network.md` so this skill can surface the exact address. Users without a VM can ignore this section.

## Quick Health Check

For a fast pre-flight before browser automation sessions, run Steps 2 and 4 only. If both pass, you're good to go. The full procedure is for when something is already broken.
