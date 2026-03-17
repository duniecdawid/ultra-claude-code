# Account & Config Management

## Config Schema

The config file lives at `~/.config/railway-cli/config.json`:

```json
{
  "accounts": {
    "personal": {
      "token": "railway-token-xxxx",
      "description": "Personal Railway account"
    },
    "work": {
      "token": "railway-token-yyyy",
      "description": "Company workspace"
    },
    "client-acme": {
      "token": "railway-token-zzzz",
      "description": "ACME Corp client project"
    }
  },
  "projects": {
    "/home/user/Projects/MyApp": {
      "account": "personal",
      "service": "web",
      "environment": "production"
    },
    "/home/user/Projects/WorkAPI": {
      "account": "work",
      "service": "api-server",
      "environment": "production"
    }
  },
  "default_account": "personal"
}
```

### Fields

**accounts** — Named Railway accounts, each with:
- `token` — Railway API token or project token
- `description` — Human-readable label (optional but helpful)

**projects** — Maps local directory paths to accounts, with optional defaults:
- `account` — Which account name to use
- `service` — Default service to target (optional, avoids `-s` flag every time)
- `environment` — Default environment (optional, avoids `-e` flag every time)

**default_account** — Fallback when a directory has no mapping

## Getting Tokens

Guide the user to create tokens from the Railway dashboard:

### API Token (account-level, works across all projects)
1. Go to Railway dashboard → Account Settings → Tokens
2. Click "Create Token"
3. Copy the token — it's only shown once

### Project Token (scoped to one project)
1. Go to Railway dashboard → Project → Settings → Tokens
2. Click "Create Token"
3. Copy the token

API tokens are more convenient for multi-project accounts. Project tokens are better for CI/CD or when you want tighter scope.

## Operations

### Add Account

```bash
# 1. Read current config (or create empty one)
cat ~/.config/railway-cli/config.json 2>/dev/null || echo '{"accounts":{},"projects":{}}'

# 2. Add the account (use python/jq to update JSON)
# 3. Write back

# 4. Verify the token works
RAILWAY_TOKEN=<new-token> railway whoami
```

Always verify the token with `railway whoami` after adding. If it fails, the token is invalid.

### Remove Account

Before removing, check if any projects map to this account. Warn the user if so — those projects will lose their mapping.

### List Accounts

Read the config and display:
```
Accounts:
  personal  — Personal Railway account
  work      — Company workspace ← default
  client    — ACME Corp client project

Projects using each:
  personal: /home/user/Projects/MyApp
  work:     /home/user/Projects/WorkAPI
  client:   (none)
```

### Map Project to Account

```bash
# From the project directory:
# 1. Read config
# 2. Add/update entry in "projects" for the current directory
# 3. Optionally link the Railway project: RAILWAY_TOKEN=<token> railway link
# 4. Optionally set default service/environment
```

After mapping, verify with:
```bash
RAILWAY_TOKEN=<token> railway status
```

### Which Account Am I Using?

Look up the current directory in the config. Display:
```
Directory:   /home/user/Projects/MyApp
Account:     personal
Service:     web (default)
Environment: production (default)
```

If no mapping exists, say so and offer to create one.

## First-Time Setup Flow

When the config file doesn't exist:

1. "Looks like this is your first time using Railway with token management. Let's set up your first account."
2. Ask: "What name do you want for this account? (e.g., 'personal', 'work')"
3. Ask: "Paste your Railway API token (get one from Railway dashboard → Account Settings → Tokens)"
4. Create the config file with the account
5. Verify with `RAILWAY_TOKEN=<token> railway whoami`
6. Ask: "Want to map the current project directory to this account?"
7. If yes, add the project mapping and run `RAILWAY_TOKEN=<token> railway link`
