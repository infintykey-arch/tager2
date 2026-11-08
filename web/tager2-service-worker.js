'use strict';

const CACHE_NAME = 'tager2-local-v1';
const CACHE_PREFIX = 'tager2-local-';

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const scope = self.registration.scope;
    const manifestUrl = new URL('precache-manifest.json', scope);
    const manifestResponse = await fetch(manifestUrl, { cache: 'no-store' });
    if (!manifestResponse.ok) {
      throw new Error(`تعذر تحميل قائمة ملفات العمل المحلي: ${manifestResponse.status}`);
    }

    const paths = await manifestResponse.json();
    const cache = await caches.open(CACHE_NAME);
    const rootUrl = new URL('./', scope);
    const indexResponse = await fetch(new URL('index.html', scope), { cache: 'no-store' });
    if (!indexResponse.ok) {
      throw new Error(`تعذر تخزين صفحة التطبيق: ${indexResponse.status}`);
    }
    await cache.put(rootUrl, indexResponse.clone());

    for (let start = 0; start < paths.length; start += 32) {
      const batch = paths.slice(start, start + 32).map((path) => new URL(path, scope).href);
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
