import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last answer the system gave, kept only to draw the settings row. It
/// never stops a later request: every room entry asks again.
const microphoneAllowedKey = 'mafia.microphone.allowed.v1';

enum MicrophoneStatus {
  granted,

  /// Refused, and the system will show its dialog again when asked.
  denied,

  /// Refused for good: only the phone's settings can change it (native).
  blocked,

  /// No microphone here (a desktop build, a test).
  unsupported,
}

/// The system's microphone question, behind one seam so widget tests can
/// answer it.
abstract class MicrophoneAccess {
  bool get supported;

  /// The current answer, without showing anything.
  Future<MicrophoneStatus> status();

  /// Shows the system dialog when the system still can.
  Future<MicrophoneStatus> request();

  /// Opens this app's page in the phone's settings. False where there is no
  /// such page (the web).
  Future<bool> openSettings();
}

class DeviceMicrophoneAccess implements MicrophoneAccess {
  const DeviceMicrophoneAccess();

  bool get _native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get supported => kIsWeb || _native;

  @override
  Future<MicrophoneStatus> status() async {
    if (!supported) return MicrophoneStatus.unsupported;
    if (kIsWeb) return MicrophoneStatus.denied;
    try {
      return _map(await Permission.microphone.status);
    } catch (_) {
      return MicrophoneStatus.denied;
    }
  }

  @override
  Future<MicrophoneStatus> request() async {
    if (!supported) return MicrophoneStatus.unsupported;
    if (kIsWeb) return _probeWeb();
    try {
      return _map(await Permission.microphone.request());
    } catch (_) {
      return MicrophoneStatus.denied;
    }
  }

  @override
  Future<bool> openSettings() async {
    if (!_native) return false;
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }

  static MicrophoneStatus _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return MicrophoneStatus.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return MicrophoneStatus.blocked;
    return MicrophoneStatus.denied;
  }

  /// The browser asks on `getUserMedia`; the tracks are stopped at once, the
  /// room acquires its own.
  static Future<MicrophoneStatus> _probeWeb() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': false,
      });
      final allowed = stream.getAudioTracks().isNotEmpty;
      for (final track in stream.getTracks()) {
        track.stop();
      }
      await stream.dispose();
      return allowed ? MicrophoneStatus.granted : MicrophoneStatus.denied;
    } catch (_) {
      return MicrophoneStatus.denied;
    }
  }
}

final microphoneAccessProvider = Provider<MicrophoneAccess>(
  (_) => const DeviceMicrophoneAccess(),
);

/// Asks for the microphone at the one moment it is needed: the player just
/// chose to enter an online room, where the voice is.
///
/// It used to be asked the moment the game opened, and again on every launch
/// while the answer was not yes, which Google Play's audio policy flags: a
/// player who only ever plays at one table was asked for a microphone the game
/// never used. Now the system's own dialog appears on the tap that enters a
/// room, with nothing of ours in front of it, and only while the phone can
/// still ask; a microphone blocked for good is left to the lobby's card.
///
/// The web is skipped: the browser asks on the room's own `getUserMedia`, and
/// asking here as well would show its prompt twice. Never throws, never blocks
/// the entry.
Future<void> askMicrophoneForRoom(MicrophoneAccess access) async {
  if (kIsWeb) return;
  try {
    if (!access.supported) return;
    var status = await access.status();
    if (status == MicrophoneStatus.denied) status = await access.request();
    if (status == MicrophoneStatus.unsupported) return;
    await (await SharedPreferences.getInstance()).setBool(
      microphoneAllowedKey,
      status == MicrophoneStatus.granted,
    );
  } catch (_) {
    // The voice engine asks again when it starts; an entry never fails over a
    // dialog.
  }
}
