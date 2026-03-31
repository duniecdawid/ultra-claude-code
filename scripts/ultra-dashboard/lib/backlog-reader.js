const fs = require('fs');
const path = require('path');

const CATEGORIES = [
  { key: 'bug', file: 'bugs.json', prefix: 'B' },
  { key: 'question', file: 'questions.json', prefix: 'Q' },
  { key: 'idea', file: 'ideas.json', prefix: 'I' },
  { key: 'debt', file: 'debt.json', prefix: 'D' }
];

// Map old type names to new category keys
const TYPE_TO_CATEGORY = { bug: 'bug', dependency: 'question', idea: 'idea' };

/**
 * Read all backlog category files for a project.
 * Reads from documentation/backlog/*.json.
 * Returns { items: [], summary: { ... } }
 */
function readBacklog(projectRoot) {
  const backlogDir = path.join(projectRoot, 'documentation', 'backlog');
  let items = [];

  try {
    if (fs.statSync(backlogDir).isDirectory()) {
      for (const cat of CATEGORIES) {
        try {
          const data = JSON.parse(fs.readFileSync(path.join(backlogDir, cat.file), 'utf8'));
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

  // Compute blocked_by from blocks arrays
  const blockedByMap = {};
  for (const item of items) {
    if (item.blocks && item.blocks.length > 0) {
      for (const targetId of item.blocks) {
        if (!blockedByMap[targetId]) blockedByMap[targetId] = [];
        blockedByMap[targetId].push(item.id);
      }
    }
  }
  for (const item of items) {
    item._blocked_by = blockedByMap[item.id] || [];
  }

  const summary = {
    total: items.length,
    open: 0,
    in_progress: 0,
    done: 0,
    wontfix: 0,
    by_category: { bug: 0, question: 0, idea: 0, debt: 0 },
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
 * Quick count of open backlog items for badge display.
 */
function getBacklogOpenCount(projectRoot) {
  const { summary } = readBacklog(projectRoot);
  return summary.open + summary.in_progress;
}

module.exports = { readBacklog, getBacklogOpenCount };
