const fs = require('fs');
const path = require('path');
const os = require('os');
const { readRegistry } = require('./registry');

const STALL_THRESHOLD = 600; // 10 minutes in seconds
const healthState = new Map(); // planDir -> { stalledTasks, totalTasks, status, rateLimitSuspected }

function log(planDir, message) {
  const logFile = path.join(planDir, 'watchdog.log');
  const timestamp = new Date().toISOString();
  try {
    fs.appendFileSync(logFile, `[${timestamp}] ${message}\n`);
  } catch {}
}

function writeStatus(planDir, stalledTasks, totalTasks, status, rateLimitSuspected, usage) {
  const statusFile = path.join(planDir, 'watchdog-status.json');
  const data = {
    timestamp: new Date().toISOString(),
    status,
    stalled_tasks: stalledTasks,
    total_active_tasks: totalTasks,
    rate_limit_suspected: rateLimitSuspected,
    usage_threshold_exceeded: usage ? usage.threshold_exceeded : false,
    usage_five_hour_pct: usage ? usage.five_hour_pct : null,
    usage_resets_at: usage ? usage.resets_at : null,
    check_interval_seconds: 30,
    stall_threshold_seconds: STALL_THRESHOLD
  };
  try {
    const tmp = statusFile + '.tmp.' + process.pid;
    fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
    fs.renameSync(tmp, statusFile);
  } catch {}

  healthState.set(planDir, data);
}

function checkPlan(planDir) {
  const tasksDir = path.join(planDir, 'tasks');
  let taskDirs;
  try {
    taskDirs = fs.readdirSync(tasksDir, { withFileTypes: true })
      .filter(d => d.isDirectory() && d.name.startsWith('task-'))
      .map(d => path.join(tasksDir, d.name));
  } catch {
    writeStatus(planDir, 0, 0, 'waiting_for_tasks', false);
    return;
  }

  if (taskDirs.length === 0) {
    writeStatus(planDir, 0, 0, 'waiting_for_tasks', false);
    return;
  }

  const nowEpoch = Math.floor(Date.now() / 1000);
  let stalledCount = 0;
  let activeCount = 0;

  for (const taskDir of taskDirs) {
    let latestMod = 0;
    try {
      const files = findMdFiles(taskDir);
      for (const file of files) {
        const stat = fs.statSync(file);
        const modTime = Math.floor(stat.mtimeMs / 1000);
        if (modTime > latestMod) latestMod = modTime;
      }
    } catch {}

    if (latestMod === 0) continue; // No files yet — task just started

    activeCount++;
    const age = nowEpoch - latestMod;
    if (age > STALL_THRESHOLD) {
      stalledCount++;
      const taskName = path.basename(taskDir);
      log(planDir, `STALL: ${taskName} — no changes for ${Math.floor(age / 60)} minutes`);
    }
  }

  // Rate limit detection: all active tasks stalled simultaneously
  const rateLimitSuspected = activeCount > 1 && stalledCount === activeCount;

  let status;
  if (rateLimitSuspected) {
    status = 'rate_limit_suspected';
    log(planDir, `RATE LIMIT SUSPECTED: all ${activeCount} active tasks stalled`);
  } else if (stalledCount > 0) {
    status = 'partial_stall';
  } else {
    status = 'healthy';
  }

  // Check usage threshold and include in status
  const usage = checkUsageThreshold();
  const usageExceeded = usage ? usage.threshold_exceeded : false;

  writeStatus(planDir, stalledCount, activeCount, status, rateLimitSuspected, usage);
}

function checkUsageThreshold() {
  const usageFile = path.join(os.homedir(), '.claude', 'usage-status.json');
  try {
    const data = JSON.parse(fs.readFileSync(usageFile, 'utf8'));
    if (!data.accounts) return null;

    // Find most recently updated account
    let latest = null;
    for (const account of Object.values(data.accounts)) {
      if (!latest || (account.updated_at || '') > (latest.updated_at || '')) {
        latest = account;
      }
    }
    if (!latest || !latest.rate_limits || !latest.rate_limits.five_hour) return null;

    const fh = latest.rate_limits.five_hour;
    return {
      five_hour_pct: fh.used_percentage,
      resets_at: fh.resets_at,
      threshold_exceeded: fh.used_percentage >= 90,
      updated_at: latest.updated_at
    };
  } catch {
    return null;
  }
}

function findMdFiles(dir) {
  const results = [];
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      if (entry.isFile() && entry.name.endsWith('.md')) {
        results.push(fullPath);
      } else if (entry.isDirectory()) {
        results.push(...findMdFiles(fullPath));
      }
    }
  } catch {}
  return results;
}

let intervalId = null;

function tick() {
  const reg = readRegistry();
  const activePlans = reg.plans.filter(p => p.active);

  for (const plan of activePlans) {
    if (fs.existsSync(plan.plan_dir)) {
      checkPlan(plan.plan_dir);
    }
  }
}

function startHealthMonitor(opts = {}) {
  const interval = opts.interval || 30000;
  intervalId = setInterval(tick, interval);
  // Run initial check immediately
  tick();
  console.log(`Health monitor started (${interval}ms poll)`);
}

function stopHealthMonitor() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
  }
}

function getHealthState() {
  const state = {};
  for (const [planDir, data] of healthState) {
    state[planDir] = { ...data };
  }
  return state;
}

module.exports = { startHealthMonitor, stopHealthMonitor, getHealthState, checkUsageThreshold };
