# Logs & Debugging

All commands below assume the token is resolved from config. Always prefix with `RAILWAY_API_TOKEN=<token>`.

## Logs

### Stream Deployment Logs

```bash
# Stream logs from the current service
RAILWAY_API_TOKEN=<token> railway logs

# Stream logs from a specific service
RAILWAY_API_TOKEN=<token> railway logs -s api-server

# Show only the last N lines
RAILWAY_API_TOKEN=<token> railway logs -n 100

# View build logs (not runtime logs)
RAILWAY_API_TOKEN=<token> railway logs --build

# Target a specific environment
RAILWAY_API_TOKEN=<token> railway logs -e staging

# Show logs from the LATEST deployment, even if failed/crashed
RAILWAY_API_TOKEN=<token> railway logs --latest

# Show logs from a specific deployment by ID
RAILWAY_API_TOKEN=<token> railway logs <DEPLOYMENT_ID>

# Filter logs by level
RAILWAY_API_TOKEN=<token> railway logs --filter "@level:error"

# Time-based filtering
RAILWAY_API_TOKEN=<token> railway logs --since 2h
RAILWAY_API_TOKEN=<token> railway logs --since 30m --until 10m
```

### Build Logs vs Runtime Logs

- **Build logs** (`--build`): What happened during `npm install`, `pip install`, Docker build, etc. Check here when deploys fail before starting.
- **Runtime logs** (default): What your app outputs to stdout/stderr after it starts. Check here when the app crashes or misbehaves.

### Listing Deployments

```bash
# List recent deployments with status, time, and IDs
RAILWAY_API_TOKEN=<token> railway deployment list --limit 5 --json

# List deployments for a specific service
RAILWAY_API_TOKEN=<token> railway deployment list -s api-server --limit 5 --json
```

The JSON output includes deployment IDs, statuses (SUCCESS, FAILED, CRASHED, BUILDING, etc.), and timestamps. Use this to:
- **Identify which deployment is newest** — not just the active one
- **Get the deployment ID** to pass to `railway logs <DEPLOYMENT_ID>` for targeted log inspection
- **See the status progression** — did it fail during build, crash after start, or is it still building?

### `--latest` vs Default Behavior

**Critical distinction:**
- `railway logs` (no flag) — shows logs from the most recent **successful** deployment, or the latest if none succeeded. When debugging a crash, this often shows the OLD working deployment, not the broken one.
- `railway logs --latest` — always shows logs from the **newest deployment by time**, regardless of status. This is what you want when debugging.

**Always use `--latest` when debugging deployment failures.**

## Status

```bash
# Show current project, service, and environment info
RAILWAY_API_TOKEN=<token> railway status

# Check which account the token belongs to
RAILWAY_API_TOKEN=<token> railway whoami
```

## Debugging Workflow

When something goes wrong, follow this sequence:

### 1. Confirm Context
```bash
RAILWAY_API_TOKEN=<token> railway status
```
Confirm you're looking at the right project/service/environment before investigating.

### 2. List Recent Deployments
```bash
RAILWAY_API_TOKEN=<token> railway deployment list --limit 5 --json
```
Identify the **newest deployment** and its status. Key things to look for:
- **FAILED** or **CRASHED** — the deployment broke; you need its logs
- **BUILDING** — still in progress; wait or check build logs
- **SUCCESS** on latest but app is broken — runtime issue, not deploy issue
- Note the **deployment ID** of the problematic deployment for targeted log inspection

### 3. Check Runtime Logs (Latest Deployment)
```bash
# Always use --latest when debugging to see the newest deployment's logs
RAILWAY_API_TOKEN=<token> railway logs --latest -n 200

# Or target a specific deployment by ID (from step 2)
RAILWAY_API_TOKEN=<token> railway logs <DEPLOYMENT_ID> -n 200

# Filter to errors only if output is noisy
RAILWAY_API_TOKEN=<token> railway logs --latest --filter "@level:error"
```
Look for crash messages, unhandled errors, connection failures, OOM kills.

### 4. Check Build Logs
```bash
RAILWAY_API_TOKEN=<token> railway logs --build
```
If the deployment status is FAILED and runtime logs are empty, the issue is in the build phase — missing dependencies, syntax errors, wrong runtime version.

### 5. Check Variables
```bash
RAILWAY_API_TOKEN=<token> railway variable list
```
Missing or wrong environment variables are a top cause of failures — especially DATABASE_URL, API keys, and PORT.

### 6. SSH In (if running)
```bash
RAILWAY_API_TOKEN=<token> railway ssh
```
If the service is running but misbehaving, SSH in to inspect the filesystem, check processes, or test connectivity.

### 7. Open Dashboard
```bash
RAILWAY_API_TOKEN=<token> railway open
```
Sometimes the web dashboard has info not available via CLI — deployment history, metrics, resource usage.

## Common Issues

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Deploy fails during build | Missing dependency, wrong runtime version | Check build logs, add `nixpacks.toml` or `Dockerfile` |
| App starts then crashes | Missing env var, wrong DATABASE_URL | Check `railway variable list`, compare with local `.env` |
| "Port already in use" | App hardcodes port instead of using `$PORT` | Use `process.env.PORT` — Railway assigns the port |
| Timeout on health check | App takes too long to start | Increase start command timeout, optimize startup |
| Auth error on CLI command | Token expired or revoked | Generate new token from Railway dashboard |
| "Project not found" | Token doesn't have access to this project | Check `railway whoami`, verify project membership |
| Slow deploys | Large build context | Add `.railwayignore` to exclude `node_modules`, `.git`, etc. |
| `railway logs` shows old/working deployment | Default shows last successful deploy, not latest | Use `railway logs --latest` or `railway logs <DEPLOYMENT_ID>` |
| Can't tell which deployment failed | Multiple recent deploys, unclear status | Run `railway deployment list --limit 5 --json` to see statuses and timestamps |

## Railway-Specific Behavior

- **PORT**: Railway sets the `PORT` env var. Your app must listen on `$PORT`, not a hardcoded value.
- **Health checks**: Railway pings your app to verify it started. If your app doesn't respond to HTTP on `$PORT` within the timeout, the deploy is marked as failed.
- **Automatic restarts**: Railway restarts crashed services automatically, but check logs to fix the root cause rather than relying on restarts.
- **Deploy hooks**: Railway can run commands before/after deploy via `railway.toml`. Useful for migrations.
- **Log defaults**: `railway logs` without flags shows the most recent successful deployment. Use `--latest` to always see the newest deployment regardless of status. This matters most when debugging — without `--latest`, you may be reading logs from the old working deployment.
