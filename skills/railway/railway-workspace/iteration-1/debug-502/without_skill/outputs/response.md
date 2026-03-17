# Debugging a Railway 502 Error

A 502 Bad Gateway on Railway almost always means Railway's proxy can't reach your app — either the process crashed on startup, it's listening on the wrong port, or it ran out of memory. Here's how to systematically track down the cause.

---

## Step 1: Check the Deployment Logs First

This is the fastest way to see the actual error. In the Railway dashboard:

1. Open your project
2. Click on the service that's returning 502
3. Go to **Deployments** tab
4. Click the most recent deployment
5. Read the full log output — look for crash messages, unhandled exceptions, or "Address already in use" errors

Or via the Railway CLI:

```bash
railway logs
```

If you want to follow logs in real time:

```bash
railway logs --tail
```

Look for:
- Stack traces or unhandled promise rejections
- `SIGTERM`, `SIGKILL`, or exit code messages
- "Cannot find module" or other startup errors
- The server actually printing a "listening on port X" message — if you don't see it, the server never started

---

## Step 2: Verify the PORT Environment Variable

Railway injects a `PORT` environment variable that changes per deployment. Your app **must** bind to `process.env.PORT`, not a hardcoded port like `3000`.

Check what your server startup looks like. It should be something like:

```js
const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Listening on port ${port}`));
```

If it's hardcoded, that's your bug. Railway's proxy forwards to the dynamic `PORT` value — if your app is on `3000` but Railway expects `8080` (or whatever it assigned), you'll get a 502.

To verify what PORT Railway is providing:

```bash
railway variables
```

Look for the `PORT` variable in the output.

---

## Step 3: Check for a Recent Change That Broke the Build

You said it worked yesterday — something changed. Common culprits:

**Check recent git commits:**
```bash
git log --oneline -10
```

**Did a dependency update happen?** Check if `package-lock.json` or `yarn.lock` changed recently:
```bash
git diff HEAD~1 -- package-lock.json
```

**Did an environment variable get deleted?** In Railway dashboard → your service → **Variables** tab. If a required env var (database URL, API key, etc.) was removed, your app will crash on startup.

---

## Step 4: Check the Build vs Runtime Logs

Railway has two phases — build and deploy. A 502 usually means the deploy (runtime) phase is failing, but confirm:

In the deployment detail view, toggle between **Build Logs** and **Deploy Logs**. If build logs are clean but deploy logs show a crash, the problem is runtime (bad env var, port binding, missing dependency at runtime).

---

## Step 5: Check Memory and Resource Limits

If your app recently started doing more work (e.g., loading a larger dataset, processing more messages), it may be hitting Railway's memory limit and getting OOM-killed.

In Railway dashboard → your service → **Metrics** tab. Look at memory usage over the past 24 hours. A spike to the ceiling followed by a restart loop is a strong signal.

If memory is the issue, you either need to optimize memory usage or upgrade your Railway plan/resource limits.

---

## Step 6: Try a Manual Redeploy

Sometimes Railway deployments get into a bad state. Force a fresh deploy:

```bash
railway up
```

Or in the dashboard: **Deployments** → **Redeploy** on the last successful deployment (the one from yesterday).

---

## Step 7: Reproduce Locally with Production Variables

Pull your Railway environment variables locally and run the app:

```bash
railway run npm start
```

`railway run` injects all your Railway environment variables into the local process. If it crashes locally with those variables, you'll see the exact error without needing to dig through remote logs.

---

## Most Likely Causes (in order of frequency)

1. **App is crashing on startup** — check deploy logs for stack trace
2. **Wrong PORT binding** — app hardcodes a port instead of using `process.env.PORT`
3. **Missing environment variable** — a required secret was deleted or renamed
4. **Dependency issue** — a package updated and introduced a breaking change
5. **OOM kill** — memory limit hit, process keeps restarting

Start with Step 1 (logs) — 90% of the time the answer is right there in the crash output.
