---
description: Manage Railway.com deployments via railway-cli with multi-account token support. Handles account switching, project linking, deployments, logs, variables, and services — all without browser login. Each project directory maps to a specific Railway account token so you never deploy to the wrong account. Use when the user mentions Railway, railway deploy, railway logs, railway variables, railway accounts, railway tokens, railway services, railway status, or needs to connect a project to Railway. Triggers on "railway", "deploy to railway", "railway logs", "railway status", "railway variables", "switch railway account", "railway token", "add railway account".
user-invocable: true
argument-hint: "action (e.g. 'deploy', 'logs', 'status', 'add account', 'link project', 'variables')"
---

# Railway

Manage Railway.com projects via railway-cli with multi-account token support. No browser login needed — everything runs through tokens.

## Why Tokens Matter

Railway CLI normally requires `railway login` which opens a browser. When you manage multiple Railway accounts (personal, work, client projects), switching accounts means logging out and back in. Tokens solve this: each project directory maps to an account token, and the skill sets the right token env var automatically before running any command.

## Token Types — Critical Distinction

Railway uses **two different environment variables** depending on token scope:

| Token Type | Env Var | Where to Create | Scope |
|-----------|---------|----------------|-------|
| **API token** (account-level) | `RAILWAY_API_TOKEN` | Dashboard → Account Settings → Tokens | All projects in account/workspace |
| **Project token** | `RAILWAY_TOKEN` | Dashboard → Project → Settings → Tokens | Single project only |

**Use `RAILWAY_API_TOKEN` for multi-account workflows** — it works across all projects in the account. `RAILWAY_TOKEN` is only for project-scoped tokens (CI/CD, single-project automation).

The config stores the token type so the right env var is used automatically.

## Config Location

All account and project mapping data lives in `~/.config/railway-cli/config.json`.

Read `references/config.md` for the config schema and management operations (add/remove accounts, map projects).

## Routing

Based on `$ARGUMENTS` or the user's request, determine the action category:

### Account & Config Management
Triggers: "add account", "remove account", "list accounts", "switch account", "set token", "map project", "which account"

→ Read `references/config.md` and follow the account management instructions.

### Deployment
Triggers: "deploy", "redeploy", "up", "take down", "restart"

→ Read `references/deployment.md` for deploy workflows.

### Logs & Debugging
Triggers: "logs", "build logs", "errors", "debug", "status", "why is it failing"

→ Read `references/debugging.md` for log streaming and troubleshooting.

### Variables & Environments
Triggers: "variables", "env vars", "set variable", "environment", "staging", "production"

→ Read `references/variables.md` for variable and environment management.

### Services & Infrastructure
Triggers: "service", "database", "add postgres", "volume", "domain", "scale"

→ Read `references/services.md` for service and infrastructure management.

### General Status / Info
Triggers: "status", "whoami", "which project", "info"

→ Run status commands with the right token (see below).

## Core Mechanism: Running Commands with the Right Token

Every railway-cli command must run with the correct account token. The flow is:

1. **Determine the project directory** — use the current working directory
2. **Look up the account** — read `~/.config/railway-cli/config.json`, find the project mapping for this directory
3. **Get the token** — resolve the account name to its token
4. **Run the command** — prefix with the correct env var based on token type:
   - API tokens (account-level): `RAILWAY_API_TOKEN=<token> railway <command>`
   - Project tokens: `RAILWAY_TOKEN=<token> railway <command>`

If no mapping exists for the current directory, tell the user and offer to set one up (link the project to an account).

```bash
# Example: deploy with account-level token (most common)
RAILWAY_API_TOKEN=<resolved-token> railway up

# Example: check logs
RAILWAY_API_TOKEN=<resolved-token> railway logs

# Example: list variables
RAILWAY_API_TOKEN=<resolved-token> railway variable list

# Example: with project-scoped token (CI/CD)
RAILWAY_TOKEN=<project-token> railway up
```

### First-Time Setup

If `~/.config/railway-cli/config.json` doesn't exist, guide the user through initial setup:

1. Ask them to create a project token or API token from the Railway dashboard
2. Create the config file with their first account
3. Map the current project directory to that account

Read `references/config.md` for the detailed setup flow.

## Global Flags

These flags work with most railway commands — use them when the user targets a specific service or environment:

| Flag | Purpose |
|------|---------|
| `-s, --service <name>` | Target a specific service |
| `-e, --environment <name>` | Target a specific environment |
| `--json` | Output as JSON (useful for parsing) |
| `-y, --yes` | Skip confirmation prompts |

## Important Notes

- **Always verify the account** before destructive operations (deploy, delete, scale down). Show the user which account and project they're about to affect.
- **Token types matter**: `RAILWAY_API_TOKEN` for account/workspace tokens, `RAILWAY_TOKEN` for project-scoped tokens. Using the wrong env var causes "Unauthorized" errors even with a valid token.
- **railway link** still works — after linking, the project remembers its Railway project ID locally. The token just handles auth.
- If a command fails with auth errors, the token may be expired or revoked. Guide the user to generate a new one.
