import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_backend.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/narrator_bank.dart';
import 'package:mafia_master/ui/economy/cosmetic_preview.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';

import '../support/localized.dart';

class _Recorder extends SilentAudioBackend {
  final played = <String>[];
  @override
  Future<void> play(String assetKey, {double rate = 1.0, double volume = 1.0}) async =>
      played.add(assetKey);
}

void main() {
  testWidgets('the store preview of a narrator pack plays its own voice', (
    tester,
  ) async {
    final backend = _Recorder();
    final audio = AudioDirector(backend: backend)
      ..narrator = NarratorBank([
        const NarratorClip(
          id: 'kratos_discussion',
          beat: NarratorBeat.discussion,
          when: 'always',
          family: true,
          file: 'voice/kratos/discussion_01.ogg',
        ),
      ])
      ..registerNarratorBank(
        'narrator_keeper',
        NarratorBank([
          const NarratorClip(
            id: 'keeper_discussion',
            beat: NarratorBeat.discussion,
            when: 'always',
            family: true,
            file: 'voice/narrator_keeper/discussion.ogg',
          ),
        ]),
      );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioDirectorProvider.overrideWithValue(audio)],
        child: localizedApp(
          Scaffold(
            body: SingleChildScrollView(
              child: NarratorPreview(
                narrator: Cosmetics.narrators['narrator_keeper']!,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byIcon(Icons.volume_up_outlined));
    await tester.tap(find.byIcon(Icons.volume_up_outlined));
    await tester.pump();
    expect(backend.played, ['voice/narrator_keeper/discussion.ogg']);
    expect(audio.activeVoice, isNull);
  });
}
