import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/social/titles_partner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

/// F10 client: dark by default, titles equip with a request id and absorb
/// the fresh state, the Partner is free (server for accounts, device for
/// guests) and refused only during a live match.
void main() {
  late FakeBackend backend;
  late Map<String, dynamic> capabilities;
  Map<String, dynamic> titleState = {};
  Map<String, dynamic> partnerAnswer = {};

  Map<String, dynamic> hub({String? equipped}) => {
    'enabled': true,
    'equipped': equipped,
    'titles': [
      {'code': 'kabir_elshella', 'source': 'invite', 'nameAr': 'كبير الشلة',
        'nameEn': 'Head of the Gang', 'owned': true},
      {'code': 'season_zero_casekeeper', 'source': 'season', 'nameAr': 'حافظ القضايا',
        'nameEn': 'Casekeeper', 'owned': false},
    ],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    capabilities = {'version': 2, 'titles': true, 'partner': true};
    titleState = hub();
    partnerAnswer = {'enabled': true, 'side': null};
    backend = FakeBackend(roomId: 'r', state: roomState(), players: roster(5));
    backend.responders['economy'] = (body) => switch (body['action']) {
      'capabilities' => capabilities,
      'titleHub' => titleState,
      'titleEquip' => () {
        titleState = hub(equipped: body['code'] as String?);
        return {'ok': true, 'requestId': body['requestId'], 'state': titleState};
      }(),
      'partnerGet' => partnerAnswer,
      'partnerSet' => partnerAnswer['busy'] == true
          ? {'ok': false, 'requestId': body['requestId'], 'code': 'IN_MATCH'}
          : {'ok': true, 'requestId': body['requestId'],
              'state': {'enabled': true, 'side': body['side']}},
      _ => {'ok': true},
    };
  });

  Iterable<Map<String, dynamic>> calls(String action) => backend.calls
      .where((c) => c.function == 'economy' && c.body['action'] == action)
      .map((c) => c.body);

  Future<void> pump(WidgetTester tester, Widget child, {bool signedIn = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineBackendFactoryProvider.overrideWithValue(() async => backend),
          accountProfileProvider.overrideWith(
            (ref) => Stream.value(signedIn
                ? const AccountProfile(signedIn: true, email: 'a@b.c', emailConfirmed: true)
                : AccountProfile.guest),
          ),
        ],
        // An app that has already asked the server (the widgets never ask
        // on their own: M1).
        child: localizedApp(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(economyCapabilitiesProvider);
                return SingleChildScrollView(child: child);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('switches off: nothing drawn, nothing asked', (tester) async {
    capabilities = {'version': 2};
    await pump(tester, const Column(children: [TitleEquipList(), PartnerPicker()]));
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(calls('titleHub'), isEmpty);
    expect(calls('partnerGet'), isEmpty);
  });

  testWidgets('owned titles only; equip sends a request id and absorbs state', (tester) async {
    await pump(tester, const TitleEquipList());
    expect(find.text('كبير الشلة'), findsOneWidget);
    expect(find.text('حافظ القضايا'), findsNothing, reason: 'unowned titles are not offered');
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('كبير الشلة'),
        matching: find.byType(ListTile),
      ),
    );
    final sealImage = tester.widget<Image>(
      find.descendant(
        of: find.byWidget(tile.leading!),
        matching: find.byType(Image),
      ),
    );
    expect(
      (sealImage.image as AssetImage).assetName,
      'assets/images/titles/title_seal_kabir_elshella.webp',
    );
    await tester.tap(find.byKey(TitleEquipList.titleKey('kabir_elshella')));
    await tester.pumpAndSettle();
    final sent = calls('titleEquip').single;
    expect(sent['code'], 'kabir_elshella');
    expect(sent['requestId'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(calls('titleHub'), hasLength(1), reason: 'the mutation returned the state');
  });

  testWidgets('an account picks on the server; IN_MATCH keeps the old side', (tester) async {
    await pump(tester, const PartnerPicker());
    await tester.tap(find.byKey(PartnerPicker.optionKey(PartnerSide.doctor)));
    await tester.pumpAndSettle();
    expect(calls('partnerSet').single['side'], 'doctor');
    expect(
      tester.widget<ChoiceChip>(find.byKey(PartnerPicker.optionKey(PartnerSide.doctor))).selected,
      isTrue,
    );
    partnerAnswer = {'enabled': true, 'side': 'doctor', 'busy': true};
    await tester.tap(find.byKey(PartnerPicker.optionKey(PartnerSide.mafia)));
    await tester.pumpAndSettle();
    expect(find.text('تقدر تغيّر رفيقك بعد ما الماتش يخلص'), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(find.byKey(PartnerPicker.optionKey(PartnerSide.doctor))).selected,
      isTrue,
    );
  });

  testWidgets('a guest keeps the Partner on the device, versioned', (tester) async {
    await pump(tester, const PartnerPicker(), signedIn: false);
    await tester.tap(find.byKey(PartnerPicker.optionKey(PartnerSide.citizen)));
    await tester.pumpAndSettle();
    expect(calls('partnerSet'), isEmpty, reason: 'a guest never writes the server');
    expect(await PartnerLocalStore.read(), PartnerSide.citizen);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PartnerLocalStore.storageKey), '{"v":1,"side":"citizen"}');
  });

  test('an unknown stored version is dropped, not misread', () async {
    SharedPreferences.setMockInitialValues({
      PartnerLocalStore.storageKey: '{"v":9,"side":"mafia"}',
    });
    expect(await PartnerLocalStore.read(), isNull);
  });

  test('TitleHub parses and ignores junk', () {
    final parsed = TitleHub.fromJson(hub(equipped: 'kabir_elshella'));
    expect(parsed.equippedTitle?.code, 'kabir_elshella');
    expect(TitleHub.fromJson({'enabled': false}).enabled, isFalse);
    expect(TitleHub.fromJson({'enabled': true, 'titles': ['x', 3]}).titles, isEmpty);
  });
}
