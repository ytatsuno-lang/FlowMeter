// 水槽式タブ (iOS版 TankView.swift 相当)
import { tankCrossSection, tankVolumeM3, flowRateTank } from './formula.js';
import { fmtFlow, fmtSeconds, uuid } from './format.js';
import * as locCtx from './location.js';
import { addMeasurement } from './storage.js';
import { openSaveSheet } from './app.js';

const state = {
  shape: 'rectangular',
  width: 1.0,
  depth: 1.0,
  diameter: 1.0,
  levelDelta: 0.10,
  startTime: null,
  elapsedFinal: null,
  tickId: null,
};

let el = {};

export function init() {
  el = {
    root: document.getElementById('tab-tank'),
    shapeRadios: document.querySelectorAll('input[name="tank-shape"]'),
    rectGroup: document.getElementById('tank-rect-group'),
    circGroup: document.getElementById('tank-circ-group'),
    width: document.getElementById('tank-width'),
    depth: document.getElementById('tank-depth'),
    diameter: document.getElementById('tank-diameter'),
    levelDelta: document.getElementById('tank-level-delta'),
    crossSection: document.getElementById('tank-cross-section'),
    volumeText: document.getElementById('tank-volume'),
    timer: document.getElementById('tank-timer'),
    flow: document.getElementById('tank-flow'),
    mainBtn: document.getElementById('tank-main-btn'),
    mainBtnTitle: document.getElementById('tank-main-btn-title'),
    mainBtnSub: document.getElementById('tank-main-btn-sub'),
    resetBtn: document.getElementById('tank-reset-btn'),
    saveBtn: document.getElementById('tank-save-btn'),
  };

  for (const r of el.shapeRadios) {
    r.addEventListener('change', () => {
      state.shape = r.value;
      render();
    });
  }

  bindNumberInput(el.width, v => state.width = v);
  bindNumberInput(el.depth, v => state.depth = v);
  bindNumberInput(el.diameter, v => state.diameter = v);
  bindNumberInput(el.levelDelta, v => state.levelDelta = v);

  el.mainBtn.addEventListener('click', mainAction);
  el.resetBtn.addEventListener('click', reset);
  el.saveBtn.addEventListener('click', saveCurrent);

  // 初期値セット
  el.width.value = state.width;
  el.depth.value = state.depth;
  el.diameter.value = state.diameter;
  el.levelDelta.value = state.levelDelta;

  render();
}

function bindNumberInput(input, setter) {
  input.addEventListener('input', () => {
    const v = parseFloat(input.value);
    setter(isFinite(v) ? v : 0);
    render();
  });
}

function isRunning() { return state.startTime !== null; }
function hasResult() { return state.elapsedFinal !== null; }
function canEdit() { return !isRunning() && !hasResult(); }
function canStart() {
  if (!(state.levelDelta > 0)) return false;
  if (state.shape === 'rectangular') return state.width > 0 && state.depth > 0;
  return state.diameter > 0;
}
function canSave() { return hasResult() && !isRunning(); }

function elapsed() {
  if (state.elapsedFinal != null) return state.elapsedFinal;
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

function tankSnapshot(seconds) {
  return {
    shape: state.shape,
    width: state.shape === 'rectangular' ? state.width : 0,
    depth: state.shape === 'rectangular' ? state.depth : 0,
    diameter: state.shape === 'circular' ? state.diameter : 0,
    levelDelta: state.levelDelta,
    elapsedSeconds: seconds,
  };
}

function mainAction() {
  if (hasResult()) return;
  const now = Date.now();
  if (state.startTime) {
    state.elapsedFinal = (now - state.startTime) / 1000;
    state.startTime = null;
    stopTicker();
  } else {
    if (!canStart()) return;
    // フォーカス解除
    document.activeElement?.blur?.();
    locCtx.refresh();
    state.startTime = now;
    startTicker();
  }
  render();
}

function reset() {
  state.startTime = null;
  state.elapsedFinal = null;
  stopTicker();
  render();
}

async function saveCurrent() {
  if (!canSave()) return;
  const m = {
    id: uuid(),
    date: new Date().toISOString(),
    method: 'tank',
    capacityL: 0,
    lapTimes: [],
    tank: tankSnapshot(state.elapsedFinal),
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
    const t = tankSnapshot(e);
    el.flow.textContent = `${fmtFlow(flowRateTank(t))} m³/h`;
  } else {
    el.flow.textContent = '—';
  }
}

function render() {
  // shape radios state
  for (const r of el.shapeRadios) {
    r.checked = r.value === state.shape;
    r.disabled = !canEdit();
  }
  el.rectGroup.classList.toggle('hidden', state.shape !== 'rectangular');
  el.circGroup.classList.toggle('hidden', state.shape !== 'circular');

  // disable inputs while running/has result
  [el.width, el.depth, el.diameter, el.levelDelta].forEach(i => i.disabled = !canEdit());

  // prediction box
  const t = tankSnapshot(0);
  const area = tankCrossSection(t);
  const vol = tankVolumeM3(t);
  el.crossSection.textContent = `${area.toFixed(3)} m²`;
  el.volumeText.textContent = `${vol.toFixed(3)} m³ = ${(vol * 1000).toFixed(1)} L`;

  // timer
  renderTimer();

  // main button
  let label, sub, cls;
  if (hasResult()) { label = '完了'; sub = '計測済み'; cls = 'gray'; }
  else if (isRunning()) { label = 'STOP'; sub = '水位がΔh変化したらタップ'; cls = 'orange'; }
  else { label = 'START'; sub = '水位の基準を読んだらタップ'; cls = canStart() ? 'blue' : 'gray'; }
  el.mainBtnTitle.textContent = label;
  el.mainBtnSub.textContent = sub;
  el.mainBtn.className = `main-btn ${cls}`;
  el.mainBtn.disabled = !canStart() && !isRunning() && !hasResult();

  el.resetBtn.disabled = !isRunning() && !hasResult();
  el.saveBtn.disabled = !canSave();
  el.saveBtn.classList.toggle('enabled', canSave());

  // タブの状態属性（CSSがスクロール挙動の出し分けに使用）
  el.root.dataset.state = hasResult() ? 'finished'
                        : isRunning() ? 'running'
                        : 'idle';
}
