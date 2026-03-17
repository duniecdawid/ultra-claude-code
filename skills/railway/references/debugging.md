# Logs & Debugging

All commands below assume the token is resolved from config. Always prefix with `RAILWAY_TOKEN=<token>`.

## Logs

### Stream Deployment Logs

```bash
# Stream logs from the current service
RAILWAY_TOKEN=<token> railway logs

# Stream logs from a specific service
RAILWAY_TOKEN=<token> railway logs -s api-server

# Show only the last N lines
RAILWAY_TOKEN=<token> railway logs -n 100

# View build logs (not runtime logs)
RAILWAY_TOKEN=<token> railway logs --build

# Target a specific environment
RAILWAY_TOKEN=<token> railway logs -e staging
```

### Build Logs vs Runtime Logs

- **Build logs** (`--build`): What happened during `npm install`, `pip install`, Docker build, etc. Check here when deploys fail before starting.
- **Runtime logs** (default): What your app outputs to stdout/stderr after it starts. Check here when the app crashes or misbehaves.

## Status

```bash
# Show current project, service, and environment info
RAILWAY_TOKEN=<token> railway status

# Check which account the token belongs to
RAILWAY_TOKEN=<token> railway whoami
```

## Debugging Workflow

When something goes wrong, follow this sequence:

### 1. Check Status
```bash
RAILWAY_TOKEN=<token> railway status
```
Confirm you're looking at the right project/service/environment.

### 2. Check Runtime Logs
```bash
RAILWAY_TOKEN=<token> railway logs -n 200
```
Look for crash messages, unhandled errors, connection failures.

### 3. Check Build Logs
```bash
RAILWAY_TOKEN=<token> railway logs --build
```
If the service never started, the issue is in the build phase.

### 4. Check Variables
```bash
RAILWAY_TOKEN=<token> railway variable list
```
Missing or wrong environment variables are a top cause of failures — especially DATABASE_URL, API keys, and PORT.

### 5. SSH In (if running)
```bash
RAILWAY_TOKEN=<token> railway ssh
```
If the service is running but misbehaving, SSH in to inspect the filesystem, check processes, or test connectivity.

### 6. Open Dashboard
```bash
RAILWAY_TOKEN=<token> railway open
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

## Railway-Specific Behavior

- **PORT**: Railway sets the `PORT` env var. Your app must listen on `$PORT`, not a hardcoded value.
- **Health checks**: Railway pings your app to verify it started. If your app doesn't respond to HTTP on `$PORT` within the timeout, the deploy is marked as failed.
- **Automatic restarts**: Railway restarts crashed services automatically, but check logs to fix the root cause rather than relying on restarts.
- **Deploy hooks**: Railway can run commands before/after deploy via `railway.toml`. Useful for migrations.
