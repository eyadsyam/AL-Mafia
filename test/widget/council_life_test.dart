import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/platform/invite_share.dart';
import 'package:mafia_master/platform/monetization/play_billing.dart';
import 'package:mafia_master/platform/monetization/purchase_store.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/council_art.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/play_offers.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/setup/coin_store.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// Phase 107 — Council Life on the client: gated by the server, claims name
/// the server's day, a level is celebrated once, the board honours the
/// player's choice, the Starter Bundle is bought once and never consumed.

Map<String, dynamic> caps({
  bool contracts = true,
  bool rank = true,
  bool leaderboard = true,
  bool invites = true,
  bool bundle = false,
  bool bundleOwned = false,
  bool daily = false,
  List<Map<String, Object?>> products = const [],
}) => {
  'version': 2,
  'adSteps': false,
  'daily': daily,
  'dailyAd': false,
  'recoverable': true,
  'accountTag': 'a' * 64,
  'adFree': false,
  'interstitial': {'enabled': false},
  'products': products,
  'council': {
    'contracts': contracts,
    'rank': rank,
    'leaderboard': leaderboard,
    'invites': invites,
    'starterBundle': bundle,
    'starterBundleOwned': bundleOwned,
  },
};

Map<String, dynamic> contracts({
  bool claimable = true,
  bool claimed = false,
  bool weeklyClaimable = false,
  List<Map<String, Object?>> levelUps = const [],
}) => {
  'enabled': true,
  'day': '2026-09-25',
  'contracts': [
    {
      'slot': 0,
      'code': 'finish_1',
      'metric': 'finish',
      'target': 1,
      'progress': claimable || claimed ? 1 : 0,
      'coins': 15,
      'claimed': claimed,
      'claimable': claimable && !claimed,
    },
    {
      'slot': 1,
      'code': 'finish_mafia',
      'metric': 'mafia',
      'target': 1,
      'progress': 0,
      'coins': 30,
      'claimed': false,
      'claimable': false,
    },
    {
      'slot': 2,
      'code': 'reunion_1',
      'metric': 'reunion',
      'target': 1,
      'progress': 0,
      'coins': 25,
      'claimed': false,
      'claimable': false,
    },
  ],
  'bonus': {'coins': 30, 'claimed': false, 'done': claimed ? 1 : 0},
  'weekly': {
    'week': '2026-W39',
    'target': 10,
    'progress': weeklyClaimable ? 10 : 4,
    'coins': 150,
    'xp': 150,
    'claimed': false,
    'claimable': weeklyClaimable,
  },
  'levelUps': levelUps,
};

Map<String, dynamic> rank({
  int xp = 240,
  int level = 2,
  bool visible = true,
  List<Map<String, Object?>> levelUps = const [],
}) => {
  'enabled': true,
  'xp': xp,
  'level': level,
  'tier': 1,
  'levelXp': 100 * (level - 1) + 10 * (level - 1) * (level - 2),
  'nextLevelXp': 100 * level + 10 * level * (level - 1),
  'nextReward': 25,
  'weekXp': 90,
  'leaderboardVisible': visible,
  'levelUps': levelUps,
};

Map<String, dynamic> invite({bool canRedeem = false}) => {
  'enabled': true,
  'code': 'K7QM2XA',
  'inviterCoins': 100,
  'inviteeCoins': 50,
  'cap': 20,
  'rewarded': 3,
  'pending': 1,
  'redeemed': null,
  'canRedeem': canRedeem,
};

class _Billing implements PlayBilling {
  final bought = <(String, bool)>[];
  final finished = <String>[];
  final events$ = StreamController<StorePurchaseEvent>.broadcast();
  @override
  bool get supported => true;
  @override
  Stream<StorePurchaseEvent> get events => events$.stream;
  @override
  Future<void> start() async {}
  @override
  Future<bool> available() async => true;
  @override
  Future<Map<String, PlayListing>> listings(Set<String> ids) async => {
    for (final id in ids) id: PlayListing(id: id, title: id, price: 'EGP 49.99'),
  };
  @override
  Future<bool> buy(
    String productId, {
    required bool consumable,
    required String accountTag,
  }) async {
    bought.add((productId, consumable));
    return true;
  }

  @override
  Future<void> restore() async {}
  @override
  Future<void> finishEntitlement(String token) async => finished.add(token);
  @override
  void dispose() {}
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(phase: 'result'),
      players: roster(5),
    );
  });

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    PlayBilling? billing,
    InviteSharer? sharer,
    Size size = const Size(390, 1400),
    Locale locale = const Locale('ar'),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          audioDirectorProvider.overrideWithValue(AudioDirector()),
          if (billing != null) playBillingProvider.overrideWithValue(billing),
          if (sharer != null) inviteSharerProvider.overrideWithValue(sharer),
        ],
        child: localizedApp(Scaffold(body: child), locale: locale),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
  }

  Iterable<Map<String, dynamic>> economyCalls(String action) => backend.calls
      .where((c) => c.function == 'economy' && c.body['action'] == action)
      .map((c) => c.body);

  group('gating', () {
    testWidgets('council off: no Council tab in the vault', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(contracts: false, rank: false, invites: false),
        _ => {'balance': 0, 'catalog': [], 'owned': []},
      };
      await pump(tester, const CoinStore());
      expect(find.text(arStrings.storeTabCouncil), findsNothing);
      expect(economyCalls('contracts_get'), isEmpty);
      expect(economyCalls('rank_get'), isEmpty);
    });

    testWidgets('an old server (no council answer) keeps the tab hidden', (
      tester,
    ) async {
      backend.responders['economy'] = (body) {
        if (body['action'] == 'capabilities') {
          throw const BackendException('BAD_REQUEST', 'invalid economy request');
        }
        return {'balance': 0, 'catalog': [], 'owned': []};
      };
      await pump(tester, const CoinStore());
      expect(find.text(arStrings.storeTabCouncil), findsNothing);
    });

    testWidgets('council on: the tab appears and shows rank and contracts', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contracts_get' => contracts(),
        'rank_get' => rank(),
        _ => {'balance': 0, 'catalog': [], 'owned': []},
      };
      await pump(tester, const CoinStore());
      expect(find.text(arStrings.storeTabCouncil), findsOneWidget);
      await tester.tap(find.text(arStrings.storeTabCouncil));
      await tester.pumpAndSettle();
      expect(find.byKey(CouncilHubTab.rankKey), findsOneWidget);
      expect(find.text(arStrings.contractFinishOne), findsOneWidget);
      expect(find.text(arStrings.contractMafia), findsOneWidget);
      expect(find.text(arStrings.rankTier1), findsOneWidget);
    });

    testWidgets('only the parts the server switched on are drawn', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(contracts: false, leaderboard: false, invites: false),
        'rank_get' => rank(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      expect(find.byKey(CouncilHubTab.rankKey), findsOneWidget);
      expect(find.byKey(CouncilHubTab.contractsKey), findsNothing);
      expect(find.byKey(CouncilHubTab.leaderboardKey), findsNothing);
      expect(find.byType(InviteCard), findsNothing);
      expect(economyCalls('contracts_get'), isEmpty);
    });
  });

  group('contracts', () {
    testWidgets('a claim names the server day and slot; paid once', (
      tester,
    ) async {
      var claimed = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contract_claim' => () {
          claimed = true;
          return {...contracts(claimed: true), 'granted': 15, 'bonusGranted': 0};
        }(),
        'contracts_get' => contracts(claimed: claimed),
        'rank_get' => rank(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      final unready = tester.widget<FilledButton>(find.byKey(CouncilHubTab.claimKey(1)));
      expect(unready.onPressed, isNull, reason: 'not claimable before it is done');
      await tester.tap(find.byKey(CouncilHubTab.claimKey(0)));
      await tester.pump();
      await tester.pump();
      expect(economyCalls('contract_claim').single, {
        'action': 'contract_claim',
        'day': '2026-09-25',
        'slot': 0,
      });
      expect(find.text(arStrings.dailyCofferGranted(15)), findsOneWidget);
      expect(find.byKey(CouncilHubTab.claimKey(0)), findsNothing);
      expect(find.text(arStrings.contractClaimed), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a refused claim is said plainly', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contract_claim' => throw const BackendException('CONTRACT_INCOMPLETE', 'x'),
        'contracts_get' => contracts(),
        'rank_get' => rank(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.tap(find.byKey(CouncilHubTab.claimKey(0)));
      await tester.pump();
      await tester.pump();
      expect(find.text(arStrings.contractIncomplete), findsOneWidget);
    });

    testWidgets('the weekly claim names the ISO week', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'weekly_claim' => {
          ...contracts(weeklyClaimable: false),
          'granted': 150,
          'xpGranted': 0,
        },
        'contracts_get' => contracts(weeklyClaimable: true),
        'rank_get' => rank(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.scrollUntilVisible(find.byKey(CouncilHubTab.weeklyKey), 200);
      await tester.tap(find.byKey(CouncilHubTab.weeklyKey));
      await tester.pump();
      await tester.pump();
      expect(economyCalls('weekly_claim').single, {
        'action': 'weekly_claim',
        'week': '2026-W39',
      });
      await tester.pumpAndSettle();
    });
  });

  group('rank', () {
    testWidgets('a level the server paid is celebrated once', (tester) async {
      var first = true;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contracts_get' => contracts(),
        'rank_get' => () {
          final answer = rank(
            xp: 230,
            level: 3,
            levelUps: first
                ? [
                    {'level': 3, 'coins': 25},
                  ]
                : const [],
          );
          first = false;
          return answer;
        }(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.pumpAndSettle();
      expect(find.byKey(LevelUpSheet.sheetKey), findsOneWidget);
      expect(find.text(arStrings.levelUpBody(3, 25)), findsOneWidget);
      await tester.tap(find.text(arStrings.continueAction));
      await tester.pumpAndSettle();
      expect(find.byKey(LevelUpSheet.sheetKey), findsNothing);
    });

    test('tiers: five levels each, ten titles', () {
      expect(rankTier(1), 1);
      expect(rankTier(5), 1);
      expect(rankTier(6), 2);
      expect(rankTier(45), 9);
      expect(rankTier(46), 10);
      expect(rankTier(50), 10);
      expect(rankTitle(enStrings, 10), 'Godfather');
      expect(rankTitle(arStrings, 1), 'مبتدئ');
    });

    testWidgets('every emblem paints, from a seat badge to the celebration', (
      tester,
    ) async {
      await pump(
        tester,
        Wrap(
          children: [
            for (final size in [22.0, 28.0, 64.0, 112.0])
              for (var level = 1; level <= 50; level += 5)
                RankEmblem(level: level, size: size),
            const ContractIcon(metric: 'finish'),
            const ContractIcon(metric: 'town'),
            const ContractIcon(metric: 'mafia'),
            const ContractIcon(metric: 'win'),
            const ContractIcon(metric: 'host'),
            const ContractIcon(metric: 'reunion'),
            const StarterBundleArt(),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(RankEmblem), findsNWidgets(40));
    });

    test('a seat carries a level, and nothing else from the Council', () {
      final seat = SeatCosmetics.fromJson({'rank': 7});
      expect(seat?.rank, 7);
      expect(seat?.frame, isNull);
      expect(SeatCosmetics.fromJson({'rank': 99}), isNull, reason: 'out of range');
      expect(SeatCosmetics.fromJson({'frame': 'frame_gilded'})?.rank, isNull);
    });
  });

  group('leaderboard', () {
    Map<String, dynamic> board({bool visible = true}) => {
      'enabled': true,
      'week': '2026-W39',
      'entries': [
        {'position': 1, 'xp': 900, 'name': 'ليلى', 'gender': 'female', 'level': 7, 'me': false},
        if (visible)
          {'position': 2, 'xp': 240, 'name': 'أنا', 'gender': 'male', 'level': 2, 'me': true},
      ],
      'me': {'position': 2, 'xp': 240},
      'visible': visible,
    };

    testWidgets('top entries, and the switch hides the player', (tester) async {
      var visible = true;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contracts_get' => contracts(),
        'rank_get' => rank(visible: visible),
        'leaderboard_get' => board(visible: visible),
        'leaderboard_visibility' => () {
          visible = body['visible'] as bool;
          return {'leaderboardVisible': visible};
        }(),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.tap(find.byKey(CouncilHubTab.leaderboardKey));
      await tester.pumpAndSettle();
      expect(find.byKey(LeaderboardSheet.rowKey(1)), findsOneWidget);
      expect(find.byKey(LeaderboardSheet.rowKey(2)), findsOneWidget);
      expect(find.text('ليلى'), findsOneWidget);
      final toggle = find.byKey(LeaderboardVisibilitySwitch.switchKey);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(economyCalls('leaderboard_visibility').single, {
        'action': 'leaderboard_visibility',
        'visible': false,
      });
      // Hidden: not listed, but the player still sees their own place.
      expect(find.byKey(LeaderboardSheet.rowKey(2)), findsNothing);
      expect(find.text(arStrings.leaderboardHidden), findsOneWidget);
      expect(
        find.textContaining(arStrings.leaderboardYou(2)),
        findsOneWidget,
      );
    });
  });

  group('invite', () {
    testWidgets('the code is shown, and a new account can use one', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(contracts: false, rank: false),
        'invite_get' => invite(canRedeem: true),
        'invite_redeem' => body['code'] == 'ZZZZZZZ'
            ? {...invite(canRedeem: true), 'status': 'not_found'}
            : throw const BackendException('INVITE_SELF', 'x'),
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.pumpAndSettle();
      expect(find.text('K7QM2XA'), findsOneWidget);
      expect(find.text(arStrings.inviteCounters(3, 20, 1)), findsOneWidget);
      final redeem = find.byKey(InviteCard.redeemKey);
      expect(tester.widget<FilledButton>(redeem).onPressed, isNull);
      await tester.enterText(find.byKey(InviteCard.fieldKey), 'zzzzzzz');
      await tester.pump();
      await tester.tap(redeem);
      await tester.pumpAndSettle();
      expect(economyCalls('invite_redeem').single['code'], 'ZZZZZZZ');
      expect(find.text(arStrings.inviteNotFound), findsOneWidget);
      await tester.enterText(find.byKey(InviteCard.fieldKey), 'K7QM2XA');
      await tester.pump();
      await tester.tap(redeem);
      await tester.pumpAndSettle();
      expect(find.text(arStrings.inviteSelf), findsOneWidget);
    });

    testWidgets('sharing falls back to copying where the platform has no sheet', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(contracts: false, rank: false),
        'invite_get' => invite(canRedeem: true),
        _ => {'ok': true},
      };
      final copied = <String>[];
      await pump(
        tester,
        const CouncilHubTab(),
        sharer: InviteSharer(
          share: (_) async => throw UnsupportedError('no share sheet'),
          copy: (text) async {
            copied.add(text);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(InviteCard.shareKey));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(copied.single, contains('K7QM2XA'));
      expect(find.text(arStrings.shareTextCopied), findsOneWidget);
    });

    testWidgets('an unread notice carries its own small emblem', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(contracts: false, rank: false),
        'invite_get' => {
          ...invite(canRedeem: true),
          'v3': {
            'caps': {'season': 10, 'lifetime': 40},
            'notices': [
              {
                'id': 1,
                'kind': 'first_match',
                'name': 'نور',
                'progress': 0,
                'coins': 25,
              },
            ],
          },
        },
        _ => {'ok': true},
      };
      await pump(tester, const CouncilHubTab());
      await tester.pumpAndSettle();
      expect(find.text(arStrings.inviteFirstMatchNotice('نور', 25)), findsOneWidget);
      // ignore: avoid_print
      print(tester.widgetList<Image>(find.byType(Image)).map((i) => i.image));
      final matches = tester
          .widgetList<Image>(find.byType(Image))
          .where(
            (i) =>
                i.image is AssetImage &&
                (i.image as AssetImage).assetName ==
                    'assets/images/council/invite_notice_first_match.webp',
          );
      expect(matches, hasLength(1));
    });
  });

  group('result screen', () {
    testWidgets('after the match: contracts now ready and XP gained', (
      tester,
    ) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        'contracts_get' => contracts(claimable: false),
        'rank_get' => rank(xp: 240),
        // D7: one call records the match and reads what it moved.
        'resultSummary' => {
          'ok': true,
          'contracts': contracts(claimable: true),
          'rank': rank(xp: 290),
          'hub': {'enabled': false},
        },
        _ => {'ok': true},
      };
      // The hub was open before the match.
      await pump(tester, const CouncilHubTab());
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, const CouncilResultStrip(roomId: 'room-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(CouncilResultStrip.stripKey), findsOneWidget);
      expect(
        find.text(arStrings.resultContractToast(arStrings.contractFinishOne, 15)),
        findsOneWidget,
      );
      expect(economyCalls('contract_claim'), isEmpty, reason: 'nothing is claimed here');
      expect(economyCalls('resultSummary'), hasLength(1));
      expect(economyCalls('resultSummary').single['roomId'], 'room-1');
      expect(
        economyCalls('resultSummary').single['requestId'],
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
        reason: 'D7: the summary carries a request id the server replays',
      );
      expect(economyCalls('sync'), isEmpty, reason: 'D7: no burst of separate calls');
    });

    testWidgets('the server delta wins over a before/after diff', (tester) async {
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(invites: false),
        // A replayed summary: rank already includes this room's XP, so a
        // client-side diff would read zero; the server's delta says 50.
        'resultSummary' => {
          'ok': true,
          'contracts': contracts(claimable: false),
          'rank': rank(xp: 290),
          'hub': {'enabled': false},
          'deltas': {'coins': 60, 'councilXp': 50, 'seasonXp': 10},
          'replayed': true,
        },
        _ => {'ok': true},
      };
      await pump(tester, const CouncilResultStrip(roomId: 'room-1'));
      await tester.pumpAndSettle();
      // The XP now arrives as a progress card: rank, bar and a +50 chip.
      expect(find.byKey(CouncilResultStrip.progressKey), findsOneWidget);
      expect(find.textContaining('+50'), findsOneWidget);
    });

    testWidgets('council off: the result screen shows nothing new', (
      tester,
    ) async {
      backend.responders['economy'] = (_) => {'ok': true};
      await pump(tester, const CouncilResultStrip(roomId: 'room-1'));
      await tester.pumpAndSettle();
      expect(find.byKey(CouncilResultStrip.stripKey), findsNothing);
      expect(economyCalls('contracts_get'), isEmpty);
    });
  });

  group('home attention', () {
    testWidgets('a dot when the coffer waits; none when all is collected', (
      tester,
    ) async {
      var collected = false;
      backend.responders['economy'] = (body) => switch (body['action']) {
        'capabilities' => caps(daily: true, invites: false),
        'daily_status' => {
          'enabled': true,
          'day': '2026-09-25',
          'coffer': {'claimed': collected, 'amount': 20},
          'wheel': {'spun': collected, 'prizes': []},
          'week': {},
          'ad': {},
        },
        'contracts_get' => contracts(claimable: false),
        _ => {'ok': true},
      };
      await pump(tester, const CoinStoreButton(compact: true));
      await tester.pumpAndSettle();
      expect(find.byKey(CouncilAttentionBadge.dotKey), findsOneWidget);
      collected = true;
      await pump(tester, const SizedBox.shrink());
      await pump(tester, const CoinStoreButton(compact: true));
      await tester.pumpAndSettle();
      expect(find.byKey(CouncilAttentionBadge.dotKey), findsNothing);
    });
  });

  group('Starter Bundle', () {
    const bundle = {'id': 'mm_starter_bundle', 'kind': 'bundle', 'coins': 600, 'item': 'frame_council_seal'};

    testWidgets('bought as a non-consumable; acknowledged, never consumed', (
      tester,
    ) async {
      final billing = _Billing();
      backend.responders['economy'] = (_) => caps(bundle: true, products: [bundle]);
      backend.responders['play_purchase'] = (_) => {
        'state': 'active',
        'kind': 'bundle',
        'granted': true,
        'alreadyOwned': false,
        'needsAcknowledge': true,
        'needsConsume': false,
      };
      await pump(tester, const PlayOffersTab(), billing: billing);
      await tester.pumpAndSettle();
      expect(find.text(arStrings.bundleTitle), findsOneWidget);
      await tester.tap(find.byKey(PlayOffersTab.buyKey('mm_starter_bundle')));
      await tester.pumpAndSettle();
      expect(billing.bought.single, ('mm_starter_bundle', false),
          reason: 'never a consumable purchase');
      billing.events$.add(
        const StorePurchaseEvent(
          state: StorePurchaseState.purchased,
          productId: 'mm_starter_bundle',
          token: 'token-bundle-1',
        ),
      );
      await tester.pumpAndSettle();
      expect(billing.finished, ['token-bundle-1']);
      await billing.events$.close();
    });

    testWidgets('a second bundle on the account is left for Play to refund', (
      tester,
    ) async {
      final billing = _Billing();
      backend.responders['economy'] = (_) => caps(bundle: true, products: [bundle]);
      backend.responders['play_purchase'] = (_) => {
        'state': 'active',
        'kind': 'bundle',
        'granted': false,
        'alreadyOwned': true,
        'needsAcknowledge': false,
        'needsConsume': false,
      };
      await pump(tester, const PlayOffersTab(), billing: billing);
      await tester.pumpAndSettle();
      billing.events$.add(
        const StorePurchaseEvent(
          state: StorePurchaseState.purchased,
          productId: 'mm_starter_bundle',
          token: 'token-bundle-2',
        ),
      );
      await tester.pumpAndSettle();
      expect(billing.finished, isEmpty, reason: 'not acknowledged: Play refunds it');
      expect(find.text(arStrings.bundleAlreadyOwned), findsOneWidget);
      await billing.events$.close();
    });

    test('the capabilities read a bundle as a non-consumable with its item', () {
      final parsed = EconomyCapabilities.fromJson(caps(bundle: true, products: [bundle]));
      final offer = parsed.products.single;
      expect(offer.bundle, isTrue);
      expect(offer.consumable, isFalse);
      expect(offer.item, 'frame_council_seal');
      expect(parsed.council.starterBundle, isTrue);
    });
  });

  group('narrow phones', () {
    for (final width in [320.0, 360.0, 430.0]) {
      for (final locale in const [Locale('ar'), Locale('en')]) {
        testWidgets('the hub fits at $width dp (${locale.languageCode})', (
          tester,
        ) async {
          backend.responders['economy'] = (body) => switch (body['action']) {
            'capabilities' => caps(),
            'contracts_get' => contracts(),
            'rank_get' => rank(),
            'invite_get' => invite(canRedeem: true),
            _ => {'ok': true},
          };
          await pump(
            tester,
            const CouncilHubTab(),
            size: Size(width, 2400),
            locale: locale,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(InviteCard), findsOneWidget);
        });
      }
    }
  });
}
