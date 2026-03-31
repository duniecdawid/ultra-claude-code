const { execSync } = require('child_process');
const path = require('path');

// Cache: key = "docsDir|since", value = { data, ts }
const cache = new Map();
const CACHE_TTL = 10_000;

const SINCE_RE = /^(HEAD~\d{1,3}|\d+\s*(hours?|days?|weeks?)\s*ago)$/;

function getGitChanges(docsDir, since = 'HEAD~5') {
  if (!SINCE_RE.test(since)) since = 'HEAD~5';

  const key = `${docsDir}|${since}`;
  const cached = cache.get(key);
  if (cached && Date.now() - cached.ts < CACHE_TTL) return cached.data;

  try {
    const gitRoot = execSync(`git -C "${docsDir}" rev-parse --show-toplevel`, {
      encoding: 'utf8', timeout: 5000
    }).trim();

    // Get diff of documentation dir against the ref
    const diff = execSync(
      `git -C "${gitRoot}" diff --unified=0 --no-color "${since}" -- "${docsDir}"`,
      { encoding: 'utf8', timeout: 10000, maxBuffer: 5 * 1024 * 1024 }
    );

    const result = parseDiff(diff, docsDir);
    cache.set(key, { data: result, ts: Date.now() });
    return result;
  } catch (e) {
    // git errors (no repo, bad ref, etc.) — return empty
    const empty = { changedFiles: [], fileChanges: {} };
    cache.set(key, { data: empty, ts: Date.now() });
    return empty;
  }
}

function parseDiff(diff, docsDir) {
  const changedFiles = [];
  const fileChanges = {};
  let currentFile = null;
  const docsDirName = path.basename(docsDir);

  for (const line of diff.split('\n')) {
    // Match: diff --git a/documentation/path b/documentation/path
    if (line.startsWith('diff --git ')) {
      const match = line.match(/diff --git a\/.+ b\/(.+)/);
      if (match) {
        const fullPath = match[1];
        // Strip everything up to and including "documentation/"
        const idx = fullPath.indexOf(docsDirName + '/');
        currentFile = idx >= 0 ? fullPath.slice(idx + docsDirName.length + 1) : fullPath;
        if (!fileChanges[currentFile]) {
          changedFiles.push(currentFile);
          fileChanges[currentFile] = { changedLines: [] };
        }
      }
      continue;
    }

    // Match: @@ -old[,count] +new[,count] @@
    if (line.startsWith('@@') && currentFile) {
      const match = line.match(/@@ .+ \+(\d+)(?:,(\d+))? @@/);
      if (match) {
        const start = parseInt(match[1], 10);
        const count = match[2] !== undefined ? parseInt(match[2], 10) : 1;
        if (count > 0) {
          fileChanges[currentFile].changedLines.push([start, start + count - 1]);
        }
      }
    }
  }

  return { changedFiles, fileChanges };
}

module.exports = { getGitChanges };
