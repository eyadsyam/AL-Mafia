import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/models/enums.dart';

const characterBondLedgerVersion = 1;

/// Cases at a character's table that open each of its four letters.
const bondTierThresholds = [1, 3, 7, 15];

/// Progress for one of the four characters. Flavour only: none of these
/// counters is currency, an entitlement, or an input to match setup.
class CharacterBond {
  final int cases;
  final int victories;
  final int witnesses;
  final int personal;

  const CharacterBond({
    this.cases = 0,
    this.victories = 0,
    this.witnesses = 0,
    this.personal = 0,
  });

  int get tier => bondTierThresholds.where((need) => cases >= need).length;

  /// Cases still needed for the next letter, or null once all four are open.
  int? get casesToNextTier => tier >= bondTierThresholds.length
      ? null
      : bondTierThresholds[tier] - cases;

  CharacterBond add({
    int cases = 0,
    int victories = 0,
    int witnesses = 0,
    int personal = 0,
  }) => CharacterBond(
    cases: this.cases + cases,
    victories: this.victories + victories,
    witnesses: this.witnesses + witnesses,
    personal: this.personal + personal,
  );

  Map<String, Object> toJson() => {
    'cases': cases,
    'victories': victories,
    'witnesses': witnesses,
    'personal': personal,
  };

  static CharacterBond fromJson(Object? value) {
    if (value is! Map) return const CharacterBond();
    int count(String key) {
      final raw = value[key];
      return raw is num && raw >= 0 ? raw.toInt() : 0;
    }

    return CharacterBond(
      cases: count('cases'),
      victories: count('victories'),
      witnesses: count('witnesses'),
      personal: count('personal'),
    );
  }
}

/// A public, completed result distilled to the only facts the dossiers use.
class CharacterBondCase {
  final String receiptId;
  final DateTime completedAt;
  final Alignment winner;
  final Set<Role> roles;
  final Set<Role> survivingRoles;
  final Role? personalRole;
  final bool zeroDeaths;
  final Role momentRole;

  const CharacterBondCase({
    required this.receiptId,
    required this.completedAt,
    required this.winner,
    required this.roles,
    required this.survivingRoles,
    required this.momentRole,
    this.personalRole,
    this.zeroDeaths = false,
  });

  Map<String, Object?> toJson() => {
    'receiptId': receiptId,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'winner': winner.name,
    'roles': roles.map((role) => role.name).toList(),
    'survivingRoles': survivingRoles.map((role) => role.name).toList(),
    'personalRole': personalRole?.name,
    'zeroDeaths': zeroDeaths,
    'momentRole': momentRole.name,
  };

  static CharacterBondCase? fromJson(Object? value) {
    if (value is! Map || value['receiptId'] is! String) return null;
    final completedAt = DateTime.tryParse(
      value['completedAt'] as String? ?? '',
    );
    final winner = Alignment.values
        .where((item) => item.name == value['winner'])
        .firstOrNull;
    final moment = Role.values
        .where((item) => item.name == value['momentRole'])
        .firstOrNull;
    Set<Role> rolesOf(Object? raw) => raw is List
        ? raw
              .whereType<String>()
              .map(
                (name) =>
                    Role.values.where((item) => item.name == name).firstOrNull,
              )
              .whereType<Role>()
              .toSet()
        : <Role>{};
    final roles = rolesOf(value['roles']);
    if (completedAt == null ||
        winner == null ||
        moment == null ||
        roles.isEmpty) {
      return null;
    }
    final personal = Role.values
        .where((item) => item.name == value['personalRole'])
        .firstOrNull;
    return CharacterBondCase(
      receiptId: value['receiptId'] as String,
      completedAt: completedAt,
      winner: winner,
      roles: roles,
      survivingRoles: rolesOf(value['survivingRoles']),
      personalRole: personal,
      zeroDeaths: value['zeroDeaths'] == true,
      momentRole: moment,
    );
  }
}

class CharacterBondLedger {
  final Map<Role, CharacterBond> bonds;
  final Map<String, CharacterBondCase> receipts;

  const CharacterBondLedger({this.bonds = const {}, this.receipts = const {}});

  static const empty = CharacterBondLedger();

  bool get isEmpty => receipts.isEmpty;
  CharacterBond bond(Role role) => bonds[role] ?? const CharacterBond();

  CharacterBondCase? get lastCase {
    CharacterBondCase? latest;
    for (final item in receipts.values) {
      if (latest == null || item.completedAt.isAfter(latest.completedAt)) {
        latest = item;
      }
    }
    return latest;
  }

  Map<String, Object> toJson() => {
    'version': characterBondLedgerVersion,
    'bonds': {for (final role in Role.values) role.name: bond(role).toJson()},
    'receipts': {
      for (final entry in receipts.entries) entry.key: entry.value.toJson(),
    },
  };

  static CharacterBondLedger fromJson(Object? value) {
    if (value is! Map || value['version'] != characterBondLedgerVersion) {
      return empty;
    }
    final rawBonds = value['bonds'];
    final rawReceipts = value['receipts'];
    final bonds = <Role, CharacterBond>{};
    if (rawBonds is Map) {
      for (final role in Role.values) {
        bonds[role] = CharacterBond.fromJson(rawBonds[role.name]);
      }
    }
    final receipts = <String, CharacterBondCase>{};
    if (rawReceipts is Map) {
      for (final entry in rawReceipts.entries) {
        if (entry.key is! String) continue;
        final parsed = CharacterBondCase.fromJson(entry.value);
        if (parsed != null && parsed.receiptId == entry.key) {
          receipts[entry.key as String] = parsed;
        }
      }
    }
    return CharacterBondLedger(
      bonds: Map.unmodifiable(bonds),
      receipts: Map.unmodifiable(receipts),
    );
  }
}

/// Pure progression: applying the same public-result receipt twice is a no-op.
CharacterBondLedger progressCharacterBonds(
  CharacterBondLedger current,
  CharacterBondCase completed,
) {
  if (completed.receiptId.isEmpty ||
      completed.roles.isEmpty ||
      current.receipts.containsKey(completed.receiptId)) {
    return current;
  }
  final bonds = Map<Role, CharacterBond>.from(current.bonds);
  for (final role in completed.roles) {
    final won = role.alignment == completed.winner;
    bonds[role] = current
        .bond(role)
        .add(
          cases: 1,
          victories: won ? 1 : 0,
          witnesses: completed.survivingRoles.contains(role) ? 1 : 0,
          personal: completed.personalRole == role ? 1 : 0,
        );
  }
  return CharacterBondLedger(
    bonds: Map.unmodifiable(bonds),
    receipts: Map.unmodifiable({
      ...current.receipts,
      completed.receiptId: completed,
    }),
  );
}

Role characterMomentRole({
  required Alignment winner,
  required Set<Role> roles,
  required Set<Role> survivingRoles,
  Role? personalRole,
  bool zeroDeaths = false,
}) {
  if (personalRole != null && roles.contains(personalRole)) return personalRole;
  if (zeroDeaths && roles.contains(Role.doctor)) return Role.doctor;
  if (winner == Alignment.mafia && roles.contains(Role.mafia))
    return Role.mafia;
  if (survivingRoles.contains(Role.detective)) return Role.detective;
  if (roles.contains(Role.citizen)) return Role.citizen;
  return roles.first;
}

Role homeBondVoice(
  CharacterBondLedger ledger,
  DateTime now, {
  required Duration inactiveAfter,
}) {
  final last = ledger.lastCase;
  if (last == null) return Role.citizen;
  if (now.difference(last.completedAt) >= inactiveAfter) {
    return Role.detective;
  }
  if (last.zeroDeaths && last.roles.contains(Role.doctor)) return Role.doctor;
  if (last.winner == Alignment.mafia && last.roles.contains(Role.mafia)) {
    return Role.mafia;
  }
  return Role.citizen;
}

class CharacterBondStore {
  static const storageKey = 'mafia.characterBonds.v1';

  Future<CharacterBondLedger> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return CharacterBondLedger.empty;
      return CharacterBondLedger.fromJson(jsonDecode(raw));
    } catch (_) {
      return CharacterBondLedger.empty;
    }
  }

  Future<void> save(CharacterBondLedger ledger) async {
    final ok = await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(ledger.toJson()),
    );
    if (!ok) throw StateError('Character bond storage unavailable');
  }
}

final characterBondClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
final characterBondStoreProvider = Provider((ref) => CharacterBondStore());

final characterBondLedgerProvider =
    AsyncNotifierProvider<CharacterBondController, CharacterBondLedger>(
      CharacterBondController.new,
    );

class CharacterBondController extends AsyncNotifier<CharacterBondLedger> {
  @override
  Future<CharacterBondLedger> build() =>
      ref.read(characterBondStoreProvider).load();

  Future<bool> record(CharacterBondCase completed) async {
    final current = state.valueOrNull ?? await future;
    final next = progressCharacterBonds(current, completed);
    if (identical(next, current)) return false;
    await ref.read(characterBondStoreProvider).save(next);
    state = AsyncData(next);
    return true;
  }
}
