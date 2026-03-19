# Deployment

All commands below assume the token is resolved from config. Always prefix with `RAILWAY_API_TOKEN=<token>`.

## Deploy Current Directory

```bash
# Standard deploy — uploads code and builds on Railway
RAILWAY_API_TOKEN=<token> railway up

# Deploy without waiting for logs (background)
RAILWAY_API_TOKEN=<token> railway up --detach

# Target a specific service (if project has multiple)
RAILWAY_API_TOKEN=<token> railway up -s api-server

# Target a specific environment
RAILWAY_API_TOKEN=<token> railway up -e staging
```

`railway up` deploys the current directory. Railway auto-detects the language/framework and builds accordingly (Nixpacks). If a `Dockerfile` exists, it uses that instead.

## Redeploy

```bash
# Redeploy the latest deployment (same code, fresh build)
RAILWAY_API_TOKEN=<token> railway redeploy

# Redeploy a specific service
RAILWAY_API_TOKEN=<token> railway redeploy -s api-server
```

Useful when you want to rebuild without pushing new code — e.g., after changing environment variables.

## Restart

```bash
# Restart the service (no rebuild, just restart the container)
RAILWAY_API_TOKEN=<token> railway restart

# Restart a specific service
RAILWAY_API_TOKEN=<token> railway restart -s api-server
```

## Take Down

```bash
# Remove the deployment (service stays, but deployment is stopped)
RAILWAY_API_TOKEN=<token> railway down

# Skip confirmation
RAILWAY_API_TOKEN=<token> railway down -y
```

## Deploy Workflow

The recommended flow when deploying:

1. **Verify account and project** — run `railway status` to confirm you're deploying to the right place
2. **Check current state** — `railway logs` to see if something is already running
3. **Deploy** — `railway up`
4. **Monitor** — watch the build logs that stream automatically, or use `railway logs` after `--detach`
5. **Verify** — check the deployment URL or `railway status`

## GitLab CI/CD Integration

The official way to deploy from GitLab CI/CD (per [Railway blog](https://blog.railway.com/p/gitlab-ci-cd)):

```yaml
stages:
  - deploy

deploy:
  stage: deploy
  image: ghcr.io/railwayapp/cli:latest
  only:
    - master
  script:
    - railway up --service=$SVC_ID --detach
  environment:
    name: production
```

**Required GitLab CI/CD Variables:**
- `RAILWAY_TOKEN` — **Project token** (not service deploy token). Create at Railway > Project > Settings > Tokens.
- `SVC_ID` — Service ID or service name. Get via `Cmd/Ctrl+K` > "Copy Service ID" in Railway dashboard.

**Critical gotchas learned the hard way:**
- **Use the Railway CLI Docker image** (`ghcr.io/railwayapp/cli:latest`), NOT `npm install -g @railway/cli` on node:alpine. The npm-installed CLI silently fails with exit code 1 and no error output.
- **`--service` flag is required** when using project tokens in CI. Without it, `railway up` doesn't know which service to deploy to.
- **GitLab "Protected" variables** are only injected into protected branches. If your deploy branch isn't protected, uncheck "Protected" on the variable.
- **GitLab "Masked" variables** must match `[a-zA-Z0-9+/=@:.~-]` and be 8+ chars. If the token doesn't match, it's silently set to empty.
- **Don't re-declare** `RAILWAY_TOKEN` in the job's `variables:` block — GitLab CI/CD variables are already in the environment. Re-declaring can cause expansion issues.
- **`RAILWAY_TOKEN`** is the env var name the CLI reads automatically. No `railway login` step is needed.

## Common Gotchas

- **Wrong account**: Always verify with `railway status` before deploying. Deploying to the wrong account is the #1 mistake with multi-account setups.
- **Build failures**: Check build logs with `railway logs --build`. Common causes: missing dependencies, wrong Node/Python version.
- **Dockerfile vs Nixpacks**: If Railway picks the wrong builder, add a `railway.toml` or `nixpacks.toml` to configure explicitly.
- **Large files**: Railway has upload size limits. Use `.railwayignore` (same syntax as `.gitignore`) to exclude unnecessary files.
