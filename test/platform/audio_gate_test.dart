import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';

/// T042 / L-11 — [AudioDirector] cannot emit while the phone is in a player's
/// hand.
///
/// ## Why this throws rather than returning quietly
///
/// A narration cue that plays during someone's night turn tells the whole table
/// what stage that turn has reached. Silently swallowing such a call would let
/// the bug ship: the cue would simply never be heard in testing, and the first
/// person to notice would be a player who worked out the pattern. Throwing
/// makes the mistake loud at the point it is made, which is the only place it
/// can still be fixed cheaply.
void main() {
  group('L-11 audio gate', () {
    test('playing while in hand throws', () {
      final director = AudioDirector()..setLocation(PhoneLocation.inHand);
      expect(() => director.play(AudioCue.nightFalls), throwsStateError);
    });

    test('playing on the table is allowed', () {
      final director = AudioDirector()..setLocation(PhoneLocation.onTable);
      expect(() => director.play(AudioCue.nightFalls), returnsNormally);
    });

    test('the gate closes again when the phone is picked back up', () {
      final director = AudioDirector()..setLocation(PhoneLocation.onTable);
      expect(() => director.play(AudioCue.speakerChange), returnsNormally);

      director.setLocation(PhoneLocation.inHand);
      expect(() => director.play(AudioCue.speakerChange), throwsStateError);

      director.setLocation(PhoneLocation.onTable);
      expect(() => director.play(AudioCue.speakerChange), returnsNormally);
    });

    test('a fresh director defaults to the table, not to in-hand', () {
      // The default has to be the *permissive* one, because the restrictive
      // state is entered explicitly when a turn begins. Defaulting to inHand
      // would make every legitimate on-table cue throw, and the fix would
      // predictably be to remove the gate.
      expect(() => AudioDirector().play(AudioCue.speakerChange), returnsNormally);
    });

    test('no in-hand surface can reach the audio director', () {
      // The gate is a runtime check; this is the static half. An in-hand screen
      // that never touches AudioDirector cannot trip the gate in the first
      // place.
      const inHandSources = [
        'lib/ui/widgets/turn_shell.dart',
        'lib/ui/widgets/hold_pad.dart',
        'lib/ui/widgets/pass_screen.dart',
        'lib/ui/widgets/player_tile.dart',
        'lib/ui/widgets/role_card.dart',
        'lib/ui/screens/night/night_action_screen.dart',
        'lib/ui/screens/day/voting_screen.dart',
      ];

      final offenders = <String>[];
      for (final path in inHandSources) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        if (file.readAsStringSync().contains('AudioDirector')) {
          offenders.add(path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'LEAK: these in-hand surfaces reference AudioDirector: '
              '$offenders');
    });
  });

  /// The one sound allowed under a player's own thumb, and the fence round it.
  ///
  /// The card turn is an exception to the gate above, and the danger with an
  /// exception is not the exception — it is the second one, added later,
  /// because the first one was already there. These tests are the fence: the
  /// door is one method, it takes no argument, and the ordinary door is still
  /// shut.
  group('the card turn is the only sound allowed in a hand', () {
    test('it plays with the phone in a hand', () {
      final director = AudioDirector()..setLocation(PhoneLocation.inHand);
      director.playCardTurn();
      expect(director.emitted, equals([AudioCue.cardFlip]));
    });

    test('the ordinary door is still shut, cardFlip included', () {
      final director = AudioDirector()..setLocation(PhoneLocation.inHand);
      // Not "every cue except cardFlip". Every cue.
      for (final cue in AudioCue.values) {
        expect(() => director.play(cue), throwsStateError,
            reason: '$cue got through AudioDirector.play while the phone was '
                'in somebody\'s hand. The card turn has its own method; the '
                'gate is not the place to make room for it.');
      }
    });

    test('it takes no argument, so the exception cannot be widened', () {
      // Structural, and the reason is in the failure mode rather than in the
      // code: an exception that accepts a cue is one call site away from being
      // a general in-hand channel, and the call site always looks reasonable
      // on the day it is written.
      final source =
          File('lib/platform/audio_director.dart').readAsStringSync();
      expect(source.contains('void playCardTurn()'), isTrue,
          reason: 'playCardTurn has grown a parameter. It exists precisely '
              'because it cannot be pointed at anything else.');
    });

    test('a master mute takes it with everything else', () {
      final director = AudioDirector()
        ..setLocation(PhoneLocation.inHand)
        ..muted = true;
      director.playCardTurn();
      expect(director.emitted, isEmpty);
    });

    test('it is the same sound whatever the card is', () {
      // There is no role in its signature and no role in its body, so this can
      // only be asserted the way the type already guarantees it: one cue, one
      // file, reached from a method that knows nothing about the match.
      expect(AudioCue.cardFlip.sound, isNotNull);
      expect(AudioCue.cardFlip.narration, isFalse,
          reason: 'a narration switch that silenced the card turn would make '
              'the turn sound different for hosts with narration off — same '
              'shape of tell, one setting away');
    });
  });
}
