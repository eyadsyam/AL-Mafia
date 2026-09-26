import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/whisper_store.dart';
import 'package:mafia_master/engine/clock.dart';
import 'package:mafia_master/engine/match_engine.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/game_transport.dart';
import 'package:mafia_master/transport/local_transport.dart';

/// Phase 5's gate: a whole match, played through [GameTransport] and nothing
/// else.
///
/// The variable below is deliberately typed as the *interface*. Nothing in this
/// file may reach past it — no `engine.`, no `match.`, no `LocalTransport`
/// method that is not on `GameTransport` — because that is the only way to find
/// out whether the interface is actually sufficient before there is a second
/// implementation to discover it is not.
void main() {
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
  const roles = {
    Role.mafia: 2,
    Role.doctor: 1,
    Role.detective: 1,
    Role.citizen: 3,
  };

  late MatchEngine engine;
  late GameTransport transport;

  GameTransport open({MatchSettings settings = const MatchSettings()}) {
    engine = MatchEngine(clock: Clocks.monotonic());
    engine.start(
      names: names,
      roleCounts: roles,
      settings: settings,
      seed: 4242,
    );
    // Distribution is the one stretch where the phone is handed round before
    // any transport command exists — a role card is a secret read, not a state
    // change. `secretsFor` is how a client asks for it.
    while (engine.match.phase == GamePhase.distributing) {
      engine.confirmRevealed();
    }
    final t = LocalTransport(engine: engine, whispers: MemoryWhisperStore());
    addTearDown(t.dispose);
    return t;
  }

  setUp(() => transport = open());

  Future<void> playNight() async {
    await transport.beginNight();
    var guard = 0;
    while (transport.snapshot.currentActorSeat != null) {
      expect(++guard, lessThan(40));
      final seat = transport.snapshot.currentActorSeat!;
      final secrets = await transport.secretsFor(seat);
      expect(secrets, isNotNull);
      final turn = secrets!.turn!;
      await transport.submitNightAction(
        seat: seat,
        kind: secrets.role!.nightAction,
        targetSeat: turn.targets.isEmpty ? null : turn.targets.first,
      );
    }
    await transport.resolveNight();
  }

  Future<void> playDay() async {
    await transport.beginDay();
    var guard = 0;
    while (transport.snapshot.phase == GamePhase.openingRound) {
      expect(++guard, lessThan(40));
      final seat = transport.snapshot.currentActorSeat!;
      final target = transport.snapshot.public.players
          .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
          .seat;
      await transport.submitOpeningAccusation(seat: seat, targetSeat: target);
    }
    if (transport.snapshot.phase == GamePhase.confrontation) {
      await transport.endConfrontation(silent: false);
    }
    await transport.beginVoting();
    guard = 0;
    while (transport.snapshot.currentActorSeat != null) {
      expect(++guard, lessThan(40));
      final seat = transport.snapshot.currentActorSeat!;
      final target = transport.snapshot.public.players
          .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
          .seat;
      await transport.submitVote(seat: seat, targetSeat: target);
    }
    await transport.resolveDayVote();
    if (transport.snapshot.phase == GamePhase.reveal) {
      await transport.winCheck();
    }
  }

  test('a full match plays through the interface alone', () async {
    var guard = 0;
    while (transport.snapshot.outcome == null && guard < 12) {
      guard++;
      await playNight();
      if (transport.snapshot.phase == GamePhase.morning) {
        // A night can end the match. The morning is announced first either way.
        await transport.concludeAfterNight();
      }
      if (transport.snapshot.outcome != null) break;
      await playDay();
    }
    expect(
      transport.snapshot.outcome,
      isNotNull,
      reason: 'the match must reach a result inside $guard cycles',
    );
  });

  test('the transport is authoritative and reports a local link', () {
    expect(transport.isAuthoritative, isTrue);
    expect(transport.snapshot.connection, equals(ConnectionQuality.local));
  });

  group('the snapshot carries no roles', () {
    test('not on the roster, and not anywhere else on it', () async {
      await playNight();
      final snapshot = transport.snapshot;
      // `PublicPlayer` has no role field, so this is a property of the type
      // rather than of what happens to be filled in. Stated anyway, because it
      // is the whole reason a snapshot can be broadcast to a room.
      final rendered = snapshot.public.players.map((p) => p.toString());
      for (final role in Role.values) {
        expect(
          rendered.any((line) => line.contains(role.name)),
          isFalse,
          reason: '${role.name} reachable from the public roster',
        );
      }
    });
  });

  group('secretsFor', () {
    test('answers only for the seat holding the phone', () async {
      await transport.beginNight();
      final actor = transport.snapshot.currentActorSeat!;
      expect(await transport.secretsFor(actor), isNotNull);
      for (final other in [for (var s = 0; s < names.length; s++) s]) {
        if (other == actor) continue;
        expect(
          await transport.secretsFor(other),
          isNull,
          reason: 'seat $other is not holding the phone',
        );
      }
    });

    test('answers nobody once the night has closed', () async {
      await playNight();
      for (var seat = 0; seat < names.length; seat++) {
        expect(await transport.secretsFor(seat), isNull);
      }
    });

    test('an off-roster seat is null, not a crash', () async {
      expect(await transport.secretsFor(-1), isNull);
      expect(await transport.secretsFor(99), isNull);
    });
  });

  group('watch', () {
    test('a late subscriber gets the current snapshot first', () async {
      await playNight();
      final first = await transport.watch().first;
      expect(first.phase, equals(transport.snapshot.phase));
      expect(first.dayNumber, equals(transport.snapshot.dayNumber));
    });

    test('every command emits', () async {
      final seen = <GamePhase>[];
      final sub = transport.watch().listen((s) => seen.add(s.phase));
      addTearDown(sub.cancel);

      await transport.beginNight();
      await Future<void>.delayed(Duration.zero);
      expect(seen, contains(GamePhase.night));
    });
  });

  group('whispers', () {
    test('the body reaches the recipient and never the snapshot', () async {
      transport = open(settings: const MatchSettings(whisperEnabled: true));
      await playNight();
      await transport.beginDay();
      while (transport.snapshot.phase == GamePhase.openingRound) {
        final seat = transport.snapshot.currentActorSeat!;
        // The seat after this one may be last night's victim, and the opening
        // round refuses to accuse the dead. Name the first living neighbour.
        final target = transport.snapshot.public.players
            .firstWhere((p) => p.seat != seat && p.status == PlayerStatus.alive)
            .seat;
        await transport.submitOpeningAccusation(seat: seat, targetSeat: target);
      }
      if (transport.snapshot.phase == GamePhase.confrontation) {
        await transport.endConfrontation(silent: false);
      }

      const body = 'the-body-that-must-not-travel';
      final sender = transport.snapshot.public.players
          .firstWhere((p) => p.status == PlayerStatus.alive)
          .seat;
      final recipient = transport.snapshot.public.players
          .firstWhere((p) => p.seat != sender && p.status == PlayerStatus.alive)
          .seat;
      await transport.sendWhisper(
        fromSeat: sender,
        toSeat: recipient,
        body: body,
      );

      final snapshot = transport.snapshot;
      expect(
        snapshot.whisperGraph,
        hasLength(1),
        reason: 'the edge is public — that is the point of the layer',
      );
      expect(snapshot.toString(), isNot(contains(body)));
      expect(snapshot.whisperGraph.single.toString(), isNot(contains(body)));

      // It arrives on the recipient's next private turn (doc 09 §3.6).
      await transport.beginVoting();
      while (transport.snapshot.currentActorSeat != null) {
        final seat = transport.snapshot.currentActorSeat!;
        await transport.submitVote(seat: seat, targetSeat: null);
      }
      await transport.resolveDayVote();
      await transport.winCheck();
      await transport.beginNight();

      while (transport.snapshot.currentActorSeat != null) {
        final seat = transport.snapshot.currentActorSeat!;
        final secrets = await transport.secretsFor(seat);
        if (seat == recipient) {
          expect(secrets!.whisperBody, equals(body));
        } else {
          expect(
            secrets!.whisperBody,
            isNull,
            reason: 'seat $seat must not be handed somebody else\'s whisper',
          );
        }
        await transport.submitNightAction(
          seat: seat,
          kind: secrets.role!.nightAction,
          targetSeat: null,
        );
      }
    });
  });

  group('advancePhase — no phase can stall', () {
    test('it always moves a live match forward', () async {
      var guard = 0;
      while (transport.snapshot.outcome == null && guard < 500) {
        guard++;
        final before = transport.snapshot;
        await transport.advancePhase();
        final after = transport.snapshot;
        expect(
          before.phase != after.phase ||
              before.currentActorSeat != after.currentActorSeat ||
              before.dayNumber != after.dayNumber,
          isTrue,
          reason:
              'advancePhase left the match exactly where it was, in '
              '${before.phase.name} — that is a stall',
        );
      }
      expect(
        transport.snapshot.outcome,
        isNotNull,
        reason: 'a match driven only by expiry defaults must still end',
      );
    });
  });
}
