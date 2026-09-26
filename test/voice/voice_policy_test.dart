import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/voice_policy.dart';

/// The microphone policy table of doc 10 §6.3, and the two copies of it.
///
/// One copy is `lib/engine/voice_policy.dart`, which every client mutes itself
/// against. The other is `supabase/functions/_shared/voice.ts`, which the
/// server refuses the floor against. They are written in different languages
/// and different phase vocabularies, and if they ever disagreed the
/// disagreement would be a live microphone during a night — a leak of exactly
/// the kind doc 05 exists to prevent, arriving through a door doc 05 does not
/// mention.
///
/// So the table is asserted twice: once as the rule, and once as the mirror.
void main() {
  group('the policy table (doc 10 §6.3)', () {
    test('the private stretch is silent, with no exceptions', () {
      for (final phase in [
        GamePhase.distributing,
        GamePhase.preNightLobby,
        GamePhase.night,
        GamePhase.nightResolving,
      ]) {
        expect(micPolicyFor(phase), equals(MicPolicy.muted), reason: '$phase');
        expect(
          voiceTornDownIn(phase),
          isTrue,
          reason:
              '$phase must not merely mute — the connection itself is a '
              'per-player status indicator (doc 10 §6.3)',
        );
      }
    });

    test('the ballot is silent', () {
      expect(micPolicyFor(GamePhase.voting), equals(MicPolicy.muted));
      expect(micPolicyFor(GamePhase.voteResolving), equals(MicPolicy.muted));
    });

    test('the app speaks alone', () {
      expect(micPolicyFor(GamePhase.morning), equals(MicPolicy.muted));
      expect(micPolicyFor(GamePhase.reveal), equals(MicPolicy.muted));
      expect(micPolicyFor(GamePhase.winCheck), equals(MicPolicy.muted));
    });

    test('one voice at a time where the room is pointed at one seat', () {
      expect(
        micPolicyFor(GamePhase.openingRound),
        equals(MicPolicy.activeSpeakerOnly),
      );
      expect(
        micPolicyFor(GamePhase.confrontation),
        equals(MicPolicy.activeSpeakerOnly),
      );
    });

    test('discussion follows the mode the room chose', () {
      expect(
        micPolicyFor(
          GamePhase.discussion,
          discussion: DiscussionMode.structured,
        ),
        equals(MicPolicy.activeSpeakerOnly),
      );
      expect(
        micPolicyFor(GamePhase.discussion, discussion: DiscussionMode.free),
        equals(MicPolicy.open),
      );
    });

    test('open only where nothing is secret yet, or nothing is any more', () {
      for (final phase in [
        GamePhase.setup,
        GamePhase.rolesConfigured,
        GamePhase.result,
        GamePhase.analytics,
      ]) {
        expect(micPolicyFor(phase), equals(MicPolicy.open), reason: '$phase');
      }
    });

    test('every phase has an answer, and no phase is open by accident', () {
      // The function has no `default:`, so this is really a check that the
      // enum and the table are the same length. It is here anyway, because the
      // day somebody adds a phase and reaches for `default:` to make the
      // analyzer quiet is the day it stops being true.
      final open = GamePhase.values
          .where((p) => micPolicyFor(p) == MicPolicy.open)
          .toSet();
      expect(
        open,
        equals({
          GamePhase.setup,
          GamePhase.rolesConfigured,
          GamePhase.result,
          GamePhase.analytics,
        }),
      );
    });
  });

  group('the server mirrors it', () {
    /// The `micPolicyFor` switch out of `_shared/voice.ts`, read as data.
    ///
    /// A textual read rather than a running Deno: what can drift here is the
    /// table, not the language, and the table is exactly what a text read can
    /// see.
    Map<String, String> serverTable() {
      final source = File(
        'supabase/functions/_shared/voice.ts',
      ).readAsStringSync();
      final body = source.substring(
        source.indexOf('export function micPolicyFor'),
        source.indexOf('export function floorOwnerSeat'),
      );

      final table = <String, String>{};
      final pending = <String>[];
      for (final raw in body.split('\n')) {
        final line = raw.trim();
        final caseMatch = RegExp(r'^case "(\w+)":$').firstMatch(line);
        if (caseMatch != null) {
          pending.add(caseMatch.group(1)!);
          continue;
        }
        final returnMatch = RegExp(r'^return "(\w+)";$').firstMatch(line);
        if (returnMatch != null) {
          for (final phase in pending) {
            table[phase] = returnMatch.group(1)!;
          }
          pending.clear();
          continue;
        }
        // `discuss` returns a ternary. Recorded under the structured answer,
        // which is what the Dart default argument is too.
        if (line.startsWith('return settings.discussionMode')) {
          for (final phase in pending) {
            table[phase] = 'activeSpeakerOnly';
          }
          pending.clear();
        }
      }
      return table;
    }

    /// Server phase name → the [GamePhase] it arrives as on a client.
    ///
    /// `defense` has no Dart phase: the offline state machine folds a defence
    /// into the confrontation window, and the server keeps the name because
    /// the schema always has. It is checked against the confrontation's answer.
    const equivalents = <String, GamePhase>{
      'lobby': GamePhase.setup,
      'reveal': GamePhase.distributing,
      'night': GamePhase.night,
      'morning': GamePhase.morning,
      'opening': GamePhase.openingRound,
      'confront': GamePhase.confrontation,
      'defense': GamePhase.confrontation,
      'discuss': GamePhase.discussion,
      'vote': GamePhase.voting,
      'result': GamePhase.result,
    };

    test('every phase the schema allows has a policy on the server', () {
      final table = serverTable();
      for (final phase in equivalents.keys) {
        expect(
          table,
          contains(phase),
          reason:
              '$phase has no case in _shared/voice.ts, so it would fall '
              'through to the default',
        );
      }
    });

    test('and it is the same policy the client mutes itself against', () {
      final table = serverTable();
      for (final entry in equivalents.entries) {
        expect(
          table[entry.key],
          equals(micPolicyFor(entry.value).name),
          reason:
              'server "${entry.key}" and Dart ${entry.value} disagree — '
              'one of them would leave a microphone open',
        );
      }
    });
  });
}
