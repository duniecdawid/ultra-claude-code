const express = require('express');
const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync } = require('child_process');
const router = express.Router();
const { readRegistry, writeRegistry, discoverPlans, findPlan, getProjectRoots } = require('../lib/registry');

// Cached auth info — refreshed every 5 minutes
let authCache = null;
function refreshAuth() {
  try {
    const out = execSync('claude auth status --json 2>/dev/null', { timeout: 5000, encoding: 'utf8' });
    authCache = JSON.parse(out);
  } catch { authCache = null; }
}
refreshAuth();
setInterval(refreshAuth, 5 * 60 * 1000);
const { readPlanProject, readPlanTeams, readPlanEvents, parsePlanTasks } = require('../lib/plan-reader');
const { getLayoutState } = require('../lib/tmux-layout');
const { getHealthState } = require('../lib/plan-health');

router.use(express.json());

// POST /api/register
router.post('/register', (req, res) => {
  const { project, plan, plan_dir, project_root } = req.body;
  if (!project || !plan || !plan_dir || !project_root) {
    return res.status(400).json({ error: 'missing fields: project, plan, plan_dir, project_root' });
  }
  const reg = readRegistry();
  const idx = reg.plans.findIndex(p => p.project === project && p.plan === plan);
  if (idx >= 0) {
    reg.plans[idx].active = true;
    reg.plans[idx].plan_dir = plan_dir;
    reg.plans[idx].project_root = project_root;
    reg.plans[idx].registered_at = new Date().toISOString();
  } else {
    reg.plans.push({
      project, plan, plan_dir, project_root,
      registered_at: new Date().toISOString(),
      active: true
    });
  }
  writeRegistry(reg);
  res.json({ ok: true, project, plan });
});

// POST /api/deregister
router.post('/deregister', (req, res) => {
  const { project, plan } = req.body;
  const reg = readRegistry();
  const entry = reg.plans.find(p => p.project === project && p.plan === plan);
  if (entry) {
    entry.active = false;
    writeRegistry(reg);
  }
  res.json({ ok: true, project, plan });
});

// GET /api/plans
router.get('/plans', (req, res) => {
  const reg = discoverPlans();
  const enriched = reg.plans.map(p => {
    const proj = readPlanProject(p.plan_dir);
    if (proj && proj.status === 'executing') {
      const teams = readPlanTeams(p.plan_dir);
      const activeTeams = teams.filter(t => t.status && t.status !== 'completed' && t.status !== 'pending');
      if (activeTeams.length > 0) {
        proj._active_stages = activeTeams.map(t => ({ task_id: t.task_id, task_name: t.task_name, status: t.status }));
      }
    }
    return { ...p, live_status: proj };
  });
  res.json({ plans: enriched });
});

// GET /api/plan/:project/:planName/:resource
router.get('/plan/:project/:planName/:resource', (req, res) => {
  const { project, planName, resource } = req.params;
  const entry = findPlan(decodeURIComponent(project), decodeURIComponent(planName));
  if (!entry) return res.status(404).json({ error: 'plan not found' });

  switch (resource) {
    case 'project': return res.json(readPlanProject(entry.plan_dir) || {});
    case 'teams': return res.json(readPlanTeams(entry.plan_dir));
    case 'plan': return res.json(parsePlanTasks(entry.plan_dir));
    case 'events': return res.json(readPlanEvents(entry.plan_dir));
    default: return res.status(404).json({ error: 'unknown resource' });
  }
});

// GET /api/projects — unified project list with plan counts and docs status
router.get('/projects', (req, res) => {
  const reg = discoverPlans();
  const roots = getProjectRoots();

  // Build project map from plans
  const projectMap = {};
  for (const p of reg.plans) {
    if (!projectMap[p.project]) {
      projectMap[p.project] = {
        name: p.project,
        root: p.project_root,
        total_plans: 0,
        active_plans: 0,
        has_docs: false,
        active_stages: []
      };
    }
    const proj = projectMap[p.project];
    proj.total_plans++;
    const status = readPlanProject(p.plan_dir);
    const isActive = p.active || (status && status.status === 'executing');
    if (isActive) {
      proj.active_plans++;
      if (status && status.status === 'executing') {
        const teams = readPlanTeams(p.plan_dir);
        teams.filter(t => t.status && t.status !== 'completed' && t.status !== 'pending')
          .forEach(t => proj.active_stages.push({ plan: p.plan, task_id: t.task_id, status: t.status }));
      }
    }
  }

  // Add projects that have docs but no plans
  for (const root of roots) {
    const name = path.basename(root);
    if (!projectMap[name]) {
      projectMap[name] = { name, root, total_plans: 0, active_plans: 0, has_docs: false, active_stages: [] };
    }
  }

  // Check docs availability
  for (const proj of Object.values(projectMap)) {
    try {
      const docsDir = path.join(proj.root, 'documentation');
      proj.has_docs = fs.statSync(docsDir).isDirectory();
    } catch {}
  }

  const projects = Object.values(projectMap).sort((a, b) => {
    // Active projects first, then by name
    if (a.active_plans !== b.active_plans) return b.active_plans - a.active_plans;
    return a.name.localeCompare(b.name);
  });

  res.json({ projects });
});

// GET /api/tmux
router.get('/tmux', (req, res) => {
  res.json(getLayoutState());
});

// GET /api/health
router.get('/health', (req, res) => {
  res.json(getHealthState());
});

// GET /api/usage — Claude Code rate limits per account
router.get('/usage', (req, res) => {
  const usageFile = path.join(os.homedir(), '.claude', 'usage-status.json');
  try {
    const data = JSON.parse(fs.readFileSync(usageFile, 'utf8'));
    const activeEmail = authCache ? authCache.email : null;

    // New format: accounts keyed by email
    if (data.accounts) {
      const accounts = Object.values(data.accounts)
        .filter(a => a.rate_limits)
        .sort((a, b) => {
          // Active account first, then by updated_at descending
          if (a.email === activeEmail) return -1;
          if (b.email === activeEmail) return 1;
          return (b.updated_at || '').localeCompare(a.updated_at || '');
        });
      return res.json({ accounts, active_email: activeEmail, updated_at: data.updated_at });
    }

    // Legacy format: sessions keyed by session_id (backwards compat)
    const sessions = data.sessions || {};
    let best = null;
    for (const [, s] of Object.entries(sessions)) {
      if (s.rate_limits && s.rate_limits.five_hour) {
        if (!best || s.updated_at > best.updated_at) best = s;
      }
    }
    if (best) {
      const account = { email: activeEmail, rate_limits: best.rate_limits, updated_at: best.updated_at };
      return res.json({ accounts: [account], active_email: activeEmail, updated_at: data.updated_at });
    }
    res.json({ accounts: [], active_email: activeEmail });
  } catch (e) {
    if (e.code === 'ENOENT') return res.json({ accounts: [], active_email: authCache ? authCache.email : null });
    res.status(500).json({ error: e.message });
  }
});

module.exports = router;
