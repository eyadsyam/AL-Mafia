# Android permissions — release disclosure

- INTERNET / ACCESS_NETWORK_STATE: online matches and connectivity.
- WAKE_LOCK: media playback may keep the device awake while in use.
- RECORD_AUDIO: optional live voice; denial leaves gameplay available. No recording feature.
- MODIFY_AUDIO_SETTINGS: communication audio routing.
- BLUETOOTH_CONNECT: optional headset routing on Android 12+.
- Legacy BLUETOOTH, if present in merged dependencies: headset routing on older Android.
- AndroidX DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION: internal broadcast protection.

Voice is encrypted in transit and can connect directly or through a relay. Do not claim audio never reaches a relay. The game does not store voice recordings; service providers process connection metadata. Verify the final parsed APK permission list before upload.

Microphone and Bluetooth hardware are explicitly optional. Release backup is disabled to avoid restoring anonymous session credentials onto another device. Cleartext networking is disabled.
