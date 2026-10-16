import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'audio_backend.dart';
import 'cue_slots.dart';

AudioBackend createBrowserAudioBackend() => BrowserAudioBackend();

/// The web's backend: a few media elements and **one** Web Audio context.
///
/// ## Why not the audio package on the web
///
/// The audio package's web plugin gives every player its own element *and* its own
/// AudioContext, and the warm-up made a player per cue and per narrator line:
/// about 130 of each at start-up (measured 2026-10-15). Every context is an
/// audio render thread and a device stream; Chrome passes its own player cap
/// and Safari limits contexts outright. In a browser whose audio device gave
/// out under that, nothing played afterwards — the score, the cues and the
/// Stories narrator all went silent. And each of its players resumed its
/// context only after loading, outside the tap, which Safari refuses.
///
/// So here: [slots] cue players taken in turn ([CueSlots]), one loop player
/// for the score, all routed through one context whose gains carry the
/// volume (Safari ignores a media element's own volume, and the score's 0.5
/// is a designed level). Every `play()` happens inside the call that asked
/// for it, so a tap's gesture is the sound's; [unlock] resumes the context
/// and releases each player on the first tap.
///
/// What plays and when is unchanged: the director decides, as on a phone.
class BrowserAudioBackend implements AudioBackend {
  /// Enough for every cue that can overlap another (a drum under a bed under
  /// a tick) with room to spare; a ninth at once cuts the one started
  /// longest ago.
  static const slots = 8;

  final CueSlots _slots = CueSlots(slots);
  final List<web.HTMLAudioElement> _cues = [];
  final List<web.GainNode?> _gains = [];
  final Set<web.HTMLAudioElement> _released = {};

  web.AudioContext? _context;
  bool _noContext = false;

  web.HTMLAudioElement? _loop;
  web.GainNode? _loopGain;
  String? _loopKey;
  bool _loopBlocked = false;

  /// Bumped by every [stopLoop]: a start that a stop overtook (a mute or
  /// the app going to the background mid-start) never plays.
  int _loopGeneration = 0;

  static String _url(String key) => Uri.base
      .resolve(ui_web.assetManager.getAssetUrl('assets/$key'))
      .toString();

  /// The one context, made on first need. Null where the browser has none
  /// (players then sound on their own, at the element's volume).
  web.AudioContext? get _ctx {
    if (_context != null || _noContext) return _context;
    try {
      _context = web.AudioContext();
    } catch (error) {
      _noContext = true;
      debugPrint('audio: no Web Audio here, players sound alone — $error');
    }
    return _context;
  }

  web.GainNode? _route(web.HTMLAudioElement element) {
    final ctx = _ctx;
    if (ctx == null) return null;
    try {
      final gain = ctx.createGain();
      ctx.createMediaElementSource(element).connect(gain);
      gain.connect(ctx.destination);
      return gain;
    } catch (error) {
      debugPrint('audio: could not route a player — $error');
      return null;
    }
  }

  void _resume() {
    final ctx = _context;
    if (ctx == null || ctx.state == 'running' || ctx.state == 'closed') return;
    ctx.resume().toDart.ignore();
  }

  void _setVolume(web.HTMLAudioElement element, web.GainNode? gain, double v) {
    final volume = v.clamp(0.0, 1.0).toDouble();
    if (gain != null) {
      gain.gain.value = volume;
    } else {
      element.volume = volume;
    }
  }

  void _ensurePlayers() {
    while (_cues.length < slots) {
      final element = web.HTMLAudioElement()..preload = 'auto';
      _cues.add(element);
      _gains.add(_route(element));
    }
  }

  /// No per-clip decode ahead: a media element plays a clip once it has it,
  /// so a first cue is a few milliseconds late, never silent. The first
  /// [slots] keys (the director lists its short cues first) are opened ahead
  /// on the players; the rest, narrator lines mostly, open when played.
  @override
  Future<void> warmUp(Iterable<String> assetKeys) async {
    try {
      _ensurePlayers();
      for (final key in assetKeys) {
        final slot = _slots.preload(key);
        if (slot == null) break;
        _cues[slot].src = _url(key);
      }
    } catch (error) {
      debugPrint('audio: could not prepare the players — $error');
    }
  }

  @override
  Future<void> play(
    String assetKey, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    try {
      _ensurePlayers();
      _resume();
      final (:slot, :load) = _slots.take(
        assetKey,
        sounding: (i) => !_cues[i].paused && !_cues[i].ended,
      );
      final element = _cues[slot];
      if (load) {
        element.src = _url(assetKey);
      } else {
        element.pause();
        element.currentTime = 0;
      }
      _setVolume(element, _gains[slot], volume);
      element.playbackRate = rate;
      // Inside the caller's call: a tap's gesture is this sound's.
      await element.play().toDart;
    } catch (error) {
      // Refused (no gesture yet), interrupted by a stop, or a missing file:
      // the game goes on without this sound.
      debugPrint('audio: could not play $assetKey — $error');
    }
  }

  @override
  Future<void> stopAll() async {
    for (final element in _cues) {
      try {
        element.pause();
        if (element.src.isNotEmpty) element.currentTime = 0;
      } catch (_) {
        // Already trying to make it quiet.
      }
    }
  }

  @override
  Future<void> startLoop(String assetKey, {double volume = 1.0}) async {
    final playing = _loop;
    if (_loopKey == assetKey && playing != null) {
      _setVolume(playing, _loopGain, volume);
      return;
    }
    final stopping = stopLoop();
    final generation = _loopGeneration;
    await stopping;
    if (generation != _loopGeneration) return;
    web.HTMLAudioElement? started;
    try {
      final element = web.HTMLAudioElement()
        ..preload = 'auto'
        ..loop = true
        ..src = _url(assetKey);
      started = element;
      _loop = element;
      _loopKey = assetKey;
      _loopGain = _route(element);
      _setVolume(element, _loopGain, volume);
      _loopBlocked = false;
      _resume();
      await element.play().toDart;
      if (generation != _loopGeneration) _silence(element);
    } catch (error) {
      // The browser's autoplay policy before a first tap; [unlock] retries.
      if (generation == _loopGeneration && identical(_loop, started)) {
        _loopBlocked = true;
      }
      debugPrint('audio: could not start loop $assetKey — $error');
    }
  }

  static void _silence(web.HTMLAudioElement element) {
    try {
      element
        ..pause()
        ..removeAttribute('src')
        ..load();
    } catch (_) {
      // Already trying to make it quiet.
    }
  }

  @override
  Future<void> stopLoop() async {
    _loopGeneration++;
    final element = _loop;
    _loop = null;
    _loopKey = null;
    _loopGain?.disconnect();
    _loopGain = null;
    _loopBlocked = false;
    if (element != null) _silence(element);
  }

  /// Every tap: the context resumes (from 'suspended', or 'interrupted'
  /// after a call on an iPhone — every tap tries again until it runs), each
  /// player that has a clip is released for later sounds no tap starts (a
  /// timer's end; Safari grants that per element, to a load() inside a
  /// gesture), and a score the browser refused starts now — all inside the
  /// tap. A player that gets its first clip later is released on the next
  /// tap.
  @override
  Future<void> unlock() async {
    try {
      _ensurePlayers();
      _resume();
      for (final element in _cues) {
        if (_released.contains(element) || element.src.isEmpty) continue;
        if (!element.paused) {
          _released.add(element); // sounding already: it was allowed
          continue;
        }
        element.load();
        _released.add(element);
      }
      final loop = _loop;
      if (loop != null && (_loopBlocked || loop.paused)) {
        _loopBlocked = false;
        await loop.play().toDart;
      }
    } catch (error) {
      if (_loop != null) _loopBlocked = true;
      debugPrint('audio: unlock — $error');
    }
  }

  @override
  Future<void> dispose() async {
    await stopLoop();
    _cues.forEach(_silence);
    _cues.clear();
    _gains.clear();
    final ctx = _context;
    _context = null;
    if (ctx != null && ctx.state != 'closed') ctx.close().toDart.ignore();
  }
}
