import 'package:flutter_test/flutter_test.dart';
import '../../lib/platform/monetization/ad_placement_registry.dart';
import '../../lib/platform/monetization/ad_policy.dart';
import '../../lib/platform/monetization/ad_session.dart';

void main() {
  const now = 1800000000000;
  AdRegistryV4 registry() => AdRegistryV4.fromJson({
    'version': 4,
    'enabled': true,
    'revision': 1,
    'ttlSeconds': 86400,
    'placements': [
      for (var i = 0; i < adInventoryV4.length; i++)
        {
          'id': adInventoryV4[i].id,
          'format': adInventoryV4[i].format.name,
          'platform': 'android',
          'enabled': true,
          'unitId': 'ca-app-pub-9179063936085117/${(1000000000 + i)}',
        },
    ],
  }, now);
  AdContextV4 context(
    AdPlacementV4 p, {
    bool busy = false,
    bool consent = true,
    AdEntitlementV4 entitlement = AdEntitlementV4.free,
    int launches = 3,
  }) => AdContextV4(
    surface: p.surface,
    android: true,
    foreground: true,
    busy: busy,
    consent: consent,
    contentReady: true,
    onboarded: true,
    entitlement: entitlement,
    launches: launches,
    completedMatches: 2,
    routeGeneration: 1,
    loadedAtMs: now,
    backgroundedAtMs: now - 14400000,
    optIn: true,
    eligibleClaim: true,
    explicitHomeExit: true,
  );
  test('all 24 placements fail closed across shared denied states', () {
    expect(adInventoryV4.length, 24);
    for (final p in adInventoryV4) {
      expect(
        decideAdV4(p, registry(), context(p), const AdLedgerV4(), now),
        AdVerdictV4.show,
      );
      expect(
        decideAdV4(p, AdRegistryV4.off, context(p), const AdLedgerV4(), now),
        AdVerdictV4.disabled,
      );
      expect(
        decideAdV4(
          p,
          registry(),
          context(p, busy: true),
          const AdLedgerV4(),
          now,
        ),
        AdVerdictV4.busy,
      );
      expect(
        decideAdV4(
          p,
          registry(),
          context(p, consent: false),
          const AdLedgerV4(),
          now,
        ),
        AdVerdictV4.consent,
      );
      expect(
        decideAdV4(
          p,
          registry(),
          context(p, entitlement: AdEntitlementV4.unknown),
          const AdLedgerV4(),
          now,
        ),
        AdVerdictV4.entitlementUnknown,
      );
    }
  });
  test('automatic grace, exact cooldown and restart rollback', () {
    final p = adInventoryV4[8];
    expect(
      decideAdV4(
        p,
        registry(),
        context(p, launches: 2),
        const AdLedgerV4(),
        now,
      ),
      AdVerdictV4.grace,
    );
    final ledger = AdLedgerV4.fromJson(
      const AdLedgerV4(highWaterMs: now, lastDismissMs: now - 299999).toJson(),
    );
    expect(
      decideAdV4(p, registry(), context(p), ledger, now - 86400000),
      AdVerdictV4.gap,
    );
    expect(
      decideAdV4(
        p,
        registry(),
        context(p),
        const AdLedgerV4(lastDismissMs: now - 300000),
        now,
      ),
      AdVerdictV4.show,
    );
    expect(
      decideAdV4(
        p,
        registry(),
        context(p),
        const AdLedgerV4(automaticShows: [now - 1, now - 2]),
        now,
      ),
      AdVerdictV4.cap,
    );
  });
  test('late load, stale revision, bounded loads and fullscreen ownership', () {
    final s = AdSessionV4();
    final r = registry();
    final first = s.beginLoad(adInventoryV4[0], r)!;
    final second = s.beginLoad(adInventoryV4[6], r)!;
    expect(s.beginLoad(adInventoryV4[7], r), isNull);
    expect(s.finishLoad(first, r), isTrue);
    expect(s.acquireFullscreen(first, r), isTrue);
    expect(s.acquireFullscreen(second, r), isFalse);
    s.invalidate();
    expect(s.finishLoad(second, r), isFalse);
    expect(s.fullscreenBusy, isTrue);
    s.releaseFullscreen(second);
    expect(s.fullscreenBusy, isTrue);
    s.releaseFullscreen(first);
    expect(s.fullscreenBusy, isFalse);
    expect(s.acquireFullscreen(first, r), isFalse);
  });
  test('missing and malformed capabilities are disabled', () {
    for (final raw in [
      null,
      {},
      {'version': 4, 'enabled': true, 'revision': '1'},
    ]) {
      expect(AdRegistryV4.fromJson(raw, now).units, isEmpty);
    }
  });
}
