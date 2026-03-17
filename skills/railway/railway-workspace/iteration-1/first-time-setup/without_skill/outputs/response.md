# Setting Up Multiple Railway Accounts with the CLI

Railway CLI doesn't have a built-in "profile" system like AWS CLI, but you can work around this cleanly using environment variables. Here's the approach I'd recommend.

---

## How It Works

Railway CLI reads your auth token from either:
1. A local config file (`~/.railway/config.json`)
2. The environment variable `RAILWAY_TOKEN`

The cleanest multi-account workflow is to use project-level tokens stored in each project's directory, so the right account is used automatically based on where you are.

---

## Step 1: Log in to your personal account first

```bash
railway login
```

This opens a browser and saves your personal account token to `~/.railway/config.json`. This becomes your default account.

---

## Step 2: Get a token for your client account

Since you can't store two accounts in the global config at once, you'll use a **project token** for your client project instead of a full account login.

1. Log in to your client Railway account via the **web dashboard** (app.railway.app)
2. Go to your client project
3. Navigate to: **Project Settings → Tokens**
4. Create a new token (e.g. name it "CLI Access")
5. Copy the token value

---

## Step 3: Store the client token in your project directory

In the root of your client project, create a `.env` file (or add to the existing one) with:

```bash
RAILWAY_TOKEN=your_client_project_token_here
```

**Important:** Add `.env` to your `.gitignore` if it isn't already, so this token doesn't get committed:

```bash
echo ".env" >> .gitignore
```

---

## Step 4: Use `direnv` to auto-load the token (recommended)

Install `direnv` if you don't have it:

```bash
# macOS
brew install direnv

# Ubuntu/Debian
sudo apt install direnv
```

Add the direnv hook to your shell config (`~/.zshrc` or `~/.bashrc`):

```bash
eval "$(direnv hook zsh)"   # for zsh
# or
eval "$(direnv hook bash)"  # for bash
```

Reload your shell:

```bash
source ~/.zshrc
```

Then in your client project directory, create a `.envrc` file:

```bash
export RAILWAY_TOKEN=your_client_project_token_here
```

Allow direnv to load it:

```bash
direnv allow
```

---

## How It Flows in Practice

**When working on your personal project:**
```bash
cd ~/Projects/my-personal-project
railway status   # uses your personal account (from ~/.railway/config.json)
railway up
```

**When working on your client project:**
```bash
cd ~/Projects/client-project
# direnv auto-loads RAILWAY_TOKEN for the client account
railway status   # uses the client project token automatically
railway up
```

No logging in and out. No browser prompts. The right account activates based on your working directory.

---

## Without direnv (manual alternative)

If you'd rather not install direnv, you can prefix commands with the token inline:

```bash
RAILWAY_TOKEN=your_client_token railway status
RAILWAY_TOKEN=your_client_token railway up
```

Or create a shell alias in your `~/.zshrc`:

```bash
alias railway-client='RAILWAY_TOKEN=your_client_token_here railway'
```

Then use:
```bash
railway-client status
railway-client up
```

---

## Verifying Which Account Is Active

At any time, check which project/account is in context:

```bash
railway status
```

This shows the linked project and environment, so you can confirm you're operating on the right account before running destructive commands.

---

## Summary

| Context | Auth Method | How Activated |
|---|---|---|
| Personal account | `~/.railway/config.json` (set via `railway login`) | Default, everywhere |
| Client account | `RAILWAY_TOKEN` env var | Auto via direnv in project dir |

The direnv approach is the cleanest — it's zero-friction once set up and impossible to accidentally use the wrong account.
