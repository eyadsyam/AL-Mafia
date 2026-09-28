import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';

/// T076 — narration, ambient and drum cues fire only during on-table phases.
///
/// The unit-level gate ([AudioDirector]) proves a cue *cannot* play in hand.
/// This proves the flow never tries: the phone's reported location tracks the
/// phase correctly, and each cue lands in the phase the design assigns it
/// (§8).
void main() {
  const surface = Size(390, 844);
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];

  late ProviderContainer container;
  late AudioDirector audio;

  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  Future<void> pumpFlow(
    WidgetTester tester, {
    bool narrationEnabled = true,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    audio = AudioDirector();
    container = ProviderContainer(
      overrides: [audioDirectorProvider.overrideWithValue(audio)],
    );
    addTearDown(container.dispose);

    controller().startMatch(
      names: names,
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      },
      settings: MatchSettings(
        discussionMode: DiscussionMode.free,
        narrationEnabled: narrationEnabled,
      ),
      seed: 7,
    );

    // Deal the roles through the engine; distribution is not what is under test.
    final engine = controller().engine;
    while (engine.match.phase == GamePhase.distributing) {
      engine.revealFor(engine.match.currentActorSeat!);
      engine.confirmRevealed();
    }
    controller().adoptMatch(engine.match);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(MatchFlow(onExit: () {}, onAnalytics: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> hold(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(HoldPad).first),
    );
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
  }

  Future<void> playNight(WidgetTester tester) async {
    expect(find.text('الليل يقترب'), findsNothing);
    await tester.pumpAndSettle();

    while (controller().engine.match.phase == GamePhase.night) {
      await hold(tester);
      await tester.tap(find.byType(NightGridTile).first);
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.dwellGate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();
      await tester.pump(MafiaTiming.defaults.turnFloor);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();
    }
  }

  group('phone location tracks the phase', () {
    testWidgets('night opens directly with the in-hand audio gate closed', (
      tester,
    ) async {
      await pumpFlow(tester);
      expect(controller().engine.match.phase, GamePhase.night);
      expect(audio.location, equals(PhoneLocation.inHand));

      expect(find.text('الليل يقترب'), findsNothing);
      await tester.pumpAndSettle();
      expect(controller().engine.match.phase, GamePhase.night);
      expect(
        audio.location,
        equals(PhoneLocation.inHand),
        reason: 'the night must close the audio gate',
      );
    });

    testWidgets('the morning reopens the gate', (tester) async {
      await pumpFlow(tester);
      await playNight(tester);
      expect(controller().engine.match.phase, GamePhase.morning);
      expect(audio.location, equals(PhoneLocation.onTable));
    });

    testWidgets('the ballot closes the gate again', (tester) async {
      await pumpFlow(tester);
      await playNight(tester);
      await tester.tap(find.text('ابدأ النقاش'));
      await tester.pumpAndSettle();

      // Day 1 opens on the «اسم واحد» round, which is on the table and has
      // to be played through before the discussion exists.
      while (controller().engine.match.phase == GamePhase.openingRound) {
        await tester.tap(find.byType(PlayerTile).first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('خلص النقاش'));
      await tester.pumpAndSettle();

      expect(controller().engine.match.phase, GamePhase.voting);
      expect(
        audio.location,
        equals(PhoneLocation.inHand),
        reason: 'a secret ballot is an in-hand phase',
      );
    });
  });

  group('cues land in the right phase', () {
    testWidgets('direct night handoff plays no social narration', (
      tester,
    ) async {
      await pumpFlow(tester);
      expect(audio.emitted, isEmpty);

      expect(find.text('الليل يقترب'), findsNothing);
      await tester.pumpAndSettle();

      expect(audio.emitted, isEmpty);
    });

    testWidgets('the morning cue plays once the night resolves', (
      tester,
    ) async {
      await pumpFlow(tester);
      await playNight(tester);
      expect(audio.emitted, contains(AudioCue.morning));
    });

    testWidgets('no cue is emitted while a turn is in someone\'s hand', (
      tester,
    ) async {
      await pumpFlow(tester);
      expect(find.text('الليل يقترب'), findsNothing);
      await tester.pumpAndSettle();

      final beforeTurns = List<AudioCue>.from(audio.emitted);
      await hold(tester);
      await tester.tap(find.byType(NightGridTile).first);
      await tester.pump(MafiaTiming.defaults.dwellGate);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(TurnShell.actionButton));
      await tester.pumpAndSettle();

      expect(
        audio.emitted,
        equals(beforeTurns),
        reason: 'something played during an in-hand turn',
      );
    });

    testWidgets('turning narration off silences speech but not the chime', (
      tester,
    ) async {
      await pumpFlow(tester, narrationEnabled: false);
      audio.narrationEnabled = false;

      expect(find.text('الليل يقترب'), findsNothing);
      await tester.pumpAndSettle();

      expect(audio.emitted, isNot(contains(AudioCue.nightFalls)));
      expect(audio.emitted, isNot(contains(AudioCue.mafiaWake)));

      // A functional cue is not narration and stays audible.
      audio.setLocation(PhoneLocation.onTable);
      audio.play(AudioCue.speakerChange);
      expect(audio.emitted, contains(AudioCue.speakerChange));
    });
  });

  group('the cue catalogue matches the design system', () {
    test('every §8 cue exists and only narration is switchable', () {
      // Doc 01 §8 listed six. The atmosphere brief added three more — the card
      // flip, the last-ten-seconds tick, and the result sting — so the
      // catalogue is a superset of §8 rather than a match to it. Spelled out as
      // two sets rather than a count, because a count tells whoever breaks this
      // nothing about what they broke.
      expect(
        AudioCue.values.where((c) => c.narration).toSet(),
        equals({AudioCue.nightFalls, AudioCue.mafiaWake, AudioCue.morning}),
        reason:
            'the switchable set changed: only spoken narration may be '
            'switched off, because a functional cue that could vanish would '
            'make turn length depend on a setting',
      );
      expect(
        AudioCue.values.where((c) => !c.narration).toSet(),
        equals({
          // Doc 01 §8 and the atmosphere brief.
          AudioCue.speakerChange,
          AudioCue.timerEnd,
          AudioCue.eliminationReveal,
          AudioCue.cardFlip,
          AudioCue.timerWarning,
          AudioCue.win,
          // Doc 12 §8 — the online table. Every one of them fires on a public
          // surface with the phone flat: a lobby, a whisper crossing a table
          // the whole room can see, a ballot, a death, a confrontation
          // opening. None is switchable, for the reason above.
          AudioCue.joinChime,
          AudioCue.leaveChime,
          AudioCue.whisperSend,
          AudioCue.whisperReceive,
          AudioCue.voteTick,
          AudioCue.deathTear,
          AudioCue.confrontationSwell,
          AudioCue.brandMotif, // F19: the sonic mark, at launch only
        }),
      );

      // Every cue that claims a sound has one on disk. The seven added for doc
      // 12 §8 were synthesised rather than produced, and a generated asset is
      // exactly the kind that goes missing in a rebuild without anybody
      // noticing until a match is silent.
      for (final cue in AudioCue.values) {
        final sound = cue.sound;
        if (sound == null) continue;
        expect(
          File('assets/$sound').existsSync(),
          isTrue,
          reason: '${cue.name} names $sound, which is not in assets/',
        );
      }
    });

    test('the seven cues the atmosphere brief names are all present', () {
      // Named individually so a rename cannot quietly drop one: night falls,
      // morning breaks, card flip, timer tick, turn change, elimination, win.
      const required = <AudioCue>{
        AudioCue.nightFalls,
        AudioCue.morning,
        AudioCue.cardFlip,
        AudioCue.timerWarning,
        AudioCue.speakerChange,
        AudioCue.eliminationReveal,
        AudioCue.win,
      };
      expect(AudioCue.values.toSet().containsAll(required), isTrue);

      // And each has something to play. `mafiaWake` deliberately does not — it
      // is a spoken line with no ambient bed — so it is not in this set.
      for (final cue in required) {
        expect(
          cue.sound,
          isNotNull,
          reason:
              '${cue.name} has no sound file; run '
              '`python tool/generate_audio.py`',
        );
      }
    });
  });
}
