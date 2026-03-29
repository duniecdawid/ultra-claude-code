const express = require('express');
const router = express.Router();
const { readRegistry, writeRegistry, discoverPlans, findPlan } = require('../lib/registry');
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

// GET /api/tmux
router.get('/tmux', (req, res) => {
  res.json(getLayoutState());
});

// GET /api/health
router.get('/health', (req, res) => {
  res.json(getHealthState());
});

module.exports = router;
