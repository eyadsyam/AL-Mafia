import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/v2/session.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/stories/v2/world_checker.dart';

final _world = StoryWorld.decode(
  File('assets/stories_v2/qahwet_el_moallem.json').readAsStringSync(),
);

List<String> _players(int n) => [for (var i = 1; i <= n; i++) 'لاعب $i'];

void main() {
  group('the pilot world', () {
    test('passes every machine-checkable rule', () {
      expect(const StoryWorldChecker().check(_world), isEmpty);
    });

    test('the checker catches a clock time and a trace that misses paths', () {
      final source = File(
        'assets/stories_v2/qahwet_el_moallem.json',
      ).readAsStringSync();
      final broken = StoryWorld.decode(
        source
            .replaceFirst('من ساعة ما وقع', 'الساعة ٨:٤٣')
            .replaceFirst(
              '"place": "cafe_floor",\n            "text": "واحد من اللي',
              '"place": "coal_alley",\n            "text": "واحد من اللي',
            ),
      );
      final problems = const StoryWorldChecker().check(broken);
      expect(problems.any((p) => p.startsWith('clock time')), isTrue);
      expect(
        problems.any((p) => p.contains('n01: guilty version needs')),
        isTrue,
      );
    });
  });

  group('dealing', () {
    test('mode and seats follow the table size', () {
      for (var n = 1; n <= 10; n++) {
        final table = StoryTable.deal(
          world: _world,
          players: _players(n),
          seed: n,
        );
        expect(table.mode, storyTableModeFor(n));
        switch (table.mode) {
          case StoryTableMode.solo:
            expect(table.seats, hasLength(1));
            expect(table.seats.single.isDetective, isTrue);
            expect(table.suspectIds, hasLength(StoryTable.soloSuspects));
          case StoryTableMode.allSuspects:
            expect(table.seats.where((s) => s.isDetective), isEmpty);
            expect(table.suspectIds, hasLength(n));
          case StoryTableMode.detective:
            expect(table.seats.where((s) => s.isDetective), hasLength(1));
            expect(table.suspectIds, hasLength(n - 1));
        }
        expect(table.suspectIds.toSet(), hasLength(table.suspectIds.length));
      }
    });

    test(
      'the culprit is always on the table, and played when friends play',
      () {
        for (var n = 1; n <= 10; n++) {
          for (var seed = 0; seed < 200; seed++) {
            final table = StoryTable.deal(
              world: _world,
              players: _players(n),
              seed: seed,
            );
            expect(table.suspectIds, contains(table.culpritId));
            if (table.mode != StoryTableMode.solo) {
              expect(table.seatOf(table.culpritId), isNotNull);
            }
            if (table.partnerId case final partner?) {
              expect(table.mode, StoryTableMode.detective);
              expect(table.seatOf(partner), isNotNull);
              expect(partner, isNot(table.culpritId));
            }
          }
        }
      },
    );

    test('the same seed deals the same table; seeds vary the culprit', () {
      final a = StoryTable.deal(world: _world, players: _players(6), seed: 42);
      final b = StoryTable.deal(world: _world, players: _players(6), seed: 42);
      expect(b.culpritId, a.culpritId);
      expect(b.suspectIds, a.suspectIds);
      final culprits = {
        for (var seed = 0; seed < 300; seed++)
          StoryTable.deal(
            world: _world,
            players: _players(6),
            seed: seed,
          ).culpritId,
      };
      expect(culprits, hasLength(10));
    });

    test('recent culprits are avoided, with a fallback when none is left', () {
      for (var seed = 0; seed < 100; seed++) {
        final first = StoryTable.deal(
          world: _world,
          players: _players(3),
          seed: seed,
        );
        final again = StoryTable.deal(
          world: _world,
          players: _players(3),
          seed: seed,
          recentCulprits: {first.culpritId},
        );
        expect(again.culpritId, isNot(first.culpritId));
      }
      final everyone = {for (final s in _world.suspects) s.id};
      final table = StoryTable.deal(
        world: _world,
        players: _players(2),
        seed: 1,
        recentCulprits: everyone,
      );
      expect(table.suspectIds, contains(table.culpritId));
    });

    test('roles: only the 5–10 table has secrets', () {
      final group = StoryTable.deal(
        world: _world,
        players: _players(3),
        seed: 3,
      );
      expect(
        group.seats.map(group.roleOf),
        everyElement(StorySeatRole.unknown),
      );
      final big = StoryTable.deal(world: _world, players: _players(7), seed: 3);
      final roles = big.seats.map(big.roleOf).toList();
      expect(roles.where((r) => r == StorySeatRole.detective), hasLength(1));
      expect(roles.where((r) => r == StorySeatRole.killer), hasLength(1));
      expect(
        roles.where((r) => r == StorySeatRole.partner),
        hasLength(big.partnerId == null ? 0 : 1),
      );
    });
  });

  group('what the table finds', () {
    test('any three searches meet the culprit, in every version', () {
      final places = [for (final p in _world.places) p.id];
      for (var n = 1; n <= 10; n++) {
        for (var seed = 0; seed < 60; seed++) {
          final table = StoryTable.deal(
            world: _world,
            players: _players(n),
            seed: seed,
          );
          final guilt = {
            for (final t in _world.suspect(table.culpritId).guilty.traces)
              t.text,
          };
          for (var a = 0; a < 5; a++) {
            for (var b = a + 1; b < 5; b++) {
              for (var c = b + 1; c < 5; c++) {
                final found = [
                  for (final p in [places[a], places[b], places[c]])
                    ...table.tracesAt(p),
                ];
                expect(found.any(guilt.contains), isTrue);
              }
            }
          }
        }
      }
    });

    test('alibis appear only for seated innocents; facts name only them', () {
      final table = StoryTable.deal(
        world: _world,
        players: _players(5),
        seed: 9,
      );
      final all = [for (final p in _world.places) ...table.tracesAt(p.id)];
      for (final s in _world.suspects) {
        final present = all.contains(s.innocentTrace.text);
        expect(
          present,
          table.suspectIds.contains(s.id) && !table.isGuilty(s.id),
        );
        expect(
          table.caseFacts.contains(s.hook),
          table.suspectIds.contains(s.id),
        );
      }
    });
  });

  group('the session', () {
    test('5–10: one pass, then the desk; interruption covers the page', () {
      final table = StoryTable.deal(
        world: _world,
        players: _players(5),
        seed: 5,
      );
      var s = StorySessionV2.start(table);
      expect(s.stage, StoryStage.cast);
      s = s.begin();
      for (var i = 0; i < 5; i++) {
        expect(s.stage, StoryStage.handoff);
        expect(s.turn, i);
        s = s.openCard().revealSecret();
        expect(s.coverForInterruption().stage, StoryStage.handoff);
        expect(s.coverForInterruption().turn, i);
        s = s.hideSecret();
      }
      expect(s.stage, StoryStage.desk);
    });

    test('2–4: public introductions, no private pages', () {
      final table = StoryTable.deal(
        world: _world,
        players: _players(3),
        seed: 5,
      );
      var s = StorySessionV2.start(table).begin();
      expect(s.stage, StoryStage.introductions);
      s = s.nextIntroduction().nextIntroduction().nextIntroduction();
      expect(s.stage, StoryStage.desk);
      expect(() => s.openCard(), throwsStateError);
    });

    test(
      'three searches, one bonus for solo only, never the same place twice',
      () {
        final solo = StoryTable.deal(
          world: _world,
          players: _players(1),
          seed: 2,
        );
        var s = StorySessionV2.start(solo);
        expect(s.stage, StoryStage.desk);
        final ids = [for (final p in _world.places) p.id];
        s = s.search(ids[0]);
        expect(() => s.search(ids[0]), throwsStateError);
        expect(s.canBuySearch, isFalse);
        s = s.search(ids[1]).search(ids[2]);
        expect(s.searchesLeft, 0);
        expect(s.canBuySearch, isTrue);
        s = s.grantBonusSearch().search(ids[3]);
        expect(s.canBuySearch, isFalse);
        final group = StorySessionV2.start(
          StoryTable.deal(world: _world, players: _players(2), seed: 2),
        ).begin().nextIntroduction().nextIntroduction();
        final done = group.search(ids[0]).search(ids[1]).search(ids[2]);
        expect(done.canBuySearch, isFalse);
      },
    );

    test('a group names who only; solo also why and how', () {
      final group = StoryTable.deal(
        world: _world,
        players: _players(6),
        seed: 8,
      );
      var g = StorySessionV2.start(group).begin();
      for (var i = 0; i < 6; i++) {
        g = g.openCard().revealSecret().hideSecret();
      }
      g = g.openDecision();
      expect(
        () => g.accuse(
          StoryAccusationV2(
            suspectId: group.culpritId,
            motiveId: 'x',
            methodId: 'y',
          ),
        ),
        throwsArgumentError,
      );
      g = g.accuse(StoryAccusationV2(suspectId: group.culpritId)).showResult();
      expect(g.solved, isTrue);
      expect(g.motiveRight, isNull);

      final solo = StoryTable.deal(
        world: _world,
        players: _players(1),
        seed: 8,
      );
      final guilt = _world.suspect(solo.culpritId).guilty;
      final s = StorySessionV2.start(solo).openDecision();
      expect(
        () => s.accuse(StoryAccusationV2(suspectId: solo.culpritId)),
        throwsArgumentError,
      );
      final done = s.accuse(
        StoryAccusationV2(
          suspectId: solo.culpritId,
          motiveId: guilt.motive.id,
          methodId: 'wrong',
        ),
      );
      // Solo solves the case only with who, why and how all right.
      expect(done.whoRight, isTrue);
      expect(done.solved, isFalse);
      expect(done.motiveRight, isTrue);
      expect(done.methodRight, isFalse);
      final full = s.accuse(
        StoryAccusationV2(
          suspectId: solo.culpritId,
          motiveId: guilt.motive.id,
          methodId: guilt.method.id,
        ),
      );
      expect(full.solved, isTrue);
    });

    test('a server pick deals around its culprit and partner', () {
      for (var players = 1; players <= 10; players++) {
        for (final suspect in _world.suspects) {
          for (var seed = 0; seed < 6; seed++) {
            final partner = suspect.guilty.partner?.partnerId;
            final withPartner = players >= 5 && partner != null && seed.isOdd;
            final table = StoryTable.deal(
              world: _world,
              players: _players(players),
              seed: seed,
              pick: StoryCulpritPick(
                culpritId: suspect.id,
                partnerId: withPartner ? partner : null,
              ),
            );
            expect(table.culpritId, suspect.id);
            expect(table.suspectIds, contains(suspect.id));
            expect(table.partnerId, withPartner ? partner : isNull);
            if (withPartner) expect(table.suspectIds, contains(partner));
            expect(table.suspectIds.toSet().length, table.suspectIds.length);
          }
        }
      }
      expect(
        () => StoryTable.deal(
          world: _world,
          players: _players(5),
          seed: 1,
          pick: const StoryCulpritPick(culpritId: 'nobody'),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryTable.deal(
          world: _world,
          players: _players(3),
          seed: 1,
          pick: const StoryCulpritPick(culpritId: 'n01', partnerId: 'n02'),
        ),
        throwsArgumentError,
      );
    });
  });
}
