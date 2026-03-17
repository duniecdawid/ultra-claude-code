# Railway Multi-Account Setup Response

Great — since you already have railway-cli installed, let's set you up so you can work with both accounts using tokens. This avoids browser logins entirely; each project directory maps to the right account automatically.

---

## How It Works

We'll create a config file at `~/.config/railway-cli/config.json` that stores named accounts (each with a token) and maps your project directories to the right account. Before running any railway command, you prefix it with `RAILWAY_TOKEN=<token>` — or once mapped, a small helper does this for you automatically.

---

## Step 1: Create API Tokens for Both Accounts

You need one API token per Railway account. API tokens are account-level and work across all projects in that account, which is the most convenient option for your use case.

**For each account:**

1. Log into that Railway account at [railway.app](https://railway.app)
2. Go to **Account Settings → Tokens**
3. Click **Create Token**
4. Copy the token immediately — it's only shown once

Do this for both your personal account and your client account. You'll end up with two tokens:
- `personal-token` (for your personal account)
- `client-token` (for your client project account)

---

## Step 2: Create the Config File

Create the directory and config file:

```bash
mkdir -p ~/.config/railway-cli
```

Then create `~/.config/railway-cli/config.json` with this structure (substituting your real tokens):

```json
{
  "accounts": {
    "personal": {
      "token": "YOUR_PERSONAL_TOKEN_HERE",
      "description": "Personal Railway account"
    },
    "client": {
      "token": "YOUR_CLIENT_TOKEN_HERE",
      "description": "Client project account"
    }
  },
  "projects": {},
  "default_account": "personal"
}
```

---

## Step 3: Verify Both Tokens Work

Run these to confirm both tokens authenticate correctly:

```bash
RAILWAY_TOKEN=YOUR_PERSONAL_TOKEN_HERE railway whoami
RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE railway whoami
```

Each should print the email address of the respective Railway account. If either fails, the token was copied incorrectly or may have been revoked — go back to the Railway dashboard and generate a new one.

---

## Step 4: Map Your Project Directories

Now tell the config which account each local project belongs to. For each project directory, add an entry to the `"projects"` section of the config. For example:

```json
{
  "accounts": {
    "personal": {
      "token": "YOUR_PERSONAL_TOKEN_HERE",
      "description": "Personal Railway account"
    },
    "client": {
      "token": "YOUR_CLIENT_TOKEN_HERE",
      "description": "Client project account"
    }
  },
  "projects": {
    "/home/you/Projects/my-personal-app": {
      "account": "personal",
      "environment": "production"
    },
    "/home/you/Projects/client-project": {
      "account": "client",
      "environment": "production"
    }
  },
  "default_account": "personal"
}
```

Replace the paths with your actual project directories (use absolute paths).

---

## Step 5: Link Each Project to Its Railway Project

From each project directory, run `railway link` with the correct token so the CLI knows which Railway project to target:

```bash
# For your personal project
cd /home/you/Projects/my-personal-app
RAILWAY_TOKEN=YOUR_PERSONAL_TOKEN_HERE railway link

# For your client project
cd /home/you/Projects/client-project
RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE railway link
```

Both commands will prompt you to select the Railway project from a list. After linking, each directory has a `.railway` file recording the project ID.

---

## Step 6: Verify the Setup

From each project directory, confirm the right project and account are being targeted:

```bash
# From personal project dir
cd /home/you/Projects/my-personal-app
RAILWAY_TOKEN=YOUR_PERSONAL_TOKEN_HERE railway status

# From client project dir
cd /home/you/Projects/client-project
RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE railway status
```

Each should show the correct project name and environment.

---

## Day-to-Day Usage

Once set up, always prefix railway commands with the token for the account you're targeting:

```bash
# Deploy personal project
cd /home/you/Projects/my-personal-app
RAILWAY_TOKEN=YOUR_PERSONAL_TOKEN_HERE railway up

# Check client project logs
cd /home/you/Projects/client-project
RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE railway logs

# Set a variable on client project
RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE railway variable set MY_VAR=value
```

**Tip:** To avoid typing the token every time, export it in your shell session when you know you'll be working on one account for a while:

```bash
export RAILWAY_TOKEN=YOUR_CLIENT_TOKEN_HERE
# Now all railway commands in this session use the client account
railway logs
railway up
railway variable list
```

Unset it when done:

```bash
unset RAILWAY_TOKEN
```

---

## Quick Reference

| Account | Token Variable | Default Account? |
|---------|---------------|-----------------|
| personal | `YOUR_PERSONAL_TOKEN_HERE` | Yes |
| client | `YOUR_CLIENT_TOKEN_HERE` | No |

Once this is in place, you'll never need to use `railway login` or touch a browser again for either account.
