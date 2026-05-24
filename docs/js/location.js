// 位置情報の共有コンテキスト (iOS版 LocationContext.swift 相当)
// 状態: { location, capturedAt, state }
// state: 'idle' | 'loading' | 'success' | 'denied' | 'failed'

const STATE = {
  location: null,
  capturedAt: null,
  state: 'idle',
  errorMessage: null,
};

const listeners = new Set();

function publish() {
  for (const fn of listeners) {
    try { fn(getState()); } catch (e) { console.error(e); }
  }
}

export function subscribe(fn) {
  listeners.add(fn);
  fn(getState());
  return () => listeners.delete(fn);
}

export function getState() {
  return { ...STATE };
}

export function isStale(now = Date.now()) {
  if (!STATE.capturedAt) return false;
  return (now - STATE.capturedAt) > 3600 * 1000;  // 1時間
}

// 1件分のジオロケ取得（Promiseベース）
function getCurrentPosition(timeoutMs = 20000) {
  return new Promise((resolve, reject) => {
    if (!('geolocation' in navigator)) {
      reject(new Error('このブラウザは位置情報に対応していません'));
      return;
    }
    navigator.geolocation.getCurrentPosition(
      resolve,
      reject,
      { enableHighAccuracy: false, maximumAge: 60000, timeout: timeoutMs }
    );
  });
}

// Nominatim 逆ジオコーディング (5秒タイムアウト)
async function reverseGeocode(lat, lon, timeoutMs = 5000) {
  const url = `https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lon}&format=json&accept-language=ja&zoom=18`;
  const controller = new AbortController();
  const tid = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal, headers: { 'Accept': 'application/json' } });
    if (!res.ok) return null;
    const data = await res.json();
    return data;
  } catch (e) {
    console.warn('reverseGeocode failed:', e.message);
    return null;
  } finally {
    clearTimeout(tid);
  }
}

// Nominatim レスポンスから 住所/POI を抽出
function extractAddress(data) {
  if (!data?.address) return null;
  const a = data.address;
  const parts = [];
  if (a.state || a.province) parts.push(a.state || a.province);
  if (a.city || a.town || a.village || a.county) parts.push(a.city || a.town || a.village || a.county);
  if (a.suburb || a.neighbourhood || a.quarter) parts.push(a.suburb || a.neighbourhood || a.quarter);
  if (a.road) parts.push(a.road);
  if (a.house_number) parts.push(a.house_number);
  return parts.length ? parts.join('') : null;
}

function extractPlaceName(data, address) {
  if (!data) return null;
  // POI候補: amenity, building, shop, leisure 等の場合は name を使う
  const cls = data.class;
  const t = data.type;
  if (data.name && cls && cls !== 'place' && cls !== 'highway' && cls !== 'boundary') {
    return data.name;
  }
  // display_name の最初の要素が住所と違うならPOIとして採用
  if (data.display_name && address) {
    const head = data.display_name.split(',')[0].trim();
    if (head && head !== address && !address.includes(head) && !/^\d/.test(head)) {
      return head;
    }
  }
  return null;
}

let inFlight = null;

// 位置情報を取得して状態を更新
export async function refresh() {
  if (inFlight) return inFlight;
  STATE.state = 'loading';
  STATE.errorMessage = null;
  publish();

  inFlight = (async () => {
    try {
      const pos = await getCurrentPosition();
      const { latitude, longitude, accuracy } = pos.coords;
      // 座標は即取れた → success にする (住所は後追い)
      STATE.location = {
        latitude,
        longitude,
        horizontalAccuracy: accuracy ?? 0,
        placeName: null,
        address: null,
        areasOfInterest: [],
        capturedAt: Date.now(),
      };
      STATE.capturedAt = Date.now();
      STATE.state = 'success';
      publish();
      // 住所は別途
      const geo = await reverseGeocode(latitude, longitude);
      if (geo) {
        const address = extractAddress(geo);
        const placeName = extractPlaceName(geo, address);
        STATE.location = {
          ...STATE.location,
          address,
          placeName,
          areasOfInterest: [],
        };
        publish();
      }
    } catch (e) {
      // GeolocationPositionError
      if (e && e.code === 1) {
        STATE.state = 'denied';
        STATE.errorMessage = '位置情報の使用が許可されていません';
      } else if (STATE.location) {
        // 既存位置を保持
        STATE.state = 'failed';
        STATE.errorMessage = '更新失敗、前回の位置を保持';
      } else {
        STATE.state = 'failed';
        STATE.errorMessage = e?.message || '位置情報を取得できませんでした';
      }
      publish();
    } finally {
      inFlight = null;
    }
  })();
  return inFlight;
}

// 既存位置があるならそれを使い、無いか古ければ再取得
export function refreshIfNeeded() {
  if (!STATE.location || isStale()) {
    return refresh();
  }
  return Promise.resolve();
}
