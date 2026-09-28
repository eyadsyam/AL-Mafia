import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/request_id.dart';
import '../../transport/online_backend.dart';
import '../account/account_sheet.dart';
import '../economy/economy_capabilities.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// F10 — titles and the core Partner (data, providers and minimal hooks).
///
/// Where these may appear is part of the contract (spec §4 F10): titles on
/// Profile, the Casebook, the pre-deal lobby plate and the public result;
/// the Partner on Home, dossiers, the Casebook header and the post-result
/// line. Neither is ever imported by a hand-off, reveal, night or live-seat
/// surface (test/golden/leakage/handoff_purity_test.dart walks the imports).

// ── Titles ──────────────────────────────────────────────────────────────────

class TitleEntry {
  final String code;
  final String source;
  final String nameAr;
  final String nameEn;
  final bool owned;
  const TitleEntry({
    required this.code,
    required this.source,
    required this.nameAr,
    required this.nameEn,
    required this.owned,
  });

  String name(Locale locale) => locale.languageCode == 'ar' ? nameAr : nameEn;

  static TitleEntry? fromJson(Object? json) {
    if (json is! Map || json['code'] is! String) return null;
    return TitleEntry(
      code: json['code'] as String,
      source: json['source'] as String? ?? '',
      nameAr: json['nameAr'] as String? ?? '',
      nameEn: json['nameEn'] as String? ?? '',
      owned: json['owned'] == true,
    );
  }
}

/// `titleHub → {enabled,equipped,titles[]}`.
class TitleHub {
  final bool enabled;
  final String? equipped;
  final List<TitleEntry> titles;
  const TitleHub({this.enabled = false, this.equipped, this.titles = const []});

  static const off = TitleHub();

  List<TitleEntry> get owned => [for (final t in titles) if (t.owned) t];

  TitleEntry? get equippedTitle =>
      titles.where((t) => t.code == equipped && t.owned).firstOrNull;

  factory TitleHub.fromJson(Map<String, dynamic> json) {
    if (json['enabled'] != true) return off;
    return TitleHub(
      enabled: true,
      equipped: json['equipped'] as String?,
      titles: [
        for (final row in (json['titles'] as List?) ?? const [])
          ?TitleEntry.fromJson(row),
      ],
    );
  }
}

class TitleEquipFailed implements Exception {
  final String? code;
  const TitleEquipFailed(this.code);
}

final titleHubProvider = AsyncNotifierProvider<TitleHubController, TitleHub>(
  TitleHubController.new,
);

class TitleHubController extends AsyncNotifier<TitleHub> {
  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  @override
  Future<TitleHub> build() async {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.titles) return TitleHub.off;
    try {
      return TitleHub.fromJson(await _call({'action': 'titleHub'}));
    } catch (_) {
      return TitleHub.off;
    }
  }

  /// Equips [code] (null takes the title off). One request id per intent, so
  /// a retry after a lost response is the same equip, not a second one.
  Future<void> equip(String? code, {String? requestId}) async {
    final id = requestId ?? newRequestId();
    final Map<String, dynamic> answer;
    try {
      answer = await _call({'action': 'titleEquip', 'code': code, 'requestId': id});
    } on BackendException catch (error) {
      throw TitleEquipFailed(error.code);
    }
    if (answer['ok'] != true) throw TitleEquipFailed(answer['code'] as String?);
    final fresh = answer['state'];
    if (fresh is Map) {
      state = AsyncData(TitleHub.fromJson(Map<String, dynamic>.from(fresh)));
    }
  }
}

/// The equipped titles of a room's seats: `{seat: TitleEntry}`. Read only for
/// the pre-deal lobby plate and the public result; the server answers empty
/// while the room is being played.
Future<Map<int, TitleEntry>> fetchRoomTitles(
  OnlineBackend backend,
  String roomId,
) async {
  final answer = await backend.call('economy', {
    'action': 'roomTitles',
    'roomId': roomId,
  });
  final seats = answer['seats'];
  if (answer['enabled'] != true || seats is! Map) return const {};
  return {
    for (final entry in seats.entries)
      if (int.tryParse('${entry.key}') case final seat?)
        if (TitleEntry.fromJson({...?(entry.value as Map?), 'owned': true})
            case final title?)
          seat: title,
  };
}

// ── Partner ─────────────────────────────────────────────────────────────────

enum PartnerSide { detective, doctor, mafia, citizen }

PartnerSide? partnerSideFrom(Object? value) =>
    PartnerSide.values.where((s) => s.name == value).firstOrNull;

/// A guest's Partner lives on the device, versioned so a later format can be
/// read or dropped deliberately rather than misread.
class PartnerLocalStore {
  static const storageKey = 'partner_choice';
  static const version = 1;

  static Future<PartnerSide?> read() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map || json['v'] != version) return null;
      return partnerSideFrom(json['side']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(PartnerSide side) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        storageKey,
        jsonEncode({'v': version, 'side': side.name}),
      );
    } catch (_) {}
  }
}

class PartnerState {
  final bool enabled;
  final PartnerSide? side;
  const PartnerState({this.enabled = false, this.side});
}

class PartnerBusy implements Exception {
  const PartnerBusy();
}

final partnerProvider = AsyncNotifierProvider<PartnerController, PartnerState>(
  PartnerController.new,
);

/// The free Partner choice. Accounts keep it on the server (`player_partner`);
/// guests keep it on the device. Either way the switch is free and has no
/// grind; the server refuses it only while a match is being played.
class PartnerController extends AsyncNotifier<PartnerState> {
  Future<Map<String, dynamic>> _call(Map<String, Object?> body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    return backend.call('economy', body);
  }

  Future<bool> _account() async {
    try {
      return (await ref.read(accountProfileProvider.future)).signedIn;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<PartnerState> build() async {
    final caps = await ref.watch(economyCapabilitiesProvider.future);
    if (!caps.partner) return const PartnerState();
    final local = await PartnerLocalStore.read();
    if (!await _account()) return PartnerState(enabled: true, side: local);
    try {
      final answer = await _call({'action': 'partnerGet'});
      if (answer['enabled'] != true) return const PartnerState();
      return PartnerState(
        enabled: true,
        side: partnerSideFrom(answer['side']) ?? local,
      );
    } catch (_) {
      return PartnerState(enabled: true, side: local);
    }
  }

  /// Throws [PartnerBusy] while this account is seated in a live match.
  Future<void> choose(PartnerSide side, {String? requestId}) async {
    final current = state.valueOrNull;
    if (current == null || !current.enabled) return;
    if (await _account()) {
      final answer = await _call({
        'action': 'partnerSet',
        'side': side.name,
        'requestId': requestId ?? newRequestId(),
      });
      if (answer['ok'] != true) {
        if (answer['code'] == 'IN_MATCH') throw const PartnerBusy();
        return;
      }
    }
    await PartnerLocalStore.write(side);
    state = AsyncData(PartnerState(enabled: true, side: side));
  }
}

// ── Minimal hooks (the art lane styles these) ──────────────────────────────

/// The four portraits to pick from. Draws nothing while Partner is off.
class PartnerPicker extends ConsumerWidget {
  const PartnerPicker({super.key});

  static Key optionKey(PartnerSide side) => ValueKey('partner_${side.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProvider).valueOrNull;
    if (partner == null || !partner.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    final s = context.spacing;
    String label(PartnerSide side) => switch (side) {
      PartnerSide.detective => l.partnerDetective,
      PartnerSide.doctor => l.partnerDoctor,
      PartnerSide.mafia => l.partnerMafia,
      PartnerSide.citizen => l.partnerCitizen,
    };
    return Wrap(
      spacing: s.sm,
      runSpacing: s.sm,
      children: [
        for (final side in PartnerSide.values)
          // TODO(art): the gallery portrait for [side] replaces the chip.
          ChoiceChip(
            key: optionKey(side),
            label: Text(label(side)),
            selected: partner.side == side,
            onSelected: (_) async {
              try {
                await ref.read(partnerProvider.notifier).choose(side);
              } on PartnerBusy {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.partnerBusy)),
                  );
                }
              } catch (_) {}
            },
          ),
      ],
    );
  }
}

/// The owned titles with the equipped one marked. Draws nothing while off.
class TitleEquipList extends ConsumerWidget {
  const TitleEquipList({super.key});

  static Key titleKey(String code) => ValueKey('title_$code');
  static const Key noneKey = ValueKey('title_none');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(titleHubProvider).valueOrNull;
    if (hub == null || !hub.enabled) return const SizedBox.shrink();
    final l = context.l10n;
    final locale = Localizations.localeOf(context);
    final owned = hub.owned;
    if (owned.isEmpty) {
      return Text(
        l.titlesNone,
        style: context.typography.bodySmall.copyWith(
          color: context.colors.textMuted,
        ),
      );
    }
    Future<void> equip(String? code) async {
      try {
        await ref.read(titleHubProvider.notifier).equip(code);
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // TODO(art): the seal/plate treatment for each title row.
        ListTile(
          key: noneKey,
          title: Text(l.titlesUnequip),
          trailing: hub.equipped == null ? const Icon(Icons.check_rounded) : null,
          onTap: () => equip(null),
        ),
        for (final title in owned)
          ListTile(
            key: titleKey(title.code),
            title: Text(title.name(locale)),
            trailing: hub.equipped == title.code
                ? const Icon(Icons.check_rounded, color: VaultTokens.gold)
                : null,
            onTap: () => equip(title.code),
          ),
      ],
    );
  }
}
