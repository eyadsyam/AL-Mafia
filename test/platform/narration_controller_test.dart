import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/narration_controller.dart';

class _FakePlayer implements NarrationPlayer {
  final positionCtl = StreamController<Duration>.broadcast(sync: true);
  final durationCtl = StreamController<Duration>.broadcast(sync: true);
  final completeCtl = StreamController<void>.broadcast(sync: true);
  final calls = <String>[];
  bool failStart = false;

  @override
  Stream<Duration> get positions => positionCtl.stream;
  @override
  Stream<Duration> get durations => durationCtl.stream;
  @override
  Stream<void> get completions => completeCtl.stream;

  @override
  Future<void> start(String assetKey) async {
    calls.add('start $assetKey');
    if (failStart) throw StateError('no file');
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<void> seek(Duration to) async => calls.add('seek ${to.inSeconds}');
  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> dispose() async => calls.add('dispose');
}

const _asset = 'assets/voice/stories_v2/qahwet_el_moallem.ogg';

void main() {
  late _FakePlayer player;
  late NarrationController narration;

  setUp(() {
    player = _FakePlayer();
    narration = NarrationController(player, web: false);
  });

  test(
    'plays the asset without the assets/ prefix; the web gets the mp3',
    () async {
      await narration.play(_asset);
      expect(player.calls.last, 'start voice/stories_v2/qahwet_el_moallem.ogg');
      expect(narration.state, NarrationState.playing);
      final webPlayer = _FakePlayer();
      await NarrationController(webPlayer, web: true).play(_asset);
      expect(
        webPlayer.calls.last,
        'start voice/stories_v2/qahwet_el_moallem.mp3',
      );
    },
  );

  test(
    'toggle pauses and resumes; the end stops and offers play again',
    () async {
      await narration.toggle(_asset);
      player.durationCtl.add(const Duration(seconds: 17));
      player.positionCtl.add(const Duration(seconds: 6));
      expect(narration.position, const Duration(seconds: 6));
      await narration.toggle(_asset);
      expect(narration.state, NarrationState.paused);
      await narration.toggle(_asset);
      expect(player.calls.last, 'resume');
      player.completeCtl.add(null);
      expect(narration.state, NarrationState.ended);
      expect(narration.position, const Duration(seconds: 17));
      await narration.toggle(_asset);
      expect(player.calls.last, 'start voice/stories_v2/qahwet_el_moallem.ogg');
    },
  );

  test('skips five seconds either way, clamped to the track', () async {
    await narration.play(_asset);
    player.durationCtl.add(const Duration(seconds: 17));
    player.positionCtl.add(const Duration(seconds: 3));
    await narration.skip(-NarrationController.skipStep);
    expect(player.calls.last, 'seek 0');
    player.positionCtl.add(const Duration(seconds: 15));
    await narration.skip(NarrationController.skipStep);
    expect(player.calls.last, 'seek 17');
  });

  test('a tap on the bar of a finished track plays from there', () async {
    await narration.play(_asset);
    player.durationCtl.add(const Duration(seconds: 17));
    player.completeCtl.add(null);
    await narration.seek(const Duration(seconds: 8));
    expect(narration.state, NarrationState.playing);
    expect(player.calls.sublist(player.calls.length - 2), [
      'start voice/stories_v2/qahwet_el_moallem.ogg',
      'seek 8',
    ]);
  });

  test('restart and stop', () async {
    await narration.play(_asset);
    await narration.restart();
    expect(player.calls.where((c) => c.startsWith('start')), hasLength(2));
    await narration.stop();
    expect(narration.state, NarrationState.idle);
    expect(narration.position, Duration.zero);
  });

  test('a missing file is quiet: error state, no throw', () async {
    player.failStart = true;
    await narration.play(_asset);
    expect(narration.state, NarrationState.error);
  });
}
