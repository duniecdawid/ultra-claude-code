# Config as Code

Railway supports defining build and deploy settings in `railway.toml` or `railway.json` files alongside your code. Config in code always overrides dashboard settings, giving you version-controlled, reproducible deployments.

## Why Config Files Over Dashboard

Manual dashboard configuration drifts over time and can't be reviewed in PRs. Config files mean:
- Settings are version-controlled and reviewable
- New team members get the right config automatically
- Deployments are reproducible across environments
- No "someone changed a setting in the dashboard" surprises

## File Format

TOML and JSON are equivalent — use whichever you prefer. TOML is more readable for simple configs.

```toml
# railway.toml
[build]
builder = "RAILPACK"
buildCommand = "npm run build"

[deploy]
startCommand = "npm run start"
healthcheckPath = "/api/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

```json
// railway.json — equivalent
{
  "$schema": "https://railway.com/railway.schema.json",
  "build": {
    "builder": "RAILPACK",
    "buildCommand": "npm run build"
  },
  "deploy": {
    "startCommand": "npm run start",
    "healthcheckPath": "/api/health",
    "healthcheckTimeout": 300,
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 3
  }
}
```

The JSON schema at `https://railway.com/railway.schema.json` provides autocomplete in VS Code.

## Multi-Service Repos

When a single repo deploys multiple Railway services, create a separate config file for each service. The default `railway.toml` goes to the main service; additional services get named files like `railway-worker.toml`.

### Pattern: Named Config Files

```
my-project/
├── railway.toml              # Main web service
├── railway-worker.toml       # Background worker
├── railway-ai-worker.toml    # AI processing worker
├── railway-cron.toml         # Scheduled jobs
├── docker/
│   └── Dockerfile.custom     # Custom Docker build (if needed)
├── src/
│   └── ...
└── package.json
```

Each Railway service must be configured to use its specific config file. Set the config file path in Railway service settings (absolute from repo root):
- Main service: `/railway.toml` (auto-detected)
- Worker service: `/railway-worker.toml`
- AI worker: `/railway-ai-worker.toml`

Set this via the dashboard (Service > Settings > Railway Config File) or via CLI:
```bash
# The config file path is set per-service in Railway's dashboard
# Service > Settings > Source > Railway Config File
# Enter the absolute path, e.g.: /railway-worker.toml
```

### Example: Web + Workers

**Main web service** (`railway.toml`):
```toml
[build]
builder = "RAILPACK"

[deploy]
startCommand = "npm run start"
healthcheckPath = "/api/health"
healthcheckTimeout = 300
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

**Background worker** (`railway-worker.toml`):
```toml
[build]
builder = "RAILPACK"

[deploy]
startCommand = "npm run enrich:worker"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

Workers typically have no healthcheck (no HTTP endpoint) and use a different start command.

**AI worker** (`railway-ai-worker.toml`):
```toml
[build]
builder = "RAILPACK"

[deploy]
startCommand = "npx tsx src/scripts/ai-enrich-worker.ts"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

### Monorepo Pattern: Subdirectory Configs

For monorepos with isolated subdirectories, each service can have its own `railway.toml` inside its directory:

```
monorepo/
├── frontend/
│   ├── railway.toml           # Frontend config
│   └── src/
├── backend/
│   ├── railway.toml           # Backend config
│   └── src/
└── worker/
    ├── railway.toml           # Worker config
    └── src/
```

Set the config path in Railway as `/frontend/railway.toml`, `/backend/railway.toml`, etc. Note: the config file path does NOT follow the root directory setting — always use absolute paths from the repo root.

## Configurable Settings Reference

### Build Settings

| Setting | Type | Description |
|---------|------|-------------|
| `builder` | `"RAILPACK"` or `"DOCKERFILE"` | Build system (default: RAILPACK; auto-uses Dockerfile if present) |
| `buildCommand` | string | Build command passed to builder |
| `dockerfilePath` | string | Path to non-standard Dockerfile (e.g., `docker/Dockerfile.custom`) |
| `watchPatterns` | string[] | Paths that trigger deploys (e.g., `["src/**", "package.json"]`) |
| `railpackVersion` | string | Pin a specific Railpack version |

### Deploy Settings

| Setting | Type | Description |
|---------|------|-------------|
| `startCommand` | string | Command to start the service |
| `preDeployCommand` | string[] | Commands to run before start (e.g., migrations) |
| `healthcheckPath` | string | HTTP path to check service health |
| `healthcheckTimeout` | number | Seconds to wait for healthy response |
| `restartPolicyType` | `"ON_FAILURE"` / `"ALWAYS"` / `"NEVER"` | Restart behavior on crash |
| `restartPolicyMaxRetries` | number | Max restart attempts |
| `cronSchedule` | string | Cron expression for scheduled services |
| `multiRegionConfig` | object | Multi-region replica configuration |
| `overlapSeconds` | number | Overlap time during zero-downtime deploy |
| `drainingSeconds` | number | Grace period between SIGTERM and SIGKILL |

### Environment Overrides

Override settings per environment by nesting under `environments.<name>`:

```toml
# Base config
[deploy]
startCommand = "npm run start"

# Override for staging
[environments.staging.deploy]
startCommand = "npm run staging"

# Override for PR environments
[environments.pr.deploy]
startCommand = "npm run preview"
```

Priority order: environment-specific config > base config > dashboard settings.

## Creating Config Files for an Existing Project

When adding config-as-code to a project that already has services running:

1. **Check current settings** — look at each service's build and deploy settings in the dashboard
2. **Create TOML files** — one per service, capturing the current settings
3. **Set config file paths** — point each Railway service to its config file
4. **Deploy** — the config file takes effect on the next deployment
5. **Verify** — check deployment details to confirm settings came from the config file (file icon indicator in dashboard)

Dashboard settings remain as fallbacks — config files override them but don't delete them.

## Watch Patterns for Multi-Service

To prevent changes in one service from triggering rebuilds of others, use `watchPatterns`:

```toml
# railway-worker.toml — only rebuild when worker code changes
[build]
builder = "RAILPACK"
watchPatterns = ["src/scripts/enrich-worker.ts", "src/lib/enrichment/**", "package.json"]

[deploy]
startCommand = "npm run enrich:worker"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3
```

This is especially important in multi-service repos where a single git push would otherwise trigger all services to rebuild.
