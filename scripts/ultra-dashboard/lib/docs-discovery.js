const fs = require('fs');
const path = require('path');
const { getProjectRoots } = require('./registry');

function getDocProjects() {
  const roots = getProjectRoots();
  const projects = [];
  const seen = new Set();

  for (const root of roots) {
    const docsDir = path.join(root, 'documentation');
    const name = path.basename(root);
    if (seen.has(name)) continue;
    seen.add(name);
    try {
      const stat = fs.statSync(docsDir);
      if (stat.isDirectory()) {
        projects.push({ name, slug: name, root, docsDir });
      }
    } catch {}
  }

  return projects.sort((a, b) => a.name.localeCompare(b.name));
}

function resolveProject(slug) {
  return getDocProjects().find(p => p.slug === slug) || null;
}

// Section display names for canonical directories
const SECTION_NAMES = {
  technology: 'Technology',
  architecture: 'Architecture',
  standards: 'Standards',
  testing: 'Testing',
  rfcs: 'RFCs',
  product: 'Product',
  description: 'Description',
  research: 'Research',
  requirements: 'Requirements',
  personas: 'Personas',
  plans: 'Plans',
  dependencies: 'Dependencies',
};

function toTitle(filename) {
  return filename
    .replace(/\.md$/i, '')
    .replace(/^README$/i, 'Overview')
    .replace(/^(\d+)-/, '$1. ')
    .replace(/-/g, ' ')
    .replace(/\b\w/g, c => c.toUpperCase());
}

function generateSidebar(docsDir) {
  // Use existing _sidebar.md if present
  const existing = path.join(docsDir, '_sidebar.md');
  try {
    return fs.readFileSync(existing, 'utf8');
  } catch {}

  const lines = ['- [Home](README.md)', ''];

  // Top-level README files (other than the main one)
  const topFiles = listMdFiles(docsDir).filter(f => f !== 'README.md');
  topFiles.forEach(f => lines.push(`- [${toTitle(f)}](${f})`));
  if (topFiles.length) lines.push('');

  // Walk canonical top-level directories
  const topDirs = ['technology', 'product', 'plans', 'dependencies'];
  for (const topDir of topDirs) {
    const dirPath = path.join(docsDir, topDir);
    if (!isDir(dirPath)) continue;

    const sectionName = SECTION_NAMES[topDir] || toTitle(topDir);
    const topReadme = listMdFiles(dirPath).find(f => f.toLowerCase() === 'readme.md');
    if (topReadme) {
      lines.push(`- **[${sectionName}](${topDir}/${topReadme})**`);
    } else {
      lines.push(`- **${sectionName}**`);
    }

    if (topDir === 'technology' || topDir === 'product') {
      // Direct files under technology/ or product/
      const directFiles = listMdFiles(dirPath).filter(f => f.toLowerCase() !== 'readme.md');
      for (const f of directFiles) {
        lines.push(`  - [${toTitle(f)}](${topDir}/${f})`);
      }
      // Subdirectories as nested sections
      const subDirs = listDirs(dirPath);
      for (const sub of subDirs) {
        const subPath = path.join(dirPath, sub);
        const subName = SECTION_NAMES[sub] || toTitle(sub);
        const subFiles = listMdFiles(subPath);
        if (subFiles.length === 0) continue;

        const readme = subFiles.find(f => f.toLowerCase() === 'readme.md');
        if (readme) {
          lines.push(`  - **[${subName}](${topDir}/${sub}/${readme})**`);
        } else {
          lines.push(`  - **${subName}**`);
        }
        for (const f of subFiles) {
          if (f.toLowerCase() === 'readme.md') continue;
          lines.push(`    - [${toTitle(f)}](${topDir}/${sub}/${f})`);
        }
      }
    } else if (topDir === 'plans') {
      // Plan directories — just show plan names linking to their README
      const planDirs = listDirs(dirPath);
      for (const plan of planDirs) {
        const planReadme = path.join(dirPath, plan, 'README.md');
        if (fs.existsSync(planReadme)) {
          lines.push(`  - [${toTitle(plan)}](plans/${plan}/README.md)`);
        }
      }
    } else {
      // dependencies or other — list files
      const files = listMdFiles(dirPath);
      for (const f of files) {
        lines.push(`  - [${toTitle(f)}](${topDir}/${f})`);
      }
    }
    lines.push('');
  }

  // Catch any other top-level directories not in the canonical list
  const allTopDirs = listDirs(docsDir);
  for (const d of allTopDirs) {
    if (topDirs.includes(d) || d.startsWith('.') || d.startsWith('_')) continue;
    const dirPath = path.join(docsDir, d);
    const files = listMdFilesRecursive(dirPath, d);
    if (files.length === 0) continue;
    lines.push(`- **${SECTION_NAMES[d] || toTitle(d)}**`);
    for (const { rel, title } of files) {
      lines.push(`  - [${title}](${rel})`);
    }
    lines.push('');
  }

  return lines.join('\n');
}

function listMdFiles(dir) {
  try {
    return fs.readdirSync(dir)
      .filter(f => f.endsWith('.md') && !f.startsWith('_') && fs.statSync(path.join(dir, f)).isFile())
      .sort();
  } catch { return []; }
}

function listDirs(dir) {
  try {
    return fs.readdirSync(dir)
      .filter(f => !f.startsWith('.') && !f.startsWith('_') && isDir(path.join(dir, f)))
      .sort();
  } catch { return []; }
}

function listMdFilesRecursive(dir, prefix) {
  const results = [];
  try {
    for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
      if (ent.name.startsWith('.') || ent.name.startsWith('_')) continue;
      const rel = prefix + '/' + ent.name;
      if (ent.isFile() && ent.name.endsWith('.md')) {
        results.push({ rel, title: toTitle(ent.name) });
      } else if (ent.isDirectory()) {
        results.push(...listMdFilesRecursive(path.join(dir, ent.name), rel));
      }
    }
  } catch {}
  return results;
}

function isDir(p) {
  try { return fs.statSync(p).isDirectory(); } catch { return false; }
}

function generateDocsifyIndex(projectName, slug) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${esc(projectName)} — Docs</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/docsify-themeable@0/dist/css/theme-simple-dark.min.css">
  <style>
    :root {
      --base-background-color: #0d1117;
      --sidebar-background: #161b22;
      --sidebar-border-color: #21262d;
      --sidebar-nav-link-color--active: #58a6ff;
      --sidebar-nav-link-font-weight--active: 600;
      --search-input-background-color: #21262d;
      --search-input-border-color: #30363d;
      --search-result-keyword-background: #1f6feb44;
      --link-color: #58a6ff;
      --heading-color: #e6edf3;
      --base-color: #c9d1d9;
      --code-inline-background: #21262d;
      --code-theme-background: #161b22;
      --blockquote-border-color: #1f6feb;
      --notice-tip-border-color: #3fb950;
      --table-row-even-background: #161b22;
    }
    .app-name-link { display: none !important; }
    .sidebar > h1 { display: none !important; }
    /* Git change gutter */
    .markdown-section { position: relative !important; }
    .git-gutter {
      position: absolute; left: -14px; top: 0; width: 4px; bottom: 0;
      pointer-events: none; z-index: 10;
    }
    .git-gutter-mark {
      position: absolute; left: 0; width: 4px;
      background: #f0883e; border-radius: 2px; min-height: 4px;
    }
    .sidebar-nav a[data-git-changed]::after {
      content: '●'; color: #f0883e; margin-left: 6px; font-size: 0.7em;
    }
  </style>
</head>
<body>
  <div id="app">Loading...</div>
  <script>
    window.$docsify = {
      basePath: '/docs/${esc(slug)}/',
      loadSidebar: true,
      subMaxLevel: 0,
      search: {
        placeholder: 'Search docs...',
        noData: 'No results',
        paths: 'auto'
      },
      auto2top: true,
      hideSidebar: false,
      relativePath: false,
      plugins: [function gitChanges(hook, vm) {
        var changeData = null;
        var rawMarkdown = '';

        // Fetch git changes once on init
        fetch('/api/docs/${esc(slug)}/git-changes?since=HEAD~5')
          .then(function(r) { return r.json(); })
          .then(function(d) { changeData = d; })
          .catch(function() {});

        // Store raw markdown for line mapping
        hook.beforeEach(function(md) {
          rawMarkdown = md;
          return md;
        });

        hook.doneEach(function() {
          if (!changeData) return;

          // --- Sidebar badges ---
          var links = document.querySelectorAll('.sidebar-nav a[href]');
          for (var i = 0; i < links.length; i++) {
            var href = links[i].getAttribute('href') || '';
            var filePath = href.replace(/^#\\//, '');
            if (!filePath || filePath === '/') filePath = 'README.md';
            if (!/\\.md$/i.test(filePath)) filePath += '.md';
            if (changeData.changedFiles.indexOf(filePath) >= 0) {
              links[i].setAttribute('data-git-changed', '');
            }
          }

          // --- Gutter marks ---
          var file = vm.route.file;
          if (!file || !changeData.fileChanges[file]) return;
          var ranges = changeData.fileChanges[file].changedLines;
          if (!ranges || !ranges.length) return;

          // Build section map: split markdown by blank lines, track line ranges
          var lines = rawMarkdown.split('\\n');
          var sections = [];
          var secStart = 0;
          for (var ln = 0; ln < lines.length; ln++) {
            if (lines[ln].trim() === '' && ln > secStart) {
              sections.push([secStart + 1, ln]); // 1-indexed
              secStart = ln + 1;
            }
          }
          if (secStart < lines.length) sections.push([secStart + 1, lines.length]);

          // Get block elements in rendered content
          var container = document.querySelector('.markdown-section');
          if (!container) return;

          // Remove old gutter
          var old = container.querySelector('.git-gutter');
          if (old) old.remove();

          var blocks = [];
          for (var c = 0; c < container.children.length; c++) {
            var el = container.children[c];
            var tag = el.tagName;
            if (/^(P|H[1-6]|PRE|TABLE|UL|OL|BLOCKQUOTE|HR|DIV|DL)$/.test(tag)) {
              blocks.push(el);
            }
          }

          // Map blocks to sections (sequential 1:1, skip empty sections)
          var gutter = document.createElement('div');
          gutter.className = 'git-gutter';
          var bi = 0;
          for (var si = 0; si < sections.length && bi < blocks.length; si++) {
            var sec = sections[si];
            // Check if any line in this section is purely whitespace (separator)
            var allBlank = true;
            for (var sl = sec[0] - 1; sl < sec[1]; sl++) {
              if (lines[sl] && lines[sl].trim() !== '') { allBlank = false; break; }
            }
            if (allBlank) continue;

            var block = blocks[bi++];
            // Check if this section overlaps any changed range
            var hit = false;
            for (var ri = 0; ri < ranges.length; ri++) {
              if (sec[0] <= ranges[ri][1] && sec[1] >= ranges[ri][0]) {
                hit = true; break;
              }
            }
            if (hit) {
              var mark = document.createElement('div');
              mark.className = 'git-gutter-mark';
              mark.style.top = block.offsetTop + 'px';
              mark.style.height = block.offsetHeight + 'px';
              gutter.appendChild(mark);
            }
          }

          if (gutter.children.length > 0) container.appendChild(gutter);
        });
      }]
    };
  </script>
  <script src="https://cdn.jsdelivr.net/npm/docsify@4/lib/docsify.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/docsify@4/lib/plugins/search.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-javascript.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-typescript.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-bash.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-json.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-yaml.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-python.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/prismjs@1/components/prism-go.min.js"></script>
</body>
</html>`;
}

function esc(s) {
  return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

module.exports = { getDocProjects, resolveProject, generateSidebar, generateDocsifyIndex };
