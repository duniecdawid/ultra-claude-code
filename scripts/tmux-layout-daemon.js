#!/usr/bin/env node
// Tmux Layout Daemon — arranges panes by @agent-name labels
// Usage: node tmux-layout-daemon.js [--ensure]
// --ensure: check if already running, start in background if not

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execSync, spawn } = require('child_process');

const HOME = os.homedir();
const PID_FILE = path.join(HOME, '.claude', 'ultra', 'tmux-layout.pid');

// --- Singleton management ---

function isRunning(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

function readPid() {
  try {
    return parseInt(fs.readFileSync(PID_FILE, 'utf8').trim());
  } catch {
    return null;
  }
}

if (process.argv.includes('--ensure')) {
  const existingPid = readPid();
  if (existingPid && isRunning(existingPid)) {
    console.log(`Tmux layout daemon already running (PID ${existingPid})`);
    process.exit(0);
  }

  // Fork to background
  const child = spawn(process.execPath, [__filename], {
    detached: true,
    stdio: 'ignore',
    env: { ...process.env, TMUX_LAYOUT_DAEMONIZED: '1' }
  });
  child.unref();

  // Wait briefly for startup
  setTimeout(() => {
    const newPid = readPid();
    if (newPid && isRunning(newPid)) {
      console.log(`Tmux layout daemon started (PID ${newPid})`);
    } else {
      console.log('Tmux layout daemon starting...');
    }
    process.exit(0);
  }, 1000);
  return;
}

// --- Layout engine ---

const managedWindows = new Map();

function tmux(cmd) {
  try {
    return execSync('tmux ' + cmd, { encoding: 'utf8', timeout: 5000 }).trim();
  } catch {
    return null;
  }
}

function scanPanes() {
  const output = tmux('list-panes -a -F "#{window_id} #{pane_id} #{@agent-name} #{pane_width} #{pane_height}"');
  if (!output) return new Map();

  const windows = new Map();
  for (const line of output.split('\n')) {
    const parts = line.trim().split(' ');
    if (parts.length < 5) continue;
    const [windowId, paneId, label, width, height] = parts;
    if (!windows.has(windowId)) windows.set(windowId, []);
    windows.get(windowId).push({ paneId, label: label || '', width: parseInt(width), height: parseInt(height) });
  }
  return windows;
}

function classifyPanes(panes) {
  const result = { mainPane: null, pmPane: null, tkPane: null, gatePane: null, tasks: {} };

  for (const p of panes) {
    if (p.label === 'main-context') result.mainPane = p.paneId;
    else if (p.label.startsWith('pm')) result.pmPane = p.paneId;
    else if (p.label.startsWith('knowledge')) result.tkPane = p.paneId;
    else if (p.label.startsWith('final-gate')) result.gatePane = p.paneId;
    else {
      const match = p.label.match(/^task-(\d+)$/);
      if (match) {
        const num = match[1];
        if (!result.tasks[num]) result.tasks[num] = [];
        result.tasks[num].push(p.paneId);
      }
    }
  }
  return result;
}

function arrangeWindow(windowId, panes) {
  const classified = classifyPanes(panes);
  if (!classified.mainPane) return;

  const { mainPane, pmPane, tkPane, gatePane, tasks } = classified;
  const taskNums = Object.keys(tasks).sort((a, b) => parseInt(a) - parseInt(b));

  const labeledPanes = [];
  if (pmPane) labeledPanes.push(pmPane);
  if (tkPane) labeledPanes.push(tkPane);
  if (gatePane) labeledPanes.push(gatePane);
  for (const num of taskNums) {
    labeledPanes.push(...tasks[num]);
  }

  if (labeledPanes.length === 0) return;

  // Break all labeled non-main panes to hidden windows
  for (const pid of labeledPanes) {
    tmux(`break-pane -d -s ${pid}`);
  }

  execSync('sleep 0.2');

  // Rebuild left column
  if (pmPane) {
    tmux(`join-pane -v -s ${pmPane} -t ${mainPane} -l 50%`);
  }
  if (tkPane) {
    const target = pmPane || mainPane;
    tmux(`join-pane -v -s ${tkPane} -t ${target} -l 50%`);
  }

  // Rebuild task columns
  let columnHeads = [];
  for (const num of taskNums) {
    const taskPanes = tasks[num];
    if (taskPanes.length === 0) continue;

    const head = taskPanes[0];
    if (columnHeads.length === 0) {
      tmux(`join-pane -fh -s ${head} -t ${mainPane}`);
    } else {
      const lastCol = columnHeads[columnHeads.length - 1];
      tmux(`join-pane -fh -s ${head} -t ${lastCol}`);
    }
    columnHeads.push(head);

    let prev = head;
    let remaining = taskPanes.length - 1;
    for (let i = 1; i < taskPanes.length; i++) {
      const pct = Math.round(100 * remaining / (remaining + 1));
      tmux(`join-pane -v -s ${taskPanes[i]} -t ${prev} -l ${pct}%`);
      prev = taskPanes[i];
      remaining--;
    }
  }

  // Final gate column
  if (gatePane) {
    if (columnHeads.length === 0) {
      tmux(`join-pane -fh -s ${gatePane} -t ${mainPane}`);
    } else {
      const lastCol = columnHeads[columnHeads.length - 1];
      tmux(`join-pane -fh -s ${gatePane} -t ${lastCol}`);
    }
    columnHeads.push(gatePane);
  }

  // Equalize all columns (left column + task columns + gate) equally
  const totalColumns = 1 + columnHeads.length; // 1 for left column
  const winWidth = parseInt(tmux(`display-message -t ${mainPane} -p "#{window_width}"`) || '0');
  const winHeight = parseInt(tmux(`display-message -t ${mainPane} -p "#{window_height}"`) || '0');

  if (winWidth > 0 && totalColumns > 1) {
    const colWidth = Math.floor((winWidth - (totalColumns - 1)) / totalColumns);

    for (let pass = 0; pass < 2; pass++) {
      for (const head of columnHeads) {
        tmux(`resize-pane -t ${head} -x ${colWidth}`);
      }
      for (const lp of [mainPane, pmPane, tkPane]) {
        if (lp) tmux(`resize-pane -t ${lp} -x ${colWidth}`);
      }
    }
  }

  // Equalize left column panes vertically
  if (winHeight > 0) {
    const leftPanes = [mainPane, pmPane, tkPane].filter(Boolean);
    if (leftPanes.length > 1) {
      const paneH = Math.floor((winHeight - (leftPanes.length - 1)) / leftPanes.length);
      for (const lp of leftPanes) {
        tmux(`resize-pane -t ${lp} -y ${paneH}`);
      }
    }
  }

  tmux(`set-option -w -t ${windowId} pane-border-status top`);
  tmux(`set-option -w -t ${windowId} pane-border-format " #{@agent-name} "`);
  tmux(`select-pane -t ${mainPane}`);
}

function getSnapshot(panes) {
  return panes
    .filter(p => p.label)
    .map(p => `${p.paneId}:${p.label}`)
    .sort()
    .join('|');
}

function getSize(panes) {
  if (panes.length === 0) return '';
  return `${panes[0].width}x${panes[0].height}`;
}

function tick() {
  const windows = scanPanes();

  for (const [windowId, panes] of windows) {
    const hasMain = panes.some(p => p.label === 'main-context');
    if (!hasMain) {
      managedWindows.delete(windowId);
      continue;
    }

    const snapshot = getSnapshot(panes);
    const size = getSize(panes);
    const prev = managedWindows.get(windowId);

    if (!prev || prev.lastSnapshot !== snapshot || prev.lastSize !== size) {
      arrangeWindow(windowId, panes);
      const updated = scanPanes().get(windowId) || panes;
      managedWindows.set(windowId, {
        lastSnapshot: getSnapshot(updated),
        lastSize: getSize(updated)
      });
    }
  }

  for (const windowId of managedWindows.keys()) {
    if (!windows.has(windowId)) {
      managedWindows.delete(windowId);
    }
  }
}

// --- Normal startup (daemon mode) ---

fs.mkdirSync(path.dirname(PID_FILE), { recursive: true });
fs.writeFileSync(PID_FILE, String(process.pid));

const INTERVAL = 2000;
setInterval(tick, INTERVAL);
console.log(`Tmux layout daemon running (PID ${process.pid}, ${INTERVAL}ms poll)`);

// Clean up on exit
process.on('exit', () => { try { fs.unlinkSync(PID_FILE); } catch {} });
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
