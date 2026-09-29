// Invite notifications on the web while the site is closed or hidden.
//
// Separate from `sw.js` (the offline cache, scope "/"): Firebase registers
// this file under its own scope, so the build-stamped offline worker is
// untouched. Config comes from firebase-config.js; while that is null this
// worker does nothing at all.
//
// The notification itself (title, body, icon, badge, requireInteraction,
// vibrate, and the link to /join/<CODE>) is built by the server
// (supabase/functions/_shared/push.ts) and shown by the Firebase SDK. The
// payload names only the room code, the sender's name and handle and the
// invite id (Doc 05).
importScripts('firebase-config.js');

if (self.MAFIA_FIREBASE) {
  importScripts(
    'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
    'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
  );
  const { vapidKey, ...config } = self.MAFIA_FIREBASE;
  firebase.initializeApp(config);
  firebase.messaging();
}

// A click on our notification focuses an open tab on the join link, or opens
// one. The Firebase SDK does this too for its own notifications; this covers
// a browser that hands the click to us instead.
self.addEventListener('notificationclick', (event) => {
  const data = (event.notification && event.notification.data) || {};
  const fcm = data.FCM_MSG || {};
  const code = (fcm.data && fcm.data.code) || data.code;
  const link = data.link || (fcm.notification && fcm.notification.click_action) ||
    (/^[A-Z0-9]{6}$/.test(code || '') ? `/join/${code}` : '/');
  event.notification.close();
  event.waitUntil((async () => {
    const url = new URL(link, self.location.origin).href;
    const tabs = await clients.matchAll({ type: 'window', includeUncontrolled: true });
    for (const tab of tabs) {
      if (new URL(tab.url).origin === self.location.origin && 'focus' in tab) {
        await tab.focus();
        if ('navigate' in tab) await tab.navigate(url);
        return;
      }
    }
    await clients.openWindow(url);
  })());
});
