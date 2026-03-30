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

function ubItem(label, pct, resetEpoch) {
  if (pct == null) return '';
  var p = Math.round(pct);
  var color = usageBarColor(p);
  return '<div class="ub-item">' +
    '<span class="ub-label">' + esc(label) + '</span>' +
    '<div class="ub-track"><div class="ub-fill" style="width:' + Math.min(p, 100) + '%;background:' + color + '"></div></div>' +
    '<span class="ub-pct" style="color:' + color + '">' + p + '%</span>' +
    (resetEpoch ? '<span class="ub-reset">' + fmtCountdown(resetEpoch) + '</span>' : '') +
  '</div>';
}

function renderAccountRow(account, isCurrent, isActive) {
  var rl = account.rate_limits || {};
  var items = '';
  var overLimit = false;
  var nowEpoch = Date.now() / 1000;
  if (rl.five_hour) {
    var fhOver = rl.five_hour.used_percentage > 100 && (!rl.five_hour.resets_at || rl.five_hour.resets_at > nowEpoch);
    if (fhOver) overLimit = true;
    items += ubItem('5h', fhOver ? rl.five_hour.used_percentage : Math.min(rl.five_hour.used_percentage, 100), rl.five_hour.resets_at);
  }
  if (rl.seven_day) {
    var sdOver = rl.seven_day.used_percentage > 100 && (!rl.seven_day.resets_at || rl.seven_day.resets_at > nowEpoch);
    if (sdOver) overLimit = true;
    items += ubItem('7d', sdOver ? rl.seven_day.used_percentage : Math.min(rl.seven_day.used_percentage, 100), rl.seven_day.resets_at);
  }
  if (overLimit) items += '<span class="ub-overlimit">OVER LIMIT</span>';
  var acct = '<span class="ub-account">' + esc(account.email || '');
  if (account.orgName) acct += ' <span class="ub-org">' + esc(account.orgName) + '</span>';
  acct += '</span>';
  var cls = 'ub-row';
  if (isCurrent) cls += ' current';
  if (!isActive) cls += ' inactive';
  return '<div class="' + cls + '">' + items + acct + '</div>';
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
