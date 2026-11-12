'use strict';

const CACHE_NAME = 'tager2-local-v3';
const CACHE_PREFIX = 'tager2-local-';

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const scope = self.registration.scope;
    const manifestUrl = new URL('precache-manifest.json', scope);
    const manifestResponse = await fetch(manifestUrl, { cache: 'no-store' });
    if (!manifestResponse.ok) {
      throw new Error(`تعذر تحميل قائمة ملفات العمل المحلي: ${manifestResponse.status}`);
    }

    const manifest = await manifestResponse.json();
    // Accept the old array shape during local upgrades, but new builds list only
    // the small application shell. Feature assets are cached on first use.
    const corePaths = Array.isArray(manifest) ? manifest : manifest.core;
    if (!Array.isArray(corePaths)) {
      throw new Error('قائمة ملفات التطبيق الأساسية غير صالحة.');
    }

    const cache = await caches.open(CACHE_NAME);
    const rootUrl = new URL('./', scope);
    const indexResponse = await fetch(new URL('index.html', scope), { cache: 'no-store' });
    if (!indexResponse.ok) {
      throw new Error(`تعذر تخزين صفحة التطبيق: ${indexResponse.status}`);
    }
    await cache.put(rootUrl, indexResponse.clone());

    for (let start = 0; start < corePaths.length; start += 16) {
      const batch = corePaths.slice(start, start + 16).map((path) => new URL(path, scope).href);
      await cache.addAll(batch);
    }
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names
      .filter((name) => name.startsWith(CACHE_PREFIX) && name !== CACHE_NAME)
      .map((name) => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('message', (event) => {
  if (!event.data || event.data.type !== 'cache-startup-resources') return;
  const requested = Array.isArray(event.data.urls) ? event.data.urls : [];
  event.waitUntil((async () => {
    const scope = new URL(self.registration.scope);
    const cache = await caches.open(CACHE_NAME);
    const urls = [...new Set(requested.map((value) => {
      try {
        const url = new URL(value, scope);
        if (url.origin !== scope.origin || !url.pathname.startsWith(scope.pathname)) return null;
        if (url.pathname.endsWith('/tager2-service-worker.js') ||
            url.pathname.endsWith('/precache-manifest.json')) return null;
        return url.href;
      } catch (_) {
        return null;
      }
    }).filter(Boolean))];

    // The browser already fetched these resources to render the first visit.
    // force-cache reuses the browser's HTTP cache where available; only this
    // small observed startup set is copied into Cache Storage, not every asset.
    await Promise.all(urls.map(async (url) => {
      if (await cache.match(url, { ignoreSearch: true })) return;
      try {
        const response = await fetch(new Request(url, { cache: 'force-cache' }));
        if (response.ok && response.type !== 'opaque') {
          await cache.put(url, response.clone());
        }
      } catch (_) {
        // A failed background cache fill must not disrupt the visible app.
      }
    }));
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE_NAME);
    const cached = await cache.match(request, { ignoreSearch: true });
    if (cached) return cached;

    try {
      const response = await fetch(request);
      if (response.ok) await cache.put(request, response.clone());
      return response;
    } catch (error) {
      if (request.mode === 'navigate') {
        const offlinePage = await cache.match(new URL('index.html', self.registration.scope));
        if (offlinePage) return offlinePage;
      }
      throw error;
    }
  })());
});
