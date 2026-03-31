const fs = require('fs');
const path = require('path');

const CATEGORIES = [
  { key: 'bug', file: 'bugs.json', prefix: 'B' },
  { key: 'external', file: 'external.json', prefix: 'E' },
  { key: 'idea', file: 'ideas.json', prefix: 'I' },
  { key: 'debt', file: 'technical-debt.json', prefix: 'D' }
];

// Map old type names to new category keys
const TYPE_TO_CATEGORY = { bug: 'bug', dependency: 'external', idea: 'idea' };

/**
 * Read all tracker category files for a project.
 * Supports both new multi-file format (documentation/tracker/*.json)
 * and legacy single-file format (documentation/tracker.json).
 * Returns { items: [], summary: { ... } }
 */
function readTracker(projectRoot) {
  const trackerDir = path.join(projectRoot, 'documentation', 'tracker');
  let items = [];

  // Try new multi-file format first
  let foundMultiFile = false;
  try {
    if (fs.statSync(trackerDir).isDirectory()) {
      foundMultiFile = true;
      for (const cat of CATEGORIES) {
        try {
          const data = JSON.parse(fs.readFileSync(path.join(trackerDir, cat.file), 'utf8'));
          const catItems = (data.items || []).map(item => ({ ...item, _category: cat.key }));
          items = items.concat(catItems);
        } catch {
          // File doesn't exist for this category — skip
        }
      }
    }
  } catch {
    // Directory doesn't exist
  }

  // Fall back to legacy single-file format
  if (!foundMultiFile) {
    const legacyPath = path.join(projectRoot, 'documentation', 'tracker.json');
    try {
      const data = JSON.parse(fs.readFileSync(legacyPath, 'utf8'));
      items = (data.items || []).map(item => ({
        ...item,
        _category: TYPE_TO_CATEGORY[item.type] || 'idea'
      }));
    } catch {
      // No tracker at all
    }
  }

  const summary = {
    total: items.length,
    open: 0,
    in_progress: 0,
    done: 0,
    wontfix: 0,
    by_category: { bug: 0, external: 0, idea: 0, debt: 0 },
    by_priority: { high: 0, medium: 0, low: 0 }
  };

  for (const item of items) {
    if (item.status === 'open') summary.open++;
    else if (item.status === 'in-progress') summary.in_progress++;
    else if (item.status === 'done') summary.done++;
    else if (item.status === 'wontfix') summary.wontfix++;

    const cat = item._category || 'idea';
    if (summary.by_category[cat] !== undefined) summary.by_category[cat]++;
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
