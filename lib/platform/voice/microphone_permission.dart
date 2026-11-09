import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// The last answer the system gave, kept only to draw the settings row. It
/// never stops a later request: every launch and every room asks again.
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
