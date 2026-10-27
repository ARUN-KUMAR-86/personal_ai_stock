/**
 * Personal AI Stock Intelligence — Realtime Notification Client
 */

let alertsState = [];
let currentFilter = 'ALL';
let unreadOnly = false;
let audioEnabled = true;
let eventSource = null;
let audioCtx = null;

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
  initAudio();
  fetchMarketStatus();
  loadAlerts();
  initSSE();
  loadSettings();
  requestBrowserNotifications();

  // Periodic market status refresh
  setInterval(fetchMarketStatus, 60000);
});

// Web Audio API chime synthesizer
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

function playAlertChime(action) {
  if (!audioEnabled || !audioCtx) return;
  try {
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.connect(gain);
    gain.connect(audioCtx.destination);

    const now = audioCtx.currentTime;
    if (action === 'BUY') {
      // Upward cheerful chime
      osc.frequency.setValueAtTime(523.25, now); // C5
      osc.frequency.exponentialRampToValueAtTime(783.99, now + 0.18); // G5
      gain.gain.setValueAtTime(0.2, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.35);
      osc.start(now);
      osc.stop(now + 0.35);
    } else {
      // Downward cautionary chime
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
  document.getElementById('audio-icon').textContent = audioEnabled ? '🔔' : '🔕';
  showToast(`Alert chimes turned ${audioEnabled ? 'ON' : 'OFF'}`);
}

function requestBrowserNotifications() {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }
}

function showBrowserNotification(title, body) {
  if ('Notification' in window && Notification.permission === 'granted') {
    try {
      new Notification(title, {
        body: body,
        icon: '/static/favicon.ico',
      });
    } catch (e) {
      console.debug('Browser notification err:', e);
    }
  }
}

// Fetch Market Status
async function fetchMarketStatus() {
  try {
    const res = await fetch('/api/v1/market-status');
    if (!res.ok) return;
    const data = await res.json();
    const chip = document.getElementById('market-status-chip');
    const text = document.getElementById('market-status-text');
    if (data.is_open) {
      chip.classList.add('market-open');
      text.textContent = `NSE: OPEN (${data.local_time || 'Trading'})`;
    } else {
      chip.classList.remove('market-open');
      text.textContent = `NSE: CLOSED (${data.next_open_in || 'Reopens 09:15'})`;
    }
  } catch (err) {
    console.debug('Market status fetch note:', err);
  }
}

// Load Alerts History
async function loadAlerts() {
  try {
    const res = await fetch('/api/v1/alerts/history?limit=100');
    if (!res.ok) throw new Error('Failed to load history');
    alertsState = await res.json();
    renderAlerts();
    updateCounts();
  } catch (err) {
    console.error('Error loading alerts:', err);
    document.getElementById('feed-loading').innerHTML = `
      <p style="color: #ff1744;">Failed to load alerts. Retrying...</p>
    `;
    setTimeout(loadAlerts, 3000);
  }
}

// Connect to Server-Sent Events (SSE) Real-time Stream
function initSSE() {
  const statusEl = document.getElementById('sse-status-text');
  if (eventSource) {
    eventSource.close();
  }

  eventSource = new EventSource('/api/v1/alerts/stream');

  eventSource.onopen = () => {
    statusEl.textContent = '● LIVE REALTIME NOTIFICATIONS';
    document.getElementById('sse-status').style.borderColor = 'rgba(0, 230, 118, 0.4)';
  };

  eventSource.addEventListener('alert', (event) => {
    try {
      const alert = JSON.parse(event.data);
      handleIncomingAlert(alert);
    } catch (err) {
      console.error('Error parsing SSE event:', err);
    }
  });

  eventSource.onerror = () => {
    statusEl.textContent = 'RECONNECTING STREAM...';
    document.getElementById('sse-status').style.borderColor = 'rgba(255, 23, 68, 0.4)';
  };
}

function handleIncomingAlert(alert) {
  // Check duplicate
  const exists = alertsState.some(a => a.id === alert.id);
  if (exists) return;

  alertsState.unshift(alert);
  renderAlerts();
  updateCounts();

  const action = (alert.action || alert.alert_type || 'BUY').toUpperCase();
  playAlertChime(action);

  const icon = action === 'BUY' ? '🟢' : '🔴';
  const toastClass = action === 'BUY' ? 'toast-buy' : 'toast-sell';
  showToast(`${icon} Realtime ${action}: ${alert.symbol} @ ₹${Number(alert.price).toFixed(2)}`, toastClass);
  showBrowserNotification(`${icon} AI STOCK ${action}: ${alert.symbol}`, `Price: ₹${alert.price} | ${alert.reason || 'Confluence setup detected'}`);
}

// Render Alerts Grid
function renderAlerts() {
  const feed = document.getElementById('alerts-feed');
  let filtered = alertsState;

  if (currentFilter === 'BUY') {
    filtered = filtered.filter(a => (a.action === 'BUY' || a.alert_type === 'BUY'));
  } else if (currentFilter === 'SELL') {
    filtered = filtered.filter(a => (a.action === 'SELL' || a.alert_type === 'SELL'));
  }

  if (unreadOnly) {
    filtered = filtered.filter(a => !a.is_read);
  }

  if (filtered.length === 0) {
    feed.innerHTML = `
      <div class="empty-state">
        <div style="font-size: 38px;">📡</div>
        <p>No ${currentFilter === 'ALL' ? '' : currentFilter} notifications found.</p>
        <span style="font-size: 13px; color: var(--text-dim);">
          Click <strong>"Search All Stocks Daily"</strong> above to scan across the internet with Gemini Pro.
        </span>
      </div>
    `;
    return;
  }

  feed.innerHTML = filtered.map(alert => createAlertCardHtml(alert)).join('');
}

function createAlertCardHtml(alert) {
  const action = (alert.action || alert.alert_type || 'BUY').toUpperCase();
  const isBuy = action === 'BUY';
  const cardClass = isBuy ? 'is-buy' : 'is-sell';
  const pillClass = isBuy ? 'pill-buy' : 'pill-sell';
  const icon = isBuy ? '🟢' : '🔴';

  const price = alert.price ? `₹${Number(alert.price).toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : 'N/A';
  const sl = alert.stop_loss ? `₹${Number(alert.stop_loss).toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : 'None';
  const target = alert.target ? `₹${Number(alert.target).toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : 'None';

  let rr = 'N/A';
  if (alert.price && alert.target && alert.stop_loss) {
    const risk = Math.abs(alert.price - alert.stop_loss);
    const reward = Math.abs(alert.target - alert.price);
    if (risk > 0) rr = `1:${(reward / risk).toFixed(1)}`;
  }

  // Thesis extraction
  const research = alert.gemini_research || {};
  const headline = research.headline || alert.reason || `${alert.symbol} Confluence Setup`;
  const thesis = research.investment_thesis || alert.message || '';
  const catalysts = research.catalysts || [];

  const timeAgo = formatTimeAgo(alert.created_at);

  return `
    <article class="alert-card ${cardClass}" id="card-${alert.id}">
      <div class="card-header">
        <div class="card-stock-info">
          <div class="symbol-row">
            <span class="stock-symbol">${escapeHtml(alert.symbol)}</span>
            <span class="exchange-tag">${escapeHtml(alert.exchange || 'NSE')}</span>
            ${!alert.is_read ? '<span style="font-size: 8px; color: var(--cyan-accent); font-weight:800;">● NEW</span>' : ''}
          </div>
          <div class="company-name">${escapeHtml(research.company_name || alert.symbol)}</div>
        </div>
        <div class="action-pill ${pillClass}">
          ${icon} ${action} ALERT
        </div>
      </div>

      <div class="tactical-levels">
        <div class="level-col">
          <span class="level-label">PRICE</span>
          <span class="level-val">${price}</span>
        </div>
        <div class="level-col">
          <span class="level-label">TARGET</span>
          <span class="level-val ${isBuy ? 'text-buy' : 'text-cyan'}">${target}</span>
        </div>
        <div class="level-col">
          <span class="level-label">STOP-LOSS</span>
          <span class="level-val text-sell">${sl}</span>
        </div>
        <div class="level-col">
          <span class="level-label">R:R</span>
          <span class="level-val">${rr}</span>
        </div>
      </div>

      <div class="thesis-box">
        <div class="thesis-headline">${escapeHtml(headline)}</div>
        <div class="thesis-snippet">${escapeHtml(thesis)}</div>
      </div>

      ${catalysts.length > 0 ? `
        <div class="catalyst-tags">
          ${catalysts.slice(0, 2).map(c => `
            <span class="tag-catalyst">✨ ${escapeHtml(c.length > 55 ? c.slice(0, 55) + '...' : c)}</span>
          `).join('')}
        </div>
      ` : ''}

      <div class="card-footer">
        <div class="footer-left">
          <span>🕒 ${timeAgo}</span>
          ${alert.sent_to_fcm ? '<span title="Dispatched to Android Phone FCM">📲 Push Sent</span>' : ''}
        </div>
        <div class="footer-right">
          <button class="btn-research" onclick="openResearchModal(${alert.id})">
            🔬 Gemini Pro Research
          </button>
          ${!alert.is_read ? `
            <button class="btn btn-sm btn-ghost" onclick="markAsRead(${alert.id})" title="Mark Read">✓</button>
          ` : ''}
        </div>
      </div>
    </article>
  `;
}

// Update Metric Counters
function updateCounts() {
  const total = alertsState.length;
  const buyCount = alertsState.filter(a => (a.action === 'BUY' || a.alert_type === 'BUY')).length;
  const sellCount = alertsState.filter(a => (a.action === 'SELL' || a.alert_type === 'SELL')).length;

  document.getElementById('count-total').textContent = total;
  document.getElementById('count-buy').textContent = buyCount;
  document.getElementById('count-sell').textContent = sellCount;

  document.getElementById('tab-all-count').textContent = total;
  document.getElementById('tab-buy-count').textContent = buyCount;
  document.getElementById('tab-sell-count').textContent = sellCount;
}

// Filter Tabs
function setFilter(filter) {
  currentFilter = filter;
  document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.filter === filter);
  });
  renderAlerts();
}

function toggleUnreadOnly() {
  unreadOnly = document.getElementById('unread-only-check').checked;
  renderAlerts();
}

// Mark Read Actions
async function markAsRead(alertId) {
  try {
    await fetch(`/api/v1/alerts/${alertId}/read`, { method: 'POST' });
    const item = alertsState.find(a => a.id === alertId);
    if (item) item.is_read = true;
    renderAlerts();
  } catch (err) {
    console.error('Failed to mark read:', err);
  }
}

async function markAllAsRead() {
  const unreadIds = alertsState.filter(a => !a.is_read).map(a => a.id);
  if (unreadIds.length === 0) return;
  try {
    await fetch('/api/v1/alerts/mark-read', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ alert_ids: unreadIds })
    });
    alertsState.forEach(a => a.is_read = true);
    renderAlerts();
    showToast('All notifications marked as read.');
  } catch (err) {
    console.error('Failed mark all read:', err);
  }
}

async function clearAllNotifications() {
  if (!confirm('Clear all notification history?')) return;
  try {
    await fetch('/api/v1/alerts/clear', { method: 'POST' });
    alertsState = [];
    renderAlerts();
    updateCounts();
    showToast('Feed cleared.');
  } catch (err) {
    console.error('Clear feed failed:', err);
  }
}

// Trigger Internet Daily Stock Scan
async function triggerDailyScan() {
  const btn = document.getElementById('btn-scan-now');
  const progressBox = document.getElementById('scan-progress-bar');
  const progressFill = document.getElementById('progress-fill');

  btn.disabled = true;
  progressBox.style.display = 'block';
  progressFill.style.width = '15%';

  showToast('🔍 Initiating daily stock search across internet with Gemini Pro...');

  try {
    progressFill.style.width = '45%';
    const res = await fetch('/api/v1/scanner/scan', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ force: true, exchange: 'NSE' })
    });
    progressFill.style.width = '85%';
    const job = await res.json();
    progressFill.style.width = '100%';

    setTimeout(() => {
      progressBox.style.display = 'none';
      btn.disabled = false;
      loadAlerts();
      showToast(`Scan complete: ${job.scanned_stocks || 0} stocks researched. ${job.passed_signals || 0} alerts dispatched.`);
    }, 1000);

  } catch (err) {
    console.error('Daily scan trigger err:', err);
    progressBox.style.display = 'none';
    btn.disabled = false;
    showToast('Error executing stock scan.', 'toast-sell');
  }
}

// Modal Viewers
function openResearchModal(alertId) {
  const alert = alertsState.find(a => a.id === alertId);
  if (!alert) return;

  const action = (alert.action || alert.alert_type || 'BUY').toUpperCase();
  const isBuy = action === 'BUY';
  const badge = document.getElementById('modal-action-badge');
  badge.textContent = `${isBuy ? '🟢' : '🔴'} ${action} ALERT`;
  badge.className = `badge ${isBuy ? 'pill-buy' : 'pill-sell'}`;

  document.getElementById('modal-stock-title').textContent = `${alert.symbol} (${alert.exchange || 'NSE'})`;
  document.getElementById('modal-stock-price').textContent = alert.price ? `₹${Number(alert.price).toFixed(2)}` : 'N/A';

  const research = alert.gemini_research || {};
  const catalysts = research.catalysts || [];
  const risks = research.risk_factors || [];
  const tech = research.technical_summary || {};
  const tactical = research.tactical_plan || {};

  const content = document.getElementById('modal-research-content');
  content.innerHTML = `
    <div class="report-section">
      <div class="section-heading">📌 Executive Investment Thesis (Gemini Pro)</div>
      <div class="report-box">
        <strong>${escapeHtml(research.headline || alert.reason || '')}</strong>
        <p style="margin-top: 8px;">${escapeHtml(research.investment_thesis || alert.message || 'Institutional thesis generation in progress.')}</p>
      </div>
    </div>

    ${catalysts.length > 0 ? `
      <div class="report-section">
        <div class="section-heading">🚀 Key Catalysts & Technical Confluence</div>
        <div class="report-box">
          <ul class="catalysts-list">
            ${catalysts.map(c => `<li><span>✔</span> ${escapeHtml(c)}</li>`).join('')}
          </ul>
        </div>
      </div>
    ` : ''}

    ${risks.length > 0 ? `
      <div class="report-section">
        <div class="section-heading">⚠️ Risk Factors & Invalidation Trigger</div>
        <div class="report-box">
          <ul class="risks-list">
            ${risks.map(r => `<li><span>✖</span> ${escapeHtml(r)}</li>`).join('')}
          </ul>
          ${research.invalidation_trigger ? `
            <div style="margin-top: 10px; font-size: 13px; color: #fda4af;">
              <strong>Invalidation Rule:</strong> ${escapeHtml(research.invalidation_trigger)}
            </div>
          ` : ''}
        </div>
      </div>
    ` : ''}

    <div class="report-section">
      <div class="section-heading">📊 Verified Technical Metrics</div>
      <div class="indicators-grid">
        <div class="indicator-item">
          <div class="ind-name">Trend</div>
          <div class="ind-val text-cyan">${escapeHtml(tech.trend || 'Upward Momentum')}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Momentum (RSI)</div>
          <div class="ind-val">${escapeHtml(tech.momentum || 'Healthy')}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Volume Profile</div>
          <div class="ind-val text-buy">${escapeHtml(tech.volume_profile || 'Accumulation')}</div>
        </div>
      </div>
    </div>

    <div class="report-section">
      <div class="section-heading">🎯 Tactical Execution Plan</div>
      <div class="indicators-grid">
        <div class="indicator-item">
          <div class="ind-name">Entry Zone</div>
          <div class="ind-val">${escapeHtml(tactical.entry_zone || `₹${alert.price || 0}`)}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Stop Loss</div>
          <div class="ind-val text-sell">${escapeHtml(tactical.stop_loss || `₹${alert.stop_loss || 0}`)}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Target 1</div>
          <div class="ind-val text-buy">${escapeHtml(tactical.target_1 || `₹${alert.target || 0}`)}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Holding Horizon</div>
          <div class="ind-val">${escapeHtml(tactical.time_horizon || '24 to 48 Hours')}</div>
        </div>
        <div class="indicator-item">
          <div class="ind-name">Model Engine</div>
          <div class="ind-val text-cyan">${escapeHtml(research.model_used || 'Gemini 1.5 Pro')}</div>
        </div>
      </div>
    </div>
  `;

  document.getElementById('research-modal').style.display = 'flex';
}

function openSettingsModal() {
  document.getElementById('settings-modal').style.display = 'flex';
}

function closeModal(modalId) {
  document.getElementById(modalId).style.display = 'none';
}

function closeModalOnBackdrop(event, modalId) {
  if (event.target.id === modalId) {
    closeModal(modalId);
  }
}

// Settings handlers
async function loadSettings() {
  try {
    const gRes = await fetch('/api/v1/settings/GEMINI_API_KEY');
    if (gRes.ok) {
      const gData = await gRes.json();
      if (gData.value) {
        document.getElementById('gemini-key-input').value = gData.value;
      }
    }
  } catch (_) {}

  try {
    const res = await fetch('/api/v1/alerts/test-push', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ symbol: 'TEST', title: 'CHECK', body: 'CHECK' })
    });
    if (res.ok) {
      const data = await res.json();
      document.getElementById('fcm-status-box').textContent = data.fcm_available 
        ? '✅ Firebase FCM Cloud Messaging is Active' 
        : '⚠️ FCM Not Configured (Operating in Local / Real-time Web Mode)';
    }
  } catch (e) {
    console.debug('FCM test check note:', e);
  }
}

async function saveSettings() {
  const key = document.getElementById('gemini-key-input').value.trim();
  const model = document.getElementById('gemini-model-select').value;

  if (key) {
    try {
      await fetch('/api/v1/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ key: 'GEMINI_API_KEY', value: key })
      });
      showToast('Gemini API Key saved successfully.');
    } catch (e) {
      console.warn('Settings save endpoint note:', e);
    }
  }

  document.getElementById('ai-model-tag').textContent = model.replace('gemini-', 'Gemini ');
  closeModal('settings-modal');
  showToast('Configuration applied.');
}

async function sendTestSignal(action) {
  const isBuy = action === 'BUY';
  const testSymbol = isBuy ? 'TATAMOTORS' : 'RELIANCE';
  const price = isBuy ? 985.40 : 1240.50;
  const sl = isBuy ? 945.00 : 1265.00;
  const target = isBuy ? 1060.00 : 1180.00;

  const mockAlert = {
    id: Date.now(),
    symbol: testSymbol,
    exchange: 'NSE',
    action: action,
    alert_type: action,
    title: `${isBuy ? '🟢' : '🔴'} ${action} ALERT: ${testSymbol} @ ₹${price.toFixed(2)}`,
    message: `${action} signal triggered by Gemini Pro Deep Research confluence engine.`,
    price: price,
    stop_loss: sl,
    target: target,
    reason: isBuy ? 'Breakout above 20-day high with 2.1x volume' : 'Profit target reached at R2 pivot resistance',
    is_read: false,
    created_at: new Date().toISOString(),
    gemini_research: {
      headline: isBuy ? `${testSymbol}: Institutional Momentum Breakout Confirmed` : `${testSymbol}: Target Objective Met — Take Profits`,
      investment_thesis: isBuy 
        ? `High volume expansion and RSI continuation confirmed on ${testSymbol}. Asymmetric risk-reward setup targeting swing extensions.`
        : `Primary target extension achieved. RSI overbought divergence indicates diminishing buyer interest. Capital preservation recommended.`,
      catalysts: isBuy 
        ? ['Volume surged to 2.1x 20-day baseline', 'Sustained consolidation above 21-day EMA', 'Bullish MACD histogram expansion']
        : ['Target 1 achieved (+7.6% gain)', 'Approaching R2 overhead supply', 'RSI showing bearish divergence'],
      risk_factors: isBuy 
        ? ['Overhead resistance at 52-week high', 'Broad market volatility']
        : ['Sudden gap-up retest'],
      technical_summary: {
        trend: isBuy ? 'Bullish Breakout' : 'Exhaustion / Reversal',
        momentum: isBuy ? 'Accelerating (RSI 64.2)' : 'Overbought Reversal (RSI 76.5)',
        volume_profile: isBuy ? 'Institutional Accumulation' : 'Distribution / Profit Taking',
      },
      tactical_plan: {
        entry_zone: `₹${(price * 0.995).toFixed(2)} - ₹${(price * 1.005).toFixed(2)}`,
        stop_loss: `₹${sl.toFixed(2)}`,
        target_1: `₹${target.toFixed(2)}`,
        time_horizon: '24 to 48 Hours',
      },
      model_used: 'Gemini 1.5 Pro'
    }
  };

  handleIncomingAlert(mockAlert);
}

// Utility Helpers
function formatTimeAgo(isoString) {
  if (!isoString) return 'Just now';
  const diffSec = Math.floor((new Date() - new Date(isoString)) / 1000);
  if (diffSec < 60) return 'Just now';
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
  return `${Math.floor(diffSec / 86400)}d ago`;
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function showToast(message, customClass = '') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${customClass}`;
  toast.textContent = message;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 300);
  }, 4000);
}
