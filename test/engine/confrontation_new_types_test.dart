import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/information/confrontation_generator.dart';
import 'package:mafia_master/engine/information/game_history.dart';
import 'package:mafia_master/engine/information/records.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/information_enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/information_text.dart';

import '../support/localized.dart';

/// The confrontations the owner added on 2026-10-30, each from facts the whole
/// table saw: a Day-1 accusation of someone later shown innocent, a whisper to
/// last night's victim, a whisper to a Mafioso voted out. And the silenced
/// player is never the one asked to answer out loud.
void main() {
  const on = MatchSettings(whisperEnabled: true);

  List<Player> roster(Set<int> alive) => [
    for (var seat = 0; seat < 7; seat++)
      Player(
        seat: seat,
        name: 'P$seat',
        role: Role.citizen,
        status: alive.contains(seat) ? PlayerStatus.alive : PlayerStatus.dead,
      ),
  ];

  Confrontation? pick(
    List<DayRecord> days,
    Set<int> alive,
    int dayNumber, {
    List<NightRecord> nights = const [],
    MatchSettings settings = on,
    int? silenced,
  }) => selectConfrontation(
    history: GameHistory(
      nights: nights,
      days: days,
      names: {for (final s in alive) s: 'P$s'},
      alive: alive,
    ),
    players: roster(alive),
    dayNumber: dayNumber,
    matchSeed: 9,
    settings: settings,
    silencedSeat: silenced,
  );

  NightRecord night(int n, {int? victim}) => NightRecord(
    nightNumber: n,
    suspicions: const {},
    reasons: const {},
    victim: victim,
    saveOccurred: false,
    resolved: true,
  );

  const w14 = WhisperMeta(id: 'w:1:3:6', day: 1, fromSeat: 3, toSeat: 6);

  test('C12: accused an innocent who was voted out', () {
    final c = pick(
      const [
        DayRecord(dayNumber: 1, openingAccusations: {2: 5}),
        DayRecord(dayNumber: 2, eliminated: 5, eliminatedWasMafia: false),
      ],
      {0, 1, 2, 3, 4, 6},
      3,
    );
    expect(c?.type, ConfrontationType.c12);
    expect(c?.targetSeat, 2);
    expect(c?.evidenceSeat, 5);
  });

  test('C12 never fires on a right accusation, or for a dead accuser', () {
    expect(
      pick(
        const [
          DayRecord(dayNumber: 1, openingAccusations: {2: 5}),
          DayRecord(dayNumber: 2, eliminated: 5, eliminatedWasMafia: true),
        ],
        {0, 1, 2, 3, 4, 6},
        3,
      )?.type,
      isNot(ConfrontationType.c12),
    );
    expect(
      pick(
        const [
          DayRecord(dayNumber: 1, openingAccusations: {2: 5}),
          DayRecord(dayNumber: 2, eliminated: 5, eliminatedWasMafia: false),
        ],
        {0, 1, 3, 4, 6},
        3,
      ),
      isNull,
    );
  });

  test('C13: whispered yesterday to tonight\'s victim', () {
    final c = pick(
      const [
        DayRecord(
          dayNumber: 1,
          whispers: [
            WhisperMeta(id: 'w:1:1:4', day: 1, fromSeat: 1, toSeat: 4),
          ],
        ),
      ],
      {0, 1, 2, 3, 5, 6},
      2,
      nights: [night(1), night(2, victim: 4)],
    );
    expect(c?.type, ConfrontationType.c13);
    expect(c?.targetSeat, 1);
  });

  test('C13 needs last night to be tonight\'s: an old death is not news', () {
    final c = pick(
      const [
        DayRecord(
          dayNumber: 1,
          whispers: [
            WhisperMeta(id: 'w:1:1:4', day: 1, fromSeat: 1, toSeat: 4),
          ],
        ),
        DayRecord(dayNumber: 2),
      ],
      {0, 1, 2, 3, 5, 6},
      3,
      nights: [night(1), night(2, victim: 4)],
    );
    expect(c?.type, isNot(ConfrontationType.c13));
  });

  test('C14: whispered to a Mafioso voted out', () {
    final c = pick(
      const [
        DayRecord(dayNumber: 1, whispers: [w14]),
        DayRecord(dayNumber: 2, eliminated: 6, eliminatedWasMafia: true),
      ],
      {0, 1, 2, 3, 4, 5},
      3,
    );
    expect(c?.type, ConfrontationType.c14);
    expect(c?.targetSeat, 3);
    expect(c?.evidenceSeat, 6);
  });

  test('the whisper types stay off when whispers are off', () {
    final c = pick(
      const [
        DayRecord(dayNumber: 1, whispers: [w14]),
        DayRecord(dayNumber: 2, eliminated: 6, eliminatedWasMafia: true),
      ],
      {0, 1, 2, 3, 4, 5},
      3,
      settings: const MatchSettings(),
    );
    expect(c, isNull);
  });

  test('the silenced seat is never asked; another may be', () {
    const days = [
      DayRecord(
        dayNumber: 1,
        openingAccusations: {3: 5, 4: 6},
        votes: {3: 2, 4: 1},
      ),
    ];
    const all = {0, 1, 2, 3, 4, 5, 6};
    for (final silenced in [3, 4]) {
      final c = pick(days, all, 2, silenced: silenced);
      expect(c?.targetSeat, isNot(silenced));
      expect(c, isNotNull);
    }
  });

  group('the words', () {
    String? say(
      ConfrontationType type, {
      bool female = false,
      bool xFemale = false,
    }) => InformationText.confrontation(
      arStrings,
      Confrontation(type: type, targetSeat: 2, evidenceSeat: 5),
      const {2: 'سارة', 5: 'منى'},
      female: female,
      isFemale: (seat) => seat == 5 && xFemale,
    );

    test('each new type names the other seat and fits both genders', () {
      for (final type in [
        ConfrontationType.c12,
        ConfrontationType.c13,
        ConfrontationType.c14,
      ]) {
        final m = say(type)!;
        final f = say(type, female: true, xFemale: true)!;
        expect(m, contains('منى'));
        expect(f, contains('منى'));
        expect(f, isNot(m));
      }
      expect(say(ConfrontationType.c13, xFemale: true), contains('اتقتلت'));
      expect(say(ConfrontationType.c13), contains('اتقتل '));
      expect(say(ConfrontationType.c14, xFemale: true), contains('طلعت مافيا'));
    });

    test('a name that is gone says nothing rather than half a sentence', () {
      expect(
        InformationText.confrontation(
          arStrings,
          const Confrontation(
            type: ConfrontationType.c14,
            targetSeat: 2,
            evidenceSeat: 9,
          ),
          const {2: 'سارة'},
        ),
        isNull,
      );
    });
  });
}
