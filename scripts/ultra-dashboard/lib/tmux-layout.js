const { execSync } = require('child_process');

const LEFT_WIDTH = 70;
const managedWindows = new Map(); // windowId -> { lastSnapshot, lastSize }

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
  if (!classified.mainPane) return; // Not a managed window

  const { mainPane, pmPane, tkPane, gatePane, tasks } = classified;
  const taskNums = Object.keys(tasks).sort((a, b) => parseInt(a) - parseInt(b));

  // Collect all labeled non-main panes
  const labeledPanes = [];
  if (pmPane) labeledPanes.push(pmPane);
  if (tkPane) labeledPanes.push(tkPane);
  if (gatePane) labeledPanes.push(gatePane);
  for (const num of taskNums) {
    labeledPanes.push(...tasks[num]);
  }

  if (labeledPanes.length === 0) return; // Nothing to arrange

  // Break all labeled non-main panes to hidden windows
  for (const pid of labeledPanes) {
    tmux(`break-pane -d -s ${pid}`);
  }

  // Small delay for tmux to process
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

    // Stack remaining panes below
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

  // Equalize columns (two-pass)
  if (columnHeads.length > 0) {
    const winWidth = parseInt(tmux(`display-message -t ${mainPane} -p "#{window_width}"`) || '0');
    const winHeight = parseInt(tmux(`display-message -t ${mainPane} -p "#{window_height}"`) || '0');

    if (winWidth > 0) {
      const rightWidth = winWidth - LEFT_WIDTH - 1;
      const colWidth = Math.floor((rightWidth - (columnHeads.length - 1)) / columnHeads.length);

      for (let pass = 0; pass < 2; pass++) {
        for (const head of columnHeads) {
          tmux(`resize-pane -t ${head} -x ${colWidth}`);
        }
        // Pin all left-column panes
        for (const lp of [mainPane, pmPane, tkPane]) {
          if (lp) tmux(`resize-pane -t ${lp} -x ${LEFT_WIDTH}`);
        }
      }
    }

    // Enforce left column heights
    if (winHeight > 0) {
      let leftCount = 1;
      if (pmPane) leftCount++;
      if (tkPane) leftCount++;
      if (leftCount === 3) {
        const mainH = Math.floor(winHeight * 50 / 100);
        const sharedH = Math.floor((winHeight - mainH) / 2);
        tmux(`resize-pane -t ${mainPane} -y ${mainH}`);
        tmux(`resize-pane -t ${pmPane} -y ${sharedH}`);
      } else if (leftCount === 2) {
        const mainH = Math.floor(winHeight * 60 / 100);
        tmux(`resize-pane -t ${mainPane} -y ${mainH}`);
      }
    }
  }

  // Ensure borders show labels
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

let intervalId = null;

function tick() {
  const windows = scanPanes();

  for (const [windowId, panes] of windows) {
    // Only manage windows with a main-context pane
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
      // Re-read after arrangement
      const updated = scanPanes().get(windowId) || panes;
      managedWindows.set(windowId, {
        lastSnapshot: getSnapshot(updated),
        lastSize: getSize(updated)
      });
    }
  }

  // Clean up windows that no longer exist
  for (const windowId of managedWindows.keys()) {
    if (!windows.has(windowId)) {
      managedWindows.delete(windowId);
    }
  }
}

function startLayoutManager(opts = {}) {
  const interval = opts.interval || 2000;
  // Set main-context label on the pane that started us (if running inside tmux)
  const currentPane = tmux('display-message -p "#{pane_id}"');
  if (currentPane) {
    tmux(`set-option -p -t ${currentPane} @agent-name "main-context"`);
  }
  intervalId = setInterval(tick, interval);
  console.log(`Layout manager started (${interval}ms poll)`);
}

function stopLayoutManager() {
  if (intervalId) {
    clearInterval(intervalId);
    intervalId = null;
  }
}

function getLayoutState() {
  const state = {};
  for (const [windowId, data] of managedWindows) {
    state[windowId] = { ...data };
  }
  return state;
}

module.exports = { startLayoutManager, stopLayoutManager, getLayoutState, arrangeWindow, scanPanes };
