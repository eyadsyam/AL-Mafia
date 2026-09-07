# Permissions declaration — Play Console

## RECORD_AUDIO — the one line for the console

> Voice chat between players during an online match. Audio is transmitted
> peer-to-peer in real time and is never recorded, stored, or sent to our
> servers. The permission is requested only when a player joins an online room,
> and every feature of the game works without it.

*(279 characters. Play's justification field allows more, but the reviewer is
reading dozens of these — the shorter and more specific it is, the faster it
clears.)*

### Arabic, if the console asks for the default locale

> دردشة صوتية بين اللاعبين أثناء المباراة أونلاين. الصوت بيتنقل مباشرة بين
> أجهزة اللاعبين ومش بيتسجّل ولا بيتخزّن ولا بيوصل لأي سيرفر عندنا. الإذن
> بيُطلب بس لما اللاعب يدخل أوضة أونلاين، واللعبة كلها شغّالة من غيره.

### If a reviewer pushes back

Three facts, each checkable:

1. **It is requested late, not at launch.** Nothing asks for the microphone
   until a player is inside an online room. The whole offline game — which is
   the app's primary mode — never asks at all.
2. **Refusal is not degraded, it is supported.** A match completes normally
   with the permission denied, with voice muted, or with voice entirely broken.
   This is a standing constraint in the codebase, not a claim: see
   `docs/10-online-architecture.md` §1.2 and the "voice fully disabled"
   acceptance test.
3. **Nothing is recorded.** The audio path is `flutter_webrtc` peer-to-peer.
   There is no recording API in the app, no audio file is ever written, and no
   audio byte reaches Supabase. What passes through the server is SDP and ICE
   candidates — connection setup — which are deleted within one hour.

---

## The full permission set, and why each is there

| Permission | Declared by | Requested on | Why |
|---|---|---|---|
| `INTERNET` | us | all versions | Online play. Without it every Supabase call fails at the socket. |
| `ACCESS_NETWORK_STATE` | us | all versions | So the connection banner can tell "this phone has no network" from "the server did not answer". They need different sentences. |
| `RECORD_AUDIO` | us | all versions | In-match voice, as above. The only runtime prompt the app ever raises. |
| `MODIFY_AUDIO_SETTINGS` | `flutter_webrtc` | all versions | Switching the audio route and mode for a call. Normal permission — no prompt. |
| `BLUETOOTH` | `flutter_webrtc` | **`maxSdkVersion="30"`** | Routing that call to a Bluetooth headset on Android 11 and below. Not requested at all on Android 12+. Normal permission — no prompt. |

Plus `com.mafiamaster.mafia_master.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`,
which AndroidX defines and holds itself so its own runtime-registered receivers
are not exported. It grants nothing and is invisible in the store listing.

**There is no `CAMERA` permission.** `flutter_webrtc` ships one for video calls;
this app never constructs a video track, so the merger does not pull it in.

**There is no `DUMP` permission either**, although a raw string search of the
binary manifest finds the word — which is worth writing down, because it cost
an afternoon once. The match is
`android:permission="android.permission.DUMP"` on `ProfileInstallerReceiver`
(from `androidx.profileinstaller`, pulled in by Flutter). That attribute
*restricts* who may send that broadcast to callers already holding DUMP. It is
a guard, not a request, and removing it with `tools:node="remove"` does nothing
except add a line to the manifest that a future reader has to work out.

### How to check, correctly

Read the parsed manifest, not the bytes:

```bash
"$LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt2" dump permissions     build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Verified against `app-arm64-v8a-release.apk`, 4 September 2026:

```
uses-permission: name='android.permission.INTERNET'
uses-permission: name='android.permission.ACCESS_NETWORK_STATE'
uses-permission: name='android.permission.RECORD_AUDIO'
uses-permission: name='com.mafiamaster...DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION'
uses-permission: name='android.permission.BLUETOOTH' maxSdkVersion='30'
uses-permission: name='android.permission.MODIFY_AUDIO_SETTINGS'
```
