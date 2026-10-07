import '../../core/theme/design_tokens.dart';

/// Public inventory only. No role, seat or match-secret data belongs here.
enum AdFormatV4 { rewarded, appOpen, interstitial, banner, native }

class AdPlacementV4 {
  final String id;
  final AdFormatV4 format;
  final String surface;
  const AdPlacementV4(this.id, this.format, this.surface);
  bool get fullscreen =>
      format != AdFormatV4.banner && format != AdFormatV4.native;
  bool get automatic =>
      format == AdFormatV4.appOpen || format == AdFormatV4.interstitial;
}

const adInventoryV4 = <AdPlacementV4>[
  AdPlacementV4('reward_match_double', AdFormatV4.rewarded, 'online_result'),
  AdPlacementV4('reward_match_triple', AdFormatV4.rewarded, 'online_result'),
  AdPlacementV4('reward_daily', AdFormatV4.rewarded, 'vault_rewards'),
  AdPlacementV4('reward_spin', AdFormatV4.rewarded, 'vault_rewards'),
  AdPlacementV4('reward_coffer', AdFormatV4.rewarded, 'vault_rewards'),
  AdPlacementV4('reward_swap', AdFormatV4.rewarded, 'council_contracts'),
  AdPlacementV4('open_cold', AdFormatV4.appOpen, 'launch'),
  AdPlacementV4('open_resume', AdFormatV4.appOpen, 'resume_loading'),
  AdPlacementV4(
    'interstitial_online_result',
    AdFormatV4.interstitial,
    'completed_online_exit',
  ),
  AdPlacementV4(
    'interstitial_local_result',
    AdFormatV4.interstitial,
    'completed_local_exit',
  ),
  AdPlacementV4('banner_home', AdFormatV4.banner, 'home'),
  AdPlacementV4('banner_online_hub', AdFormatV4.banner, 'online_hub'),
  AdPlacementV4('banner_history', AdFormatV4.banner, 'history'),
  AdPlacementV4('banner_vault', AdFormatV4.banner, 'vault'),
  AdPlacementV4('banner_cosmetics', AdFormatV4.banner, 'cosmetics'),
  AdPlacementV4('banner_profile', AdFormatV4.banner, 'profile'),
  AdPlacementV4('banner_casebook', AdFormatV4.banner, 'casebook'),
  AdPlacementV4('native_home', AdFormatV4.native, 'home'),
  AdPlacementV4('native_online_hub', AdFormatV4.native, 'online_hub'),
  AdPlacementV4('native_history', AdFormatV4.native, 'history'),
  AdPlacementV4('native_vault', AdFormatV4.native, 'vault'),
  AdPlacementV4('native_characters', AdFormatV4.native, 'characters'),
  AdPlacementV4('native_casebook', AdFormatV4.native, 'casebook'),
  AdPlacementV4('native_council', AdFormatV4.native, 'council'),
];

class AdRegistryV4 {
  final int revision;
  final int expiresAtMs;
  final Map<String, String> units;
  const AdRegistryV4._(this.revision, this.expiresAtMs, this.units);
  static const off = AdRegistryV4._(0, 0, {});

  factory AdRegistryV4.fromJson(Object? raw, int receivedAtMs) {
    if (raw is! Map || raw['version'] != 4 || raw['enabled'] != true) {
      return off;
    }
    final revision = raw['revision'];
    final ttl = raw['ttlSeconds'];
    final rows = raw['placements'];
    if (revision is! int ||
        revision <= 0 ||
        ttl is! int ||
        ttl <= 0 ||
        ttl > AdV4Tokens.configTtl.inSeconds ||
        rows is! List) {
      return off;
    }
    final units = <String, String>{};
    final seen = <String>{};
    final ids = <String>{};
    for (final row in rows) {
      if (row is! Map ||
          row['id'] is! String ||
          !ids.add(row['id'] as String)) {
        return off;
      }
      final matches = adInventoryV4.where((p) => p.id == row['id']);
      if (matches.isEmpty) return off;
      if (row['enabled'] != true) continue;
      final placement = matches.single;
      final unit = row['unitId'];
      if (row['platform'] != 'android' ||
          row['format'] != placement.format.name ||
          unit is! String ||
          !unit.startsWith('ca-app-pub-' '91790639' '36085117/') ||
          !RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(unit) ||
          !seen.add(unit)) {
        return off;
      }
      units[placement.id] = unit;
    }
    return AdRegistryV4._(
      revision,
      receivedAtMs + ttl * 1000,
      Map.unmodifiable(units),
    );
  }
}
