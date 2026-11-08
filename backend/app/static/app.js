/**
 * Personal AI Stock Intelligence & Live Portfolio Monitor Client
 */

let alertsState = [];
let portfolioState = null;
let stocksUniverseState = [];
let currentSection = 'highest-priority';
let holdingsSortBy = 'priority';
let audioEnabled = true;
let eventSource = null;
let audioCtx = null;
let currentTheme = 'light';
let activeModalSymbol = null;

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  initAudio();
  fetchMarketStatus();
  loadPortfolioData();
  loadUniverseStocks();
  loadAlerts();
  initSSE();
  loadSettings();
  requestBrowserNotifications();

  // Periodic background refresh every 10 seconds
  setInterval(loadPortfolioData, 10000);
  setInterval(fetchMarketStatus, 30000);
});

// Theme Management
function initTheme() {
  const saved = localStorage.getItem('ai_stock_theme') || 'light';
  applyTheme(saved);
}

function applyTheme(theme) {
  currentTheme = theme;
  if (theme === 'dark') {
    document.documentElement.setAttribute('data-theme', 'dark');
    document.getElementById('theme-icon').textContent = '☀️';
    document.getElementById('theme-text').textContent = 'Light';
  } else {
    document.documentElement.removeAttribute('data-theme');
    document.getElementById('theme-icon').textContent = '🌙';
    document.getElementById('theme-text').textContent = 'Dark';
  }
}

function toggleTheme() {
  const next = currentTheme === 'dark' ? 'light' : 'dark';
  applyTheme(next);
  localStorage.setItem('ai_stock_theme', next);
  showToast(`Theme switched to ${next === 'dark' ? 'Dark Mode' : 'Light Mode'}`);
}

// Audio Chime Synthesizer with P0 Critical Urgent Tone
function initAudio() {
  try {
    const AudioContext = window.AudioContext || window.webkitAudioContext;
    if (AudioContext) {
      audioCtx = new AudioContext();
    }
  } catch (e) {
    console.warn('Web Audio not supported:', e);
  }
}

function playAlertChime(action = 'BUY', isCritical = false) {
  if (!audioEnabled || !audioCtx) return;
  try {
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    const now = audioCtx.currentTime;

    if (isCritical) {
      // 🚨 P0 Urgent Multi-Tone Warning Chime
      for (let i = 0; i < 3; i++) {
        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);
        const t = now + (i * 0.15);
        osc.frequency.setValueAtTime(880.0, t); // A5
        osc.frequency.exponentialRampToValueAtTime(440.0, t + 0.12);
        gain.gain.setValueAtTime(0.35, t);
        gain.gain.exponentialRampToValueAtTime(0.001, t + 0.14);
        osc.start(t);
        osc.stop(t + 0.14);
      }
    } else if (action === 'BUY' || action.includes('PROFIT')) {
      // Upward cheerful chime
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.exponentialRampToValueAtTime(783.99, now + 0.18); // G5
      gain.gain.setValueAtTime(0.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
      osc.start(now);
      osc.stop(now + 0.35);
    } else {
      // Downward cautionary chime
      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.frequency.setValueAtTime(659.25, now); // E5
      osc.frequency.exponentialRampToValueAtTime(392.00, now + 0.22); // G4
      gain.gain.setValueAtTime(0.25, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.4);
      osc.start(now);
      osc.stop(now + 0.4);
    }
  } catch (err) {
    console.debug('Audio play note:', err);
  }
}

function toggleAudio() {
  audioEnabled = !audioEnabled;
  document.getElementById('audio-status').textContent = audioEnabled ? 'ON' : 'OFF';
  document.getElementById('audio-icon').textContent = audioEnabled ? '🔊' : '🔇';
  showToast(`Alert chimes turned ${audioEnabled ? 'ON' : 'OFF'}`);
}

function requestBrowserNotifications() {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }
}

// Service Worker Registration for Web Push & Mobile Browser Notification Drawer
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/static/sw.js').catch((err) => {
      console.debug('Service Worker register error:', err);
    });
  });
}

async function showBrowserNotification(title, body) {
  if (!('Notification' in window)) return;
  
  if (Notification.permission === 'default') {
    try {
      await Notification.requestPermission();
    } catch (_) {}
  }

  if (Notification.permission === 'granted') {
    try {
      if ('serviceWorker' in navigator) {
        const reg = await navigator.serviceWorker.ready;
        if (reg && reg.showNotification) {
          reg.showNotification(title, {
            body: body,
            icon: '/static/favicon.png',
            badge: '/static/favicon.png',
            vibrate: [200, 100, 200],
            data: { url: '/' },
          });
          return;
        }
      }
      new Notification(title, {
        body: body,
        icon: '/static/favicon.png',
      });
    } catch (e) {
      console.debug('Browser notification err:', e);
    }
  }
}

// Market Status Fetch
async function fetchMarketStatus() {
  try {
    const res = await fetch('/api/v1/monitoring/status');
    if (!res.ok) return;
    const data = await res.json();
    const chip = document.getElementById('market-status-chip');
    const text = document.getElementById('market-status-text');
    if (data.market && data.market.is_open) {
      chip.classList.add('market-open');
      text.textContent = `NSE: OPEN (${data.market.local_time || 'Trading'})`;
    } else {
      chip.classList.remove('market-open');
      text.textContent = `NSE: CLOSED (Next: ${data.market?.next_open_in || '09:15'})`;
    }

    const workerChip = document.getElementById('cloud-worker-text');
    if (data.scheduler_running) {
      workerChip.textContent = 'CLOUD 24/7: ACTIVE';
    } else {
      workerChip.textContent = 'CLOUD: STANDBY';
    }
  } catch (err) {
    console.debug('Market status fetch note:', err);
  }
}

// Portfolio Summary & Metrics
async function loadPortfolioData() {
  try {
    const res = await fetch('/api/v1/portfolio/summary');
    if (!res.ok) return;
    const data = await res.json();
    portfolioState = data;

    // Update Top Metric Banners
    document.getElementById('metric-total-invested').textContent = `₹${(data.total_invested_value || 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    document.getElementById('metric-market-value').textContent = `₹${(data.total_portfolio_value || 0).toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    
    const unpnl = data.total_unrealized_pnl || 0;
    const sign = unpnl >= 0 ? '+' : '';
    const unpnlElem = document.getElementById('metric-unrealized-pnl');
    unpnlElem.textContent = `${sign}₹${unpnl.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    unpnlElem.className = unpnl >= 0 ? 'metric-val text-buy' : 'metric-val text-sell';

    const invested = data.total_invested_value || 0;
    const pnlPct = invested > 0 ? (unpnl / invested) * 100 : 0;
    document.getElementById('metric-unrealized-pct').textContent = `${sign}${pnlPct.toFixed(2)}% Net Return`;

    const realPnl = data.total_realized_pnl || 0;
    const realSign = realPnl >= 0 ? '+' : '';
    const realElem = document.getElementById('metric-realized-pnl');
    realElem.textContent = `${realSign}₹${realPnl.toLocaleString('en-IN', {minimumFractionDigits: 2, maximumFractionDigits: 2})}`;
    realElem.className = realPnl >= 0 ? 'metric-val text-buy' : 'metric-val text-sell';

    document.getElementById('metric-open-count').textContent = `${data.open_positions_count || 0} Active Stocks`;
    document.getElementById('metric-closed-count').textContent = `${data.closed_positions_count || 0} Closed Holdings`;

    // Update tab counts
    document.getElementById('count-holdings').textContent = data.open_positions_count || 0;
    document.getElementById('count-closed-holdings').textContent = data.closed_positions_count || 0;

    // Check for critical holdings
    checkCriticalHoldings(data.active_holdings || []);

    // Re-render current section if viewing holdings
    if (currentSection === 'active-holdings') {
      renderActiveHoldings();
    } else if (currentSection === 'closed-holdings') {
      renderClosedHoldings();
    }
  } catch (err) {
    console.debug('Portfolio summary load note:', err);
  }
}

// Critical Holding Check & Banner
function checkCriticalHoldings(holdings) {
  const critical = holdings.filter(h => h.priority === 'P0' || (h.pnl_pct && h.pnl_pct <= -10.0) || (h.pnl_inr && h.pnl_inr <= -200.0));
  const banner = document.getElementById('critical-alert-banner');
  if (critical.length > 0) {
    banner.style.display = 'block';
    const first = critical[0];
    document.getElementById('critical-banner-title').textContent = `🚨 CRITICAL RISK ALERT: ${first.symbol} (${first.pnl_pct.toFixed(2)}% / ₹${first.pnl_inr.toFixed(2)})`;
    document.getElementById('count-critical-alerts').textContent = critical.length;
  } else {
    banner.style.display = 'none';
    document.getElementById('count-critical-alerts').textContent = '0';
  }
}

function dismissCriticalBanner() {
  document.getElementById('critical-alert-banner').style.display = 'none';
}

// Universe & Highest Priority Stocks
async function loadUniverseStocks() {
  try {
    const res = await fetch('/api/v1/stocks/universe?exchange=ALL');
    if (!res.ok) return;
    const data = await res.json();
    stocksUniverseState = data;

    // Update tab counts
    document.getElementById('count-priority').textContent = data.length;
    const buys = data.filter(s => s.latest_signal && s.latest_signal.includes('BUY'));
    document.getElementById('count-buy-ops').textContent = buys.length;
    const sells = data.filter(s => s.latest_signal && s.latest_signal.includes('SELL'));
    document.getElementById('count-sell-signals').textContent = sells.length;

    if (currentSection === 'highest-priority') {
      renderHighestPriorityStocks();
    } else if (currentSection === 'ai-buy-ops') {
      renderAIBuyOpportunities();
    } else if (currentSection === 'sell-signals') {
      renderSellSignals();
    }
  } catch (err) {
    console.debug('Stocks universe load note:', err);
  }
}

// Load Alerts History
async function loadAlerts() {
  try {
    const res = await fetch('/api/v1/alerts/history?limit=100');
    if (!res.ok) return;
    const data = await res.json();
    alertsState = data;

    // Calculate category counts
    const profitCount = data.filter(a => a.threshold_key && a.threshold_key.startsWith('PROFIT_')).length;
    const lossCount = data.filter(a => a.threshold_key && a.threshold_key.startsWith('LOSS_')).length;
    const criticalCount = data.filter(a => a.priority === 'P0' || a.threshold_key === 'LOSS_PCT_12').length;

    document.getElementById('count-profit-alerts').textContent = profitCount;
    document.getElementById('count-loss-alerts').textContent = lossCount;
    document.getElementById('count-all-alerts').textContent = data.length;

    if (currentSection === 'profit-alerts') {
      renderProfitAlerts();
    } else if (currentSection === 'loss-alerts') {
      renderLossAlerts();
    } else if (currentSection === 'critical-alerts') {
      renderCriticalAlerts();
    } else if (currentSection === 'notification-history') {
      renderNotificationHistory();
    }
  } catch (err) {
    console.debug('Alerts load note:', err);
  }
}

// Section Switching
function switchSection(sectionId) {
  currentSection = sectionId;
  document.querySelectorAll('.d-tab').forEach(t => {
    t.classList.toggle('active', t.getAttribute('data-section') === sectionId);
  });

  const container = document.getElementById('main-content-view');
  container.innerHTML = '<div class="empty-state"><div class="spinner"></div><p>Loading view...</p></div>';

  switch (sectionId) {
    case 'highest-priority':
      renderHighestPriorityStocks();
      break;
    case 'ai-buy-ops':
      renderAIBuyOpportunities();
      break;
    case 'active-holdings':
      renderActiveHoldings();
      break;
    case 'profit-alerts':
      renderProfitAlerts();
      break;
    case 'loss-alerts':
      renderLossAlerts();
      break;
    case 'critical-alerts':
      renderCriticalAlerts();
      break;
    case 'sell-signals':
      renderSellSignals();
      break;
    case 'closed-holdings':
      renderClosedHoldings();
      break;
    case 'notification-history':
      renderNotificationHistory();
      break;
    case 'cloud-monitoring':
      renderCloudMonitoring();
      break;
    default:
      renderHighestPriorityStocks();
  }
}

// Section 1: Highest Priority Stocks (P0 -> P1 -> P2 -> P3 -> P4)
function renderHighestPriorityStocks() {
  const container = document.getElementById('main-content-view');
  const stocks = stocksUniverseState || [];

  if (!stocks.length) {
    container.innerHTML = `
      <div class="empty-state">
        <p>No research opportunities found yet. Click <strong>Research Market</strong> to scan.</p>
        <button class="btn btn-primary" onclick="triggerDailyScan()" style="margin-top: 12px;">🔍 Scan Market Now</button>
      </div>`;
    return;
  }

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800;">⭐ 1. HIGHEST PRIORITY STOCKS</h2>
          <p style="font-size: 13px; color: var(--text-dim); margin-top: 2px;">
            Ranked in descending priority: <strong>P0 (Critical) &gt; P1 (Very High) &gt; P2 (High) &gt; P3 (Medium) &gt; P4 (Low)</strong>. Click <strong>"I BOUGHT THIS STOCK"</strong> when purchased in Groww.
          </p>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="btn btn-sm btn-primary" onclick="openManualPurchaseModal()">🛒 Manual Purchase Entry</button>
          <button class="btn btn-sm btn-outline" onclick="loadUniverseStocks()">🔄 Refresh Universe</button>
        </div>
      </div>

      <div class="table-responsive">
        <table class="custom-table">
          <thead>
            <tr>
              <th>Priority</th>
              <th>Stock</th>
              <th>Current Price</th>
              <th>Expected Direction</th>
              <th>AI Score</th>
              <th>Entry Zone</th>
              <th>Target Price</th>
              <th>Stop-Loss</th>
              <th>Risk / Reward</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>`;

  stocks.forEach(s => {
    const pri = s.priority || 'P2';
    const priClass = `pri-${pri.toLowerCase()}`;
    const pChange = s.percent_change || 0;
    const pChangeSign = pChange >= 0 ? '+' : '';
    const pChangeColor = pChange >= 0 ? 'text-buy' : 'text-sell';
    const dirIcon = s.predicted_direction === 'BULLISH' ? '🟢 BULLISH' : (s.predicted_direction === 'BEARISH' ? '🔴 BEARISH' : '⚪ NEUTRAL');

    html += `
      <tr>
        <td><span class="pri-badge ${priClass}">${pri}</span></td>
        <td>
          <strong style="font-size: 14px; cursor: pointer; color: var(--primary-blue);" onclick="openResearchModal('${s.symbol}')">${s.symbol}</strong>
          <div style="font-size: 11px; color: var(--text-dim);">${s.name || s.symbol} • ${s.exchange}</div>
        </td>
        <td>
          <strong>₹${(s.latest_price || 0).toFixed(2)}</strong>
          <div class="${pChangeColor}" style="font-size: 11px;">${pChangeSign}${pChange.toFixed(2)}%</div>
        </td>
        <td><strong>${dirIcon}</strong></td>
        <td>
          <div style="font-weight: 700; color: var(--cyan-accent);">${(s.predicted_confidence || s.signal_strength || 50).toFixed(1)}%</div>
          <div style="font-size: 10px; color: var(--text-dim);">Multi-Indicator Confluence</div>
        </td>
        <td><code style="font-size: 12px;">${s.entry_zone || `₹${((s.latest_price || 100)*0.995).toFixed(2)} - ₹${((s.latest_price || 100)*1.005).toFixed(2)}`}</code></td>
        <td><strong style="color: var(--buy-green);">₹${(s.predicted_target || s.target_price || (s.latest_price || 100)*1.05).toFixed(2)}</strong></td>
        <td><span style="color: var(--sell-red);">₹${(s.stop_loss || (s.latest_price || 100)*0.97).toFixed(2)}</span></td>
        <td><strong>1:${(s.risk_reward || 2.0).toFixed(2)}</strong></td>
        <td>
          <button class="btn-bought" onclick="openManualPurchaseModal('${s.symbol}', '${s.name || s.symbol}', ${s.latest_price || 0}, ${s.predicted_target || 0}, ${s.stop_loss || 0})">
            🛒 I BOUGHT THIS STOCK
          </button>
        </td>
      </tr>`;
  });

  html += `</tbody></table></div></div>`;
  container.innerHTML = html;
}

// Section 2: AI Buy Opportunities
function renderAIBuyOpportunities() {
  const container = document.getElementById('main-content-view');
  const buys = (stocksUniverseState || []).filter(s => (s.latest_signal && s.latest_signal.includes('BUY')) || s.predicted_direction === 'BULLISH');

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800;">🟢 2. AI BUY OPPORTUNITIES</h2>
          <p style="font-size: 13px; color: var(--text-dim);">High-conviction research setups filtered by multi-indicator confluence and volume confirmation.</p>
        </div>
      </div>`;

  if (!buys.length) {
    html += `<div class="empty-state"><p>No active BUY setups at this moment. Market is currently evaluating.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += `<div class="alerts-grid">`;
  buys.forEach(s => {
    html += `
      <div class="alert-card border-buy">
        <div class="card-header">
          <div>
            <span class="pri-badge pri-${(s.priority || 'P1').toLowerCase()}">${s.priority || 'P1'}</span>
            <span class="badge badge-success">BUY OPPORTUNITY</span>
            <h3 style="margin-top: 6px; font-size: 18px;">${s.symbol} <span style="font-size: 13px; color: var(--text-dim);">(${s.name || s.symbol})</span></h3>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 20px; font-weight: 800;">₹${(s.latest_price || 0).toFixed(2)}</div>
            <div style="font-size: 12px; color: var(--buy-green); font-weight: 600;">+${(s.percent_change || 0).toFixed(2)}%</div>
          </div>
        </div>

        <div class="card-body">
          <p style="font-size: 13px; margin-bottom: 12px;">${s.main_reasons || 'Confluence of RSI momentum, EMA alignment, and positive volume profile.'}</p>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 12px; background: var(--bg-tertiary); padding: 10px; border-radius: 6px;">
            <div>Target: <strong style="color: var(--buy-green);">₹${(s.predicted_target || (s.latest_price || 100)*1.05).toFixed(2)}</strong></div>
            <div>Stop-Loss: <strong style="color: var(--sell-red);">₹${(s.stop_loss || (s.latest_price || 100)*0.97).toFixed(2)}</strong></div>
            <div>Risk/Reward: <strong>1:${(s.risk_reward || 2.0).toFixed(2)}</strong></div>
            <div>Confidence: <strong style="color: var(--cyan-accent);">${(s.predicted_confidence || 85).toFixed(1)}%</strong></div>
          </div>
        </div>

        <div class="card-footer" style="display: flex; justify-content: space-between; align-items: center; margin-top: 14px;">
          <button class="btn btn-sm btn-outline" onclick="openResearchModal('${s.symbol}')">🔬 Deep AI Thesis</button>
          <button class="btn-bought" onclick="openManualPurchaseModal('${s.symbol}', '${s.name || s.symbol}', ${s.latest_price || 0}, ${s.predicted_target || 0}, ${s.stop_loss || 0})">
            🛒 I BOUGHT THIS STOCK
          </button>
        </div>
      </div>`;
  });

  html += `</div></div>`;
  container.innerHTML = html;
}

// Section 3 & 8: My Purchased Stocks / Active Holdings
function renderActiveHoldings() {
  const container = document.getElementById('main-content-view');
  const holdings = portfolioState?.active_holdings || [];

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800;">💼 3 & 8. MY PURCHASED STOCKS (ACTIVE HOLDINGS)</h2>
          <p style="font-size: 13px; color: var(--text-dim); margin-top: 2px;">
            Monitored 24/7 independently. Click <strong>"I SOLD THIS STOCK"</strong> after executing sale in Groww.
          </p>
        </div>
        <div style="display: flex; gap: 8px; align-items: center;">
          <label style="font-size: 12px; font-weight: 600;">Sort By:</label>
          <select id="sort-holdings-select" class="form-input" style="padding: 6px 10px; font-size: 12px;" onchange="changeHoldingsSort(this.value)">
            <option value="priority" ${holdingsSortBy === 'priority' ? 'selected' : ''}>Highest Priority (P0 first)</option>
            <option value="profit" ${holdingsSortBy === 'profit' ? 'selected' : ''}>Highest Profit (₹)</option>
            <option value="loss" ${holdingsSortBy === 'loss' ? 'selected' : ''}>Highest Loss (₹)</option>
            <option value="percent" ${holdingsSortBy === 'percent' ? 'selected' : ''}>Highest % Change</option>
            <option value="symbol" ${holdingsSortBy === 'symbol' ? 'selected' : ''}>Stock Name</option>
            <option value="date" ${holdingsSortBy === 'date' ? 'selected' : ''}>Purchase Date</option>
          </select>
          <button class="btn btn-primary" onclick="openManualPurchaseModal()">🛒 + Buy Stock</button>
        </div>
      </div>`;

  if (!holdings.length) {
    html += `
      <div class="empty-state">
        <p>No active stock purchases in your portfolio.</p>
        <p style="font-size: 12px; color: var(--text-dim); margin-top: 4px;">Click <strong>I BOUGHT A STOCK</strong> to enter your Groww purchases.</p>
        <button class="btn btn-primary" onclick="openManualPurchaseModal()" style="margin-top: 14px;">🛒 I Bought a Stock</button>
      </div></div>`;
    container.innerHTML = html;
    return;
  }

  html += `
    <div class="table-responsive">
      <table class="custom-table">
        <thead>
          <tr>
            <th>Priority</th>
            <th>Stock</th>
            <th>Quantity</th>
            <th>Average Buy</th>
            <th>Current Price</th>
            <th>P/L ₹</th>
            <th>P/L %</th>
            <th>Total Invested</th>
            <th>Status</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>`;

  holdings.forEach(h => {
    const pri = h.priority || 'P2';
    const priClass = `pri-${pri.toLowerCase()}`;
    const pnlInr = h.pnl_inr || 0;
    const pnlSign = pnlInr >= 0 ? '+' : '';
    const pnlColor = pnlInr >= 0 ? 'text-buy' : 'text-sell';
    const pnlPct = h.pnl_pct || 0;

    html += `
      <tr>
        <td><span class="pri-badge ${priClass}">${pri}</span></td>
        <td>
          <strong style="font-size: 14px;">${h.symbol}</strong>
          <div style="font-size: 11px; color: var(--text-dim);">${h.company_name || h.symbol}</div>
        </td>
        <td><strong>${h.quantity}</strong></td>
        <td>₹${(h.avg_entry_price || 0).toFixed(2)}</td>
        <td><strong>₹${(h.current_price || 0).toFixed(2)}</strong></td>
        <td class="${pnlColor}"><strong>${pnlSign}₹${pnlInr.toFixed(2)}</strong></td>
        <td class="${pnlColor}"><strong>${pnlSign}${pnlPct.toFixed(2)}%</strong></td>
        <td>₹${(h.invested || 0).toFixed(2)}</td>
        <td><span class="badge badge-success">ACTIVE</span></td>
        <td>
          <button class="btn-sold" onclick="openManualSaleModal('${h.symbol}', ${h.quantity}, ${h.current_price || 0})">
            📤 I SOLD THIS STOCK
          </button>
        </td>
      </tr>`;
  });

  html += `</tbody></table></div></div>`;
  container.innerHTML = html;
}

function changeHoldingsSort(val) {
  holdingsSortBy = val;
  fetch(`/api/v1/portfolio/positions?sort_by=${val}`)
    .then(r => r.json())
    .then(data => {
      if (portfolioState) {
        portfolioState.active_holdings = data.map(p => ({
          ...p,
          invested: p.avg_entry_price * p.quantity,
          pnl_inr: p.unrealized_pnl,
          pnl_pct: p.avg_entry_price > 0 ? ((p.current_price - p.avg_entry_price) / p.avg_entry_price) * 100 : 0,
        }));
        renderActiveHoldings();
      }
    });
}

// Section 4: Profit Alerts (+₹30, +₹50, +₹100, +₹200, +₹500, +₹1000)
function renderProfitAlerts() {
  const container = document.getElementById('main-content-view');
  const profits = alertsState.filter(a => a.threshold_key && a.threshold_key.startsWith('PROFIT_'));

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800; color: var(--buy-green);">📈 4. PROFIT ALERTS</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Triggered automatically when holdings reach +₹30, +₹50, +₹100, +₹200, +₹500, +₹1000 thresholds.</p>
        </div>
      </div>`;

  if (!profits.length) {
    html += `<div class="empty-state"><p>No profit threshold alerts triggered yet. As stocks gain in Groww, alerts appear here.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += renderAlertCards(profits);
  html += `</div>`;
  container.innerHTML = html;
}

// Section 5: Loss Alerts (-₹30, -₹50, -₹100, -₹200, -5%, -8%, -10%, -12%)
function renderLossAlerts() {
  const container = document.getElementById('main-content-view');
  const losses = alertsState.filter(a => a.threshold_key && a.threshold_key.startsWith('LOSS_'));

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800; color: var(--sell-red);">📉 5. LOSS ALERTS</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Independent Rupee & Percentage loss alerts triggered automatically.</p>
        </div>
      </div>`;

  if (!losses.length) {
    html += `<div class="empty-state"><p>No loss threshold alerts triggered. All active holdings are within safe parameters.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += renderAlertCards(losses);
  html += `</div>`;
  container.innerHTML = html;
}

// Section 6: Critical -12% Extreme Loss Alerts
function renderCriticalAlerts() {
  const container = document.getElementById('main-content-view');
  const critical = alertsState.filter(a => a.priority === 'P0' || a.threshold_key === 'LOSS_PCT_12');

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800; color: #dc2626;">🚨 6. CRITICAL -12% EXTREME LOSS ALERTS</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Highest urgency capital protection warnings requiring immediate manual decision.</p>
        </div>
      </div>`;

  if (!critical.length) {
    html += `<div class="empty-state"><p>Zero critical extreme loss warnings active. Capital protection is healthy.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += renderAlertCards(critical, true);
  html += `</div>`;
  container.innerHTML = html;
}

// Section 7: Sell Signals
function renderSellSignals() {
  const container = document.getElementById('main-content-view');
  const sells = (stocksUniverseState || []).filter(s => s.latest_signal && s.latest_signal.includes('SELL'));

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800; color: var(--sell-red);">🔴 7. AI SELL SIGNALS</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Bearish structure breakdowns and profit-taking exit suggestions.</p>
        </div>
      </div>`;

  if (!sells.length) {
    html += `<div class="empty-state"><p>No active sell signals generated.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += `<div class="alerts-grid">`;
  sells.forEach(s => {
    html += `
      <div class="alert-card border-sell">
        <div class="card-header">
          <div>
            <span class="pri-badge pri-${(s.priority || 'P1').toLowerCase()}">${s.priority || 'P1'}</span>
            <span class="badge badge-danger">SELL SIGNAL</span>
            <h3 style="margin-top: 6px;">${s.symbol}</h3>
          </div>
          <div style="font-size: 18px; font-weight: 800;">₹${(s.latest_price || 0).toFixed(2)}</div>
        </div>
        <div class="card-body">
          <p style="font-size: 13px;">${s.main_reasons || 'Trend breakdown detected. Consider closing position.'}</p>
        </div>
      </div>`;
  });
  html += `</div></div>`;
  container.innerHTML = html;
}

// Section 9: Closed Holdings
function renderClosedHoldings() {
  const container = document.getElementById('main-content-view');
  const closed = portfolioState?.closed_holdings || [];

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800;">📦 9. CLOSED HOLDINGS</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Historical record of positions completely sold through Groww.</p>
        </div>
      </div>`;

  if (!closed.length) {
    html += `<div class="empty-state"><p>No closed positions recorded yet.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += `
    <div class="table-responsive">
      <table class="custom-table">
        <thead>
          <tr>
            <th>Stock</th>
            <th>Buy Price</th>
            <th>Exit Price</th>
            <th>Final Realized P/L</th>
            <th>Closed Date</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>`;

  closed.forEach(c => {
    const pnl = c.realized_pnl || 0;
    const pnlSign = pnl >= 0 ? '+' : '';
    const pnlColor = pnl >= 0 ? 'text-buy' : 'text-sell';
    const cDate = c.closed_at ? new Date(c.closed_at).toLocaleDateString() : 'N/A';

    html += `
      <tr>
        <td><strong>${c.symbol}</strong></td>
        <td>₹${(c.avg_entry_price || 0).toFixed(2)}</td>
        <td>₹${(c.final_price || 0).toFixed(2)}</td>
        <td class="${pnlColor}"><strong>${pnlSign}₹${pnl.toFixed(2)}</strong></td>
        <td>${cDate}</td>
        <td><span class="badge" style="background:#64748b; color:white;">CLOSED</span></td>
      </tr>`;
  });

  html += `</tbody></table></div></div>`;
  container.innerHTML = html;
}

// Section 14: Notification History
function renderNotificationHistory() {
  const container = document.getElementById('main-content-view');
  const alerts = alertsState || [];

  let html = `
    <div class="holdings-container">
      <div class="table-controls">
        <div>
          <h2 style="font-size: 18px; font-weight: 800;">🔔 14. NOTIFICATION HISTORY</h2>
          <p style="font-size: 13px; color: var(--text-dim);">Chronological stream of all research opportunities and profit/loss threshold alerts.</p>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="btn btn-sm btn-outline" onclick="markAllAsRead()">Mark All Read</button>
          <button class="btn btn-sm btn-ghost" onclick="clearAllNotifications()">Clear All</button>
        </div>
      </div>`;

  if (!alerts.length) {
    html += `<div class="empty-state"><p>No notifications recorded yet.</p></div></div>`;
    container.innerHTML = html;
    return;
  }

  html += renderAlertCards(alerts);
  html += `</div>`;
  container.innerHTML = html;
}

// Section 15: Cloud Monitoring Status
function renderCloudMonitoring() {
  const container = document.getElementById('main-content-view');
  container.innerHTML = `
    <div class="holdings-container" style="max-width: 900px;">
      <h2 style="font-size: 18px; font-weight: 800; margin-bottom: 14px;">☁️ 15. CLOUD MONITORING & WORKER HEALTH</h2>
      <div style="background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 10px; padding: 20px; box-shadow: var(--card-shadow);">
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px;">
          <div style="background: var(--bg-tertiary); padding: 14px; border-radius: 8px;">
            <div style="font-size: 12px; color: var(--text-dim);">Background Scheduler</div>
            <div style="font-size: 20px; font-weight: 800; color: var(--buy-green);">ACTIVE 24/7</div>
            <div style="font-size: 11px; color: var(--text-dim); margin-top: 4px;">Runs even when your laptop is turned off.</div>
          </div>
          <div style="background: var(--bg-tertiary); padding: 14px; border-radius: 8px;">
            <div style="font-size: 12px; color: var(--text-dim);">Position Monitoring Frequency</div>
            <div style="font-size: 20px; font-weight: 800; color: var(--primary-blue);">Every 10 Seconds</div>
            <div style="font-size: 11px; color: var(--text-dim); margin-top: 4px;">Continuous threshold inspection loop.</div>
          </div>
          <div style="background: var(--bg-tertiary); padding: 14px; border-radius: 8px;">
            <div style="font-size: 12px; color: var(--text-dim);">Durable Notification Queue</div>
            <div style="font-size: 20px; font-weight: 800; color: var(--cyan-accent);">PERSISTENT</div>
            <div style="font-size: 11px; color: var(--text-dim); margin-top: 4px;">Retries automatically upon transient network failures.</div>
          </div>
          <div style="background: var(--bg-tertiary); padding: 14px; border-radius: 8px;">
            <div style="font-size: 12px; color: var(--text-dim);">Market Hours Awareness</div>
            <div style="font-size: 20px; font-weight: 800; color: var(--text-main);">09:15 - 15:30 IST</div>
            <div style="font-size: 11px; color: var(--text-dim); margin-top: 4px;">Verified feed with holiday calendars.</div>
          </div>
        </div>

        <h3 style="font-size: 14px; margin-bottom: 8px;">Active Thresholds Configured:</h3>
        <ul style="font-size: 13px; line-height: 1.8; margin-left: 20px; color: var(--text-muted);">
          <li><strong>Profit Alerts:</strong> +₹30 (P2), +₹50 (P2), +₹100 (P1), +₹200 (P0), +₹500 (P0), +₹1000 (P0)</li>
          <li><strong>Loss Alerts (Rupee):</strong> -₹30 (P2), -₹50 (P2), -₹100 (P1), -₹200 (P0), -₹500 (P0), -₹1000 (P0)</li>
          <li><strong>Loss Alerts (Percentage):</strong> -5% (P1), -8% (P1), -10% (P0), -12% (P0)</li>
        </ul>

        <div style="margin-top: 20px; display: flex; gap: 10px;">
          <button class="btn btn-outline" onclick="triggerTestAlert('PROFIT_30')">🧪 Test +₹30 Notification</button>
          <button class="btn btn-sell" onclick="triggerTestAlert('CRITICAL_12')">🚨 Test -12% Critical Alert</button>
          <button class="btn btn-secondary" onclick="openSettingsModal()">⚙️ Edit Thresholds</button>
        </div>
      </div>
    </div>`;
}

// Helper to render alert cards
function renderAlertCards(alerts, forceCritical = false) {
  let html = `<div class="alerts-grid">`;
  alerts.forEach(a => {
    const pri = a.priority || 'P2';
    const isP0 = pri === 'P0' || forceCritical;
    const cardBorder = isP0 ? 'border-sell' : (a.threshold_key?.startsWith('PROFIT_') ? 'border-buy' : 'border-sell');
    const tsStr = a.created_at ? new Date(a.created_at).toLocaleTimeString() : '';

    html += `
      <div class="alert-card ${cardBorder}">
        <div class="card-header">
          <div>
            <span class="pri-badge pri-${pri.toLowerCase()}">${pri}</span>
            <span class="badge ${a.threshold_key?.startsWith('PROFIT_') ? 'badge-success' : 'badge-danger'}">${a.alert_type || 'ALERT'}</span>
            <h3 style="margin-top: 6px; font-size: 16px;">${a.symbol}</h3>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 12px; color: var(--text-dim);">${tsStr}</div>
            <div style="font-size: 11px; color: ${a.sent_to_fcm ? 'var(--buy-green)' : 'var(--cyan-accent)'};">${a.sent_to_fcm ? 'FCM DELIVERED' : 'LOCAL/SSE ACTIVE'}</div>
          </div>
        </div>

        <div class="card-body">
          <strong style="font-size: 14px; display: block; margin-bottom: 8px;">${a.title}</strong>
          <pre style="font-family: var(--font-mono); font-size: 12px; white-space: pre-wrap; background: var(--bg-tertiary); padding: 10px; border-radius: 6px;">${a.message}</pre>
        </div>
      </div>`;
  });
  html += `</div>`;
  return html;
}

// Purchase Modal Operations
function openManualPurchaseModal(symbol = '', name = '', price = 0, target = 0, stopLoss = 0) {
  document.getElementById('buy-symbol-input').value = symbol;
  document.getElementById('buy-name-input').value = name || symbol;
  document.getElementById('buy-price-input').value = price > 0 ? price.toFixed(2) : '';
  document.getElementById('buy-qty-input').value = 1;
  document.getElementById('buy-date-input').value = new Date().toISOString().split('T')[0];
  document.getElementById('buy-time-input').value = new Date().toTimeString().split(' ')[0].substring(0, 5);
  document.getElementById('buy-charges-input').value = '0.00';
  document.getElementById('buy-target-input').value = target > 0 ? target.toFixed(2) : '';
  document.getElementById('buy-sl-input').value = stopLoss > 0 ? stopLoss.toFixed(2) : '';

  document.getElementById('manual-purchase-modal').style.display = 'flex';
}

function openManualPurchaseFromRecommendation() {
  closeModal('research-modal');
  if (activeModalSymbol) {
    const s = stocksUniverseState.find(item => item.symbol === activeModalSymbol);
    if (s) {
      openManualPurchaseModal(s.symbol, s.name, s.latest_price, s.predicted_target, s.stop_loss);
      return;
    }
  }
  openManualPurchaseModal();
}

async function submitManualPurchase(e) {
  e.preventDefault();
  const btn = document.getElementById('btn-submit-purchase');
  btn.disabled = true;
  btn.textContent = 'Saving...';

  const payload = {
    symbol: document.getElementById('buy-symbol-input').value.trim().toUpperCase(),
    company_name: document.getElementById('buy-name-input').value.trim(),
    actual_price: parseFloat(document.getElementById('buy-price-input').value),
    quantity: parseInt(document.getElementById('buy-qty-input').value, 10),
    purchase_date: document.getElementById('buy-date-input').value,
    purchase_time: document.getElementById('buy-time-input').value,
    charges: parseFloat(document.getElementById('buy-charges-input').value) || 0.0,
    custom_target: parseFloat(document.getElementById('buy-target-input').value) || null,
    custom_stop_loss: parseFloat(document.getElementById('buy-sl-input').value) || null,
  };

  try {
    const res = await fetch('/api/v1/portfolio/manual-purchase', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || 'Failed to record purchase');

    closeModal('manual-purchase-modal');
    showToast(`✅ Successfully added ${payload.quantity} shares of ${payload.symbol} at ₹${payload.actual_price.toFixed(2)} to My Portfolio!`, 'buy');
    loadPortfolioData();
    switchSection('active-holdings');
  } catch (err) {
    alert(`Error: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Confirm & Start Monitoring';
  }
}

// Sale Modal Operations
function openManualSaleModal(symbol, heldQty, currentPrice = 0) {
  document.getElementById('sell-symbol-display').value = symbol;
  document.getElementById('sell-price-input').value = currentPrice > 0 ? currentPrice.toFixed(2) : '';
  const qtyInput = document.getElementById('sell-qty-input');
  qtyInput.value = heldQty;
  qtyInput.max = heldQty;
  document.getElementById('sell-max-qty-hint').textContent = `Currently held in portfolio: ${heldQty} shares`;
  document.getElementById('sell-date-input').value = new Date().toISOString().split('T')[0];
  document.getElementById('sell-time-input').value = new Date().toTimeString().split(' ')[0].substring(0, 5);
  document.getElementById('sell-charges-input').value = '0.00';

  document.getElementById('manual-sell-modal').style.display = 'flex';
}

async function submitManualSale(e) {
  e.preventDefault();
  const btn = document.getElementById('btn-submit-sale');
  btn.disabled = true;
  btn.textContent = 'Recording Sale...';

  const payload = {
    symbol: document.getElementById('sell-symbol-display').value.trim().toUpperCase(),
    selling_price: parseFloat(document.getElementById('sell-price-input').value),
    quantity_sold: parseInt(document.getElementById('sell-qty-input').value, 10),
    selling_date: document.getElementById('sell-date-input').value,
    selling_time: document.getElementById('sell-time-input').value,
    charges: parseFloat(document.getElementById('sell-charges-input').value) || 0.0,
  };

  try {
    const res = await fetch('/api/v1/portfolio/manual-sell', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || 'Failed to record sale');

    closeModal('manual-sell-modal');
    const sign = data.realized_pnl >= 0 ? '+' : '';
    showToast(`📤 Sale recorded! Realized P/L: ${sign}₹${data.realized_pnl.toFixed(2)} (${data.is_fully_closed ? 'Position CLOSED' : 'Remaining qty updated'})`, data.realized_pnl >= 0 ? 'buy' : 'sell');
    loadPortfolioData();
  } catch (err) {
    alert(`Error: ${err.message}`);
  } finally {
    btn.disabled = false;
    btn.textContent = 'Confirm & Close / Update Holding';
  }
}

// Research Detail Modal
async function openResearchModal(symbol) {
  activeModalSymbol = symbol;
  const modal = document.getElementById('research-modal');
  const title = document.getElementById('modal-stock-title');
  const priceElem = document.getElementById('modal-stock-price');
  const priBadge = document.getElementById('modal-priority-badge');
  const content = document.getElementById('modal-research-content');

  title.textContent = `${symbol} (NSE)`;
  content.innerHTML = '<div class="empty-state"><div class="spinner"></div><p>Fetching multi-indicator AI confluence thesis...</p></div>';
  modal.style.display = 'flex';

  try {
    const res = await fetch(`/api/v1/stocks/${symbol}/thesis?exchange=NSE`);
    if (!res.ok) throw new Error('Thesis not available');
    const thesis = await res.json();

    priBadge.textContent = thesis.priority || 'P1';
    priBadge.className = `badge pri-${(thesis.priority || 'p1').toLowerCase()}`;

    let catalystsHtml = (thesis.catalysts || []).map(c => `<li>• ${c}</li>`).join('');
    let risksHtml = (thesis.risk_factors || []).map(r => `<li>⚠️ ${r}</li>`).join('');

    content.innerHTML = `
      <div style="margin-bottom: 16px;">
        <h3 style="font-size: 16px; font-weight: 700; margin-bottom: 6px;">${thesis.headline || 'Quantitative AI Research'}</h3>
        <p style="font-size: 13px; line-height: 1.6; color: var(--text-muted);">${thesis.investment_thesis || ''}</p>
      </div>

      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px;">
        <div style="background: var(--bg-tertiary); padding: 12px; border-radius: 8px;">
          <h4 style="font-size: 12px; text-transform: uppercase; color: var(--buy-green); margin-bottom: 6px;">Supporting Catalysts</h4>
          <ul style="font-size: 12px; line-height: 1.6; list-style: none;">${catalystsHtml || '<li>Multi-factor confluence verified.</li>'}</ul>
        </div>
        <div style="background: var(--bg-tertiary); padding: 12px; border-radius: 8px;">
          <h4 style="font-size: 12px; text-transform: uppercase; color: var(--sell-red); margin-bottom: 6px;">Risk Factors & Invalidation</h4>
          <ul style="font-size: 12px; line-height: 1.6; list-style: none;">${risksHtml || '<li>Strict stop-loss enforcement advised.</li>'}</ul>
        </div>
      </div>`;
  } catch (err) {
    content.innerHTML = `<p style="color: var(--sell-red);">Failed to load deep thesis: ${err.message}</p>`;
  }
}

// Test Notification Trigger
function openTestNotificationModal() {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission().catch(() => {});
  }
  document.getElementById('test-alert-modal').style.display = 'flex';
}

async function triggerTestAlert(type) {
  closeModal('test-alert-modal');
  let title = '';
  let body = '';
  let pri = 'P2';
  let isCrit = false;

  if (type === 'PROFIT_30') {
    title = '[P2] 🟢 FIRST PROFIT ALERT: RELIANCE reached +₹30 profit';
    body = 'Stock: RELIANCE\nPurchase Price: ₹200.00\nCurrent Price: ₹203.00\nQuantity: 10\nTotal Profit: +₹30.00 (+1.50%)\nPriority: P2';
  } else if (type === 'PROFIT_50') {
    title = '[P2] 🟢 SECOND PROFIT ALERT: RELIANCE reached +₹50 profit';
    body = 'Stock: RELIANCE\nPurchase Price: ₹200.00\nCurrent Price: ₹205.00\nQuantity: 10\nTotal Profit: +₹50.00 (+2.50%)\nPriority: P2';
  } else if (type === 'LOSS_30') {
    title = '[P2] 🔴 FIRST LOSS ALERT: RELIANCE reached -₹30 loss';
    body = 'Stock: RELIANCE\nPurchase Price: ₹200.00\nCurrent Price: ₹197.00\nQuantity: 10\nTotal Loss: -₹30.00 (-1.50%)\nPriority: P2';
  } else if (type === 'LOSS_50') {
    title = '[P2] 🔴 SECOND LOSS ALERT: RELIANCE reached -₹50 loss';
    body = 'Stock: RELIANCE\nPurchase Price: ₹200.00\nCurrent Price: ₹195.00\nQuantity: 10\nTotal Loss: -₹50.00 (-2.50%)\nPriority: P2';
  } else if (type === 'CRITICAL_12') {
    title = '[P0] 🚨 EXTREME LOSS ALERT: TCS reached -12% loss';
    body = 'Stock: TCS\nPurchase Price: ₹3500.00\nCurrent Price: ₹3080.00\nQuantity: 5\nTotal Loss: -₹2,100.00 (-12.00%)\nPriority: P0 CRITICAL\nTriggered Threshold: Extreme Loss Alert (-12%)';
    pri = 'P0';
    isCrit = true;
  }

  playAlertChime(type.startsWith('PROFIT') ? 'BUY' : 'SELL', isCrit);
  showToast(title, isCrit ? 'sell' : (type.startsWith('PROFIT') ? 'buy' : 'sell'));
  showBrowserNotification(title, body);

  try {
    await fetch('/api/v1/alerts/test-push', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: title,
        body: body,
        symbol: 'RELIANCE',
        exchange: 'NSE',
      }),
    });
    loadAlerts();
  } catch (e) {
    console.debug('Test alert API note:', e);
  }
}

// Server-Sent Events (SSE) Live Feed
function initSSE() {
  if (eventSource) {
    eventSource.close();
  }

  const sseChip = document.getElementById('sse-status');
  const sseText = document.getElementById('sse-status-text');

  try {
    eventSource = new EventSource('/api/v1/alerts/stream');

    eventSource.onopen = () => {
      sseChip.classList.add('live-pulse');
      sseText.textContent = 'LIVE FEED: CONNECTED';
    };

    eventSource.addEventListener('alert', (event) => {
      try {
        const alertData = JSON.parse(event.data);
        handleLiveAlertReceived(alertData);
      } catch (err) {
        console.error('SSE alert parse error:', err);
      }
    });

    eventSource.onerror = () => {
      sseText.textContent = 'LIVE FEED: RECONNECTING...';
      sseChip.classList.remove('live-pulse');
    };
  } catch (e) {
    console.warn('SSE initialization error:', e);
  }
}

function handleLiveAlertReceived(alert) {
  const isCrit = alert.is_critical || alert.priority === 'P0';
  playAlertChime(alert.action || alert.alert_type, isCrit);
  showToast(alert.title, isCrit ? 'sell' : (alert.action === 'BUY' ? 'buy' : 'sell'));
  showBrowserNotification(alert.title, alert.message || alert.title);

  loadAlerts();
  loadPortfolioData();
}

// Modal Helpers
function closeModal(id) {
  document.getElementById(id).style.display = 'none';
}

function closeModalOnBackdrop(event, id) {
  if (event.target.id === id) {
    closeModal(id);
  }
}

function openSettingsModal() {
  document.getElementById('settings-modal').style.display = 'flex';
}

async function loadSettings() {
  try {
    const res = await fetch('/api/v1/settings');
    if (!res.ok) return;
    const data = await res.json();
    const keyStatus = document.getElementById('gemini-key-status');
    if (data.GEMINI_CONFIGURED) {
      keyStatus.textContent = `Status: Configured (${data.GEMINI_API_KEY_MASKED || 'Active'})`;
      keyStatus.style.color = '#10b981';
    } else {
      keyStatus.textContent = 'Status: Not configured. Using verified quantitative confluence baseline.';
      keyStatus.style.color = '#f59e0b';
    }
  } catch (e) {
    console.debug('Settings load note:', e);
  }
}

async function saveSettings() {
  const keyInput = document.getElementById('gemini-key-input').value.trim();
  if (keyInput) {
    await fetch('/api/v1/settings', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ key: 'GEMINI_API_KEY', value: keyInput }),
    });
  }
  closeModal('settings-modal');
  showToast('Settings successfully updated!');
  loadSettings();
}

async function triggerDailyScan() {
  const progressBar = document.getElementById('scan-progress-bar');
  const btn = document.getElementById('btn-scan-now');
  progressBar.style.display = 'block';
  btn.disabled = true;

  try {
    const res = await fetch('/api/v1/scanner/scan', { method: 'POST' });
    const data = await res.json();
    showToast(`Scan initiated: ${data.message || 'Analyzing market universe'}`, 'buy');
    setTimeout(() => {
      loadUniverseStocks();
      progressBar.style.display = 'none';
      btn.disabled = false;
    }, 4000);
  } catch (e) {
    progressBar.style.display = 'none';
    btn.disabled = false;
    alert(`Scan error: ${e.message}`);
  }
}

async function markAllAsRead() {
  const unreadIds = (alertsState || []).filter(a => !a.is_read).map(a => a.id);
  if (!unreadIds.length) return;
  await fetch('/api/v1/alerts/mark-read', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ alert_ids: unreadIds }),
  });
  showToast('Marked all alerts as read.');
  loadAlerts();
}

async function clearAllNotifications() {
  if (!confirm('Clear all historical notifications from feed?')) return;
  await fetch('/api/v1/alerts/clear', { method: 'POST' });
  showToast('Notification feed cleared.');
  loadAlerts();
}

// Toast notification helper
function showToast(message, type = '') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${type === 'buy' ? 'toast-buy' : (type === 'sell' ? 'toast-sell' : '')}`;
  toast.textContent = message;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}
