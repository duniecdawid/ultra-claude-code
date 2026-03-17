# Railway Deployment — Auth Error Response

It sounds like you're authenticated with the wrong Railway account. Here's how to fix it and get your project deployed.

---

## Step 1: Check which account you're currently logged in as

```bash
railway whoami
```

This will show you the email address of the currently authenticated account. If it's not the right one, proceed to the next step.

---

## Step 2: Log out of the current account

```bash
railway logout
```

---

## Step 3: Log in with the correct account

```bash
railway login
```

This will open a browser window for you to authenticate. Make sure you log in with the correct account (e.g., the one that owns or has access to the Railway project you want to deploy to).

---

## Step 4: Navigate to your project directory

```bash
cd /home/user/Projects/ClientApp
```

---

## Step 5: Link your project to the correct Railway project

If your project isn't already linked to a Railway project, run:

```bash
railway link
```

This will prompt you to select an existing project (or create a new one) from your Railway account. Choose the correct project.

If you want to verify what project you're currently linked to, run:

```bash
railway status
```

---

## Step 6: Deploy

Once linked and authenticated correctly, deploy with:

```bash
railway up
```

---

## Troubleshooting Tips

- **Multiple accounts:** If you regularly switch between Railway accounts, be aware that `railway login` replaces the stored credentials globally. There's no built-in profile switching — you'll need to log out and back in each time.
- **Team/workspace access:** If the project belongs to a Railway team or workspace, make sure the account you're logging in with has been invited to that team. You can verify this at [railway.app](https://railway.app) under your account's team settings.
- **Token-based auth (CI/CD):** If you're deploying from a script or CI environment, use a Railway API token instead of interactive login:
  ```bash
  RAILWAY_TOKEN=your_token_here railway up
  ```
  You can generate a token at railway.app → Account Settings → Tokens.
- **railway.json / railway.toml:** If there's an existing `railway.json` or `railway.toml` config file in your project that references a specific project ID from the old account, you may need to delete or update it after relinking.

---

## Summary of commands

```bash
railway whoami          # Check current account
railway logout          # Log out
railway login           # Log in with correct account
cd /home/user/Projects/ClientApp
railway link            # Link to the correct Railway project
railway up              # Deploy
```
