{{flutter_js}}
{{flutter_build_config}}

// A hand-written bootstrap, for one reason: the service worker.
//
// The generated one passes `serviceWorkerSettings` to the loader, and that path
// is deprecated — the loader now registers a worker only when the browser
// already has one, so a first-time visitor gets none at all. What it would
// register is Flutter's own `flutter_service_worker.js`, which is a stub that
// unregisters itself; the framework dropped offline caching.
//
// So the loader is asked for nothing, and `sw.js` is registered here instead.
// That is the site's own cache: the explanation film and the app shell, so a
// second visit costs no network and works without one.
_flutter.loader.load({config: {canvasKitBaseUrl: 'canvaskit/'}});

if ('serviceWorker' in navigator) {
  // After load: the worker's first act is to download a 9 MB film, and it must
  // not compete with the app the visitor is waiting for.
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  });
}
