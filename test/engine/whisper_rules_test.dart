import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/core/whisper_language.dart';
import 'package:mafia_master/data/whisper_store.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

import '../support/information_match.dart';

/// Doc 11 §5.3 — H-E1 → H-E10.
///
/// The rules live in the engine, so they are tested there: a UI that forgets to
/// disable a control is a bug, but a UI that *could* get past the engine by
/// forgetting would be a different and much worse one. Every case below is
/// stated against `MatchEngine`, and the screens are held to the same rules by
/// `whisper_card_parity_test`.
void main() {
  group('the graph', () {
    test('a whisper records the edge and returns a deterministic id', () {
      final engine = informationMatch(seed: 3);
      playQuietNight(engine);
      openDay(engine);

      final id = engine.sendWhisper(fromSeat: 0, toSeat: 2, body: 'hello');
      expect(id, equals(WhisperMeta.idFor(day: 1, fromSeat: 0, toSeat: 2)));

      final graph = engine.whispersOn(1);
      expect(graph, hasLength(1));
      expect(graph.single.fromSeat, equals(0));
      expect(graph.single.toSeat, equals(2));
      expect(graph.single.delivered, isFalse);
      expect(graph.single.voided, isFalse);
    });

    test('the graph reaches the day record, and no body does', () {
      final engine = informationMatch(seed: 4);
      playQuietNight(engine);
      openDay(engine);
      engine.sendWhisper(fromSeat: 1, toSeat: 3, body: 'a secret');

      final day = buildHistory(engine.match).dayAt(1)!;
      expect(day.whispers, hasLength(1));
      expect(day.whispers.single.fromSeat, equals(1));
      expect(engine.match.eventLog.toString(), isNot(contains('a secret')));
    });
  });

  group('H-E1 — one per living player per day', () {
    test('a second whisper on the same day is refused', () {
      final engine = informationMatch(seed: 5);
      playQuietNight(engine);
      openDay(engine);
      engine.sendWhisper(fromSeat: 0, toSeat: 2, body: 'one');
      expect(
        () => engine.sendWhisper(fromSeat: 0, toSeat: 3, body: 'two'),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'the allowance does not accumulate — a new day grants exactly one',
      () {
        final engine = informationMatch(seed: 6);
        playQuietNight(engine);
        openDay(engine);
        engine.sendWhisper(fromSeat: 0, toSeat: 2, body: 'day one');
        engine.beginVoting();
        while (engine.match.currentActorSeat != null) {
          engine.submitVote(
            seat: engine.match.currentActorSeat!,
            voterSeat: engine.match.currentActorSeat!,
            targetSeat: null,
          );
        }
        engine.resolveDayVote();
        engine.winCheck();
        playQuietNight(engine);
        openDay(engine);

        expect(engine.match.dayNumber, equals(2));
        expect(engine.whispersSentBy(0, 2), isZero);
        engine.sendWhisper(fromSeat: 0, toSeat: 2, body: 'day two');
        expect(
          () => engine.sendWhisper(fromSeat: 0, toSeat: 3, body: 'again'),
          throwsA(isA<StateError>()),
        );
      },
    );
  });

  group('H-E2 / H-E7 — the recipient dies first', () {
    test('an unread whisper is voided and the sender is told', () {
      final engine = informationMatch(seed: 8);
      playQuietNight(engine);
      openDay(engine);

      // Everybody votes seat 2 out.
      const doomed = 2;
      engine.sendWhisper(fromSeat: 0, toSeat: doomed, body: 'watch out');
      engine.beginVoting();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(
          seat: seat,
          voterSeat: seat,
          targetSeat: seat == doomed ? 0 : doomed,
        );
      }
      engine.resolveDayVote();

      expect(engine.match.players[doomed].status, equals(PlayerStatus.dead));
      expect(engine.pendingWhispersFor(doomed), isEmpty);
      final voided = engine.voidedWhispersFrom(0);
      expect(voided, hasLength(1));
      expect(voided.single.voided, isTrue);
    });

    test('a whisper already read is not voided when its reader dies', () {
      final engine = informationMatch(seed: 9);
      playQuietNight(engine);
      openDay(engine);
      const doomed = 2;
      final id = engine.sendWhisper(
        fromSeat: 0,
        toSeat: doomed,
        body: 'read me',
      );
      engine.markWhisperDelivered(id);

      engine.beginVoting();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(
          seat: seat,
          voterSeat: seat,
          targetSeat: seat == doomed ? 0 : doomed,
        );
      }
      engine.resolveDayVote();

      expect(
        engine.voidedWhispersFrom(0),
        isEmpty,
        reason: 'it arrived; dying afterwards does not un-deliver it',
      );
    });
  });

  group('H-E3 — the sender dies afterwards', () {
    test('the whisper still waits for its recipient', () {
      final engine = informationMatch(seed: 10);
      playQuietNight(engine);
      openDay(engine);

      const sender = 3;
      engine.sendWhisper(fromSeat: sender, toSeat: 1, body: 'from the grave');
      engine.beginVoting();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(
          seat: seat,
          voterSeat: seat,
          targetSeat: seat == sender ? 0 : sender,
        );
      }
      engine.resolveDayVote();

      expect(engine.match.players[sender].status, equals(PlayerStatus.dead));
      expect(
        engine.pendingWhispersFor(1),
        hasLength(1),
        reason: 'the dead can accuse from the grave',
      );
    });
  });

  group('H-E4 / H-E5 — who may be written to', () {
    test('a whisper to yourself is refused', () {
      final engine = informationMatch(seed: 11);
      playQuietNight(engine);
      openDay(engine);
      expect(
        () => engine.sendWhisper(fromSeat: 2, toSeat: 2, body: 'hi'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a whisper to a dead player is refused', () {
      final engine = informationMatch(seed: 12);
      playQuietNight(engine);
      openDay(engine);
      const doomed = 4;
      engine.beginVoting();
      while (engine.match.currentActorSeat != null) {
        final seat = engine.match.currentActorSeat!;
        engine.submitVote(
          seat: seat,
          voterSeat: seat,
          targetSeat: seat == doomed ? 0 : doomed,
        );
      }
      engine.resolveDayVote();
      engine.winCheck();
      playQuietNight(engine);
      openDay(engine);

      expect(
        () => engine.sendWhisper(fromSeat: 0, toSeat: doomed, body: 'hi'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('H-E6 / H-E10 — length', () {
    test('121 characters are refused, never truncated', () {
      final engine = informationMatch(seed: 13);
      playQuietNight(engine);
      openDay(engine);
      final tooLong = 'a' * (WhisperLimits.maxLength + 1);
      expect(
        () => engine.sendWhisper(fromSeat: 0, toSeat: 1, body: tooLong),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        engine.whispersOn(1),
        isEmpty,
        reason: 'a refused whisper leaves no edge on the graph either',
      );
    });

    test('exactly 120 characters are accepted', () {
      final engine = informationMatch(seed: 14);
      playQuietNight(engine);
      openDay(engine);
      engine.sendWhisper(
        fromSeat: 0,
        toSeat: 1,
        body: 'a' * WhisperLimits.maxLength,
      );
      expect(engine.whispersOn(1), hasLength(1));
    });

    test('an empty or whitespace-only body is refused', () {
      final engine = informationMatch(seed: 15);
      playQuietNight(engine);
      openDay(engine);
      for (final body in ['', '   ', '\n\t']) {
        expect(
          () => engine.sendWhisper(fromSeat: 0, toSeat: 1, body: body),
          throwsA(isA<ArgumentError>()),
          reason:
              'an empty whisper is still a public edge, so it would be a '
              'free signal with nothing said',
        );
      }
    });
  });

  group('H-E9 — blocking', () {
    test('a block list is local and tells the sender nothing', () {
      // The whole of H-E9 is what this class does *not* have: no notify, no
      // "you were blocked", no way for a sender to observe it at all.
      final list = WhisperBlockList();
      expect(list.isBlocked(3), isFalse);
      list.block(3);
      expect(list.isBlocked(3), isTrue);
      expect(list.blocked, equals({3}));
      list.unblock(3);
      expect(list.isBlocked(3), isFalse);
    });
  });

  group('the language check warns and never blocks', () {
    test('it matches whole words in both scripts', () {
      expect(WhisperLanguage.looksAbusive('you idiot'), isTrue);
      expect(WhisperLanguage.looksAbusive('انت كلب'), isTrue);
    });

    test('it does not match inside a longer word', () {
      // The classic false positive. A filter that fires on ordinary text
      // teaches players that the warning means nothing.
      expect(WhisperLanguage.looksAbusive('shitake mushrooms'), isFalse);
      expect(WhisperLanguage.looksAbusive('classic'), isFalse);
    });

    test('it is advisory — the engine accepts a flagged body', () {
      final engine = informationMatch(seed: 16);
      playQuietNight(engine);
      openDay(engine);
      engine.sendWhisper(fromSeat: 0, toSeat: 1, body: 'you idiot');
      expect(
        engine.whispersOn(1),
        hasLength(1),
        reason: 'doc 09 §3.5 — "with a warning, not a hard block"',
      );
    });
  });

  group('the layer switch', () {
    test('with whispers off the engine refuses outright', () {
      final engine = informationMatch(
        seed: 17,
        settings: const MatchSettings(),
      );
      playQuietNight(engine);
      openDay(engine);
      expect(
        () => engine.sendWhisper(fromSeat: 0, toSeat: 1, body: 'hi'),
        throwsA(isA<StateError>()),
      );
    });

    test('whispers are written during the discussion, not the night', () {
      final engine = informationMatch(seed: 18);
      engine.beginNight();
      expect(
        () => engine.sendWhisper(fromSeat: 0, toSeat: 1, body: 'hi'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('the body store', () {
    test('put, read, and purge round-trip', () async {
      final store = MemoryWhisperStore();
      await store.put(matchId: 1, whisperId: 'w:1:0:2', body: 'hello');
      expect(
        await store.read(matchId: 1, whisperId: 'w:1:0:2'),
        equals('hello'),
      );
      expect(
        await store.read(matchId: 2, whisperId: 'w:1:0:2'),
        isNull,
        reason: 'bodies are scoped to their match',
      );
      await store.purge(1);
      expect(await store.read(matchId: 1, whisperId: 'w:1:0:2'), isNull);
    });

    test('re-putting the same id replaces rather than duplicates', () async {
      final store = MemoryWhisperStore();
      await store.put(matchId: 1, whisperId: 'w:1:0:2', body: 'first');
      await store.put(matchId: 1, whisperId: 'w:1:0:2', body: 'second');
      expect(await store.readAll(1), equals({'w:1:0:2': 'second'}));
    });
  });
}
