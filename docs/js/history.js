// 履歴タブ (iOS版 HistoryView.swift + MeasurementDetailView 相当)
import { averageFlowRate, flowRateMeter, tankCrossSection, tankVolumeM3, tankDimensionsLabel } from './formula.js';
import { fmtFlow, fmtSeconds, fmtDate, fmtDateDetail } from './format.js';
import { listMeasurements, updateMeasurement, deleteMeasurement, exportJSON, importJSON } from './storage.js';

let el = {};

export function init() {
  el = {
    root: document.getElementById('tab-history'),
    list: document.getElementById('history-list'),
    empty: document.getElementById('history-empty'),
    exportBtn: document.getElementById('history-export-btn'),
    importBtn: document.getElementById('history-import-btn'),
    importInput: document.getElementById('history-import-input'),
    detail: document.getElementById('detail-dialog'),
    detailBody: document.getElementById('detail-body'),
    detailClose: document.getElementById('detail-close'),
  };

  el.exportBtn.addEventListener('click', onExport);
  el.importBtn.addEventListener('click', () => el.importInput.click());
  el.importInput.addEventListener('change', onImport);
  el.detailClose.addEventListener('click', closeDetail);
  el.detail.addEventListener('click', (e) => {
    if (e.target === el.detail) closeDetail();
  });
}

export async function refresh() {
  const list = await listMeasurements();
  if (list.length === 0) {
    el.empty.classList.remove('hidden');
    el.list.innerHTML = '';
    return;
  }
  el.empty.classList.add('hidden');
  el.list.innerHTML = '';
  for (const m of list) {
    el.list.appendChild(buildRow(m));
  }
}

function buildRow(m) {
  const row = document.createElement('div');
  row.className = 'history-row';
  row.dataset.id = m.id;

  const method = m.method || 'meter';
  const methodLabel = method === 'tank' ? '水槽' : 'メーター';
  const methodIconId = method === 'tank' ? 'i-droplet' : 'i-gauge';
  const flow = averageFlowRate(m);

  let detailLine = '';
  if (method === 'meter') {
    detailLine = `${(m.lapTimes || []).length}回 ・ 1周${m.capacityL || 0} L`;
  } else if (m.tank) {
    detailLine = `${m.tank.shape === 'circular' ? '円形' : '矩形'} ${tankDimensionsLabel(m.tank)} ・ Δ${(m.tank.levelDelta ?? 0).toFixed(2)}m`;
  }

  const loc = m.location;
  const locLine1 = loc ? (loc.placeName || loc.address || '座標のみ') : '';
  const locLine2 = loc && loc.placeName && loc.address ? loc.address : '';

  row.innerHTML = `
    <div class="row-header">
      <span class="method-badge"><svg class="icon"><use href="#${methodIconId}"/></svg>${methodLabel}</span>
      <span class="row-date">${fmtDate(new Date(m.date))}</span>
    </div>
    ${flow != null ? `
      <div class="row-flow">
        <span class="flow-num">${fmtFlow(flow)}</span>
        <span class="flow-unit">m³/h</span>
      </div>` : ''}
    <div class="row-detail">${detailLine}</div>
    ${loc ? `
      <div class="row-loc">
        <svg class="icon"><use href="#i-map-pin"/></svg>
        <span>${locLine1}${locLine2 ? `<br><span class="dim">${locLine2}</span>` : ''}</span>
      </div>` : ''}
    ${m.note ? `<div class="row-note"><svg class="icon"><use href="#i-pencil-line"/></svg> ${escapeHTML(m.note)}</div>` : ''}
  `;

  row.addEventListener('click', () => openDetail(m.id));
  return row;
}

function escapeHTML(s) {
  return String(s).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[c]);
}

async function openDetail(id) {
  const list = await listMeasurements();
  const m = list.find(x => x.id === id);
  if (!m) return;

  const method = m.method || 'meter';
  const flow = averageFlowRate(m);

  let methodDetail = '';
  if (method === 'meter') {
    const lapsHTML = (m.lapTimes || []).map((t, i) => `
      <div class="detail-lap-row">
        <span>${i + 1} 回目</span>
        <span class="num">${fmtSeconds(t)} s</span>
        <span class="num">${fmtFlow(flowRateMeter(m.capacityL, t))} m³/h</span>
      </div>
    `).join('');
    methodDetail = `
      <h3>メーター詳細</h3>
      <div class="detail-row"><span>1周容量</span><span>${m.capacityL} L</span></div>
      <h3>各回</h3>
      ${lapsHTML}
    `;
  } else if (m.tank) {
    const t = m.tank;
    methodDetail = `
      <h3>水槽詳細</h3>
      <div class="detail-row"><span>形状</span><span>${t.shape === 'circular' ? '円形' : '矩形'}</span></div>
      <div class="detail-row"><span>寸法</span><span>${tankDimensionsLabel(t)}</span></div>
      <div class="detail-row"><span>断面積</span><span class="num">${tankCrossSection(t).toFixed(3)} m²</span></div>
      <div class="detail-row"><span>水位差 Δh</span><span class="num">${(t.levelDelta ?? 0).toFixed(3)} m</span></div>
      <div class="detail-row"><span>体積変化</span><span class="num">${tankVolumeM3(t).toFixed(3)} m³ (${(tankVolumeM3(t) * 1000).toFixed(1)} L)</span></div>
      <div class="detail-row"><span>経過時間</span><span class="num">${fmtSeconds(t.elapsedSeconds)} s</span></div>
    `;
  }

  const loc = m.location;
  const locHTML = loc ? `
    <h3>位置情報</h3>
    ${loc.placeName ? `<div class="detail-row"><span>施設/POI</span><span>${escapeHTML(loc.placeName)}</span></div>` : ''}
    ${loc.address ? `<div class="detail-row"><span>住所</span><span>${escapeHTML(loc.address)}</span></div>` : ''}
    <div class="detail-row"><span>座標</span><span class="num">${loc.latitude.toFixed(5)}, ${loc.longitude.toFixed(5)}</span></div>
    <div class="detail-row"><span>精度</span><span class="num">±${Math.round(loc.horizontalAccuracy)} m</span></div>
  ` : '';

  el.detailBody.innerHTML = `
    <h2>詳細</h2>
    <h3>計測結果</h3>
    <div class="detail-row"><span>日時</span><span>${fmtDateDetail(new Date(m.date))}</span></div>
    <div class="detail-row"><span>方式</span><span><svg class="icon"><use href="#${method === 'tank' ? 'i-droplet' : 'i-gauge'}"/></svg> ${method === 'tank' ? '水槽式' : 'メーター式'}</span></div>
    ${flow != null ? `<div class="detail-row"><span>流量</span><span class="num strong">${fmtFlow(flow)} m³/h</span></div>` : ''}
    ${methodDetail}
    ${locHTML}
    <h3>メモ</h3>
    <textarea id="detail-note" rows="4" placeholder="任意（点検内容、気付き等）">${escapeHTML(m.note || '')}</textarea>
    <p class="dim small">画面を閉じると自動保存されます</p>
    <div class="detail-actions">
      <button id="detail-delete-btn" class="danger">この記録を削除</button>
    </div>
  `;
  el.detail.dataset.editingId = id;
  el.detail.showModal();

  document.getElementById('detail-delete-btn').addEventListener('click', () => onDelete(id));
}

async function closeDetail() {
  const id = el.detail.dataset.editingId;
  if (id) {
    const noteEl = document.getElementById('detail-note');
    if (noteEl) {
      const newNote = noteEl.value.trim();
      const list = await listMeasurements();
      const m = list.find(x => x.id === id);
      if (m && (m.note || '') !== newNote) {
        m.note = newNote;
        await updateMeasurement(m);
      }
    }
  }
  el.detail.close();
  el.detail.dataset.editingId = '';
  await refresh();
}

async function onDelete(id) {
  if (!confirm('この記録を削除しますか？')) return;
  await deleteMeasurement(id);
  el.detail.close();
  el.detail.dataset.editingId = '';
  await refresh();
}

async function onExport() {
  const json = await exportJSON();
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  a.href = url;
  a.download = `flow-measurements-${ts}.json`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  URL.revokeObjectURL(url);
}

async function onImport(e) {
  const file = e.target.files?.[0];
  if (!file) return;
  try {
    const text = await file.text();
    const merge = confirm('既存データに追加 (OK) または完全置換 (キャンセル) しますか？\n\nOK = マージ（同じIDは新しい方で上書き）\nキャンセル = 全置換');
    const result = await importJSON(text, { merge });
    alert(`インポート完了：${result.imported}件追加（合計${result.total}件）`);
    await refresh();
  } catch (err) {
    alert(`インポート失敗：${err.message}`);
  } finally {
    e.target.value = '';
  }
}
