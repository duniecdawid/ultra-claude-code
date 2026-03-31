const fs = require('fs');
const path = require('path');

/**
 * Read tracker.json for a project.
 * Returns { items: [], summary: { total, open, in_progress, done, by_type, by_priority } }
 */
function readTracker(projectRoot) {
  const trackerPath = path.join(projectRoot, 'documentation', 'tracker.json');
  let items = [];
  try {
    const data = JSON.parse(fs.readFileSync(trackerPath, 'utf8'));
    items = data.items || [];
  } catch {
    // File doesn't exist or is invalid — return empty
  }

  const summary = {
    total: items.length,
    open: 0,
    in_progress: 0,
    done: 0,
    wontfix: 0,
    by_type: { idea: 0, dependency: 0, bug: 0 },
    by_priority: { high: 0, medium: 0, low: 0 }
  };

  for (const item of items) {
    if (item.status === 'open') summary.open++;
    else if (item.status === 'in-progress') summary.in_progress++;
    else if (item.status === 'done') summary.done++;
    else if (item.status === 'wontfix') summary.wontfix++;

    if (summary.by_type[item.type] !== undefined) summary.by_type[item.type]++;
    if (summary.by_priority[item.priority] !== undefined) summary.by_priority[item.priority]++;
  }

  return { items, summary };
}

/**
 * Quick count of open tracker items for badge display.
 */
function getTrackerOpenCount(projectRoot) {
  const { summary } = readTracker(projectRoot);
  return summary.open + summary.in_progress;
}

module.exports = { readTracker, getTrackerOpenCount };
