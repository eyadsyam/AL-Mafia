import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_types.dart';
import 'package:mafia_master/data/resume_resolver.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';

import '../support/information_match.dart';

/// The Phase 1 migration gate: **old matches still open, and nothing is lost.**
///
/// ## Why the fixture is a file and not a builder
///
/// `test/data/fixtures/match_pre_information_engine.json` is a real match,
/// played through the engine and then stripped of every key and every event
/// kind that did not exist before this phase. It is checked in as *bytes*.
///
/// A fixture built by calling today's encoder would prove nothing: it would be
/// regenerated in the new format the moment the format changed, and the test
/// would keep passing while the thing it guards quietly broke. A stored match
/// on somebody's phone does not regenerate. This file is what one of those
/// looks like.
///
/// ## What "no data loss" means for a JSON-payload store
///
/// `MatchRecord` keeps a whole match as one encoded blob, so there is no column
/// migration to run. The migration surface is entirely `MatchCodec`, and it has
/// exactly two obligations: every new settings field must have a default that a
/// missing key resolves to, and every new event kind must decode. Both are
/// asserted below, in both directions — old bytes read by the new code, and new
/// bytes read back after a round trip.
void main() {
  late Map<String, dynamic> oldPayload;

  setUp(() {
    final file =
        File('test/data/fixtures/match_pre_information_engine.json');
    oldPayload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  });

  group('a match stored before the Information Engine', () {
    test('the fixture really is in the old format', () {
      // Guards the guard. If somebody regenerates this file with the current
      // encoder, the rest of this group silently stops testing anything.
      final settings = oldPayload['settings'] as Map<String, dynamic>;
      for (final key in const [
        'traceEnabled',
        'confrontationEnabled',
        'whisperEnabled',
        'revealWhisperContent',
        'openingRoundEnabled',
        'survivorConfrontationEnabled',
        'confrontationSeconds',
      ]) {
        expect(settings.containsKey(key), isFalse,
            reason: 'the fixture must predate "$key"');
      }
      final kinds = {
        for (final e in oldPayload['eventLog'] as List)
          (e as Map<String, dynamic>)['k'] as String,
      };
      expect(kinds.intersection(const {
        'nightSkipped',
        'trace',
        'opening',
        'confront',
        'confrontEnd',
        'spoke',
        'whisper',
        'whisperRead',
        'whisperVoid',
      }), isEmpty);
      expect(kinds, isNotEmpty);
    });

    test('decodes without throwing, with every event intact', () {
      final match = MatchCodec.decode(oldPayload);
      expect(match.players, hasLength(7));
      expect(match.seed, equals(424242));
      expect(match.eventLog, hasLength((oldPayload['eventLog'] as List).length));
      expect(match.phase, equals(GamePhase.reveal));
    });

    test('the new settings arrive at their defaults', () {
      final match = MatchCodec.decode(oldPayload);
      const defaults = MatchSettings.defaults();
      expect(match.settings.traceEnabled, equals(defaults.traceEnabled));
      expect(match.settings.confrontationEnabled,
          equals(defaults.confrontationEnabled));
      expect(match.settings.whisperEnabled, equals(defaults.whisperEnabled));
      expect(match.settings.openingRoundEnabled,
          equals(defaults.openingRoundEnabled));
      expect(match.settings.survivorConfrontationEnabled, isFalse,
          reason: 'C11 must not switch itself on for an adopted match');
      expect(match.settings.confrontationSeconds,
          equals(defaults.confrontationSeconds));
      // Everything it *did* carry is untouched.
      expect(match.settings.speechSeconds, equals(60));
      expect(match.settings.identityHoldSeconds, equals(5));
    });

    test('history opens it: the projection is empty, not broken', () {
      final history = buildHistory(MatchCodec.decode(oldPayload));
      expect(history.nights, hasLength(1));
      expect(history.nights.single.revealedTrace, isNull,
          reason: 'nothing was published on a night played before the layer '
              'existed, and nothing may be invented for it now');
      expect(history.days, hasLength(1));
      expect(history.days.single.openingAccusations, isEmpty);
      expect(history.days.single.confrontation, isNull);
      expect(history.allWhispers, isEmpty);
    });

    test('it still resumes, on the screen its phase implies', () {
      final match = MatchCodec.decode(oldPayload);
      final target = ResumeResolver.resolve(match);
      expect(target.screen, equals(ResumeScreen.voteReveal));
      expect(ResumeResolver.isActive(match), isTrue);
    });

    test('it can be adopted and played on', () {
      final engine = MatchEngine(clock: Clocks.monotonic());
      engine.match = MatchCodec.decode(oldPayload);
      // The match is mid-reveal; the next real command is the win check, and
      // from there the day rolls forward with the new layers live.
      engine.winCheck();
      expect(
        engine.match.phase,
        anyOf(GamePhase.preNightLobby, GamePhase.result),
      );
    });

    test('it survives a round trip through the new codec', () async {
      final match = MatchCodec.decode(oldPayload);
      final store = MemoryMatchStore();
      final repository = MemoryMatchRepository(store);
      await repository.persistStep(match);
      // The fixture is mid-match, so it comes back off the resume path rather
      // than out of History — which is the path that matters here anyway: an
      // unfinished match written by the old build has to survive being written
      // *again* by the new one.
      final reloaded = await repository.loadActiveMatch();
      expect(reloaded, equals(match));
      expect(MatchCodec.decode(MatchCodec.encode(match)), equals(match));
    });
  });

  group('a match with the new events', () {
    test('every new event kind survives encode/decode', () {
      final engine = informationMatch(seed: 909);
      // A skip, a trace, an opener, a whisper and a speaking record — one of
      // each, so the codec's new branches are all walked.
      playQuietNight(engine);
      openDay(engine);
      engine.recordSpeaking(seat: 0, seconds: 30);
      engine.sendWhisper(fromSeat: 0, toSeat: 1, body: 'hello');

      final kinds = engine.match.eventLog.map((e) => e.runtimeType).toSet();
      expect(kinds, contains(NightActionSkipped));
      expect(kinds, contains(TracePublished));
      expect(kinds, contains(OpeningAccusationCast));
      expect(kinds, contains(SpeakingRecorded));
      expect(kinds, contains(WhisperSent));

      final restored =
          MatchCodec.decode(MatchCodec.encode(engine.match));
      expect(restored, equals(engine.match));
      for (var i = 0; i < engine.match.eventLog.length; i++) {
        expect(restored.eventLog[i], equals(engine.match.eventLog[i]),
            reason: 'event $i changed across the round trip');
      }
    });

    test('a whisper body is nowhere in the encoded match', () {
      final engine = informationMatch(seed: 77);
      playQuietNight(engine);
      openDay(engine);
      const body = 'meet-me-at-dawn-and-say-nothing';
      engine.sendWhisper(fromSeat: 0, toSeat: 1, body: body);

      // The storage split of doc 09 §5, asserted where it can actually be
      // checked: the encoded match is what History and analytics decode, and
      // the body must not be reachable from it at all.
      expect(jsonEncode(MatchCodec.encode(engine.match)), isNot(contains(body)));
    });
  });
}
