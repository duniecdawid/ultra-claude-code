const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const { getDocProjects, resolveProject, generateSidebar, generateDocsifyIndex } = require('../lib/docs-discovery');

function escapeHTML(s) {
  return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// Hub page — list all projects with documentation
router.get('/', (req, res) => {
  const projects = getDocProjects();
  const cards = projects.map(p =>
    `<a href="/docs/${encodeURIComponent(p.slug)}/" class="project-card">` +
      `<div class="project-icon">${escapeHTML(p.name.charAt(0).toUpperCase())}</div>` +
      `<div class="project-info">` +
        `<div class="project-name">${escapeHTML(p.name)}</div>` +
        `<div class="project-path">${escapeHTML(p.root)}</div>` +
      `</div>` +
    `</a>`
  ).join('\n');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Project Documentation</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif; background: #0d1117; color: #c9d1d9; padding: 12px; }
  a { color: #58a6ff; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .header { margin-bottom: 24px; border-bottom: 1px solid #21262d; padding-bottom: 12px; }
  .header-top { display: flex; justify-content: space-between; align-items: baseline; flex-wrap: wrap; gap: 8px; }
  h1 { font-size: 1.3em; color: #58a6ff; margin-bottom: 4px; }
  .back-link { font-size: 0.85em; color: #8b949e; }
  .back-link:hover { color: #58a6ff; }
  .project-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 12px; }
  .project-card { display: flex; align-items: center; gap: 14px; background: #161b22; border: 1px solid #21262d; border-radius: 8px; padding: 16px 18px; transition: border-color 0.2s; text-decoration: none !important; }
  .project-card:hover { border-color: #58a6ff; }
  .project-icon { width: 40px; height: 40px; border-radius: 8px; background: #1f6feb33; color: #58a6ff; display: flex; align-items: center; justify-content: center; font-size: 1.2em; font-weight: 700; flex-shrink: 0; }
  .project-info { min-width: 0; }
  .project-name { font-weight: 600; font-size: 1em; color: #e6edf3; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .project-path { font-size: 0.78em; color: #484f58; font-family: monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; margin-top: 2px; }
  .empty { color: #484f58; text-align: center; padding: 40px; }
  @media (min-width: 640px) { body { padding: 20px; } h1 { font-size: 1.5em; } }
</style>
</head>
<body>
<div class="header">
  <div class="header-top">
    <div>
      <h1>Project Documentation</h1>
      <a href="/" class="back-link">Back to Dashboard</a>
    </div>
    <div style="font-size:0.82em;color:#8b949e;">${projects.length} project${projects.length !== 1 ? 's' : ''}</div>
  </div>
</div>
${projects.length > 0
    ? `<div class="project-grid">${cards}</div>`
    : `<div class="empty">No projects with documentation found.<br>Projects need a <code>documentation/</code> directory to appear here.</div>`
}
</body>
</html>`;

  res.type('html').send(html);
});

// Docsify index for a specific project
router.get('/:project/', (req, res) => {
  const project = resolveProject(decodeURIComponent(req.params.project));
  if (!project) return res.status(404).type('html').send(notFound(req.params.project));
  res.type('html').send(generateDocsifyIndex(project.name, project.slug));
});

// Auto-generated sidebar
router.get('/:project/_sidebar.md', (req, res) => {
  const project = resolveProject(decodeURIComponent(req.params.project));
  if (!project) return res.status(404).send('Not found');
  res.type('text/markdown').send(generateSidebar(project.docsDir));
});

// Serve markdown and assets from project's documentation/ directory
router.get('/:project/*', (req, res) => {
  const project = resolveProject(decodeURIComponent(req.params.project));
  if (!project) return res.status(404).send('Not found');

  // req.params[0] is the wildcard match
  const requestedPath = req.params[0];
  const resolved = path.resolve(project.docsDir, requestedPath);

  // Security: ensure resolved path is within the documentation directory
  if (!resolved.startsWith(project.docsDir + path.sep) && resolved !== project.docsDir) {
    return res.status(404).send('Not found');
  }

  // Check if file exists
  try {
    const stat = fs.statSync(resolved);
    if (!stat.isFile()) return res.status(404).send('Not found');
  } catch {
    return res.status(404).send('Not found');
  }

  // Set appropriate content type
  const ext = path.extname(resolved).toLowerCase();
  const mimeTypes = {
    '.md': 'text/markdown; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css',
    '.js': 'application/javascript',
    '.json': 'application/json',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.gif': 'image/gif',
    '.svg': 'image/svg+xml',
    '.webp': 'image/webp',
    '.pdf': 'application/pdf',
  };

  const contentType = mimeTypes[ext] || 'application/octet-stream';
  res.type(contentType).sendFile(resolved);
});

function notFound(slug) {
  return `<html><body style="background:#0d1117;color:#f85149;font-family:system-ui;padding:40px">` +
    `<h1>Project not found</h1><p>${escapeHTML(slug)}</p>` +
    `<a href="/docs/" style="color:#58a6ff">Back to documentation</a></body></html>`;
}

module.exports = router;
