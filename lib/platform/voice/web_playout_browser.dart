import 'dart:js_interop';
import 'dart:async';
import 'package:web/web.dart' as web;

final _blocked = <int>{};
JSFunction? _gesture;
web.HTMLAudioElement? _prime;

/// Uses the room-entry tap to authorize later remote WebRTC audio playback.
/// The actual remote tracks remain owned by flutter_webrtc renderers; this
/// element only bridges the browser's user-activation requirement across the
/// asynchronous join and signalling work.
Future<void> primeWebPlayout() async {
  final element = _prime ??=
      (web.document.createElement('audio') as web.HTMLAudioElement)
        ..src =
            'data:audio/wav;base64,UklGRiQAAABXQVZFZm10IBAAAAABAAEARKwAAESsAAABAAgAZGF0YQAAAAAA';
  element.volume = 0.0001;
  element.muted = false;
  try {
    await element.play().toDart;
  } catch (_) {
    // The normal per-renderer gesture retry remains the fallback.
  }
}

void forgetWebPlayout(int textureId) {
  _blocked.remove(textureId);
  if (_blocked.isEmpty && _gesture != null) {
    web.document.removeEventListener('pointerdown', _gesture, true.toJS);
    web.document.removeEventListener('keydown', _gesture, true.toJS);
    _gesture = null;
  }
}

void _retryOnGesture(int textureId) {
  _blocked.add(textureId);
  if (_gesture != null) return;
  _gesture = ((web.Event _) {
    // Invoke play synchronously inside the trusted gesture, before any await.
    // Never change track.enabled or element.muted: the game policy owns both.
    for (final id in _blocked.toList()) {
      unawaited(resumeWebPlayout(id));
    }
  }).toJS;
  web.document.addEventListener('pointerdown', _gesture, true.toJS);
  web.document.addEventListener('keydown', _gesture, true.toJS);
}

/// The renderer creates this element; ownership and disposal stay with it.
/// Awaiting play() distinguishes attached media from autoplay actually allowed.
Future<bool> resumeWebPlayout(int textureId) async {
  final found = web.document.getElementById(
    'audio_RTCVideoRenderer-$textureId',
  );
  // Asked of the DOM, not of Dart. An `is` test against a JS interop type is
  // always true and checks nothing — it compiles to nothing and, under wasm,
  // is a lint error — so a missing or renamed element would sail past it and
  // fail later at play(), where the diagnostic would blame autoplay policy for
  // an element that was never there.
  if (found == null || found.tagName.toLowerCase() != 'audio') {
    forgetWebPlayout(textureId);
    return false;
  }
  final element = found as web.HTMLAudioElement;
  try {
    await element.play().toDart;
    forgetWebPlayout(textureId);
    return !element.paused;
  } catch (_) {
    _retryOnGesture(textureId);
    return false;
  }
}
