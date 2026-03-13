---
description: Configure Tailscale for exposing local services (dashboards, dev servers) via HTTPS. Checks installation, connection, operator mode, and serve/funnel readiness. Fixes what it can automatically, guides the user through manual steps. Use when setting up Tailscale, exposing a local port, troubleshooting serve/funnel, or preparing for PM dashboard access. Triggers on "tailscale setup", "tailscale serve", "tailscale funnel", "expose port", "expose local service", "tailscale config", "mobile access".
user-invocable: true
argument-hint: "what to configure (optional, e.g. 'serve', 'funnel', 'full setup')"
---

# Tailscale Setup

Configure Tailscale so local services can be exposed securely — either within the tailnet (serve) or publicly (funnel). The PM status dashboard depends on this for mobile access.

## Why This Matters

`tailscale serve` turns a local port into an HTTPS endpoint accessible from any device on your tailnet. `tailscale funnel` makes it public. Both require a chain of prerequisites to be in place — this skill walks through each one and fixes what it can.

## Process

### Step 1: Detect Current State

Run these checks in parallel:

```bash
# Is tailscale installed?
which tailscale 2>/dev/null

# Is it connected?
tailscale status --self --json 2>/dev/null

# Is operator mode set? (allows serve/funnel without sudo)
# If the current user can run `tailscale serve status` without sudo, operator is set
tailscale serve status 2>&1

# What's the machine's tailscale hostname?
tailscale status --self --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('Self',{}).get('DNSName','').rstrip('.'))"

# What's the tailscale IP?
tailscale ip -4 2>/dev/null
```

Build a state object from the results:

| Check | How to detect | Status |
|-------|--------------|--------|
| **Installed** | `which tailscale` returns a path | yes/no |
| **Connected** | `tailscale status` exits 0, JSON shows `Online: true` | yes/no |
| **Operator set** | `tailscale serve status` doesn't say "Access denied" | yes/no |
| **Serve enabled** | `tailscale serve --bg 3847` doesn't say "Serve is not enabled" | yes/no/unknown |
| **Funnel enabled** | Only if user asks for funnel — check admin console | yes/no/unknown |

### Step 2: Fix What Can Be Fixed Automatically

Work through the chain in order — each step depends on the previous one:

**1. Not installed →** Tell the user:
```
Tailscale is not installed. Install it:
  curl -fsSL https://tailscale.com/install.sh | sh
Then run this skill again.
```

**2. Not connected →** Tell the user:
```
Tailscale is installed but not connected. Run:
  sudo tailscale up
Then authenticate in the browser when prompted.
```

**3. Operator not set →** This needs sudo once, then never again. Tell the user:
```
Tailscale operator mode is not set. This means serve/funnel need sudo every time.
Run this once to fix it permanently:
  sudo tailscale set --operator=$USER
```
After the user confirms they've run it, verify with `tailscale serve status` again.

**4. Serve not enabled on tailnet →** When `tailscale serve` returns "Serve is not enabled", extract the URL from the error output (it contains a link like `https://login.tailscale.com/f/serve?node=...`). Tell the user:
```
Tailscale Serve needs to be enabled on your tailnet.
Open this link and approve it:
  {extracted URL}
```

**5. Everything ready →** Report the configuration:
```
Tailscale is fully configured:
  Machine:  {hostname}.{tailnet}.ts.net
  IP:       {tailscale-ip}
  Operator: ✓ (no sudo needed)
  Serve:    ✓ ready

To expose a local service:
  tailscale serve --bg {port}     # Tailnet only (HTTPS)
  tailscale funnel --bg {port}    # Public internet (HTTPS)

Dashboard will be at: https://{hostname}.{tailnet}.ts.net/
```

### Step 3: Handle Specific Requests

If `$ARGUMENTS` specifies a particular action:

**"serve" or "expose port N"** — after ensuring prerequisites, run:
```bash
tailscale serve --bg {port}
tailscale serve status
```
Report the resulting URL.

**"funnel"** — same as serve but with `tailscale funnel --bg {port}`. Warn: this is publicly accessible.

**"status"** — just report current state without changing anything:
```bash
tailscale serve status
tailscale status --self --json
```

**"reset" or "stop"** — tear down existing serve/funnel:
```bash
tailscale serve --https=443 off
```

**"full setup"** or no arguments — walk through all steps above.

## Important Notes

- **Serve vs Funnel**: `serve` = tailnet only (your devices). `funnel` = public internet. Default to `serve` unless user explicitly asks for funnel.
- **Port conflicts**: If serve fails with EADDRINUSE, check what's already on that port with `fuser {port}/tcp` or `lsof -i :{port}`.
- **Multiple services**: Tailscale serve can only expose one service per HTTPS port (443). To serve multiple local ports, use path-based routing: `tailscale serve --set-path /dashboard localhost:3847`.
- **Idempotent**: Running `tailscale serve --bg {port}` when it's already serving that port is safe — it updates the config.
- **Cleanup**: Always `tailscale serve --https=443 off` when done, or the proxy persists across reboots.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "Access denied: serve config denied" | Operator not set | `sudo tailscale set --operator=$USER` |
| "Serve is not enabled" | Tailnet admin hasn't enabled | Visit the URL in the error message |
| HTTPS works locally but not from phone | Phone not on tailnet | Install Tailscale app on phone, join same tailnet |
| "address already in use" | Something else on port 443 | Check with `fuser 443/tcp`, or use a different port |
| Serve works but funnel doesn't | Funnel needs separate enablement | Check tailnet admin: Access controls → Funnel |
