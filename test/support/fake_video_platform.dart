import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video player that exists, so that a widget test can reach the states only
/// a working player has.
///
/// Under `flutter test` there is no video plugin at all: `initialize()` throws
/// `MissingPluginException` and the screen falls straight to its "could not
/// load" branch. That branch is worth testing and it is not the interesting
/// one — the failure the player actually meets is a *browser* refusing to start
/// playback on a film that loaded perfectly, which is only reachable once the
/// controller says it is ready.
class FakeVideoPlatform extends VideoPlayerPlatform
    with MockPlatformInterfaceMixin {
  FakeVideoPlatform({this.refusePlay = false});

  /// What a browser's autoplay policy looks like from here.
  bool refusePlay;

  int playCalls = 0;
  int pauseCalls = 0;
  bool disposed = false;

  // Single-subscription on purpose: it buffers, so the "initialized" event
  // survives the gap between creating the player and listening to it.
  final _events = StreamController<VideoEvent>();

  /// Installs this as the platform for one test and puts the real one back.
  static FakeVideoPlatform install({bool refusePlay = false}) {
    final previous = VideoPlayerPlatform.instance;
    final fake = FakeVideoPlatform(refusePlay: refusePlay);
    VideoPlayerPlatform.instance = fake;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    return fake;
  }

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    _events.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 54),
        size: const Size(1280, 720),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> play(int playerId) async {
    playCalls++;
    if (refusePlay) {
      throw PlatformException(
        code: 'NotAllowedError',
        message: 'play() failed because the user did not interact first',
      );
    }
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
    _events.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  Future<void> dispose(int playerId) async {
    disposed = true;
    await _events.close();
  }
}
