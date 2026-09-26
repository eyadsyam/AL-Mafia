import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transport/online_backend.dart';

import '../../platform/monetization/app_open_policy.dart';
import '../../platform/monetization/interstitial_policy.dart';
import '../screens/online/online_session.dart';

/// A Play product the server says is on sale. The price is never here: it
/// comes from Google Play's own product details, localized.
class PlayProductOffer {
  final String id;
  final bool consumable;
  final int? coins;
  final String? entitlement;

  /// coins, entitlement or undle (the Starter Bundle: coins and a
  /// cosmetic, bought once and never consumed).
  final String kind;

  /// The cosmetic a bundle grants.
  final String? item;
  const PlayProductOffer({
    required this.id,
    required this.consumable,
    this.coins,
    this.entitlement,
    this.kind = 'coins',
    this.item,
  });

  bool get bundle => kind == 'bundle';
}

/// Council Life (phase 107), each switched on by the server alone.
class CouncilCapabilities {
  final bool contracts;
  final bool rank;
  final bool leaderboard;
  final bool invites;
  final bool starterBundle;
  final bool starterBundleOwned;
  const CouncilCapabilities({
    this.contracts = false,
    this.rank = false,
    this.leaderboard = false,
    this.invites = false,
    this.starterBundle = false,
    this.starterBundleOwned = false,
  });

  static const off = CouncilCapabilities();

  factory CouncilCapabilities.fromJson(Object? json) {
    if (json is! Map) return off;
    bool flag(String key) => json[key] == true;
    return CouncilCapabilities(
      contracts: flag('contracts'),
      rank: flag('rank'),
      leaderboard: flag('leaderboard'),
      invites: flag('invites'),
      starterBundle: flag('starterBundle'),
      starterBundleOwned: flag('starterBundleOwned'),
    );
  }

  /// Whether the vault shows the Council tab at all.
  bool get hub => contracts || rank || invites;
}

/// Phase 109, each switched on by the server alone. An older server has no
/// `fun` key: everything off.
class FunCapabilities {
  final bool awards;
  final bool reactions;
  final bool founder;

  /// The server answers the phase-109 actions at all (it sent the key).
  final bool known;
  const FunCapabilities({
    this.awards = false,
    this.reactions = false,
    this.founder = false,
    this.known = false,
  });

  static const off = FunCapabilities();

  factory FunCapabilities.fromJson(Object? json) {
    if (json is! Map) return off;
    return FunCapabilities(
      awards: json['awards'] == true,
      reactions: json['reactions'] == true,
      founder: json['founder'] == true,
      known: true,
    );
  }
}

/// Ads v2 (phase 108), each switched on by the server alone. Missing (an
/// older server) is all off.
class AdsCapabilities {
  final AppOpenRules appOpen;
  final bool banner;
  final bool extraSpin;
  final bool extraCoffer;
  final bool extraSwap;
  const AdsCapabilities({
    this.appOpen = AppOpenRules.off,
    this.banner = false,
    this.extraSpin = false,
    this.extraCoffer = false,
    this.extraSwap = false,
  });

  static const off = AdsCapabilities();

  factory AdsCapabilities.fromJson(Object? json) {
    if (json is! Map) return off;
    final banner = json['banner'];
    final extras = json['extras'];
    bool extra(String key) => extras is Map && extras[key] == true;
    return AdsCapabilities(
      appOpen: AppOpenRules.fromJson(json['appOpen']),
      banner: banner is Map && banner['enabled'] == true,
      extraSpin: extra('spin'),
      extraCoffer: extra('coffer'),
      extraSwap: extra('swap'),
    );
  }

  bool get extras => extraSpin || extraCoffer || extraSwap;
}

/// What this server supports for 1.0.1, negotiated once per session.
///
/// Every field defaults to off. A server without the 1.0.1 migration answers
/// the `capabilities` action with BAD_REQUEST, and this build then behaves
/// exactly like 1.0.0: one post-match ad, no daily rewards, no automatic ad,
/// no Play purchases.
class EconomyCapabilities {
  final bool adSteps;
  final bool daily;
  final bool dailyAd;
  final bool adFree;
  final bool recoverable;
  final String? accountTag;
  final InterstitialRules interstitial;
  final List<PlayProductOffer> products;
  final CouncilCapabilities council;
  final AdsCapabilities ads;

  /// Phase 109: awards, reactions, the Founder badge.
  final FunCapabilities fun;

  /// Purchased coins still owed after an earlier refund; the next coin pack
  /// pays this first. Disclosed before Buy.
  final int purchaseDebt;

  /// The server could not be asked. Read as all off, but not remembered for
  /// the session: the next store open or resume asks again.
  final bool failed;

  const EconomyCapabilities({
    this.adSteps = false,
    this.daily = false,
    this.dailyAd = false,
    this.adFree = false,
    this.recoverable = false,
    this.accountTag,
    this.interstitial = InterstitialRules.off,
    this.products = const [],
    this.council = CouncilCapabilities.off,
    this.ads = AdsCapabilities.off,
    this.fun = FunCapabilities.off,
    this.purchaseDebt = 0,
    this.failed = false,
  });

  static const none = EconomyCapabilities();
  static const unreachable = EconomyCapabilities(failed: true);

  factory EconomyCapabilities.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version < 2) return none;
    bool flag(String key) => json[key] == true;
    final rules = json['interstitial'];
    return EconomyCapabilities(
      adSteps: flag('adSteps'),
      daily: flag('daily'),
      dailyAd: flag('dailyAd'),
      adFree: flag('adFree'),
      recoverable: flag('recoverable'),
      accountTag: json['accountTag'] is String
          ? json['accountTag'] as String
          : null,
      purchaseDebt: (json['purchaseDebt'] as num?)?.toInt() ?? 0,
      council: CouncilCapabilities.fromJson(json['council']),
      ads: AdsCapabilities.fromJson(json['ads']),
      fun: FunCapabilities.fromJson(json['fun']),
      interstitial: rules is Map
          ? InterstitialRules.fromJson(Map<String, dynamic>.from(rules))
          : InterstitialRules.off,
      products: [
        for (final row in (json['products'] as List?) ?? const [])
          if (row is Map && row['id'] is String)
            PlayProductOffer(
              id: row['id'] as String,
              consumable: row['kind'] == 'coins',
              coins: (row['coins'] as num?)?.toInt(),
              entitlement: row['entitlement'] as String?,
              kind: row['kind'] as String? ?? 'coins',
              item: row['item'] as String?,
            ),
      ],
    );
  }
}

/// Off on any failure: no network, no online configuration, an old server.
final economyCapabilitiesProvider = FutureProvider<EconomyCapabilities>((
  ref,
) async {
  // An old server's BAD_REQUEST is an answer (none, kept); a network failure
  // is not, and is asked again on the next vault open or app resume.
  try {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final json = await backend.call('economy', {'action': 'capabilities'});
    return EconomyCapabilities.fromJson(json);
  } on BackendException catch (error) {
    // An old server does not know the action: that is its answer.
    if (error.code == 'BAD_REQUEST') return EconomyCapabilities.none;
    return EconomyCapabilities.unreachable;
  } catch (_) {
    return EconomyCapabilities.unreachable;
  }
});

/// Asks again if the last read could not reach the server. Called when the
/// vault opens and when the app returns to the foreground.
void retryCapabilitiesIfFailed(WidgetRef ref) {
  if (ref.read(economyCapabilitiesProvider).valueOrNull?.failed ?? false) {
    ref.invalidate(economyCapabilitiesProvider);
  }
}
