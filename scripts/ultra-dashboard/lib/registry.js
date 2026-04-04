const fs = require('fs');
const path = require('path');
const os = require('os');

const HOME = os.homedir();
const REGISTRY_FILE = path.join(HOME, '.claude', 'ultra', 'dashboard-registry.json');
const PROJECTS_FILE = path.join(HOME, '.claude', 'ultra', 'dashboard-projects.json');

function readRegistry() {
  try {
    return JSON.parse(fs.readFileSync(REGISTRY_FILE, 'utf8'));
  } catch {
    return { plans: [] };
  }
}

function writeRegistry(reg) {
  const dir = path.dirname(REGISTRY_FILE);
  fs.mkdirSync(dir, { recursive: true });
  const tmp = REGISTRY_FILE + '.tmp.' + process.pid;
  fs.writeFileSync(tmp, JSON.stringify(reg, null, 2));
  fs.renameSync(tmp, REGISTRY_FILE);
}

function discoverPlans() {
  const reg = readRegistry();
  const knownRoots = new Set(reg.plans.map(p => p.project_root));

  // Project roots from explicit config (registered by migrate skill)
  try {
    const seeds = JSON.parse(fs.readFileSync(PROJECTS_FILE, 'utf8'));
    if (Array.isArray(seeds)) seeds.forEach(r => knownRoots.add(r));
  } catch {}

  let changed = false;
  for (const root of knownRoots) {
    const plansDir = path.join(root, 'documentation', 'plans');
    let entries;
    try { entries = fs.readdirSync(plansDir, { withFileTypes: true }); } catch { continue; }
    for (const ent of entries) {
      if (!ent.isDirectory()) continue;
      const planDir = path.join(plansDir, ent.name);
      // Include plans with a README (unstarted) or status/plan.json (started)
      const hasReadme = fs.existsSync(path.join(planDir, 'README.md'));
      const hasStatus = fs.existsSync(path.join(planDir, 'status', 'plan.json'));
      if (!hasReadme && !hasStatus) continue;
      const projectName = path.basename(root);
      const planName = ent.name;
      const exists = reg.plans.some(p => p.project === projectName && p.plan === planName);
      if (!exists) {
        reg.plans.push({
          project: projectName,
          plan: planName,
          plan_dir: planDir,
          project_root: root,
          registered_at: new Date().toISOString(),
          active: false
        });
        changed = true;
      }
    }
  }
  if (changed) writeRegistry(reg);
  return readRegistry();
}

function findPlan(project, planName) {
  const reg = readRegistry();
  return reg.plans.find(p => p.project === project && p.plan === planName);
}

function getProjectRoots() {
  const reg = readRegistry();
  const roots = new Set(reg.plans.map(p => p.project_root).filter(Boolean));
  try {
    const seeds = JSON.parse(fs.readFileSync(PROJECTS_FILE, 'utf8'));
    if (Array.isArray(seeds)) seeds.forEach(r => roots.add(r));
  } catch {}
  return [...roots];
}

module.exports = { readRegistry, writeRegistry, discoverPlans, findPlan, getProjectRoots, REGISTRY_FILE };
