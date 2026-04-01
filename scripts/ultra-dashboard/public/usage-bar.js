// Shared usage bar — included by all dashboard pages
function usageBarColor(pct) {
  if (pct >= 90) return '#f85149';
  if (pct >= 70) return '#d29922';
  return '#3fb950';
}

function fmtCountdown(epoch) {
  if (!epoch) return '';
  var now = Date.now() / 1000;
  var diff = epoch - now;
  if (diff <= 0) return 'reset now';
  if (diff < 60) return 'resets in <1m';
  if (diff < 3600) return 'resets in ' + Math.ceil(diff / 60) + 'm';
  var h = Math.floor(diff / 3600);
  var m = Math.ceil((diff % 3600) / 60);
  return 'resets in ' + h + 'h' + (m > 0 ? ' ' + m + 'm' : '');
}

function ubItem(label, pct, resetEpoch, isOver, isFresh) {
  if (pct == null) return '';
  var p = Math.round(pct);
  var color = usageBarColor(p);
  var bar;
  if (isFresh) {
    bar = '<span class="ub-fresh">FRESH</span>';
  } else if (isOver) {
    bar = '<span class="ub-overlimit">OVER LIMIT</span>';
  } else {
    bar = '<div class="ub-track"><div class="ub-fill" style="width:' + Math.min(p, 100) + '%;background:' + color + '"></div></div>' +
      '<span class="ub-pct" style="color:' + color + '">' + p + '%</span>';
  }
  return '<div class="ub-item">' +
    '<span class="ub-label">' + esc(label) + '</span>' +
    bar +
    (resetEpoch ? '<span class="ub-reset">' + fmtCountdown(resetEpoch) + '</span>' : '') +
  '</div>';
}

function fmtAge(isoStr) {
  if (!isoStr) return '';
  var diff = (Date.now() - new Date(isoStr).getTime()) / 1000;
  if (diff < 0) diff = 0;
  if (diff < 60) return Math.round(diff) + 's ago';
  if (diff < 3600) return Math.round(diff / 60) + 'm ago';
  if (diff < 86400) return Math.round(diff / 3600) + 'h ago';
  return Math.round(diff / 86400) + 'd ago';
}

function renderAccountRow(account, isCurrent, isActive) {
  var rl = account.rate_limits || {};
  var items = '';
  var nowEpoch = Date.now() / 1000;
  if (rl.five_hour) {
    var fhPast = rl.five_hour.resets_at && rl.five_hour.resets_at <= nowEpoch;
    var fhOver = rl.five_hour.used_percentage > 100 && !fhPast;
    items += ubItem('5h', rl.five_hour.used_percentage, rl.five_hour.resets_at, fhOver, fhPast);
  }
  if (rl.seven_day) {
    var sdPast = rl.seven_day.resets_at && rl.seven_day.resets_at <= nowEpoch;
    var sdOver = rl.seven_day.used_percentage > 100 && !sdPast;
    items += ubItem('7d', rl.seven_day.used_percentage, rl.seven_day.resets_at, sdOver, sdPast);
  }
  var age = fmtAge(account.updated_at);
  var ageSec = account.updated_at ? (Date.now() - new Date(account.updated_at).getTime()) / 1000 : 0;
  var staleClass = ageSec > 600 ? ' ub-stale' : '';
  var acct = '<span class="ub-account">' + esc(account.email || '');
  if (account.orgName) acct += ' <span class="ub-org">' + esc(account.orgName) + '</span>';
  acct += ' <span class="ub-age' + staleClass + '">' + age + '</span>';
  acct += '</span>';
  var cls = 'ub-row';
  if (isCurrent) cls += ' current';
  if (!isActive) cls += ' inactive';
  return '<div class="' + cls + '">' + acct + '<span class="ub-limits">' + items + '</span></div>';
}

async function refreshUsage() {
  try {
    var data = await fetch('/api/usage').then(function(r) { return r.json(); });
    var el = document.getElementById('usage-bar');
    var accounts = data.accounts || [];
    if (accounts.length === 0) {
      el.innerHTML = '<span class="ub-empty">No rate limit data</span>';
      return;
    }
    accounts.sort(function(a, b) {
      return (a.orgName || '').localeCompare(b.orgName || '');
    });
    var mostRecent = accounts[0];
    for (var i = 1; i < accounts.length; i++) {
      if ((accounts[i].updated_at || '') > (mostRecent.updated_at || '')) mostRecent = accounts[i];
    }
    var html = '';
    for (var i = 0; i < accounts.length; i++) {
      var a = accounts[i];
      html += renderAccountRow(a, a === mostRecent, a.email === data.active_email || a === mostRecent);
    }
    el.innerHTML = html;
  } catch (e) { console.error('Usage refresh failed:', e); }
}
