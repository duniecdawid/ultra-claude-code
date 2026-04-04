# Plan: Remove Old Web Dashboard, Extract Tmux Layout Daemon

## Context

The Ultra Claude plugin historically included an embedded web dashboard (`scripts/ultra-dashboard/`) — an Express.js HTTP server on port 3847 that served a web UI, API routes, and ran a background tmux layout manager. This dashboard has been replaced by **ultra-claude-web**, a standalone Next.js application that reads the same local state files (plan.json, events.json, etc.).

Ultra Claude must continue to save state locally. The web dashboard is an **optional add-on** — it reads local state, but Ultra Claude must never depend on it being running.

The tmux layout management (pane arrangement based on `@agent-name` labels) is still needed for plan execution. It must be extracted from the dashboard and run as a standalone background process.

---

## Guiding Principles

1. **Local state persistence is untouched.** plan.json, events.json, checkpoints, operational reports, shared/lead.md — all stay exactly as they are.
2. **The web dashboard (ultra-claude-web) is optional.** No Ultra Claude skill, agent, or reference should depend on it or reference it.
3. **Tmux layout management survives** but decoupled from the HTTP server.
4. **`@agent-name` pane labeling convention is unchanged.** Agents still self-label. The layout daemon still polls labels and arranges panes.
5. **usage-status.json stays.** PM uses it for rate limit monitoring — independent of any dashboard.

---

## Task 1: Extract Tmux Layout Daemon

### What

Take `scripts/ultra-dashboard/lib/tmux-layout.js` and wrap it in a minimal standalone script.

### Target

Create `scripts/tmux-layout-daemon.js` (or similar) that:

- Runs the same `startLayoutManager()` poll loop (2s interval)
- Uses the same `scanPanes()` → `classifyPanes()` → `arrangeWindow()` logic
- Is a standalone Node.js script with no Express/HTTP dependencies
- Supports `--ensure` flag for idempotent background startup (fork-to-background, PID file at `~/.claude/ultra/tmux-layout.pid`)
- Exits cleanly on SIGTERM/SIGINT, cleans up PID file
- Has zero dependencies beyond Node.js built-ins (`child_process`)

### Acceptance Criteria

- `node scripts/tmux-layout-daemon.js --ensure` starts the daemon in the background if not already running
- Pane arrangement behavior is identical to current `tmux-layout.js`
- No HTTP server, no Express, no routes, no web UI
- Old `scripts/ultra-dashboard/` directory is not referenced

---

## Task 2: Delete Old Dashboard

### What

Remove the entire old web dashboard system.

### Delete These Files/Directories

```
scripts/ultra-dashboard/          # Entire directory
  index.js                        # Express server, singleton management
  package.json, package-lock.json # Dashboard-specific dependencies
  node_modules/                   # Dashboard dependencies
  routes/api.js                   # HTTP API endpoints
  routes/pages.js                 # HTML page routes
  routes/docs.js                  # Docsify documentation routes
  public/                         # Static assets (CSS, JS, images)
  views/                          # HTML templates
  lib/plan-reader.js              # Plan state reader (for HTTP API)
  lib/registry.js                 # Plan discovery + registry files
  lib/backlog-reader.js           # Backlog reader (for HTTP API)
  lib/docs-discovery.js           # Documentation discovery
  lib/git-changes.js              # Git diff for docs
  lib/tmux-layout.js              # ONLY after Task 1 extracts it
  statusline.sh                   # Review — keep if used by statusline skill, delete if dashboard-only
```

```
skills/ensure-dashboard/          # Entire skill directory
skills/tmux-team-grid/            # Entire skill directory
references/ensure-dashboard.md    # Reference steps for old dashboard
docs/                             # Docsify HTML pages served by old dashboard
```

### Delete These Global State Files (from instructions/references, not filesystem)

Remove references to these files from skills and agents. They are no longer written or read:

- `~/.claude/ultra/dashboard.pid` — replaced by `tmux-layout.pid`
- `~/.claude/ultra/dashboard-registry.json` — plan discovery was for the old dashboard
- `~/.claude/ultra/dashboard-projects.json` — project registration was for the old dashboard

### Do NOT Delete

- `~/.claude/ultra/usage-status.json` — still used by PM for rate limiting
- Any plan-level state files (plan.json, events.json, checkpoints, operational reports)

---

## Task 3: Update All References

Every file that references the old dashboard must be updated. Here is the complete list of affected files and what to change in each.

### `skills/plan-execution/references/phase-1-setup.md`

- **Remove** section 1.1b ("Ultra Dashboard") entirely — the `ensure-dashboard.md` call and `$DASHBOARD_URL`
- **Replace with** a new section 1.1b that:
  - Starts the standalone tmux layout daemon: `node ${CLAUDE_PLUGIN_ROOT}/scripts/tmux-layout-daemon.js --ensure`
  - Sets the `@agent-name "main-context"` label (keep existing tmux commands)
  - Sets pane border status/format (keep existing tmux commands)
  - Removes all mention of dashboard URL

### `agents/project-manager.md`

- Remove any references to `/api/tmux` HTTP endpoint for layout verification
- If PM verifies pane labels, do it via `tmux list-panes -F "#{pane_id} #{@agent-name}"` directly instead of curling the dashboard API
- Remove any `$DASHBOARD_URL` references

### `skills/plan-enhancer/references/stage-1-understand.md`

- Remove the line/section that shows `$DASHBOARD_URL` to the user
- Do not replace — the web dashboard is optional and discovered separately

### `skills/help/SKILL.md`

- Remove `uc:ensure-dashboard` from the skill listing
- Remove `uc:tmux-team-grid` from the skill listing
- Remove any description of the old web dashboard
- Optionally mention that ultra-claude-web is an optional companion dashboard

### `skills/setup/SKILL.md`

- Remove dashboard setup steps (PID file checks, port 3847 references)
- Remove `npm install` for `scripts/ultra-dashboard/`
- Add: ensure `scripts/tmux-layout-daemon.js` is executable/accessible (no npm install needed — zero dependencies)

### `skills/update/SKILL.md`

- Remove dashboard restart logic
- Remove references to killing dashboard process
- Add: restart tmux layout daemon if running (kill old PID, re-ensure)

### `skills/migrate/references/fresh-init.md`

- Remove dashboard initialization steps
- Remove ensure-dashboard references

### `skills/roadmap/SKILL.md`

- Remove dashboard URL reference (if any — verify; it was in the grep results)

### `settings.json` (plugin manifest)

- Remove `ensure-dashboard` and `tmux-team-grid` from the skills list
- Verify no routes or scripts reference the old dashboard

### `plugin.json` / `marketplace.json`

- Bump version after all changes
- Update description if it mentions the built-in dashboard

---

## Task 4: Clean Up `uc:plan-status-sync`

This skill reads plan state and reconciles README statuses. Verify it has **no dependency** on the old dashboard. Specifically:

- It should not import or reference `plan-reader.js` from the dashboard lib
- It should not call any HTTP endpoint
- It should read plan.json, README.md, and execution artifacts directly from disk

If it does reference dashboard code, refactor to read files directly. The plan-status-sync logic is file-based and should have no HTTP dependency.

---

## Verification Checklist

After all tasks are complete:

- [ ] `grep -r "ensure-dashboard" skills/ agents/ references/` returns zero results
- [ ] `grep -r "tmux-team-grid" skills/ agents/ references/` returns zero results
- [ ] `grep -r "3847" skills/ agents/ references/ scripts/` returns zero results (except tmux-layout-daemon if it logs its own PID)
- [ ] `grep -r "dashboard\.pid" skills/ agents/ references/` returns zero results
- [ ] `grep -r "dashboard-registry" skills/ agents/ references/` returns zero results
- [ ] `grep -r "DASHBOARD_URL" skills/ agents/ references/` returns zero results
- [ ] `scripts/ultra-dashboard/` directory does not exist
- [ ] `skills/ensure-dashboard/` directory does not exist
- [ ] `skills/tmux-team-grid/` directory does not exist
- [ ] `references/ensure-dashboard.md` does not exist
- [ ] `docs/` directory does not exist (old Docsify pages)
- [ ] `node scripts/tmux-layout-daemon.js --ensure` starts successfully and arranges panes
- [ ] Plan execution (phase-1 through phase-5) works without the old dashboard
- [ ] plan.json, events.json, and all local state files continue to be written correctly
- [ ] PM agent can verify pane labels without HTTP calls
