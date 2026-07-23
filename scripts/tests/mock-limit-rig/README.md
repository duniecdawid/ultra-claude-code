# Mock Limit Rig

A local reverse proxy that impersonates the Anthropic API so a **real, live Claude Code
session** can be driven into the usage-limit state — banner, `/rate-limit-options` menu,
`StopFailure(rate_limit)` hook and all — **without burning any real quota**, and then released
again. This is the practice harness for the limit sentinel (`scripts/limit-sentinel.sh`) and the
fixture behind `skills/plan-execution/references/limit-drill.md`.

Verified against Claude Code 2.1.218 (2026-07-23): the reject response is indistinguishable from
a genuine subscription 5h-limit hit — the client renders
`You've hit your session limit · resets <local time>` (it localizes the epoch we advertise) and
parks at the composer after the menu.

## Requirements

python3 with `requests` (stdlib otherwise). No API key — the proxied session's own OAuth
credentials pass through untouched, and they never leave the machine (127.0.0.1 only).

## Usage

```bash
# 1. start the gateway (defaults: port 8399, state files next to gateway.py)
python3 gateway.py 8399 --state-dir /tmp/limit-rig &

# 2. launch a DISPOSABLE Claude Code session through it (ideally in tmux, in a scratch dir)
tmux new-session -d -s limit-drill -c /tmp/limit-drill-project \
  -e ANTHROPIC_BASE_URL=http://127.0.0.1:8399 'claude'

# 3. simulate the limit: advertise a reset ~3 min out, flip to reject, send any prompt
echo $(( $(date +%s) + 180 )) > /tmp/limit-rig/RESET_EPOCH
echo reject > /tmp/limit-rig/MODE
# -> the session shows the real limit banner + menu and parks; StopFailure fires

# 4. release: flip back before/at the advertised reset
echo pass > /tmp/limit-rig/MODE
# -> nothing happens by itself (verified: no native auto-resume) until something
#    wakes the session — which is exactly the sentinel's job
```

`MODE` is re-read on every request, so flips take effect immediately. `access.log` in the state
dir records each request and how it was answered.

## What reject mode returns

`POST /v1/messages*` (except `count_tokens`) gets HTTP 429 with:

| Header | Value |
|---|---|
| `anthropic-ratelimit-unified-status` | `rejected` |
| `anthropic-ratelimit-unified-reset` | epoch from `RESET_EPOCH` |
| `anthropic-ratelimit-unified-representative-claim` | `five_hour` |
| `anthropic-ratelimit-unified-fallback` | `unavailable` |
| `retry-after` | seconds until the advertised reset |

Body: `{"type":"error","error":{"type":"rate_limit_error","message":"Claude AI usage limit reached|<epoch>"}}`.
Every other request — and everything in `pass` mode — proxies to `https://api.anthropic.com`
with SSE streaming preserved.

## Gotchas learned building this

- Ask upstream for **identity encoding** and never relay `content-encoding` — `requests`
  transparently decompresses, and relaying the original header with plain bytes makes the client
  fail with `ZlibError`.
- SSE must be relayed **close-delimited** (`connection: close`, flush per chunk).
- The client sends the whole prompt as one `POST /v1/messages?beta=true` — rejecting only that
  path keeps auth/telemetry endpoints working so the TUI stays healthy while "limited".
