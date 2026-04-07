const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));
app.use(express.static(path.join(__dirname, 'public')));

const pages = {
  'discovery': { title: 'Discovery', description: 'Product discovery and market research with AI-powered parallel investigation.' },
  'feature-planning': { title: 'Feature Planning', description: 'Plan features with scope challenge, codebase research, and structured task breakdown.' },
  'plan-execution': { title: 'Plan Execution', description: 'Execute plans with coordinated agent teams — Executor, Reviewer, and Tester per task.' },
  'debugging': { title: 'Debugging', description: 'Hypothesis-driven bug investigation with parallel evidence gathering and reproduction.' },
  'verification': { title: 'Verification', description: 'Detect documentation drift and verify code matches specifications.' },
  'standards': { title: 'Technology Standards', description: 'Define, enforce, and verify coding standards across your project.' },
  'reference': { title: 'Reference', description: 'Complete reference of all 22 skills and 10 agents in Ultra Claude.' }
};

app.get('/', (req, res) => {
  res.render('index', {
    title: 'Ultra Claude',
    description: 'Spec-driven development for Claude Code. Documentation governs code growth. Agent teams coordinate execution.',
    page: 'home'
  });
});

app.get('/getting-started', (req, res) => {
  res.render('getting-started', {
    title: 'Getting Started — Ultra Claude',
    description: 'Install Ultra Claude, initialize your project, and plan your first feature in under 10 minutes.',
    page: 'getting-started'
  });
});

app.get('/docs/:page', (req, res) => {
  const pageData = pages[req.params.page];
  if (!pageData) return res.status(404).send('Page not found');
  res.render(`docs/${req.params.page}`, {
    title: `${pageData.title} — Ultra Claude`,
    description: pageData.description,
    page: req.params.page
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Ultra Claude docs running on port ${PORT}`);
});
