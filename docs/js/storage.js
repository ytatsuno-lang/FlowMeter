// IndexedDB ベースの永続化 (idb-keyval ライブラリ経由)
// データ構造はiOS版と互換: { id, date, method, capacityL, lapTimes, tank, note, location }

const KEY = 'measurements';

async function _get() {
  try {
    const list = await idbKeyval.get(KEY);
    return Array.isArray(list) ? list : [];
  } catch (e) {
    console.error('IndexedDB load failed', e);
    return [];
  }
}

async function _set(list) {
  try {
    await idbKeyval.set(KEY, list);
  } catch (e) {
    console.error('IndexedDB save failed', e);
    throw e;
  }
}

// 全件取得（日時降順）
export async function listMeasurements() {
  const list = await _get();
  return list.slice().sort((a, b) => new Date(b.date) - new Date(a.date));
}

export async function addMeasurement(m) {
  const list = await _get();
  list.unshift(m);
  await _set(list);
  return m;
}

export async function updateMeasurement(updated) {
  const list = await _get();
  const idx = list.findIndex(x => x.id === updated.id);
  if (idx < 0) return null;
  list[idx] = updated;
  await _set(list);
  return updated;
}

export async function deleteMeasurement(id) {
  const list = await _get();
  const filtered = list.filter(x => x.id !== id);
  await _set(filtered);
}

export async function exportJSON() {
  const list = await listMeasurements();
  return JSON.stringify(list, null, 2);
}

export async function importJSON(jsonText, { merge = true } = {}) {
  const incoming = JSON.parse(jsonText);
  if (!Array.isArray(incoming)) {
    throw new Error('JSONは配列形式である必要があります');
  }
  if (!merge) {
    await _set(incoming);
    return { imported: incoming.length, total: incoming.length };
  }
  // マージ: id重複は新しい方で上書き
  const existing = await _get();
  const map = new Map(existing.map(x => [x.id, x]));
  let added = 0;
  for (const m of incoming) {
    if (!m.id) continue;
    if (!map.has(m.id)) added++;
    map.set(m.id, m);
  }
  const merged = [...map.values()];
  await _set(merged);
  return { imported: added, total: merged.length };
}
