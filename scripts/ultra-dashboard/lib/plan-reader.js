const fs = require('fs');
const path = require('path');

function readJSON(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch {
    return null;
  }
}

function readPlanStatus(planDir) {
  // Try plan root first (new convention), fall back to status/ (legacy)
  let filePath = path.join(planDir, 'plan.json');
  let data = readJSON(filePath);
  if (!data) {
    filePath = path.join(planDir, 'status', 'plan.json');
    data = readJSON(filePath);
  }
  if (!data) return null;
  try {
    const stat = fs.statSync(filePath);
    data._last_modified_ms = stat.mtime.getTime();
  } catch {}
  return data;
}

function readPlanTeams(planDir) {
  // New convention: tasks are embedded in plan.json
  const data = readPlanStatus(planDir);
  if (data && Array.isArray(data.tasks)) {
    return data.tasks;
  }
  // Legacy fallback: read from status/teams/ directory
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
  // Try plan root first (new convention), fall back to status/ (legacy)
  return readJSON(path.join(planDir, 'events.json'))
    || readJSON(path.join(planDir, 'status', 'events.json'))
    || { events: [] };
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

module.exports = { readPlanStatus, readPlanTeams, readPlanEvents, parsePlanTasks };
