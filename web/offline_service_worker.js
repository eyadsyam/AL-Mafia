'use strict';

// The site's offline cache.
//
// Flutter used to generate a caching service worker and no longer does — the
// file it writes now is a stub whose only job is to unregister the old one, so
// a build ships with no offline story at all. This replaces that file at build
// time (see `tool/build_web.ps1`) and keeps Flutter's own registration, which
// already reloads the script on every deploy.
//
// It exists for one thing above all: the explanation film. A group sitting
// together with no connection should still be able to watch it, and a group
// with a slow one should not watch it stutter. It is fetched once, in full, and
// answered from here every time after.
//
// VERSION is stamped per build. Changing it changes this file, which is what
// makes the browser install a new worker, which is what drops the old cache.
// Without that, cache-first would pin a deployed version forever.
const VERSION = '__BUILD_VERSION__';
const CACHE = `almafia-${VERSION}`;

// The shell. Everything else arrives through the fetch handler as the app asks
// for it, which is how the cache stays to what this build uses rather than the
// 60 MB of renderer variants a build directory contains.
const PRECACHE = ['./', './flutter_bootstrap.js', './main.dart.js'];

// The film (9.8 MB) lives in a cache of its own that a deploy does not drop.
// It used to sit in the versioned cache, so every deploy made every returning
// visitor download it again in the background, on mobile data, whether they
// ever opened it or not. Bump FILM_CACHE only when the film itself changes.
const FILM = './assets/assets/video/onboarding.mp4';
const FILM_CACHE = 'almafia-film-1';

// A visitor who asked their browser to save data does not get 9.8 MB fetched
// behind their back; the film streams when they open it, as any video does.
function savingData() {
  return Boolean(self.navigator && self.navigator.connection &&
      self.navigator.connection.saveData);
}

async function precache(cacheName, path, onlyIfMissing) {
  const cache = await caches.open(cacheName);
  const url = new URL(path, self.registration.scope);
  if (onlyIfMissing && await cache.match(url)) return;
  try {
    // `reload` on purpose. Assets are served immutable for a year, so a
    // plain fetch here would hand a new build the previous build's files
    // out of the HTTP cache and never notice.
    const response = await fetch(new Request(url, { cache: 'reload' }));
    if (response.ok) await cache.put(url, response);
  } catch (error) {
    // A precache miss is not a failed install: the app still works, it
    // just pays for the file the first time it is asked for.
  }
}

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    await Promise.all(PRECACHE.map((path) => precache(CACHE, path, false)));
    if (!savingData()) await precache(FILM_CACHE, FILM, true);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name !== CACHE && name !== FILM_CACHE) await caches.delete(name);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  // Range requests belong to media elements, and the Cache API has no concept
  // of a partial response — answering one with a whole file is how a seek bar
  // stops working. Left to the network.
  if (request.headers.has('range')) return;

  // A navigation is the app itself, so the deployed version wins whenever
  // there is a network to ask. Every path on this site is served the same
  // index.html, which is why the fallback is the shell rather than the path.
  if (request.mode === 'navigate') {
    event.respondWith((async () => {
      try {
        return await fetch(request);
      } catch (error) {
        const cache = await caches.open(CACHE);
        const shell = await cache.match(new URL('./', self.registration.scope));
        return shell ?? Response.error();
      }
    })());
    return;
  }

  // Executable code must see a deploy on the first online visit. The previous
  // cached copy remains available when the connection is gone.
  if (url.pathname.endsWith('/flutter_bootstrap.js') ||
      url.pathname.endsWith('/main.dart.js')) {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      try {
        const response = await fetch(new Request(request, {cache: 'reload'}));
        if (response.ok && response.type === 'basic') {
          await cache.put(request, response.clone());
        }
        return response;
      } catch (_) {
        return (await cache.match(request, {ignoreSearch: true})) ?? Response.error();
      }
    })());
    return;
  }

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(request) ??
        await (await caches.open(FILM_CACHE)).match(request);
    if (hit) return hit;
    try {
      const response = await fetch(request);
      // Opaque cross-origin responses and error pages are not worth keeping;
      // a cached 404 outlives the deploy that fixes it.
      if (response.ok && response.type === 'basic') {
        cache.put(request, response.clone());
      }
      return response;
    } catch (error) {
      return Response.error();
    }
  })());
});
