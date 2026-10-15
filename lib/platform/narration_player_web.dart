import 'dart:async';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'narration_controller.dart';

NarrationPlayer createBrowserNarrationPlayer() => BrowserNarrationPlayer();

/// The Stories narrator in a browser: one plain `<audio>`, started inside the
/// tap that asked for it.
///
/// Not the audio package's web player: that one routes every element through
/// its own Web Audio context and calls `play()` only after the file has
/// loaded and the context has resumed — outside the tap. Safari leaves a
/// context resumed outside a gesture suspended, and a browser whose audio
/// device hiccups never resumes it, so the narrator stayed silent with its
/// button saying «شغّل». A media element needs neither.
class BrowserNarrationPlayer implements NarrationPlayer {
  BrowserNarrationPlayer() {
    _audio.preload = 'none';
    _subs = [
      web.EventStreamProviders.timeUpdateEvent
          .forTarget(_audio)
          .listen((_) => _positions.add(_at(_audio.currentTime))),
      web.EventStreamProviders.durationChangeEvent.forTarget(_audio).listen((
        _,
      ) {
        final seconds = _audio.duration;
        if (seconds.isFinite && seconds > 0) _durations.add(_at(seconds));
      }),
      web.EventStreamProviders.endedEvent
          .forTarget(_audio)
          .listen((_) => _done.add(null)),
    ];
  }

  final web.HTMLAudioElement _audio = web.HTMLAudioElement();
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _done = StreamController<void>.broadcast();
  late final List<StreamSubscription<web.Event>> _subs;

  static Duration _at(num seconds) =>
      Duration(milliseconds: (seconds * 1000).round());

  @override
  Stream<Duration> get positions => _positions.stream;

  @override
  Stream<Duration> get durations => _durations.stream;

  @override
  Stream<void> get completions => _done.stream;

  /// [assetKey] is the key without its `assets/` prefix, as the controller
  /// hands it to every player.
  @override
  Future<void> start(String assetKey) async {
    final url = Uri.base
        .resolve(ui_web.assetManager.getAssetUrl('assets/$assetKey'))
        .toString();
    if (_audio.src != url) _audio.src = url;
    _audio.currentTime = 0;
    // Synchronously inside the tap: this call is the user gesture's.
    await _audio.play().toDart;
  }

  @override
  Future<void> pause() async => _audio.pause();

  @override
  Future<void> resume() async => _audio.play().toDart;

  @override
  Future<void> seek(Duration to) async {
    _audio.currentTime = to.inMilliseconds / 1000;
    _positions.add(to);
  }

  @override
  Future<void> stop() async {
    _audio.pause();
    if (_audio.src.isNotEmpty) _audio.currentTime = 0;
  }

  @override
  Future<void> dispose() async {
    _audio.pause();
    for (final sub in _subs) {
      await sub.cancel();
    }
    _audio
      ..removeAttribute('src')
      ..load();
    await _positions.close();
    await _durations.close();
    await _done.close();
  }
}
