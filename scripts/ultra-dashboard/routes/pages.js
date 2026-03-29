const express = require('express');
const fs = require('fs');
const path = require('path');
const router = express.Router();
const { findPlan } = require('../lib/registry');

function escapeHTML(s) {
  return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function readView(name) {
  return fs.readFileSync(path.join(__dirname, '..', 'views', name), 'utf8');
}

// Homepage
router.get('/', (req, res) => {
  res.type('html').send(readView('home.html'));
});

// Per-plan detail
router.get('/plan/:project/:planName', (req, res) => {
  const project = decodeURIComponent(req.params.project);
  const planName = decodeURIComponent(req.params.planName);
  const entry = findPlan(project, planName);
  if (!entry) {
    return res.status(404).type('html').send(
      `<html><body style="background:#0d1117;color:#f85149;font-family:system-ui;padding:40px"><h1>Plan not found</h1><p>${escapeHTML(project)} / ${escapeHTML(planName)}</p><a href="/" style="color:#58a6ff">Back to dashboard</a></body></html>`
    );
  }
  let html = readView('plan.html');
  html = html.replace(/\{\{PROJECT\}\}/g, escapeHTML(project));
  html = html.replace(/\{\{PLAN_NAME\}\}/g, escapeHTML(planName));
  html = html.replace(/\{\{PROJECT_URI\}\}/g, encodeURIComponent(project));
  html = html.replace(/\{\{PLAN_NAME_URI\}\}/g, encodeURIComponent(planName));
  res.type('html').send(html);
});

module.exports = router;
