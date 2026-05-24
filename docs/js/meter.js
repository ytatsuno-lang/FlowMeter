// メーター式タブ (iOS版 MeterView.swift 相当)
import { flowRateMeter } from './formula.js';
import { fmtFlow, fmtSeconds, uuid } from './format.js';
import * as locCtx from './location.js';
import { addMeasurement } from './storage.js';
import { openSaveSheet } from './app.js';

const state = {
  capacityL: 100,            // 10 | 100 | 1000
  startTime: null,           // Date.now()
  laps: [],                  // 経過秒[]
  tickId: null,
};

let el = {};

export function init() {
  el = {
    root: document.getElementById('tab-meter'),
    capacityRadios: document.querySelectorAll('input[name="meter-capacity"]'),
    capacityDetail: document.getElementById('meter-capacity-detail'),
    timer: document.getElementById('meter-timer'),
    flow: document.getElementById('meter-flow'),
    laps: [
      document.getElementById('meter-lap-0'),
      document.getElementById('meter-lap-1'),
      document.getElementById('meter-lap-2'),
    ],
    avgRow: document.getElementById('meter-avg-row'),
    mainBtn: document.getElementById('meter-main-btn'),
    mainBtnTitle: document.getElementById('meter-main-btn-title'),
    mainBtnSub: document.getElementById('meter-main-btn-sub'),
    resetBtn: document.getElementById('meter-reset-btn'),
    saveBtn: document.getElementById('meter-save-btn'),
  };

  for (const r of el.capacityRadios) {
    r.addEventListener('change', () => {
      state.capacityL = parseInt(r.value, 10);
      updateCapacityDetail();
      render();
    });
  }

  el.mainBtn.addEventListener('click', mainAction);
  el.resetBtn.addEventListener('click', reset);
  el.saveBtn.addEventListener('click', saveCurrent);

  updateCapacityDetail();
  render();
}

function updateCapacityDetail() {
  const labels = { 10: '×0.001針 (1周 10 L)', 100: '×0.01針 (1周 100 L)', 1000: '×0.1針 (1周 1000 L)' };
  el.capacityDetail.textContent = labels[state.capacityL] || '';
}

function isRunning() { return state.startTime !== null; }
function isFinished() { return state.laps.length >= 3; }
function canSave() { return state.laps.length > 0 && !isRunning(); }

function elapsed() {
  if (!state.startTime) return 0;
  return (Date.now() - state.startTime) / 1000;
}

function startTicker() {
  stopTicker();
  state.tickId = setInterval(renderTimer, 50);
}
function stopTicker() {
  if (state.tickId) { clearInterval(state.tickId); state.tickId = null; }
}

function mainAction() {
  if (isFinished()) return;
  const now = Date.now();
  if (state.startTime) {
    const e = (now - state.startTime) / 1000;
    state.laps.push(e);
    if (state.laps.length < 3) {
      state.startTime = now;  // 次の周をすぐ計測
    } else {
      state.startTime = null;
      stopTicker();
    }
  } else {
    if (state.laps.length === 0) {
      // 計測開始時に位置を裏で取得試行
      locCtx.refresh();
    }
    state.startTime = now;
    startTicker();
  }
  render();
}

function reset() {
  state.startTime = null;
  state.laps = [];
  stopTicker();
  render();
}

function deleteLap(i) {
  state.laps.splice(i, 1);
  render();
}

async function saveCurrent() {
  if (!canSave()) return;
  const m = {
    id: uuid(),
    date: new Date().toISOString(),
    method: 'meter',
    capacityL: state.capacityL,
    lapTimes: state.laps.slice(),
    tank: null,
    note: '',
    location: null,
  };
  await openSaveSheet(m, async (final) => {
    await addMeasurement(final);
    reset();
  });
}

function renderTimer() {
  const e = elapsed();
  el.timer.textContent = e > 0 ? e.toFixed(2) : '0.00';
  if (e > 0.1) {
    el.flow.textContent = `${fmtFlow(flowRateMeter(state.capacityL, e))} m³/h`;
  } else {
    el.flow.textContent = '—';
  }
}

function render() {
  // capacity radios state
  for (const r of el.capacityRadios) {
    r.checked = parseInt(r.value, 10) === state.capacityL;
    r.disabled = isRunning() || state.laps.length > 0;
  }

  // timer
  renderTimer();

  // laps
  for (let i = 0; i < 3; i++) {
    const row = el.laps[i];
    const t = state.laps[i];
    if (t != null) {
      const flow = flowRateMeter(state.capacityL, t);
      row.innerHTML = `
        <span class="lap-title">${i + 1} 回目</span>
        <span class="lap-time">${fmtSeconds(t)} s</span>
        <span class="lap-flow">${fmtFlow(flow)} m³/h</span>
        <button class="lap-del" aria-label="${i + 1}回目を削除"><svg class="icon"><use href="#i-x-circle"/></svg></button>
      `;
      row.classList.add('has-value');
      row.querySelector('.lap-del').addEventListener('click', () => deleteLap(i));
    } else {
      row.innerHTML = `
        <span class="lap-title">${i + 1} 回目</span>
        <span class="lap-time">—</span>
        <span class="lap-flow"></span>
      `;
      row.classList.remove('has-value');
    }
  }

  // 平均
  if (state.laps.length >= 2) {
    const avg = state.laps.reduce((a, b) => a + b, 0) / state.laps.length;
    const avgFlow = flowRateMeter(state.capacityL, avg);
    el.avgRow.innerHTML = `
      <span class="lap-title">平均 (${state.laps.length}回)</span>
      <span class="lap-time">${fmtSeconds(avg)} s</span>
      <span class="lap-flow">${fmtFlow(avgFlow)} m³/h</span>
    `;
    el.avgRow.classList.remove('hidden');
  } else {
    el.avgRow.classList.add('hidden');
  }

  // main button
  let label, sub, cls;
  if (isFinished()) { label = '完了'; sub = '3回計測済み'; cls = 'gray'; }
  else if (isRunning()) { label = `LAP  ${state.laps.length + 1} / 3`; sub = '針が0を通過したらタップ'; cls = 'orange'; }
  else { label = 'START'; sub = state.laps.length === 0 ? '針が0を通過したらタップ' : '次の計測'; cls = 'blue'; }
  el.mainBtnTitle.textContent = label;
  el.mainBtnSub.textContent = sub;
  el.mainBtn.className = `main-btn ${cls}`;
  el.mainBtn.disabled = isFinished();

  // bottom
  el.resetBtn.disabled = state.laps.length === 0 && !isRunning();
  el.saveBtn.disabled = !canSave();
  el.saveBtn.classList.toggle('enabled', canSave());
}
