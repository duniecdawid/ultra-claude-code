#!/usr/bin/env node
// Global Singleton Dashboard — aggregates all Ultra Claude plan executions
// Usage: node global-dashboard.js
// Always binds port 3847. One instance system-wide.
// Registry: ~/.claude/dashboard-registry.json
// PID file: ~/.claude/dashboard.pid

const http = require('http');
const fs = require('fs');
const path = require('path');
const os = require('os');

const PORT = 3847;
const HOME = os.homedir();
const REGISTRY_FILE = path.join(HOME, '.claude', 'dashboard-registry.json');
const PID_FILE = path.join(HOME, '.claude', 'dashboard.pid');
const PROJECTS_FILE = path.join(HOME, '.claude', 'dashboard-projects.json');

// --- Registry management ---

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

function readJSON(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

// --- Historical plan discovery ---

function discoverPlans() {
  const reg = readRegistry();
  const knownRoots = new Set(reg.plans.map(p => p.project_root));

  // Also load seed file if it exists
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
      const projectJson = path.join(planDir, 'status', 'project.json');
      if (!fs.existsSync(projectJson)) continue;
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

// --- Plan data readers (parameterized by plan_dir) ---

function readPlanProject(planDir) {
  return readJSON(path.join(planDir, 'status', 'project.json'));
}

function readPlanTeams(planDir) {
  const teamsDir = path.join(planDir, 'status', 'teams');
  try {
    return fs.readdirSync(teamsDir)
      .filter(f => f.endsWith('.json'))
      .sort()
      .map(f => readJSON(path.join(teamsDir, f)))
      .filter(Boolean);
  } catch {
    return [];
  }
}

function readPlanEvents(planDir) {
  return readJSON(path.join(planDir, 'status', 'events.json')) || { events: [] };
}

function parsePlanTasks(planDir) {
  const readmePath = path.join(planDir, 'README.md');
  try {
    const content = fs.readFileSync(readmePath, 'utf8');
    const tasks = [];
    const taskRegex = /^### Task (\d+):\s*(.+)$/gm;
    let match;
    while ((match = taskRegex.exec(content)) !== null) {
      const taskNum = parseInt(match[1], 10);
      const title = match[2].trim();
      const restContent = content.slice(match.index + match[0].length);
      const nextTaskIdx = restContent.search(/^### Task \d+:/m);
      const afterMatch = nextTaskIdx > 0 ? restContent.slice(0, nextTaskIdx) : restContent;
      const classMatch = afterMatch.match(/\*\*Classification:\*\*\s*(\w+)/);
      const depMatch = afterMatch.match(/\*\*Dependencies:\*\*\s*(.+)/);
      const deps = depMatch ? depMatch[1].trim() : 'None';
      const descMatch = afterMatch.match(/\*\*Description:\*\*\s*(.+)/);
      const description = descMatch ? descMatch[1].trim() : '';
      tasks.push({
        task_id: 'task-' + taskNum,
        task_num: taskNum,
        title, classification: classMatch ? classMatch[1] : null,
        dependencies: deps, description
      });
    }
    const graphMatch = content.match(/## Task Dependency Graph[\s\S]*?```([\s\S]*?)```/);
    return { tasks, dependency_graph: graphMatch ? graphMatch[1].trim() : null };
  } catch {
    return { tasks: [], dependency_graph: null };
  }
}

// --- Resolve plan entry from URL params ---

function findPlan(project, planName) {
  const reg = readRegistry();
  return reg.plans.find(p => p.project === project && p.plan === planName);
}

// --- API routes ---

function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => { body += chunk; if (body.length > 1e6) reject(new Error('too large')); });
    req.on('end', () => { try { resolve(JSON.parse(body)); } catch (e) { reject(e); } });
  });
}

async function handleAPI(req, res) {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');

  const url = req.url;

  // POST /api/register
  if (url === '/api/register' && req.method === 'POST') {
    try {
      const body = await parseBody(req);
      const { project, plan, plan_dir, project_root } = body;
      if (!project || !plan || !plan_dir || !project_root) {
        res.statusCode = 400;
        res.end('{"error":"missing fields: project, plan, plan_dir, project_root"}');
        return;
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
      res.end(JSON.stringify({ ok: true, project, plan }));
    } catch (e) {
      res.statusCode = 400;
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // POST /api/deregister
  if (url === '/api/deregister' && req.method === 'POST') {
    try {
      const body = await parseBody(req);
      const { project, plan } = body;
      const reg = readRegistry();
      const entry = reg.plans.find(p => p.project === project && p.plan === plan);
      if (entry) {
        entry.active = false;
        writeRegistry(reg);
      }
      res.end(JSON.stringify({ ok: true, project, plan }));
    } catch (e) {
      res.statusCode = 400;
      res.end(JSON.stringify({ error: e.message }));
    }
    return;
  }

  // GET /api/plans — full registry with live status
  if (url === '/api/plans') {
    const reg = readRegistry();
    const enriched = reg.plans.map(p => {
      const proj = readPlanProject(p.plan_dir);
      return { ...p, live_status: proj };
    });
    res.end(JSON.stringify({ plans: enriched }));
    return;
  }

  // GET /api/plan/:project/:planName/project|teams|plan|events
  const planApiMatch = url.match(/^\/api\/plan\/([^/]+)\/([^/]+)\/(project|teams|plan|events)$/);
  if (planApiMatch) {
    const [, project, planName, resource] = planApiMatch;
    const entry = findPlan(decodeURIComponent(project), decodeURIComponent(planName));
    if (!entry) { res.statusCode = 404; res.end('{"error":"plan not found"}'); return; }
    switch (resource) {
      case 'project': res.end(JSON.stringify(readPlanProject(entry.plan_dir) || {})); break;
      case 'teams': res.end(JSON.stringify(readPlanTeams(entry.plan_dir))); break;
      case 'plan': res.end(JSON.stringify(parsePlanTasks(entry.plan_dir))); break;
      case 'events': res.end(JSON.stringify(readPlanEvents(entry.plan_dir))); break;
    }
    return;
  }

  res.statusCode = 404;
  res.end('{"error":"not found"}');
}

// --- HTML Templates ---

const HOMEPAGE_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Ultra Claude Dashboard</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; padding: 12px; }
  a { color: #58a6ff; text-decoration: none; }
  a:hover { text-decoration: underline; }
  h1 { font-size: 1.3em; color: #58a6ff; margin-bottom: 4px; }
  h2 { font-size: 1em; color: #8b949e; margin: 20px 0 10px; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 500; }
  .header { margin-bottom: 16px; border-bottom: 1px solid #21262d; padding-bottom: 12px; }
  .header-top { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; }
  .header-right { font-size: 0.82em; color: #8b949e; }
  .hostname { color: #484f58; font-size: 0.85em; }
  .refresh-indicator { width: 8px; height: 8px; border-radius: 50%; background: #3fb950; display: inline-block; margin-right: 6px; animation: blink 5s ease-in-out infinite; }
  @keyframes blink { 0%, 90%, 100% { opacity: 1; } 95% { opacity: 0.2; } }

  .status-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.72em; font-weight: 600; text-transform: uppercase; white-space: nowrap; }
  .status-executing { background: #1f6feb33; color: #58a6ff; }
  .status-completed { background: #23863533; color: #3fb950; }
  .status-aborted { background: #da363333; color: #f85149; }
  .status-pending { background: #21262d; color: #8b949e; }

  .no-plans { color: #484f58; padding: 20px; text-align: center; }

  /* Plan cards */
  .plan-cards { display: flex; flex-direction: column; gap: 8px; }
  .plan-card { background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 12px 14px; transition: border-color 0.2s; }
  .plan-card:hover { border-color: #30363d; }
  .plan-card.active { border-color: #1f6feb; }
  .plan-card.completed { border-color: #238636; }
  .plan-card-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; }
  .plan-project { font-size: 0.78em; color: #8b949e; font-family: monospace; }
  .plan-name { font-weight: 500; font-size: 0.95em; color: #e6edf3; }
  .plan-card:not(.active):not(.completed) .plan-name { color: #8b949e; }
  .plan-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-top: 6px; font-size: 0.78em; color: #8b949e; }

  /* Progress bar */
  .progress-bar { flex: 1; max-width: 160px; height: 6px; background: #21262d; border-radius: 3px; overflow: hidden; }
  .progress-fill { height: 100%; background: #3fb950; border-radius: 3px; transition: width 0.3s; }

  /* Project groups */
  .project-group { margin-bottom: 16px; }
  .project-heading { font-size: 0.9em; color: #c9d1d9; font-weight: 600; margin-bottom: 8px; padding-left: 2px; }

  @media (min-width: 640px) {
    body { padding: 20px; }
    h1 { font-size: 1.5em; }
    .plan-card { padding: 14px 18px; }
  }
</style>
</head>
<body>
<div class="header">
  <div class="header-top">
    <div>
      <h1>Ultra Claude Dashboard</h1>
      <div class="hostname" id="hostname"></div>
    </div>
    <div class="header-right">
      <span class="refresh-indicator"></span>Auto-refresh 5s
    </div>
  </div>
</div>
<div id="active-section"></div>
<div id="projects-section"></div>

<script>
document.getElementById('hostname').textContent = location.hostname;

function statusClass(s) {
  if (!s) return 'pending';
  if (['executing','researching','planning','implementing','reviewing','testing'].includes(s)) return 'executing';
  if (s === 'completed') return 'completed';
  if (s === 'escalated' || s === 'aborted') return 'aborted';
  return 'pending';
}

function fmtTime(sec) {
  if (!sec || sec < 0) return '';
  if (sec < 60) return sec + 's';
  if (sec < 3600) return Math.floor(sec/60) + 'm ' + (sec%60) + 's';
  return Math.floor(sec/3600) + 'h ' + Math.floor((sec%3600)/60) + 'm';
}

function fmtDate(iso) {
  if (!iso) return '';
  try { return new Date(iso).toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }); }
  catch { return iso; }
}

function renderCard(p) {
  const live = p.live_status || {};
  const status = live.status || (p.active ? 'executing' : 'completed');
  const sc = statusClass(status);
  const total = live.total_tasks || 0;
  const done = live.completed_tasks || 0;
  const pct = total > 0 ? Math.round((done / total) * 100) : 0;
  const elapsed = fmtTime(live.elapsed_seconds);
  const isActive = p.active || status === 'executing';

  return '<a href="/plan/' + encodeURIComponent(p.project) + '/' + encodeURIComponent(p.plan) + '" style="text-decoration:none">' +
    '<div class="plan-card ' + (isActive ? 'active' : (sc === 'completed' ? 'completed' : '')) + '">' +
      '<div class="plan-card-head">' +
        '<span class="plan-project">' + esc(p.project) + '</span>' +
        '<span class="status-badge status-' + sc + '">' + esc(status) + '</span>' +
      '</div>' +
      '<div class="plan-name">' + esc(p.plan) + '</div>' +
      '<div class="plan-meta">' +
        (total > 0 ? '<span>' + done + '/' + total + ' tasks</span>' +
          '<div class="progress-bar"><div class="progress-fill" style="width:' + pct + '%"></div></div>' : '') +
        (elapsed ? '<span>' + elapsed + '</span>' : '') +
        '<span>' + fmtDate(p.registered_at) + '</span>' +
      '</div>' +
    '</div>' +
  '</a>';
}

function esc(s) { return (s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }

async function refresh() {
  try {
    const data = await fetch('/api/plans').then(r => r.json());
    const plans = data.plans || [];

    // Active plans
    const active = plans.filter(p => {
      const ls = p.live_status;
      return p.active || (ls && ls.status === 'executing');
    });
    const activeEl = document.getElementById('active-section');
    if (active.length > 0) {
      activeEl.innerHTML = '<h2>Active Plans</h2><div class="plan-cards">' + active.map(renderCard).join('') + '</div>';
    } else {
      activeEl.innerHTML = '<h2>Active Plans</h2><div class="no-plans">No active plans</div>';
    }

    // All projects grouped
    const groups = {};
    plans.forEach(p => {
      if (!groups[p.project]) groups[p.project] = [];
      groups[p.project].push(p);
    });
    const projectsEl = document.getElementById('projects-section');
    if (Object.keys(groups).length === 0) {
      projectsEl.innerHTML = '<h2>All Projects</h2><div class="no-plans">No plans registered yet</div>';
    } else {
      let html = '<h2>All Projects</h2>';
      for (const [proj, projPlans] of Object.entries(groups).sort()) {
        html += '<div class="project-group">' +
          '<div class="project-heading">' + esc(proj) + ' (' + projPlans.length + ')</div>' +
          '<div class="plan-cards">' + projPlans.map(renderCard).join('') + '</div>' +
        '</div>';
      }
      projectsEl.innerHTML = html;
    }
  } catch (e) {
    console.error('Refresh failed:', e);
  }
}

refresh();
setInterval(refresh, 5000);
</script>
</body>
</html>`;

// --- Per-plan detail view (reuses status-dashboard.js design with breadcrumb) ---

function getPlanDetailHTML(project, planName) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>${planName} — ${project}</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; padding: 12px; }
  a { color: #58a6ff; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .breadcrumb { font-size: 0.82em; color: #8b949e; margin-bottom: 8px; }
  .breadcrumb a { color: #58a6ff; }
  h1 { font-size: 1.2em; color: #58a6ff; margin-bottom: 4px; }
  h2 { font-size: 1em; color: #8b949e; margin: 16px 0 8px; text-transform: uppercase; letter-spacing: 0.05em; font-weight: 500; }
  .header { margin-bottom: 12px; border-bottom: 1px solid #21262d; padding-bottom: 10px; }
  .header-top { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; }
  .header-right { font-size: 0.82em; color: #8b949e; }
  .status-badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 0.75em; font-weight: 600; text-transform: uppercase; white-space: nowrap; }
  .status-executing { background: #1f6feb33; color: #58a6ff; }
  .status-completed { background: #23863533; color: #3fb950; }
  .status-aborted { background: #da363333; color: #f85149; }
  .status-pending { background: #21262d; color: #8b949e; }
  .counters { display: flex; gap: 16px; margin: 10px 0; flex-wrap: wrap; }
  .counter { text-align: center; }
  .counter-value { font-size: 1.6em; font-weight: 700; }
  .counter-label { font-size: 0.7em; color: #8b949e; text-transform: uppercase; }
  .counter-active .counter-value { color: #58a6ff; }
  .counter-done .counter-value { color: #3fb950; }
  .counter-pending .counter-value { color: #8b949e; }
  .counter-total .counter-value { color: #c9d1d9; }
  .task-list { display: flex; flex-direction: column; gap: 6px; }
  .task-item { background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 10px 12px; }
  .task-item.active { border-color: #1f6feb; }
  .task-item.completed { border-color: #238636; }
  .task-item.escalated { border-color: #da3633; }
  .task-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px; }
  .task-id { font-weight: 600; color: #8b949e; font-family: monospace; font-size: 0.82em; }
  .task-item.active .task-id { color: #58a6ff; }
  .task-item.completed .task-id { color: #3fb950; }
  .task-title { color: #e6edf3; font-weight: 500; font-size: 0.92em; line-height: 1.3; }
  .task-item:not(.active):not(.completed):not(.escalated) .task-title { color: #8b949e; }
  .task-item.completed .task-title { color: #3fb950; }
  .task-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-top: 4px; font-size: 0.78em; }
  .task-deps { color: #484f58; }
  .task-timing { color: #8b949e; }
  .task-retries { color: #d29922; }
  .task-details { margin-top: 8px; }
  .stages { display: flex; gap: 3px; margin-bottom: 4px; }
  .stage { flex: 1; height: 6px; border-radius: 3px; background: #21262d; }
  .stage.done { background: #3fb950; }
  .stage.active { background: #58a6ff; animation: pulse 1.5s ease-in-out infinite; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
  .stage-labels { display: flex; gap: 3px; margin-bottom: 6px; }
  .stage-label { flex: 1; font-size: 0.6em; text-align: center; color: #484f58; text-transform: uppercase; }
  .stage-label.done { color: #3fb950; }
  .stage-label.active { color: #58a6ff; }
  .members { display: flex; gap: 4px; flex-wrap: wrap; }
  .member { font-size: 0.75em; padding: 2px 6px; border-radius: 4px; background: #0d1117; display: inline-flex; gap: 6px; }
  .member-name { color: #c9d1d9; }
  .member-status { font-weight: 600; }
  .member-status.active { color: #58a6ff; }
  .member-status.idle { color: #484f58; }
  .member-status.completed { color: #3fb950; }
  .member-status.crashed { color: #f85149; }
  .member-status.rate-limited { color: #d29922; }
  .events-log { background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 10px 12px; max-height: 300px; overflow-y: auto; }
  .event { padding: 3px 0; border-bottom: 1px solid #21262d22; font-size: 0.78em; }
  .event:last-child { border-bottom: none; }
  .event-time { color: #484f58; font-family: monospace; font-size: 0.9em; margin-right: 8px; }
  .event-type { font-weight: 600; margin-right: 8px; }
  .event-type.team_spawned { color: #58a6ff; }
  .event-type.team_shutdown { color: #8b949e; }
  .event-type.stage_entered { color: #d2a8ff; }
  .event-type.task_completed { color: #3fb950; }
  .event-type.task_escalated { color: #f85149; }
  .event-type.stall_detected { color: #d29922; }
  .event-type.stall_resolved { color: #3fb950; }
  .event-type.rate_limit_suspected { color: #f85149; }
  .event-type.rate_limit_recovered { color: #3fb950; }
  .event-type.implementation_approved { color: #3fb950; }
  .event-type.pipeline_spawn { color: #79c0ff; }
  .event-msg { color: #c9d1d9; }
  .refresh-indicator { width: 8px; height: 8px; border-radius: 50%; background: #3fb950; display: inline-block; margin-right: 6px; animation: blink 3s ease-in-out infinite; }
  @keyframes blink { 0%, 90%, 100% { opacity: 1; } 95% { opacity: 0.2; } }
  .description { font-size: 0.85em; color: #8b949e; margin-top: 4px; line-height: 1.4; }
  .dep-graph { font-family: monospace; font-size: 0.72em; color: #484f58; white-space: pre; line-height: 1.4; background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 10px 12px; overflow-x: auto; }
  @media (min-width: 640px) {
    body { padding: 20px; }
    h1 { font-size: 1.4em; }
    .counter-value { font-size: 1.8em; }
    .counters { gap: 24px; }
    .task-item { padding: 12px 16px; }
    .task-title { font-size: 0.95em; }
    .event { display: flex; gap: 8px; }
    .events-log { max-height: 400px; padding: 14px; }
  }
</style>
</head>
<body>
<div class="breadcrumb"><a href="/">Dashboard</a> &rsaquo; <a href="/">${escapeHTML(project)}</a> &rsaquo; ${escapeHTML(planName)}</div>
<div class="header">
  <div class="header-top">
    <h1 id="project-name">Loading...</h1>
    <div class="header-right">
      <span class="refresh-indicator"></span>Auto-refresh 3s
      <span id="project-timing"></span>
    </div>
  </div>
  <div class="description" id="project-desc"></div>
</div>
<div class="counters" id="counters"></div>
<h2>Tasks</h2>
<div class="task-list" id="tasks"></div>
<h2>Event Log</h2>
<div class="events-log" id="events"></div>

<script>
const API_BASE = '/api/plan/${encodeURIComponent(project)}/${encodeURIComponent(planName)}';
const STAGE_ORDER = ['planning', 'implementation', 'review', 'testing'];
const STAGE_MAP = {
  researching: 'research', planning: 'planning', implementing: 'implementation',
  reviewing: 'review', testing: 'testing', completed: '_done', escalated: '_done', pending: '_pending'
};

function statusClass(s) {
  if (['executing', 'researching', 'planning', 'implementing', 'reviewing', 'testing'].includes(s)) return 'executing';
  if (s === 'completed') return 'completed';
  if (s === 'escalated') return 'aborted';
  return 'pending';
}

function fmtTime(sec) {
  if (!sec || sec < 0) return '\\u2014';
  if (sec < 60) return sec + 's';
  if (sec < 3600) return Math.floor(sec / 60) + 'm ' + (sec % 60) + 's';
  return Math.floor(sec / 3600) + 'h ' + Math.floor((sec % 3600) / 60) + 'm';
}

function fmtEventTime(iso) {
  if (!iso) return '';
  try { const d = new Date(iso); return d.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' }); }
  catch { return iso; }
}

function renderProject(p) {
  document.getElementById('project-name').innerHTML =
    (p.name || 'Plan') + ' <span class="status-badge status-' + statusClass(p.status) + '">' + (p.status || 'unknown') + '</span>';
  document.getElementById('project-desc').textContent = p.description || '';
  document.getElementById('project-timing').textContent = fmtTime(p.elapsed_seconds);
  document.getElementById('counters').innerHTML =
    '<div class="counter counter-total"><div class="counter-value">' + (p.total_tasks || 0) + '</div><div class="counter-label">Total</div></div>' +
    '<div class="counter counter-active"><div class="counter-value">' + (p.active_tasks || 0) + '</div><div class="counter-label">Active</div></div>' +
    '<div class="counter counter-done"><div class="counter-value">' + (p.completed_tasks || 0) + '</div><div class="counter-label">Done</div></div>' +
    '<div class="counter counter-pending"><div class="counter-value">' + (p.pending_tasks || 0) + '</div><div class="counter-label">Pending</div></div>';
}

function renderTasks(planData, teams) {
  const el = document.getElementById('tasks');
  if (!planData.tasks || !planData.tasks.length) {
    if (!teams.length) { el.innerHTML = '<div style="color:#484f58">No tasks found</div>'; return; }
    el.innerHTML = teams.map(t => renderActiveTask(t, null)).join('');
    return;
  }
  const teamMap = {};
  teams.forEach(t => { teamMap[t.task_id] = t; });
  const items = planData.tasks.map(task => {
    const team = teamMap[task.task_id];
    if (team) return renderActiveTask(team, task);
    return renderQueuedTask(task);
  }).join('');
  const graph = planData.dependency_graph
    ? '<div class="dep-graph">' + planData.dependency_graph.replace(/</g, '&lt;') + '</div>'
    : '';
  el.innerHTML = items + graph;
}

function renderActiveTask(t, planTask) {
  const activeStage = STAGE_MAP[t.status] || '';
  const stages = STAGE_ORDER.map(s => {
    let cls = '';
    if (t.status === 'completed') cls = 'done';
    else if (t.status === 'escalated') cls = 'done';
    else if (t.stages && t.stages[s] && t.stages[s].ended_at) cls = 'done';
    else if (s === activeStage) cls = 'active';
    return { name: s, cls };
  });
  const stagesBars = stages.map(s => '<div class="stage ' + s.cls + '"></div>').join('');
  const stagesLabels = stages.map(s => '<div class="stage-label ' + s.cls + '">' + s.name.slice(0, 3) + '</div>').join('');
  const members = (t.members || []).map(m =>
    '<div class="member"><span class="member-name">' + m.name + '</span>' +
    '<span class="member-status ' + (m.status || '').replace('-', '') + '">' + (m.status || '?') + '</span></div>'
  ).join('');
  const cardClass = ['completed', 'escalated'].includes(t.status) ? t.status : 'active';
  const retries = t.retry_count > 0 ? '<span class="task-retries">retries: ' + t.retry_count + '</span>' : '';
  const deps = planTask && planTask.dependencies && planTask.dependencies !== 'None'
    ? '<span class="task-deps">dep: ' + planTask.dependencies + '</span>' : '';
  const meta = [deps, retries, '<span class="task-timing">' + fmtTime(t.elapsed_seconds) + '</span>'].filter(Boolean).join('');
  return '<div class="task-item ' + cardClass + '">' +
    '<div class="task-head">' +
      '<span class="task-id">' + (t.task_id || '') + '</span>' +
      '<span class="status-badge status-' + statusClass(t.status) + '">' + (t.status || '') + '</span>' +
    '</div>' +
    '<div class="task-title">' + (t.task_name || (planTask && planTask.title) || '') + '</div>' +
    (meta ? '<div class="task-meta">' + meta + '</div>' : '') +
    '<div class="task-details">' +
      '<div class="stages">' + stagesBars + '</div>' +
      '<div class="stage-labels">' + stagesLabels + '</div>' +
      '<div class="members">' + members + '</div>' +
    '</div>' +
  '</div>';
}

function renderQueuedTask(task) {
  const deps = task.dependencies && task.dependencies !== 'None'
    ? '<span class="task-deps">dep: ' + task.dependencies + '</span>' : '';
  return '<div class="task-item">' +
    '<div class="task-head">' +
      '<span class="task-id">' + task.task_id + '</span>' +
      '<span class="status-badge status-pending">queued</span>' +
    '</div>' +
    '<div class="task-title">' + task.title + '</div>' +
    (deps ? '<div class="task-meta">' + deps + '</div>' : '') +
  '</div>';
}

function renderEvents(data) {
  const el = document.getElementById('events');
  const events = (data.events || []).slice().reverse();
  if (!events.length) { el.innerHTML = '<div style="color:#484f58">No events yet</div>'; return; }
  el.innerHTML = events.map(e =>
    '<div class="event">' +
    '<span class="event-time">' + fmtEventTime(e.timestamp) + '</span>' +
    '<span class="event-type ' + (e.type || '') + '">' + (e.type || '').replace(/_/g, ' ') + '</span>' +
    '<span class="event-msg">' + (e.message || '') + '</span>' +
    '</div>'
  ).join('');
}

async function refresh() {
  try {
    const [proj, teams, events, plan] = await Promise.all([
      fetch(API_BASE + '/project').then(r => r.json()),
      fetch(API_BASE + '/teams').then(r => r.json()),
      fetch(API_BASE + '/events').then(r => r.json()),
      fetch(API_BASE + '/plan').then(r => r.json())
    ]);
    renderProject(proj);
    renderTasks(plan, teams);
    renderEvents(events);
  } catch (e) {
    console.error('Refresh failed:', e);
  }
}

refresh();
setInterval(refresh, 3000);
</script>
</body>
</html>`;
}

function escapeHTML(s) {
  return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// --- HTTP server ---

const server = http.createServer(async (req, res) => {
  // API routes
  if (req.url.startsWith('/api/')) {
    await handleAPI(req, res);
    return;
  }

  // Per-plan detail view: /plan/:project/:planName
  const planMatch = req.url.match(/^\/plan\/([^/]+)\/([^/]+)\/?$/);
  if (planMatch) {
    const project = decodeURIComponent(planMatch[1]);
    const planName = decodeURIComponent(planMatch[2]);
    const entry = findPlan(project, planName);
    if (!entry) {
      res.statusCode = 404;
      res.setHeader('Content-Type', 'text/html');
      res.end('<html><body style="background:#0d1117;color:#f85149;font-family:system-ui;padding:40px"><h1>Plan not found</h1><p>' + escapeHTML(project) + ' / ' + escapeHTML(planName) + '</p><a href="/" style="color:#58a6ff">Back to dashboard</a></body></html>');
      return;
    }
    res.setHeader('Content-Type', 'text/html');
    res.end(getPlanDetailHTML(project, planName));
    return;
  }

  // Homepage
  if (req.url === '/' || req.url === '/index.html') {
    res.setHeader('Content-Type', 'text/html');
    res.end(HOMEPAGE_HTML);
    return;
  }

  // Fallback
  res.statusCode = 404;
  res.setHeader('Content-Type', 'text/plain');
  res.end('Not found');
});

// --- Startup ---

// Write PID file
fs.mkdirSync(path.dirname(PID_FILE), { recursive: true });
fs.writeFileSync(PID_FILE, String(process.pid));

// Discover historical plans
discoverPlans();

server.listen(PORT, '0.0.0.0', () => {
  const ifaces = os.networkInterfaces();
  const ips = Object.values(ifaces).flat()
    .filter(i => i.family === 'IPv4' && !i.internal)
    .map(i => i.address);

  console.log(`Global dashboard running on port ${PORT}`);
  console.log(`  Local:     http://localhost:${PORT}`);
  ips.forEach(ip => console.log(`  Network:   http://${ip}:${PORT}`));
  console.log(`  Registry:  ${REGISTRY_FILE}`);
  console.log(`  PID file:  ${PID_FILE}`);
});

// Clean up PID file on exit
process.on('exit', () => { try { fs.unlinkSync(PID_FILE); } catch {} });
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
