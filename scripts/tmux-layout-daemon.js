#!/usr/bin/env node
// Tmux Layout Daemon — arranges panes by @agent-name labels
// Usage: node tmux-layout-daemon.js [--ensure]
// --ensure: check if already running, start in background if not

const fs = require('fs');
const path = require('path');
const os = require('os');
const { execFileSync, spawn } = require('child_process');

const HOME = os.homedir();
const PID_FILE = path.join(HOME, '.claude', 'ultra', 'tmux-layout.pid');
const LOG_FILE = path.join(HOME, '.claude', 'ultra', 'tmux-layout-daemon.log');
const LOG_MAX_BYTES = 2 * 1024 * 1024; // 2 MB

function log(msg) {
  try {
    try {
      const stat = fs.statSync(LOG_FILE);
      if (stat.size > LOG_MAX_BYTES) fs.writeFileSync(LOG_FILE, '');
    } catch {}
    fs.appendFileSync(LOG_FILE, `[${new Date().toISOString()}] ${msg}\n`);
  } catch {}
}

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

// Run one tmux command. argv is an array like ['break-pane', '-d', '-s', '%5'].
function tmux(argv) {
  return tmuxBatch([argv]);
}

// Run multiple tmux commands in a single tmux invocation using the `;`
// command separator. All commands go through tmux's internal command queue
// in one server round-trip, with a single redraw at the end — this is the
// key to avoiding visible pane tearing during rearrangement. Returns the
// combined stdout (tmux separates output with newlines between commands).
function tmuxBatch(cmds) {
  if (!cmds || cmds.length === 0) return '';
  const args = [];
  for (let i = 0; i < cmds.length; i++) {
    if (i > 0) args.push(';');
    args.push(...cmds[i]);
  }
  try {
    return execFileSync('tmux', args, { encoding: 'utf8', timeout: 5000 }).trim();
  } catch (err) {
    log(`ERROR: tmux batch (${cmds.length} cmds) failed: ${err.message || err}`);
    return null;
  }
}

// --- Layout string builder (Tier 2: atomic select-layout) ---
//
// tmux layout format (see tmux/layout-custom.c):
//   "<csum>,<body>"  where csum = layout_checksum(body) as 4 lowercase hex digits.
// Body cells:
//   leaf:  "WxH,xoff,yoff,paneNum"          (paneNum = pane_id without the '%' prefix)
//   split: "WxH,xoff,yoff{child,child,...}" (left-right) or "[...]" (top-bottom)
// Size math: sum(child sizes) + (count - 1) separators === parent size.

function layoutChecksum(body) {
  let c = 0;
  for (let i = 0; i < body.length; i++) {
    c = ((c >>> 1) | ((c & 1) << 15)) & 0xffff;
    c = (c + body.charCodeAt(i)) & 0xffff;
  }
  return c.toString(16).padStart(4, '0');
}

// Split `total` into `count` sibling sizes with 1-px separators between them.
// Sum(sizes) + (count - 1) === total. Remainder is distributed to the first cells.
// Returns null if there isn't enough room for every cell to get at least 1 px.
function distributeSize(total, count) {
  if (count <= 0) return null;
  if (count === 1) return [total];
  const available = total - (count - 1);
  if (available < count) return null;
  const base = Math.floor(available / count);
  const remainder = available % count;
  const sizes = new Array(count).fill(base);
  for (let i = 0; i < remainder; i++) sizes[i] += 1;
  return sizes;
}

// Build a layout body string for the given window size and column groups.
// `columnGroups` is an ordered array of columns; each column is an array of
// paneNums (top to bottom). Returns null if the window is too small.
function buildLayoutBody(W, H, columnGroups) {
  if (!columnGroups || columnGroups.length === 0) return null;

  // Single-pane special case: no splits at all.
  if (columnGroups.length === 1 && columnGroups[0].length === 1) {
    return `${W}x${H},0,0,${columnGroups[0][0]}`;
  }

  const colCount = columnGroups.length;
  const colWidths = distributeSize(W, colCount);
  if (!colWidths) return null;

  const colStrings = [];
  let xoff = 0;
  for (let c = 0; c < colCount; c++) {
    const cw = colWidths[c];
    const panes = columnGroups[c];
    const rowCount = panes.length;
    if (rowCount === 1) {
      colStrings.push(`${cw}x${H},${xoff},0,${panes[0]}`);
    } else {
      const rowHeights = distributeSize(H, rowCount);
      if (!rowHeights) return null;
      const rowStrings = [];
      let yoff = 0;
      for (let r = 0; r < rowCount; r++) {
        const rh = rowHeights[r];
        rowStrings.push(`${cw}x${rh},${xoff},${yoff},${panes[r]}`);
        yoff += rh + 1;
      }
      colStrings.push(`${cw}x${H},${xoff},0[${rowStrings.join(',')}]`);
    }
    xoff += cw + 1;
  }

  if (colCount === 1) {
    // Single column with multiple rows — colStrings[0] is already the full layout.
    return colStrings[0];
  }
  return `${W}x${H},0,0{${colStrings.join(',')}}`;
}

// Compute the list of (src, tgt) pane_id swaps that transform `currentIds`
// into `targetIds`. Both arrays must contain the same set of IDs.
// Each swap exchanges the TAILQ positions of src and tgt.
function computeSwaps(currentIds, targetIds) {
  const cur = [...currentIds];
  const swaps = [];
  for (let i = 0; i < targetIds.length; i++) {
    if (cur[i] === targetIds[i]) continue;
    const j = cur.indexOf(targetIds[i], i + 1);
    if (j === -1) return null;
    swaps.push([cur[i], cur[j]]);
    [cur[i], cur[j]] = [cur[j], cur[i]];
  }
  return swaps;
}

function scanPanes() {
  const output = tmux(['list-panes', '-a', '-F', '#{window_id} #{pane_id} #{@agent-name} #{pane_width} #{pane_height}']);
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

// Matches labels like "task-3" (legacy, no role) or "task-3-executor".
// Group 1 = task number, group 2 = role (optional).
const TASK_LABEL_RE = /^task-(\d+)(?:-(executor|reviewer|tester))?$/;

// Role priority for sorting panes within a task column.
// Anything without a recognized role falls last and preserves scan order among peers.
const ROLE_PRIORITY = { executor: 0, reviewer: 1, tester: 2 };
const ROLE_PRIORITY_UNKNOWN = 3;

function classifyPanes(panes) {
  const result = { mainPane: null, pmPane: null, gatePane: null, tasks: {}, unnamed: [] };

  // Intermediate buckets carry (role, scan order) so we can sort each task
  // column deterministically by role (executor, reviewer, tester).
  const buckets = {};
  let scanIdx = 0;

  for (const p of panes) {
    const sIdx = scanIdx++;
    if (p.label === 'main-context') result.mainPane = p.paneId;
    else if (p.label.startsWith('pm')) result.pmPane = p.paneId;
    else if (p.label.startsWith('final-gate')) result.gatePane = p.paneId;
    else {
      const match = p.label.match(TASK_LABEL_RE);
      if (match) {
        const num = match[1];
        const role = match[2] || null;
        if (!buckets[num]) buckets[num] = [];
        buckets[num].push({ paneId: p.paneId, role, sIdx });
      } else {
        result.unnamed.push(p.paneId);
      }
    }
  }

  for (const num of Object.keys(buckets)) {
    buckets[num].sort((a, b) => {
      const pa = a.role != null ? ROLE_PRIORITY[a.role] : ROLE_PRIORITY_UNKNOWN;
      const pb = b.role != null ? ROLE_PRIORITY[b.role] : ROLE_PRIORITY_UNKNOWN;
      if (pa !== pb) return pa - pb;
      return a.sIdx - b.sIdx;
    });
    result.tasks[num] = buckets[num].map(x => x.paneId);
  }

  return result;
}

const TASK_COLUMN_CAPACITY = 3; // executor + reviewer + tester

// Fold unnamed panes into the rightmost task column (up to TASK_COLUMN_CAPACITY).
// Returns any leftover unnamed panes that overflow into their own column.
function foldUnnamedIntoLastTask(tasks, taskNums, unnamed) {
  const leftover = [...unnamed];
  if (taskNums.length === 0 || leftover.length === 0) return leftover;
  const lastTask = tasks[taskNums[taskNums.length - 1]];
  const space = Math.max(0, TASK_COLUMN_CAPACITY - lastTask.length);
  if (space > 0) lastTask.push(...leftover.splice(0, space));
  return leftover;
}

// Compute the target layout as an ordered list of columns. Used both by
// arrangeWindow and by the tick loop (for change detection).
function computeTargetColumns(classified) {
  const { mainPane, pmPane, gatePane, tasks, unnamed } = classified;
  const taskNums = Object.keys(tasks).sort((a, b) => parseInt(a) - parseInt(b));

  // Clone tasks so we can mutate for the fold without touching the classification.
  const taskCols = {};
  for (const n of taskNums) taskCols[n] = [...tasks[n]];
  const leftoverUnnamed = foldUnnamedIntoLastTask(taskCols, taskNums, unnamed);

  const columns = [];
  const leftCol = [mainPane, pmPane].filter(Boolean);
  columns.push(leftCol);
  for (const n of taskNums) columns.push(taskCols[n]);
  if (leftoverUnnamed.length > 0) columns.push(leftoverUnnamed);
  if (gatePane) columns.push([gatePane]);
  return { columns, taskCols, taskNums, leftoverUnnamed };
}

function targetSignature(columns) {
  return columns.map(col => col.join(',')).join('|');
}

function arrangeWindow(windowId, panes) {
  const classified = classifyPanes(panes);
  if (!classified.mainPane) return;

  // Target layout derived from pane labels. `columns` is a DFS-ordered
  // list of column groups: [left, taskCol*, leftover?, gate?].
  const { columns } = computeTargetColumns(classified);
  const targetTailq = columns.flat();
  if (targetTailq.length === 0) return;

  // `panes` arrives in current window TAILQ order (list-panes output).
  // Every pane we classified must map back 1:1 into the window.
  const currentTailq = panes.map(p => p.paneId);
  if (currentTailq.length !== targetTailq.length) {
    log(`ERROR: ${windowId} pane count mismatch current=${currentTailq.length} target=${targetTailq.length}`);
    return;
  }
  const curSet = new Set(currentTailq);
  for (const id of targetTailq) {
    if (!curSet.has(id)) {
      log(`ERROR: ${windowId} target pane ${id} not in current window`);
      return;
    }
  }

  // Permutation of the TAILQ so select-layout assigns the right pane
  // to the right DFS cell. Each entry is a (src pane_id, tgt pane_id) swap.
  const swaps = computeSwaps(currentTailq, targetTailq);
  if (!swaps) {
    log(`ERROR: ${windowId} could not compute swap permutation`);
    return;
  }

  // Query window size for layout sizing.
  const sizeStr = tmux(['display-message', '-t', classified.mainPane, '-p', '#{window_width} #{window_height}']);
  if (!sizeStr) return;
  const [W, H] = sizeStr.split(' ').map(n => parseInt(n) || 0);
  if (W <= 0 || H <= 0) return;

  // Convert pane_ids (%N) to plain numbers for the layout string.
  const toNum = (pid) => parseInt(pid.slice(1), 10);
  const columnGroups = columns.map(col => col.map(toNum));
  const body = buildLayoutBody(W, H, columnGroups);
  if (!body) {
    log(`ERROR: ${windowId} layout body build failed (window ${W}x${H} too small?)`);
    return;
  }
  const layoutArg = `${layoutChecksum(body)},${body}`;

  // One batched tmux invocation: permute TAILQ, apply layout atomically,
  // then reset border format and focus the main pane.
  const batch = [];
  for (const [src, tgt] of swaps) {
    batch.push(['swap-pane', '-d', '-s', src, '-t', tgt]);
  }
  batch.push(['select-layout', '-t', windowId, layoutArg]);
  batch.push(['set-option', '-w', '-t', windowId, 'pane-border-status', 'top']);
  batch.push(['set-option', '-w', '-t', windowId, 'pane-border-format', ' #{@agent-name} ']);
  batch.push(['select-pane', '-t', classified.mainPane]);

  tmuxBatch(batch);
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

    const classified = classifyPanes(panes);
    const { columns, leftoverUnnamed } = computeTargetColumns(classified);
    const signature = targetSignature(columns);
    const size = getSize(panes);
    const prev = managedWindows.get(windowId);

    if (!prev || prev.lastSignature !== signature || prev.lastSize !== size) {
      const reason = !prev ? 'new window' : prev.lastSignature !== signature ? 'layout changed' : 'size changed';
      const taskNums = Object.keys(classified.tasks).sort();
      const foldedCount = classified.unnamed.length - leftoverUnnamed.length;
      const summary = [
        classified.mainPane ? 'main' : null,
        classified.pmPane ? 'pm' : null,
        taskNums.length > 0 ? `tasks:[${taskNums.join(',')}]` : null,
        foldedCount > 0 ? `folded:${foldedCount}` : null,
        leftoverUnnamed.length > 0 ? `unnamed:${leftoverUnnamed.length}` : null,
        classified.gatePane ? 'gate' : null,
      ].filter(Boolean).join(' ');
      log(`ARRANGE: ${windowId} (${reason}) — ${summary}`);

      arrangeWindow(windowId, panes);
      managedWindows.set(windowId, {
        lastSignature: signature,
        lastSize: size
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

const INTERVAL = 1000;
setInterval(tick, INTERVAL);
const startMsg = `Tmux layout daemon running (PID ${process.pid}, ${INTERVAL}ms poll)`;
console.log(startMsg);
log(`STARTUP: ${startMsg}`);

// Clean up on exit
process.on('exit', () => {
  log('SHUTDOWN: daemon exiting');
  try { fs.unlinkSync(PID_FILE); } catch {}
});
process.on('SIGTERM', () => { log('SIGNAL: received SIGTERM'); process.exit(0); });
process.on('SIGINT', () => { log('SIGNAL: received SIGINT'); process.exit(0); });
