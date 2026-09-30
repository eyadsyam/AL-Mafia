import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_backend.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/narrator_bank.dart';
import 'package:mafia_master/ui/economy/cosmetics.dart';

class _Recorder extends SilentAudioBackend {
  final played = <String>[];
  final volumes = <double>[];
  @override
  Future<void> play(
    String assetKey, {
    double rate = 1.0,
    double volume = 1.0,
  }) async {
    played.add(assetKey);
    volumes.add(volume);
  }
}

NarratorClip clip(
  String id,
  NarratorBeat beat, [
  String when = 'always',
  bool family = true,
]) => NarratorClip(
  id: id,
  beat: beat,
  when: when,
  family: family,
  file: 'voice/kratos/$id.ogg',
);

/// F16 — the spoken narrator.
void main() {
  group('conditions read only what the table can see', () {
    const died = NarrationFacts(nightEliminated: 1);
    const quiet = NarrationFacts(nightEliminated: 0);
    test('the line bank language', () {
      expect(NarratorBank.conditionHolds('always', NarrationFacts.none), true);
      expect(NarratorBank.conditionHolds('night_eliminated == 1', died), true);
      expect(
        NarratorBank.conditionHolds('night_eliminated == 1', quiet),
        false,
      );
      expect(NarratorBank.conditionHolds('night_eliminated >= 1', died), true);
      expect(NarratorBank.conditionHolds('night_eliminated == 0', quiet), true);
      expect(
        NarratorBank.conditionHolds(
          'day_eliminated == 0',
          const NarrationFacts(dayEliminated: 0),
        ),
        true,
      );
      expect(
        NarratorBank.conditionHolds('round == 1', NarrationFacts.none),
        true,
      );
      expect(
        NarratorBank.conditionHolds(
          'round == 1',
          const NarrationFacts(revote: true),
        ),
        false,
        reason: 'a revote is not a first round',
      );
      expect(
        NarratorBank.conditionHolds(
          'revote',
          const NarrationFacts(revote: true),
        ),
        true,
      );
      expect(
        NarratorBank.conditionHolds(
          'winner == mafia',
          const NarrationFacts(winner: 'mafia'),
        ),
        true,
      );
      expect(
        NarratorBank.conditionHolds('winner == mafia', NarrationFacts.none),
        false,
        reason: 'no winner is spoken before the result',
      );
      expect(
        NarratorBank.conditionHolds('outside_match', NarrationFacts.none),
        false,
      );
      expect(NarratorBank.conditionHolds('role == mafia', died), false);
      expect(NarratorBank.conditionHolds('garbage', died), false);
    });

    test('every app line in the Kratos bank is understood', () {
      final bank =
          jsonDecode(File('tool/voice/kratos_lines.json').readAsStringSync())
              as Map;
      const facts = [
        NarrationFacts(),
        NarrationFacts(nightEliminated: 0),
        NarrationFacts(nightEliminated: 1),
        NarrationFacts(dayEliminated: 0),
        NarrationFacts(dayEliminated: 1),
        NarrationFacts(revote: true),
        NarrationFacts(winner: 'town'),
        NarrationFacts(winner: 'mafia'),
      ];
      final beats = NarratorBeat.values.map((b) => b.name).toSet();
      for (final line in (bank['lines'] as List).cast<Map>()) {
        if (!beats.contains(line['beat'])) continue;
        expect(
          facts.any(
            (f) => NarratorBank.conditionHolds(line['when'] as String, f),
          ),
          isTrue,
          reason: '${line['id']} can never play: ${line['when']}',
        );
      }
    });
  });

  group('the bank', () {
    test('never the same line twice in a row when another fits', () {
      final bank = NarratorBank([
        clip('n1', NarratorBeat.night),
        clip('n2', NarratorBeat.night),
        clip('n3', NarratorBeat.night),
      ], random: Random(7));
      String? last;
      for (var i = 0; i < 50; i++) {
        final id = bank.pick(NarratorBeat.night, NarrationFacts.none)!.id;
        expect(id, isNot(last));
        last = id;
      }
    });

    test('a single line may repeat; nothing fitting is null', () {
      final bank = NarratorBank([clip('only', NarratorBeat.discussion)]);
      expect(
        bank.pick(NarratorBeat.discussion, NarrationFacts.none)!.id,
        'only',
      );
      expect(
        bank.pick(NarratorBeat.discussion, NarrationFacts.none)!.id,
        'only',
      );
      expect(bank.pick(NarratorBeat.win, NarrationFacts.none), isNull);
    });

    test('family mode plays only the gentle lines', () {
      final bank = NarratorBank([
        clip('harsh', NarratorBeat.morning, 'always', false),
        clip('soft', NarratorBeat.morning),
      ]);
      for (var i = 0; i < 10; i++) {
        expect(
          bank
              .pick(
                NarratorBeat.morning,
                NarrationFacts.none,
                familyOnly: true,
              )!
              .id,
          'soft',
        );
      }
    });

    test('the shipped manifest parses, and skips what it does not know', () {
      final shipped = NarratorBank.fromJson(
        File(narratorManifest).readAsStringSync(),
      );
      expect(shipped.clips, isA<List<NarratorClip>>());
      final mixed = NarratorBank.fromJson(
        jsonEncode({
          'clips': [
            {
              'id': 'a',
              'beat': 'night',
              'when': 'always',
              'family': true,
              'file': 'voice/kratos/a.ogg',
            },
            {
              'id': 'b',
              'beat': 'brand',
              'when': 'outside_match',
              'file': 'x.ogg',
            },
            {'id': 'c', 'beat': 'night'},
          ],
        }),
      );
      expect(mixed.clips.map((c) => c.id), ['a']);
    });
  });

  group('the director', () {
    late _Recorder backend;
    late AudioDirector audio;
    setUp(() {
      backend = _Recorder();
      audio = AudioDirector(backend: backend)
        ..narrator = NarratorBank([
          clip('night_a', NarratorBeat.night),
          clip('win_town', NarratorBeat.win, 'winner == town'),
        ])
        ..narratorVolume = 0.4;
    });

    test('speaks on the table at the player\'s voice volume', () {
      audio.narrate(NarratorBeat.night);
      expect(backend.played, ['voice/kratos/night_a.ogg']);
      expect(backend.volumes, [0.4]);
      expect(audio.emittedNarration, ['night_a']);
    });

    test('never in a hand', () {
      audio.setLocation(PhoneLocation.inHand);
      expect(() => audio.narrate(NarratorBeat.night), throwsStateError);
      expect(backend.played, isEmpty);
    });

    test('silenced by mute and by the narration switch', () {
      audio.muted = true;
      audio.narrate(NarratorBeat.night);
      audio.muted = false;
      audio.narrationEnabled = false;
      audio.narrate(NarratorBeat.night);
      expect(backend.played, isEmpty);
      expect(audio.canNarrate(NarratorBeat.night), isFalse);
    });

    test('a winner line waits for the winner', () {
      audio.narrate(NarratorBeat.win);
      expect(backend.played, isEmpty);
      audio.narrate(NarratorBeat.win, const NarrationFacts(winner: 'town'));
      expect(backend.played, ['voice/kratos/win_town.ogg']);
    });

    test('an empty bank is a silent narrator, and no night announcement', () {
      final plain = AudioDirector(backend: backend);
      plain.narrate(NarratorBeat.night);
      expect(backend.played, isEmpty);
      expect(plain.canNarrate(NarratorBeat.night), isFalse);
    });

    test('warm-up includes the installed lines', () async {
      final warmed = <String>[];
      final director = AudioDirector(backend: _Warm(warmed))
        ..narrator = NarratorBank([clip('night_a', NarratorBeat.night)]);
      await director.warmUp();
      expect(warmed, contains('voice/kratos/night_a.ogg'));
    });

    test('an active store voice never falls back to the default bank', () {
      audio.registerNarratorBank(
        'narrator_noir',
        NarratorBank([clip('noir_night', NarratorBeat.night)]),
      );
      audio.activeVoice = 'narrator_noir';
      audio.narrate(NarratorBeat.night);
      audio.narrate(NarratorBeat.win, const NarrationFacts(winner: 'town'));
      expect(backend.played, ['voice/kratos/noir_night.ogg']);
      expect(audio.canNarrate(NarratorBeat.win), isFalse);
    });

    test('store preview plays the requested bank without selecting it', () {
      audio.registerNarratorBank(
        'narrator_keeper',
        NarratorBank([clip('keeper_discussion', NarratorBeat.discussion)]),
      );
      audio.previewNarrator('narrator_keeper');
      expect(backend.played, ['voice/kratos/keeper_discussion.ogg']);
      expect(audio.activeVoice, isNull);
    });

    test('«classic» is the default voice, not a silent pack', () {
      audio.activeVoice = 'classic';
      expect(audio.activeVoice, isNull);
      audio.narrate(NarratorBeat.night);
      expect(backend.played, isNotEmpty);
    });

    test('every store narrator pack ships a declared, complete voice', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final entry in narratorPackManifests.entries) {
        final folder = entry.value.substring(0, entry.value.lastIndexOf('/'));
        expect(pubspec, contains('- $folder/'), reason: entry.key);
        final bank = NarratorBank.fromJson(
          File(entry.value).readAsStringSync(),
        );
        final beats = bank.clips.map((c) => c.beat).toSet();
        expect(
          beats,
          containsAll(const [
            NarratorBeat.night,
            NarratorBeat.morning,
            NarratorBeat.discussion,
            NarratorBeat.voting,
            NarratorBeat.win,
          ]),
          reason: entry.key,
        );
        for (final clip in bank.clips) {
          expect(File('assets/${clip.file}').existsSync(), isTrue,
              reason: clip.file);
        }
        // A paid voice speaks every moment the free narrator does: each
        // (beat, condition) of the default bank has a line in the pack.
        final base = NarratorBank.fromJson(
          File(narratorManifest).readAsStringSync(),
        );
        final packMoments = {
          for (final c in bank.clips) '${c.beat.name}|${c.when}',
        };
        for (final c in base.clips) {
          expect(packMoments, contains('${c.beat.name}|${c.when}'),
              reason: '${entry.key} lacks ${c.beat.name} when ${c.when}');
        }
      }
      expect(
        narratorPackManifests.keys.toSet(),
        Cosmetics.narrators.keys.toSet(),
        reason: 'every sold narrator has a recorded voice',
      );
    });

    test('web selects mp3 while native keeps ogg', () {
      expect(webAudioAssetKey('audio/win.ogg', web: true), 'audio/win.mp3');
      expect(webAudioAssetKey('audio/win.ogg', web: false), 'audio/win.ogg');
      expect(
        webAudioAssetKey('audio/already.mp3', web: true),
        'audio/already.mp3',
      );
    });

    test('every shipped ogg has a Safari mp3 sibling', () {
      final oggs = [
        ...Directory('assets/audio').listSync(recursive: true),
        ...Directory('assets/voice').listSync(recursive: true),
      ].whereType<File>().where((file) => file.path.endsWith('.ogg'));
      expect(oggs, isNotEmpty);
      for (final ogg in oggs) {
        expect(
          File(ogg.path.replaceFirst(RegExp(r'\.ogg$'), '.mp3')).existsSync(),
          isTrue,
          reason: ogg.path,
        );
      }
    });
  });
}

class _Warm extends SilentAudioBackend {
  final List<String> warmed;
  _Warm(this.warmed);
  @override
  Future<void> warmUp(Iterable<String> assetKeys) async =>
      warmed.addAll(assetKeys);
}
