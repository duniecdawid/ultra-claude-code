#!/usr/bin/env node
// Ultra Dashboard — unified layout, health monitoring, and web UI
// Usage: node index.js [--ensure]
// --ensure: check if already running, start in background if not

const fs = require('fs');
const path = require('path');
const os = require('os');
const { spawn } = require('child_process');

const PORT = 3847;
const HOME = os.homedir();
const PID_FILE = path.join(HOME, '.claude', 'dashboard.pid');

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
    console.log(`Ultra Dashboard already running (PID ${existingPid}, port ${PORT})`);
    process.exit(0);
  }

  // Fork to background
  const child = spawn(process.execPath, [__filename], {
    detached: true,
    stdio: 'ignore',
    env: { ...process.env, ULTRA_DASHBOARD_DAEMONIZED: '1' }
  });
  child.unref();

  // Wait briefly for startup
  setTimeout(() => {
    const newPid = readPid();
    if (newPid && isRunning(newPid)) {
      console.log(`Ultra Dashboard started (PID ${newPid}, port ${PORT})`);
    } else {
      console.log(`Ultra Dashboard starting... (port ${PORT})`);
    }
    process.exit(0);
  }, 1000);
  return;
}

// --- Normal startup ---

const express = require('express');
const { startLayoutManager } = require('./lib/tmux-layout');

const { discoverPlans, REGISTRY_FILE } = require('./lib/registry');
const apiRoutes = require('./routes/api');
const docsRoutes = require('./routes/docs');
const pageRoutes = require('./routes/pages');

const app = express();

// CORS for API
app.use('/api', (req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  next();
});

app.use('/public', express.static(path.join(__dirname, 'public')));
app.use('/api', apiRoutes);
app.use('/docs', docsRoutes);
app.use('/', pageRoutes);

// Write PID file
fs.mkdirSync(path.dirname(PID_FILE), { recursive: true });
fs.writeFileSync(PID_FILE, String(process.pid));

// Discover historical plans
discoverPlans();

// Start background services
startLayoutManager({ interval: 2000 });

// Start server
app.listen(PORT, '0.0.0.0', () => {
  const ifaces = os.networkInterfaces();
  const ips = Object.values(ifaces).flat()
    .filter(i => i.family === 'IPv4' && !i.internal)
    .map(i => i.address);

  console.log(`Ultra Dashboard running on port ${PORT}`);
  console.log(`  Local:     http://localhost:${PORT}`);
  ips.forEach(ip => console.log(`  Network:   http://${ip}:${PORT}`));
  console.log(`  Registry:  ${REGISTRY_FILE}`);
  console.log(`  PID file:  ${PID_FILE}`);
  console.log(`  Layout:    2s poll (all tmux windows)`);
});

// Clean up on exit
process.on('exit', () => { try { fs.unlinkSync(PID_FILE); } catch {} });
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
