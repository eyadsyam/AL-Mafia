import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/stories/v2/session.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/stories/v2/world_checker.dart';

const _worldPath = 'assets/stories_v2/qahwet_el_moallem.json';

final _world = StoryWorld.decode(File(_worldPath).readAsStringSync());

List<String> _players(int n) => [for (var i = 1; i <= n; i++) 'لاعب $i'];

typedef _Json = Map<String, Object?>;

/// The pilot world with [edit] applied to its decoded JSON, to break one rule
/// at a time (the file itself is never touched).
StoryWorld _edited(void Function(_Json json) edit) {
  final json = jsonDecode(File(_worldPath).readAsStringSync()) as _Json;
  edit(json);
  return StoryWorld.fromJson(json);
}

_Json _suspectJson(_Json json, String id) => [
  for (final s in json['suspects']! as List) s as _Json,
].firstWhere((s) => s['id'] == id);

_Json _guiltJson(_Json json, String id) =>
    _suspectJson(json, id)['guilty']! as _Json;

List<_Json> _tracesJson(_Json json, String id) => [
  for (final t in _guiltJson(json, id)['traces']! as List) t as _Json,
];

/// The pilot world where n01's guilt comes with n02 as his partner: the
/// engine still deals partners, the checker refuses them in format 3.
final _partnered = _edited((json) {
  final n02 = _guiltJson(json, 'n02');
  _guiltJson(json, 'n01')['partner'] = {
    'id': 'n02',
    'traces': n02['traces'],
    'reveal': n02['reveal'],
  };
});

List<String> _problems(StoryWorld world) =>
    const StoryWorldChecker().check(world);

void main() {
  group('the pilot world', () {
    test('passes every machine-checkable rule', () {
      expect(_problems(_world), isEmpty);
    });

    test('reads format 3 and nothing else', () {
      expect(_world.marks, hasLength(5));
      for (final suspect in _world.suspects) {
        expect(suspect.marks, hasLength(2));
      }
      expect(_world.place('cafe_floor').baseTrace, isEmpty);
      expect(_world.place('coal_yard').baseTrace, isNotEmpty);
      expect(
        () => _edited((json) => json['format'] = 2),
        throwsA(isA<FormatException>()),
      );
    });

    test('the checker catches a clock time', () {
      final broken = _edited(
        (json) => _suspectJson(json, 'n01')['hook'] = 'الساعة ٨:٤٣',
      );
      expect(_problems(broken).any((p) => p.startsWith('clock time')), isTrue);
    });

    test('the checker catches two suspects with the same marks', () {
      final broken = _edited(
        (json) => _suspectJson(json, 'n02')['marks'] = [
          ..._suspectJson(json, 'n01')['marks']! as List,
        ],
      );
      final problems = _problems(broken);
      expect(
        problems.any((p) => p.contains('n02: has the same marks as n01')),
        isTrue,
      );
      // The same pair then leaves both of them for the detective.
      expect(
        problems.any(
          (p) => p.startsWith('n01: searching') && p.contains('leaves 2 sus'),
        ),
        isTrue,
      );
    });

    test('the checker catches a trace with a mark its suspect lacks', () {
      final broken = _edited(
        (json) => _tracesJson(json, 'n01').first['marks'] = ['flour'],
      );
      expect(
        _problems(broken).any(
          (p) =>
              p.startsWith('n01:') &&
              p.contains('flour') &&
              p.contains('not on his hands'),
        ),
        isTrue,
      );
    });

    test('the checker catches a trace text that disagrees with its marks', () {
      // n01's cafe_floor line names the oil but lists only the coal.
      final unlisted = _edited(
        (json) => _tracesJson(json, 'n01').first['marks'] = ['coal'],
      );
      expect(
        _problems(
          unlisted,
        ).any((p) => p.contains('names tameya but does not list it')),
        isTrue,
      );
      // n01's shisha_corner line lists the oil but never names it.
      final unnamed = _edited(
        (json) => _tracesJson(json, 'n01')[1]['marks'] = ['tameya'],
      );
      expect(
        _problems(
          unnamed,
        ).any((p) => p.contains('lists tameya but its text never names it')),
        isTrue,
      );
    });

    test('the checker catches a path that leaves several suspects', () {
      // Every trace of n01's carries only the coal: any three searches find
      // one mark, which four suspects hold.
      final broken = _edited((json) {
        for (final t in _tracesJson(json, 'n01')) {
          t['marks'] = ['coal'];
        }
      });
      expect(
        _problems(broken).any(
          (p) => p.startsWith('n01: searching') && p.contains('leaves 4 sus'),
        ),
        isTrue,
      );
    });

    test('the checker catches a mark word inside a suspicion and a card', () {
      final word = _world.marks.first.words.first;
      final suspicion = _edited(
        (json) => (_suspectJson(json, 'n01')['suspicion']! as _Json)['text'] =
            'في الصفيحة $word.',
      );
      expect(
        _problems(
          suspicion,
        ).any((p) => p.startsWith('n01: suspicion names a mark')),
        isTrue,
      );
      final card = _edited(
        (json) => _suspectJson(json, 'n03')['card'] = 'أنا عزة، $word.',
      );
      expect(
        _problems(card).any((p) => p.startsWith('n03: card names a mark')),
        isTrue,
      );
    });

    test('the checker needs one trace in each place, and no partner', () {
      final short = _edited(
        (json) => (_guiltJson(json, 'n01')['traces']! as List).removeLast(),
      );
      expect(
        _problems(short).any((p) => p.startsWith('n01: guilty version needs')),
        isTrue,
      );
      expect(
        _problems(_partnered).any((p) => p == 'n01: format 3 has no partners'),
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
        for (final world in [_world, _partnered]) {
          for (var n = 1; n <= 10; n++) {
            for (var seed = 0; seed < 200; seed++) {
              final table = StoryTable.deal(
                world: world,
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
        }
        // The real world has no partners, whatever the table.
        for (var seed = 0; seed < 200; seed++) {
          expect(
            StoryTable.deal(
              world: _world,
              players: _players(8),
              seed: seed,
            ).partnerId,
            isNull,
          );
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
    test('a search lists the base trace first, then each seated line', () {
      for (var n = 2; n <= 10; n++) {
        for (var seed = 0; seed < 40; seed++) {
          final table = StoryTable.deal(
            world: _world,
            players: _players(n),
            seed: seed,
          );
          final guilt = _world.suspect(table.culpritId).guilty;
          for (final place in _world.places) {
            final found = table.tracesAt(place.id);
            expect(found, isNot(contains('')));
            if (place.baseTrace.isNotEmpty) {
              expect(found.first, place.baseTrace);
            }
            final expected = [
              if (place.baseTrace.isNotEmpty) place.baseTrace,
              for (final id in table.suspectIds)
                if (_world.suspect(id).suspicion.placeId == place.id)
                  _world.suspect(id).suspicion.text,
              for (final t in guilt.traces)
                if (t.placeId == place.id) t.text,
            ];
            expect(found..sort(), expected..sort(), reason: place.id);
          }
        }
      }
    });

    test('the order is fixed by the table, and the culprit is not first', () {
      final table = StoryTable.deal(
        world: _world,
        players: _players(10),
        seed: 7,
      );
      for (final place in _world.places) {
        expect(table.tracesAt(place.id), table.tracesAt(place.id));
      }
      final positions = <String, Set<int>>{};
      for (var seed = 0; seed < 300; seed++) {
        final dealt = StoryTable.deal(
          world: _world,
          players: _players(10),
          seed: seed,
        );
        for (final t in _world.suspect(dealt.culpritId).guilty.traces) {
          final lines = dealt.tracesAt(t.placeId);
          final skipped = _world.place(t.placeId).baseTrace.isEmpty ? 0 : 1;
          (positions[t.placeId] ??= {}).add(lines.indexOf(t.text) - skipped);
        }
      }
      for (final place in _world.places) {
        expect(
          positions[place.id]!.length,
          greaterThan(1),
          reason: '${place.id}: the culprit line sat at ${positions[place.id]}',
        );
      }
    });

    test('any three searches show the culprit marks, and only his', () {
      final places = [for (final p in _world.places) p.id];
      for (var n = 1; n <= 10; n++) {
        for (var seed = 0; seed < 60; seed++) {
          final table = StoryTable.deal(
            world: _world,
            players: _players(n),
            seed: seed,
          );
          final culprit = _world.suspect(table.culpritId);
          for (var a = 0; a < 5; a++) {
            for (var b = a + 1; b < 5; b++) {
              for (var c = b + 1; c < 5; c++) {
                final found = [
                  for (final p in [places[a], places[b], places[c]])
                    ...table.tracesAt(p),
                ];
                // What a player can read off the lines: the marks they name.
                final named = {
                  for (final m in _world.marks)
                    if (m.words.any((w) => found.any((l) => l.contains(w))))
                      m.id,
                };
                expect(named, culprit.marks.toSet());
                expect(
                  [
                    for (final s in _world.suspects)
                      if (s.marks.toSet().containsAll(named)) s.id,
                  ],
                  [culprit.id],
                );
              }
            }
          }
        }
      }
    });

    test('what is found against a suspect appears whenever he is seated', () {
      for (var seed = 0; seed < 40; seed++) {
        final table = StoryTable.deal(
          world: _world,
          players: _players(5),
          seed: seed,
        );
        final all = [for (final p in _world.places) ...table.tracesAt(p.id)];
        for (final s in _world.suspects) {
          final seated = table.suspectIds.contains(s.id);
          expect(all.contains(s.suspicion.text), seated, reason: s.id);
          expect(table.caseFacts.contains(s.hook), seated, reason: s.id);
        }
        // Guilty or not, the culprit's own suspicion is there too.
        expect(all, contains(_world.suspect(table.culpritId).suspicion.text));
      }
    });

    test('the why and how choices list each id once', () {
      for (var n = 1; n <= 10; n++) {
        for (var seed = 0; seed < 50; seed++) {
          final table = StoryTable.deal(
            world: _world,
            players: _players(n),
            seed: seed,
          );
          final guilt = _world.suspect(table.culpritId).guilty;
          final motives = [for (final m in table.motives(seed)) m.id];
          final methods = [for (final m in table.methods(seed)) m.id];
          expect(motives.toSet(), hasLength(motives.length));
          expect(methods.toSet(), hasLength(methods.length));
          expect(motives, contains(guilt.motive.id));
          expect(methods, contains(guilt.method.id));
          // The world has two method ids, so four suspects must collapse.
          expect(methods.length, lessThanOrEqualTo(2));
        }
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
      for (final world in [_world, _partnered]) {
        for (var players = 1; players <= 10; players++) {
          for (final suspect in world.suspects) {
            for (var seed = 0; seed < 6; seed++) {
              final partner = suspect.guilty.partner?.partnerId;
              final withPartner = players >= 5 && partner != null && seed.isOdd;
              final table = StoryTable.deal(
                world: world,
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
              if (withPartner) {
                expect(table.suspectIds, contains(partner));
                // The partner's own lines are found beside the culprit's.
                final partnerLines = {
                  for (final t in suspect.guilty.partner!.traces) t.text,
                };
                final found = [
                  for (final p in world.places) ...table.tracesAt(p.id),
                ];
                expect(found.where(partnerLines.contains), isNotEmpty);
              }
              expect(table.suspectIds.toSet().length, table.suspectIds.length);
            }
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
      // n01 has no partner in the real world, so naming one is refused.
      expect(
        () => StoryTable.deal(
          world: _world,
          players: _players(7),
          seed: 1,
          pick: const StoryCulpritPick(culpritId: 'n01', partnerId: 'n02'),
        ),
        throwsArgumentError,
      );
      expect(
        () => StoryTable.deal(
          world: _partnered,
          players: _players(3),
          seed: 1,
          pick: const StoryCulpritPick(culpritId: 'n01', partnerId: 'n02'),
        ),
        throwsArgumentError,
      );
    });
  });
}
