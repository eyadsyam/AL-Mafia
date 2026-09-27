import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/character_bonds.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CharacterBondCase caseOne({String id = 'match-1'}) => CharacterBondCase(
    receiptId: id,
    completedAt: DateTime.utc(2026, 9, 28),
    winner: Alignment.town,
    roles: Role.values.toSet(),
    survivingRoles: const {Role.doctor, Role.citizen},
    personalRole: Role.detective,
    momentRole: Role.detective,
  );

  test('one public result advances every role and only matching facts', () {
    final ledger = progressCharacterBonds(CharacterBondLedger.empty, caseOne());

    expect(ledger.bond(Role.mafia).cases, 1);
    expect(ledger.bond(Role.mafia).victories, 0);
    expect(ledger.bond(Role.doctor).victories, 1);
    expect(ledger.bond(Role.doctor).witnesses, 1);
    expect(ledger.bond(Role.detective).personal, 1);
    expect(ledger.bond(Role.detective).witnesses, 0);
  });

  test('a repeated receipt is the same immutable ledger', () {
    final once = progressCharacterBonds(CharacterBondLedger.empty, caseOne());
    final twice = progressCharacterBonds(once, caseOne());

    expect(identical(once, twice), isTrue);
    expect(twice.bond(Role.citizen).cases, 1);
  });

  test('tiers unlock at 1, 3, 7 and 15 cases', () {
    CharacterBondLedger ledger = CharacterBondLedger.empty;
    for (var i = 1; i <= 15; i++) {
      ledger = progressCharacterBonds(ledger, caseOne(id: 'match-$i'));
      if (i == 1) expect(ledger.bond(Role.mafia).tier, 1);
      if (i == 3) expect(ledger.bond(Role.mafia).tier, 2);
      if (i == 7) expect(ledger.bond(Role.mafia).tier, 3);
      if (i == 15) expect(ledger.bond(Role.mafia).tier, 4);
    }
  });

  test('versioned JSON round-trips and rejects a future version', () {
    final ledger = progressCharacterBonds(CharacterBondLedger.empty, caseOne());
    final decoded = CharacterBondLedger.fromJson(
      jsonDecode(jsonEncode(ledger.toJson())),
    );
    expect(decoded.bond(Role.detective).personal, 1);
    expect(decoded.receipts.keys, ['match-1']);

    final future = Map<String, Object>.from(ledger.toJson())..['version'] = 99;
    expect(CharacterBondLedger.fromJson(future).isEmpty, isTrue);
  });

  test('corrupt local storage becomes an empty ledger', () async {
    SharedPreferences.setMockInitialValues({
      CharacterBondStore.storageKey: '{not-json',
    });
    expect((await CharacterBondStore().load()).isEmpty, isTrue);
  });

  test('store persists one receipt and reloads it', () async {
    final ledger = progressCharacterBonds(CharacterBondLedger.empty, caseOne());
    await CharacterBondStore().save(ledger);
    final loaded = await CharacterBondStore().load();
    expect(loaded.receipts.keys, ['match-1']);
    expect(loaded.bond(Role.doctor).witnesses, 1);
  });

  test('home voice is deterministic from completed facts and clock', () {
    final quiet = CharacterBondCase(
      receiptId: 'quiet',
      completedAt: DateTime.utc(2026, 9, 28),
      winner: Alignment.town,
      roles: Role.values.toSet(),
      survivingRoles: Role.values.toSet(),
      momentRole: Role.doctor,
      zeroDeaths: true,
    );
    final ledger = progressCharacterBonds(CharacterBondLedger.empty, quiet);
    expect(
      homeBondVoice(
        ledger,
        DateTime.utc(2026, 9, 29),
        inactiveAfter: const Duration(days: 3),
      ),
      Role.doctor,
    );
    expect(
      homeBondVoice(
        ledger,
        DateTime.utc(2026, 10, 2),
        inactiveAfter: const Duration(days: 3),
      ),
      Role.detective,
    );
  });

  test('the first case opens a letter, favouring the player role', () {
    final after = progressCharacterBonds(CharacterBondLedger.empty, caseOne());
    final arrival = letterArrived(CharacterBondLedger.empty, after, caseOne());
    expect(arrival?.role, Role.detective);
    expect(arrival?.tier, 1);
    expect(arrival?.receiptId, 'match-1');
  });

  test('a case that crosses no threshold opens nothing', () {
    final one = progressCharacterBonds(CharacterBondLedger.empty, caseOne());
    final two = progressCharacterBonds(one, caseOne(id: 'match-2'));
    // Tier 2 needs three cases; the second case opens no letter.
    expect(letterArrived(one, two, caseOne(id: 'match-2')), isNull);
    final three = progressCharacterBonds(two, caseOne(id: 'match-3'));
    expect(letterArrived(two, three, caseOne(id: 'match-3'))?.tier, 2);
  });

  test('tier thresholds are 1, 3, 7 and 15 cases', () {
    expect(const CharacterBond(cases: 0).tier, 0);
    expect(const CharacterBond(cases: 1).tier, 1);
    expect(const CharacterBond(cases: 6).tier, 2);
    expect(const CharacterBond(cases: 7).tier, 3);
    expect(const CharacterBond(cases: 15).tier, 4);
    expect(const CharacterBond(cases: 5).casesToNextTier, 2);
    expect(const CharacterBond(cases: 40).casesToNextTier, isNull);
  });
}
