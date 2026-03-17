# Response: Deploy to Railway — Auth Error / Wrong Account

Auth errors almost always mean the CLI is using the wrong token (or no token at all). Let me walk you through diagnosing which account you're authenticated as, switching to the right one, and then deploying cleanly.

---

## Step 1: Check the current config

First, let's see what accounts and project mappings are already set up:

```bash
cat ~/.config/railway-cli/config.json
```

This shows all your saved Railway accounts and which local directories are mapped to each one. If the file doesn't exist, you'll need to set it up from scratch (see the "First-time setup" section below).

---

## Step 2: See which account is currently mapped to your project

Your project lives at `/home/user/Projects/ClientApp`. Check if that directory has an account mapping in the config.

Look for an entry under `"projects"` that matches `/home/user/Projects/ClientApp`. It should look something like:

```json
"/home/user/Projects/ClientApp": {
  "account": "some-account-name"
}
```

If it's missing, or pointing to the wrong account name, that's the problem.

---

## Step 3: Verify which account each token belongs to

For each account in the config, you can confirm the identity with:

```bash
RAILWAY_TOKEN=<token-from-config> railway whoami
```

Run this for each account token until you find the one that matches the account you want to deploy to. This tells you which Railway user/team each token is scoped to.

---

## Step 4: Fix the mapping

**Option A — The account is already in your config but the project isn't mapped to it:**

Edit `~/.config/railway-cli/config.json` and add or update the entry for your project directory:

```json
{
  "accounts": {
    "your-account-name": {
      "token": "railway-token-xxxx",
      "description": "The account you want to use"
    }
  },
  "projects": {
    "/home/user/Projects/ClientApp": {
      "account": "your-account-name"
    }
  }
}
```

**Option B — The account isn't in your config yet (new token needed):**

1. Go to the Railway dashboard for the correct account
2. Navigate to **Account Settings → Tokens** (for an API token) or **Project → Settings → Tokens** (for a project-scoped token)
3. Click **Create Token** and copy it — it's only shown once
4. Add it to your config under `"accounts"`:

```json
"client-app-account": {
  "token": "railway-token-new-xxxx",
  "description": "Client App Railway account"
}
```

5. Map the project to it:

```json
"/home/user/Projects/ClientApp": {
  "account": "client-app-account"
}
```

6. Verify the token works:

```bash
RAILWAY_TOKEN=railway-token-new-xxxx railway whoami
```

---

## Step 5: Link the project (if not already linked)

If this project hasn't been linked to a Railway project yet, run:

```bash
cd /home/user/Projects/ClientApp
RAILWAY_TOKEN=<correct-token> railway link
```

This connects the local directory to the Railway project in your account. You'll be prompted to select the project from a list.

---

## Step 6: Verify everything before deploying

Always confirm you're about to deploy to the right place:

```bash
cd /home/user/Projects/ClientApp
RAILWAY_TOKEN=<correct-token> railway status
```

This shows the linked project name, environment, and service. Make sure it matches what you expect — deploying to the wrong account/project is the #1 mistake in a multi-account setup.

---

## Step 7: Deploy

Once the status looks right:

```bash
cd /home/user/Projects/ClientApp
RAILWAY_TOKEN=<correct-token> railway up
```

Build logs will stream automatically. If you want to deploy and come back to check logs later:

```bash
RAILWAY_TOKEN=<correct-token> railway up --detach
RAILWAY_TOKEN=<correct-token> railway logs
```

---

## First-time setup (if config file doesn't exist)

If `~/.config/railway-cli/config.json` doesn't exist at all, create it:

```bash
mkdir -p ~/.config/railway-cli
```

Then create the file with your account:

```json
{
  "accounts": {
    "client-app-account": {
      "token": "railway-token-xxxx",
      "description": "Client App Railway account"
    }
  },
  "projects": {
    "/home/user/Projects/ClientApp": {
      "account": "client-app-account"
    }
  },
  "default_account": "client-app-account"
}
```

Verify it:

```bash
RAILWAY_TOKEN=railway-token-xxxx railway whoami
```

Then link and deploy as described in Steps 5–7 above.

---

## Summary of likely cause

The auth error is almost certainly one of these:

1. **No `RAILWAY_TOKEN` set** — the CLI is trying to use a local session from `railway login` that doesn't match the right account, or is expired
2. **Project directory not mapped** — no entry in the config for `/home/user/Projects/ClientApp`, so it falls back to the wrong account or no token at all
3. **Token revoked or expired** — generate a new one from the Railway dashboard

Let me know what you see in the config file and I can help you pinpoint the exact issue.
