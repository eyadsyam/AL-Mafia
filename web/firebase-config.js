// Firebase web push configuration (docs/PUSH-SETUP.md, step 5).
//
// Left as null, push on the web is simply off: invites still arrive inside
// the app. The owner pastes the web app's config object from the Firebase
// console here, plus the Web Push certificate key pair's public key as
// `vapidKey`. These values are public by design (they identify the project,
// they grant nothing); the server key is never here.
//
// Example shape:
// self.MAFIA_FIREBASE = {
//   apiKey: "…", authDomain: "….firebaseapp.com", projectId: "…",
//   messagingSenderId: "…", appId: "1:…:web:…", vapidKey: "B…",
// };
self.MAFIA_FIREBASE = null;
