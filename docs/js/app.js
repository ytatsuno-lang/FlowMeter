// アプリエントリ・タブ切替・SaveSheet・LocationBadge同期
import * as meter from './meter.js';
import * as tank from './tank.js';
import * as history from './history.js';
import * as locCtx from './location.js';
import { fmtAge, isStale as fmtIsStale } from './format.js';

const TABS = ['meter', 'tank', 'history'];

function initTabs() {
  const buttons = document.querySelectorAll('.tab-btn');
  buttons.forEach(btn => {
    btn.addEventListener('click', () => switchTab(btn.dataset.tab));
  });
  switchTab('meter');
}

function switchTab(name) {
  for (const t of TABS) {
    document.getElementById(`tab-${t}`).classList.toggle('hidden', t !== name);
    document.querySelector(`.tab-btn[data-tab="${t}"]`).classList.toggle('active', t === name);
  }
  if (name === 'history') {
    history.refresh();
  }
}

// LocationBadge: 全タブ共通で表示される位置情報バッジ
function initLocationBadges() {
  const badges = document.querySelectorAll('.location-badge');
  badges.forEach(b => {
    const btn = b.querySelector('.loc-btn');
    btn.addEventListener('click', () => locCtx.refresh());
  });
  locCtx.subscribe(renderLocationBadges);
}

function renderLocationBadges(state) {
  const badges = document.querySelectorAll('.location-badge');
  let iconId = 'i-map-pin', line1 = '位置情報なし', line2 = '', stale = false, loading = false, denied = false;

  if (state.state === 'denied') {
    iconId = 'i-map-pin-off'; line1 = '位置情報拒否中'; line2 = ''; denied = true;
  } else if (state.state === 'loading') {
    iconId = 'i-loader'; line1 = '現在地を取得中…'; line2 = ''; loading = true;
  } else if (state.location) {
    line1 = state.location.placeName || state.location.address || '座標のみ取得';
    const age = fmtAge(state.capturedAt);
    stale = fmtIsStale(state.capturedAt);
    line2 = age ? (stale ? `${age} ・ 古い可能性` : age) : '';
  } else if (state.errorMessage) {
    line1 = state.errorMessage;
  }

  for (const b of badges) {
    b.classList.toggle('stale', stale);
    b.classList.toggle('denied', denied);
    b.classList.toggle('loading', loading);
    const iconEl = b.querySelector('.loc-icon');
    iconEl.innerHTML = `<use href="#${iconId}"/>`;
    b.querySelector('.loc-line1').textContent = line1;
    b.querySelector('.loc-line2').textContent = line2;
    const btn = b.querySelector('.loc-btn');
    btn.textContent = state.location ? '更新' : '取得';
    btn.disabled = loading;
  }
}

// SaveSheet: 計測の保存時にメモ + 位置情報を確認するモーダル
export async function openSaveSheet(measurement, onConfirm) {
  const dlg = document.getElementById('save-dialog');
  const body = document.getElementById('save-body');
  const flow = (await import('./formula.js')).averageFlowRate(measurement);
  const { fmtFlow, fmtSeconds } = await import('./format.js');

  let summary;
  if (measurement.method === 'meter') {
    summary = `
      <div class="save-row"><span>流量</span><span class="num strong">${fmtFlow(flow)} m³/h</span></div>
      <div class="save-row"><span>方式</span><span>メーター式 ・ ${measurement.lapTimes.length}回 ・ 1周${measurement.capacityL} L</span></div>
    `;
  } else {
    const t = measurement.tank;
    const dim = t.shape === 'circular' ? `Φ${t.diameter.toFixed(2)}m` : `${t.width.toFixed(2)}×${t.depth.toFixed(2)}m`;
    summary = `
      <div class="save-row"><span>流量</span><span class="num strong">${fmtFlow(flow)} m³/h</span></div>
      <div class="save-row"><span>方式</span><span>水槽式 ・ ${t.shape === 'circular' ? '円形' : '矩形'}</span></div>
      <div class="save-row"><span>寸法</span><span class="num">${dim}</span></div>
      <div class="save-row"><span>水位差・経過</span><span class="num">Δ${t.levelDelta.toFixed(2)} m ・ ${fmtSeconds(t.elapsedSeconds)} s</span></div>
    `;
  }

  body.innerHTML = `
    <h2>保存</h2>
    <h3>計測結果</h3>
    ${summary}
    <h3>位置情報</h3>
    <div id="save-location-box" class="save-loc-box"></div>
    <h3>メモ</h3>
    <textarea id="save-note" rows="4" placeholder="任意（点検内容、気付き等）"></textarea>
    <div class="save-actions">
      <button id="save-cancel-btn" class="secondary">キャンセル</button>
      <button id="save-confirm-btn" class="primary">保存</button>
    </div>
  `;

  const renderLocBox = (state) => {
    const box = document.getElementById('save-location-box');
    if (!box) return;
    if (state.state === 'loading' && !state.location) {
      box.innerHTML = `
        <p class="dim">現在地を取得中…</p>
        <p class="dim small">位置情報なしで保存したい場合はそのまま「保存」をタップ</p>
      `;
    } else if (state.state === 'denied') {
      box.innerHTML = `<p class="warn">位置情報が許可されていません</p><p class="dim small">ブラウザ設定から許可してください</p>`;
    } else if (state.location) {
      const l = state.location;
      const ageText = fmtAge(state.capturedAt);
      const staleText = fmtIsStale(state.capturedAt) ? `${ageText} ・ 古い可能性` : ageText;
      box.innerHTML = `
        <div class="save-loc-detail">
          ${l.placeName ? `<div class="strong">${escapeHTML(l.placeName)}</div>` : ''}
          ${l.address ? `<div>${escapeHTML(l.address)}</div>` : (!l.placeName ? '<div class="dim">座標のみ取得</div>' : '')}
          <div class="dim small">${l.latitude.toFixed(5)}, ${l.longitude.toFixed(5)} (±${Math.round(l.horizontalAccuracy)}m)</div>
          <div class="dim small">${staleText || ''}</div>
        </div>
        <button id="save-loc-refresh" class="small">再取得</button>
      `;
      document.getElementById('save-loc-refresh')?.addEventListener('click', () => locCtx.refresh());
    } else {
      box.innerHTML = `
        <p class="dim">未取得</p>
        <button id="save-loc-fetch" class="small">取得</button>
      `;
      document.getElementById('save-loc-fetch').addEventListener('click', () => locCtx.refresh());
    }
  };

  const unsub = locCtx.subscribe(renderLocBox);

  return new Promise((resolve) => {
    document.getElementById('save-cancel-btn').addEventListener('click', () => {
      unsub();
      dlg.close();
      resolve();
    });
    document.getElementById('save-confirm-btn').addEventListener('click', async () => {
      const note = document.getElementById('save-note').value.trim();
      const final = {
        ...measurement,
        note,
        location: locCtx.getState().location,
      };
      unsub();
      dlg.close();
      try {
        await onConfirm(final);
      } catch (e) {
        alert('保存失敗: ' + e.message);
      }
      resolve();
    });
    dlg.showModal();
  });
}

function escapeHTML(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[c]);
}

// Service Worker 登録
function registerSW() {
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('./sw.js').catch(err => {
        console.warn('SW registration failed:', err);
      });
    });
  }
}

// アプリ起動
function init() {
  initTabs();
  initLocationBadges();
  meter.init();
  tank.init();
  history.init();

  // 起動時に位置情報を裏で取得試行
  locCtx.refreshIfNeeded();

  // フォアグラウンド復帰時、未取得 or 古ければ再取得
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
      locCtx.refreshIfNeeded();
    }
  });

  registerSW();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
