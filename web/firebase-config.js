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
self.MAFIA_FIREBASE = {
  apiKey: "AIzaSyB-lxaOSkSinZfVO2uMyF3iCR4kyG6Ds6A",
  authDomain: "mafia-master-e0cf5.firebaseapp.com",
  projectId: "mafia-master-e0cf5",
  storageBucket: "mafia-master-e0cf5.firebasestorage.app",
  messagingSenderId: "554819006072",
  appId: "1:554819006072:web:c01ac5c57432e05fe6878d",
  vapidKey: "BPAygnPoNoJ7MT9rzah0otgt2cXYfIoWZlmm9OD617L_pNs3WoVvFgnzfKs_AXCx0iuN1Iip6Pz9sQGXprhbfDg",
};
