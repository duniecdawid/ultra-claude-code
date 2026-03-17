# Variables & Environments

All commands below assume the token is resolved from config. Always prefix with `RAILWAY_TOKEN=<token>`.

## Variables

Railway variables are environment variables injected into your service at runtime.

### List Variables

```bash
# List all variables for the linked service
RAILWAY_TOKEN=<token> railway variable list

# List for a specific service
RAILWAY_TOKEN=<token> railway variable list -s api-server

# List for a specific environment
RAILWAY_TOKEN=<token> railway variable list -e staging

# JSON output (useful for scripting)
RAILWAY_TOKEN=<token> railway variable list --json
```

### Set Variables

```bash
# Set a single variable
RAILWAY_TOKEN=<token> railway variable set DATABASE_URL=postgres://...

# Set multiple variables at once
RAILWAY_TOKEN=<token> railway variable set KEY1=value1 KEY2=value2

# Set for a specific service and environment
RAILWAY_TOKEN=<token> railway variable set -s api-server -e staging SECRET_KEY=abc123
```

Setting a variable triggers a redeploy of the service automatically.

### Delete Variables

```bash
# Delete a variable
RAILWAY_TOKEN=<token> railway variable delete SECRET_KEY

# Delete for a specific service
RAILWAY_TOKEN=<token> railway variable delete -s api-server OLD_VAR
```

### Pull Variables Locally

```bash
# Run a local command with Railway variables injected
RAILWAY_TOKEN=<token> railway run <command>

# Example: run your app locally with production env vars
RAILWAY_TOKEN=<token> railway run npm start

# Open a shell with all variables available
RAILWAY_TOKEN=<token> railway shell
```

This is very useful for local development — you get the same environment as production without maintaining a `.env` file.

## Environments

Railway supports multiple environments per project (e.g., production, staging, development). Each environment has its own variables and deployments.

### Switch Environment

```bash
# Interactive environment picker
RAILWAY_TOKEN=<token> railway environment

# Use a specific environment for one command
RAILWAY_TOKEN=<token> railway variable list -e staging
```

### Create Environment

```bash
# Create a new environment
RAILWAY_TOKEN=<token> railway environment new staging
```

### Delete Environment

```bash
# Delete an environment (careful — this is destructive)
RAILWAY_TOKEN=<token> railway environment delete old-staging
```

## Tips

- **Shared variables**: Variables set at the project level are inherited by all services. Service-level variables override project-level ones.
- **Reference variables**: Railway supports `${{service.variable}}` syntax to reference variables from other services (e.g., database URLs).
- **Sensitive values**: Railway masks variable values in logs. Use `railway variable list` to see them, not logs.
- **Local dev**: `railway run` and `railway shell` are the cleanest ways to get production variables locally without `.env` files. Keep in mind they need the token too.
