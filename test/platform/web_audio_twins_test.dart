import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';

/// Web parity: the browser plays the `.mp3` twin of every `.ogg` (Safari cannot
/// decode Ogg). A sound, a Kratos line or a narrator-pack line whose twin is
/// missing would be silent on the web only, so every shipped `.ogg` must have
/// one, and the two must ship from the same registered folders.
void main() {
  final oggs = Directory('assets')
      .listSync(recursive: true)
      .whereType<File>()
      .map((f) => f.path.replaceAll(r'\', '/'))
      .where((p) => p.endsWith('.ogg'))
      .toList();

  test('there are sounds to check', () {
    expect(oggs.length, greaterThan(50));
  });

  test('every shipped .ogg has an .mp3 twin for the web', () {
    final missing = [
      for (final ogg in oggs)
        if (!File('${ogg.substring(0, ogg.length - 4)}.mp3').existsSync()) ogg,
    ];
    expect(missing, isEmpty, reason: 'silent on the web: $missing');
  });

  test('every twin sits in a folder the asset bundle registers', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final folders = RegExp(
      r'^\s*-\s*(assets/[^\s#]+/)\s*$',
      multiLine: true,
    ).allMatches(pubspec).map((m) => m.group(1)!).toList();
    final unregistered = [
      for (final ogg in oggs)
        if (!folders.any(ogg.startsWith)) ogg,
    ];
    expect(unregistered, isEmpty);
  });

  test('the web key swaps the extension and nothing else', () {
    expect(
      webAudioAssetKey('voice/kratos/night_01.ogg', web: true),
      'voice/kratos/night_01.mp3',
    );
    expect(
      webAudioAssetKey('voice/kratos/night_01.ogg', web: false),
      'voice/kratos/night_01.ogg',
    );
    expect(webAudioAssetKey('audio/x.mp3', web: true), 'audio/x.mp3');
  });
}
