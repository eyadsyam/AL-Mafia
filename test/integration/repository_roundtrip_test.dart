import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';

import '../support/scripted_match.dart';

/// T052 — repository contract inv. 5: a reloaded match equals the one written.
///
/// ## Why equality, and not "close enough"
///
/// The seed and the event log are not decoration. Night resolution draws from a
/// seeded RNG, and the tie-break is reproducible only if the seed survives
/// storage exactly; the doctor's no-repeat rule, the detective's one-shot rule
/// and the revote's round number are all re-derived from the event log, so a
/// dropped or reordered event changes what the engine will *allow* after a
/// resume. "Nearly the same match" is a different match.
void main() {
  group('inv. 5 round-trip fidelity', () {
    test('a mid-night match survives encode/decode unchanged', () {
      final engine = scriptedMatch(stopAfterNightActions: 2);
      final original = engine.match;

      final restored = MatchCodec.decode(MatchCodec.encode(original));

      expect(restored, equals(original));
      expect(restored.seed, equals(original.seed));
      expect(restored.currentActorSeat, equals(original.currentActorSeat));
      expect(restored.eventLog.length, equals(original.eventLog.length));
      for (var i = 0; i < original.eventLog.length; i++) {
        expect(restored.eventLog[i], equals(original.eventLog[i]),
            reason: 'event $i changed across the round trip');
      }
    });

    test('a finished match survives encode/decode unchanged', () {
      final engine = playToCompletion();
      final original = engine.match;

      final restored = MatchCodec.decode(MatchCodec.encode(original));

      expect(restored, equals(original));
      expect(restored.outcome, equals(original.outcome));
      expect(restored.phase, equals(GamePhase.result));
    });

    test('every event variant round-trips', () {
      // A match played to a win exercises most variants; a tie forces the
      // revote marker, which is the newest and most easily forgotten one.
      final engine = playToTiedVote();
      final original = engine.match;
      final kinds = original.eventLog.map((e) => e.runtimeType).toSet();

      expect(kinds.length, greaterThan(4),
          reason: 'the scripted match is not exercising enough event types');
      expect(MatchCodec.decode(MatchCodec.encode(original)), equals(original));
    });

    test('a decoded match is a genuinely separate object', () {
      // Storage must hand back a copy. If a decode returned shared lists, a
      // later engine mutation would silently rewrite history.
      final engine = scriptedMatch(stopAfterNightActions: 1);
      final original = engine.match;
      final restored = MatchCodec.decode(MatchCodec.encode(original));

      expect(identical(restored.players, original.players), isFalse);
      expect(identical(restored.eventLog, original.eventLog), isFalse);
      expect(restored, equals(original));
    });

    test('enums are stored by name, not by ordinal', () {
      // Reordering an enum declaration must not silently reinterpret stored
      // matches as a different phase or a different role.
      final engine = scriptedMatch(stopAfterNightActions: 1);
      final json = MatchCodec.encode(engine.match);

      expect(json['phase'], isA<String>());
      final firstPlayer = (json['players'] as List).first as Map<String, dynamic>;
      expect(firstPlayer['role'], isA<String>());
      expect(Role.values.map((r) => r.name), contains(firstPlayer['role']));
    });
  });

  group('repository behaviour', () {
    late MemoryMatchStore store;
    late MemoryMatchRepository repository;

    setUp(() {
      store = MemoryMatchStore();
      repository = MemoryMatchRepository(store);
    });

    test('persistStep overwrites rather than appending', () async {
      final engine = scriptedMatch(stopAfterNightActions: 1);
      await repository.persistStep(engine.match);
      await repository.persistStep(engine.match);
      await repository.persistStep(engine.match);

      expect(store.matches, hasLength(1),
          reason: 'each step of one match must address the same row');
    });

    test('loadActiveMatch returns the unfinished match', () async {
      final engine = scriptedMatch(stopAfterNightActions: 2);
      await repository.persistStep(engine.match);

      final loaded = await repository.loadActiveMatch();
      expect(loaded, equals(engine.match));
    });

    test('inv. 3: a finished match is not active', () async {
      final engine = playToCompletion();
      await repository.persistStep(engine.match);

      expect(await repository.loadActiveMatch(), isNull);
      expect(await repository.listHistory(), hasLength(1));
    });

    test('inv. 6: analytics is refused for an unfinished match', () async {
      final engine = scriptedMatch(stopAfterNightActions: 2);
      await repository.persistStep(engine.match);

      expect(
        () => repository.loadAnalytics(engine.match.id),
        throwsStateError,
        reason: 'serving analytics mid-match would expose every role at once',
      );
    });

    test('inv. 6: analytics is served for a finished match', () async {
      final engine = playToCompletion();
      await repository.persistStep(engine.match);

      final analytics = await repository.loadAnalytics(engine.match.id);
      expect(analytics.matchId, equals(engine.match.id));
      expect(analytics.data.finalRoles, isNotEmpty);
      expect(analytics.playerNames, hasLength(engine.match.players.length));
    });

    test('history is newest first and deletion removes a row', () async {
      final older = playToCompletion(seed: 1, createdAt: DateTime(2026, 1, 1));
      final newer = playToCompletion(seed: 2, createdAt: DateTime(2026, 2, 1));
      await repository.persistStep(older.match);
      await repository.persistStep(newer.match);

      var history = await repository.listHistory();
      expect(history.map((s) => s.id).toList(),
          equals([newer.match.id, older.match.id]));

      await repository.deleteMatch(newer.match.id);
      history = await repository.listHistory();
      expect(history.map((s) => s.id).toList(), equals([older.match.id]));
    });

    test('default settings round-trip, and are defaulted before any save',
        () async {
      expect(await repository.loadDefaultSettings(),
          equals(const MatchSettings.defaults()));

      const custom = MatchSettings(
        speechSeconds: 45,
        discussionMode: DiscussionMode.free,
        dayTieRule: DayTieRule.noElimination,
        narrationEnabled: false,
        abstainAllowed: true,
      );
      await repository.saveDefaultSettings(custom);
      expect(await repository.loadDefaultSettings(), equals(custom));
    });

    test('a stored match cannot be mutated through the object that wrote it',
        () async {
      final engine = scriptedMatch(stopAfterNightActions: 1);
      await repository.persistStep(engine.match);
      final before = await repository.loadActiveMatch();

      // Keep playing without persisting; storage must not have followed along.
      engine.submitNightAction(
        seat: engine.match.currentActorSeat!,
        kind: _kindFor(engine.match, engine.match.currentActorSeat!),
        targetSeat: _anyTargetFor(engine.match, engine.match.currentActorSeat!),
      );

      final after = await repository.loadActiveMatch();
      expect(after, equals(before));
      expect(after, isNot(equals(engine.match)));
    });
  });
}

NightActionKind _kindFor(Match match, int seat) => switch (match.players[seat].role) {
      Role.mafia => NightActionKind.mafiaVote,
      Role.doctor => NightActionKind.protect,
      Role.detective => NightActionKind.investigate,
      Role.citizen => NightActionKind.suspect,
    };

int _anyTargetFor(Match match, int seat) => match.players
    .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
    .seat;

/// Convenience alias so the intent reads clearly at the call sites above.
MatchEngine playToCompletion({int seed = 7, DateTime? createdAt}) =>
    scriptedMatch(playToEnd: true, seed: seed, createdAt: createdAt);
