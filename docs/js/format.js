// 数値・日時のフォーマッタ

export function fmtFlow(v) {
  if (v == null || !isFinite(v)) return '—';
  return v.toFixed(2);
}

export function fmtSeconds(v) {
  if (v == null || !isFinite(v)) return '—';
  return v.toFixed(2);
}

const _dateFormatter = new Intl.DateTimeFormat('ja-JP', {
  year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit',
  hour12: false,
});
export function fmtDate(d) {
  if (!(d instanceof Date)) d = new Date(d);
  return _dateFormatter.format(d);
}

const _detailDateFormatter = new Intl.DateTimeFormat('ja-JP', {
  year: 'numeric', month: 'long', day: 'numeric', weekday: 'short',
  hour: '2-digit', minute: '2-digit',
  hour12: false,
});
export function fmtDateDetail(d) {
  if (!(d instanceof Date)) d = new Date(d);
  return _detailDateFormatter.format(d);
}

export function fmtAge(timestamp, now = Date.now()) {
  if (timestamp == null) return null;
  const sec = Math.floor((now - timestamp) / 1000);
  if (sec < 60) return 'たった今';
  if (sec < 3600) return `${Math.floor(sec / 60)}分前`;
  const h = Math.floor(sec / 3600);
  if (h < 24) return `${h}時間前`;
  return `${Math.floor(h / 24)}日前`;
}

export function isStale(timestamp, now = Date.now()) {
  if (timestamp == null) return false;
  return (now - timestamp) > 3600 * 1000;
}

export function uuid() {
  if (crypto.randomUUID) return crypto.randomUUID();
  // Fallback
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}
