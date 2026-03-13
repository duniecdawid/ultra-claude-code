#!/usr/bin/env node
// Status Dashboard — zero-dependency Node.js server for plan execution monitoring
// Usage: node status-dashboard.js [port]
// Run from inside the plan directory (documentation/plans/{PLAN_NAME}/)
// Reads status/*.json and status/teams/*.json, serves a live dashboard.

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.argv[2] || '3847', 10);
const PLAN_DIR = process.cwd();
const STATUS_DIR = path.join(PLAN_DIR, 'status');
const TEAMS_DIR = path.join(STATUS_DIR, 'teams');

function readJSON(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function readAllTeams() {
  try {
    const files = fs.readdirSync(TEAMS_DIR).filter(f => f.endsWith('.json')).sort();
    return files.map(f => readJSON(path.join(TEAMS_DIR, f))).filter(Boolean);
  } catch {
    return [];
  }
}

function parsePlanTasks() {
  const readmePath = path.join(PLAN_DIR, 'README.md');
  try {
    const content = fs.readFileSync(readmePath, 'utf8');
    const tasks = [];
    // Match ### Task N: Title lines
    const taskRegex = /^### Task (\d+):\s*(.+)$/gm;
    let match;
    while ((match = taskRegex.exec(content)) !== null) {
      const taskNum = parseInt(match[1], 10);
      const title = match[2].trim();
      // Extract classification if present
      // Scope to current task section (up to next ### Task or end of content)
      const restContent = content.slice(match.index + match[0].length);
      const nextTaskIdx = restContent.search(/^### Task \d+:/m);
      const afterMatch = nextTaskIdx > 0 ? restContent.slice(0, nextTaskIdx) : restContent;
      const classMatch = afterMatch.match(/\*\*Classification:\*\*\s*(\w+)/);
      // Extract dependencies
      const depMatch = afterMatch.match(/\*\*Dependencies:\*\*\s*(.+)/);
      const deps = depMatch ? depMatch[1].trim() : 'None';
      // Extract description (first non-empty line after classification/blank)
      const descMatch = afterMatch.match(/\*\*Description:\*\*\s*(.+)/);
      const description = descMatch ? descMatch[1].trim() : '';
      tasks.push({
        task_id: 'task-' + taskNum,
        task_num: taskNum,
        title: title,
        classification: classMatch ? classMatch[1] : null,
        dependencies: deps,
        description: description
      });
    }
    // Also extract the dependency graph if present
    const graphMatch = content.match(/## Task Dependency Graph[\s\S]*?```([\s\S]*?)```/);
    return { tasks, dependency_graph: graphMatch ? graphMatch[1].trim() : null };
  } catch {
    return { tasks: [], dependency_graph: null };
  }
}

function handleAPI(req, res) {
  res.setHeader('Content-Type', 'application/json');
  res.setHeader('Access-Control-Allow-Origin', '*');

  if (req.url === '/api/project') {
    const data = readJSON(path.join(STATUS_DIR, 'project.json'));
    res.end(JSON.stringify(data || {}));
  } else if (req.url === '/api/teams') {
    res.end(JSON.stringify(readAllTeams()));
  } else if (req.url === '/api/plan') {
    res.end(JSON.stringify(parsePlanTasks()));
  } else if (req.url === '/api/events') {
    const data = readJSON(path.join(STATUS_DIR, 'events.json'));
    res.end(JSON.stringify(data || { events: [] }));
  } else {
    res.statusCode = 404;
    res.end('{"error":"not found"}');
  }
}

const DASHBOARD_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Plan Execution Status</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; padding: 12px; }
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

  /* Task list */
  .task-list { display: flex; flex-direction: column; gap: 6px; }
  .task-item { background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 10px 12px; }
  .task-item.active { border-color: #1f6feb; }
  .task-item.completed { border-color: #238636; }
  .task-item.escalated { border-color: #da3633; }

  /* Row 1: task-id + status badge */
  .task-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2px; }
  .task-id { font-weight: 600; color: #8b949e; font-family: monospace; font-size: 0.82em; }
  .task-item.active .task-id { color: #58a6ff; }
  .task-item.completed .task-id { color: #3fb950; }

  /* Row 2: full-width title */
  .task-title { color: #e6edf3; font-weight: 500; font-size: 0.92em; line-height: 1.3; }
  .task-item:not(.active):not(.completed):not(.escalated) .task-title { color: #8b949e; }
  .task-item.completed .task-title { color: #3fb950; }

  /* Row 3: meta (deps, timing, retries) */
  .task-meta { display: flex; align-items: center; gap: 12px; flex-wrap: wrap; margin-top: 4px; font-size: 0.78em; }
  .task-deps { color: #484f58; }
  .task-timing { color: #8b949e; }
  .task-retries { color: #d29922; }

  /* Expanded details for active/completed tasks */
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

  /* Event log */
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

  /* Desktop */
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
const STAGE_ORDER = ['research', 'planning', 'implementation', 'review', 'testing'];
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
  if (!sec || sec < 0) return '—';
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
    // Fallback: no plan parsed, show teams only
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
      fetch('/api/project').then(r => r.json()),
      fetch('/api/teams').then(r => r.json()),
      fetch('/api/events').then(r => r.json()),
      fetch('/api/plan').then(r => r.json())
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

const server = http.createServer((req, res) => {
  if (req.url.startsWith('/api/')) {
    handleAPI(req, res);
  } else {
    res.setHeader('Content-Type', 'text/html');
    res.end(DASHBOARD_HTML);
  }
});

const HOST = process.argv[3] || '0.0.0.0';

server.listen(PORT, HOST, () => {
  const os = require('os');
  const ifaces = os.networkInterfaces();
  const ips = Object.values(ifaces).flat()
    .filter(i => i.family === 'IPv4' && !i.internal)
    .map(i => i.address);

  console.log(`Status dashboard running on port ${PORT}`);
  console.log(`  Local:     http://localhost:${PORT}`);
  ips.forEach(ip => console.log(`  Network:   http://${ip}:${PORT}`));
  console.log(`  Plan dir:  ${PLAN_DIR}`);
});
