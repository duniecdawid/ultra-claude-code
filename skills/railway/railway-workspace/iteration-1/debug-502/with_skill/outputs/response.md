# Debugging Your Railway 502

A 502 means Railway's proxy can't reach your service — either the app crashed, never started, or isn't listening on the right port. Let's work through it systematically.

---

## Step 1: Confirm which project/account you're targeting

Before doing anything, make sure you're looking at the right service. Run:

```bash
RAILWAY_TOKEN=<your-token> railway status
```

This shows the current project, service, and environment. If you're not sure which token to use, check `~/.config/railway-cli/config.json` for the mapping from your project directory to its account token.

---

## Step 2: Check runtime logs

This is usually where the answer lives. Run:

```bash
RAILWAY_TOKEN=<your-token> railway logs -n 200
```

You're looking for:
- Stack traces or unhandled exceptions
- "Cannot connect to database" or similar connection errors
- The app exiting with a non-zero code
- Any `Error:` lines appearing right before the service went down

If you want to target a specific service by name:

```bash
RAILWAY_TOKEN=<your-token> railway logs -s api -n 200
```

---

## Step 3: Check build logs

If the app never started at all (e.g. a recent deploy broke the build), the runtime logs may be empty. Check the build phase:

```bash
RAILWAY_TOKEN=<your-token> railway logs --build
```

Look for:
- Failed `npm install` / `pip install` / `cargo build`
- Missing package or wrong Node/Python/runtime version
- A build step that errored out

---

## Step 4: Check environment variables

Missing or changed env vars are one of the most common causes of overnight regressions — especially if something was rotated or accidentally deleted. Run:

```bash
RAILWAY_TOKEN=<your-token> railway variable list
```

Check for:
- `DATABASE_URL` — is it present and pointing to the right database?
- `PORT` — your app should NOT set this manually; Railway injects it. If your app hardcodes a port (e.g. `3000`), it will fail Railway's health check. Use `process.env.PORT` instead.
- Any API keys or secrets the app depends on at startup

---

## Step 5: Open the dashboard for deployment history

```bash
RAILWAY_TOKEN=<your-token> railway open
```

In the dashboard, look at:
- The deployment timeline — did a new deploy go out overnight?
- Metrics — did memory or CPU spike before the 502s started?
- Health check history — is the service marked as crashed or unhealthy?

---

## Most Likely Causes Given "Was Working Yesterday"

| What changed | Symptom | Where to look |
|---|---|---|
| A new deploy went out | App crashes on startup | Runtime logs, build logs |
| An env var was rotated/deleted | DB connection error, auth failure | `variable list` |
| App hardcodes PORT instead of `$PORT` | 502 on all requests | Runtime logs, your server startup code |
| Database ran out of connections or went down | Connection pool error | Runtime logs |
| Memory limit hit | OOM kill in logs | Dashboard metrics + runtime logs |

---

## Quick Summary: Commands to Run in Order

```bash
# 1. Confirm you're on the right project
RAILWAY_TOKEN=<token> railway status

# 2. Check runtime logs first
RAILWAY_TOKEN=<token> railway logs -n 200

# 3. If the app never started, check build logs
RAILWAY_TOKEN=<token> railway logs --build

# 4. Check env vars for missing/changed values
RAILWAY_TOKEN=<token> railway variable list

# 5. Open dashboard for visual deployment history
RAILWAY_TOKEN=<token> railway open
```

---

Share what you see in the logs and I can help you pinpoint the exact fix.
