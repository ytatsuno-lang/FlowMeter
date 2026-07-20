// FlowMeter PWA Service Worker
// app shell キャッシュ + Nominatim はネットワーク優先

const CACHE_VERSION = 'flowmeter-v10';
const APP_SHELL = [
  './',
  './index.html',
  './manifest.json',
  './css/style.css',
  './js/app.js',
  './js/meter.js',
  './js/tank.js',
  './js/history.js',
  './js/storage.js',
  './js/location.js',
  './js/formula.js',
  './js/format.js',
  './icons/icon-180.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  'https://cdn.jsdelivr.net/npm/idb-keyval@6/dist/umd.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Nominatim はキャッシュしない（常にネットワーク）
  if (url.hostname.includes('nominatim.openstreetmap.org')) {
    return;  // ブラウザのデフォルト fetch に任せる
  }

  // GET 以外はそのまま
  if (event.request.method !== 'GET') return;

  // Cache First で app shell を返す
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((res) => {
        // 同一オリジン or CDN のみキャッシュ追加
        if (url.origin === self.location.origin || url.hostname === 'cdn.jsdelivr.net') {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then(c => c.put(event.request, copy));
        }
        return res;
      }).catch(() => {
        // オフラインフォールバック
        if (event.request.mode === 'navigate') {
          return caches.match('./index.html');
        }
      });
    })
  );
});
