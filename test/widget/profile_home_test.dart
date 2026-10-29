import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/account/account_footer.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart'
    show accountsAvailableProvider;
import 'package:mafia_master/ui/account/profile_panels.dart';
import 'package:mafia_master/ui/account/profile_sheets.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/setup/profile_screen.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/social/titles_partner.dart';
import 'package:mafia_master/ui/widgets/deck/deck_form_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

/// 25 characters: longer than a name can be typed, as a friend's name still
/// has to fit a row whatever it is.
const _long = 'عبد الرحمن محمد السيد الجمال';

/// 20 characters: the longest name a player can type.
const _twenty = 'عبدالرحمن محمد السيد';

/// Another 20 characters, for a friend.
const _friend20 = 'أحمد عبدالعزيز حسنين';

Finder inList(String text) => find.descendant(
  of: find.byKey(FriendsSheetKeys.list),
  matching: find.text(text),
);

final _sample = FriendsState.fromJson({
  'friends': [
    {
      'id': 'a',
      'name': 'ليلى',
      'gender': 'female',
      'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4},
    },
    {
      'id': 'b',
      'name': _long,
      'presence': {'state': 'playing'},
    },
    {
      'id': 'f',
      'name': _friend20,
      'presence': {'state': 'lobby', 'code': 'ZZ9988', 'players': 2},
    },
  ],
  'incoming': [
    {'id': 'r1', 'name': _long},
    {'id': 'r2', 'name': 'منى'},
  ],
  'outgoing': <Object>[],
  'recent': [
    {'id': 'e', 'name': 'نور', 'matches': 1},
  ],
  'invites': <Object>[],
  'me': {'handle': 'karim', 'searchable': true, 'strangerInvites': true},
});

class _Friends extends FriendsController {
  static final responded = <String>[];
  @override
  Future<FriendsState?> build() async => _sample;
  @override
  Future<void> refresh() async {}
  @override
  Future<void> respond(String id, bool accept) async =>
      responded.add('$id:$accept');
}

class _Wallet extends WalletController {
  @override
  Future<WalletState?> build() async => WalletState.fromJson({'balance': 340});
}

class _Hub extends TitleHubController {
  @override
  Future<TitleHub> build() async => TitleHub.fromJson({
    'enabled': true,
    'equipped': 'kabir_elshella',
    'titles': [
      {
        'code': 'kabir_elshella',
        'source': 'invite',
        'nameAr': 'الشبح',
        'nameEn': 'The Ghost',
        'owned': true,
      },
    ],
  });
}

/// An app that has already asked the server (the profile never asks: M1).
class _Asked extends ConsumerWidget {
  final Widget child;
  const _Asked({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(economyCapabilitiesProvider);
    ref.watch(friendsProvider);
    ref.watch(titleHubProvider);
    return child;
  }
}

void main() {
  var history = 0;
  final joined = <String>[];

  setUp(() {
    history = 0;
    joined.clear();
    _Friends.responded.clear();
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"$_twenty","gender":"male"}',
    });
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    AccountProfile account = AccountProfile.guest,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsAvailableProvider.overrideWithValue(true),
          accountProfileProvider.overrideWith((ref) => Stream.value(account)),
          economyCapabilitiesProvider.overrideWith(
            (ref) async => const EconomyCapabilities(friends: true, titles: true),
          ),
          friendsProvider.overrideWith(_Friends.new),
          walletProvider.overrideWith(_Wallet.new),
          titleHubProvider.overrideWith(_Hub.new),
          profileStatsProvider.overrideWith((ref) async => (12, 5)),
          profileLastMatchProvider.overrideWith(
            (ref) async => DateTime(2026, 10, 28, 20),
          ),
          profileClockProvider.overrideWithValue(() => DateTime(2026, 10, 29, 12)),
        ],
        child: localizedApp(
          _Asked(
            child: ProfileScreen(
              onBack: () {},
              onSaved: () {},
              onHistory: () => history++,
              onJoinRoom: joined.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the dimmed area above the sheet.
  Future<void> closeSheet(WidgetTester tester) async {
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
  }

  testWidgets('the profile is who you are, three real numbers, four rows', (
    tester,
  ) async {
    await pumpProfile(tester);
    // Identity: the name as saved, and what to tap, with the worn title.
    expect(find.text(_twenty), findsOneWidget);
    expect(find.text(arStrings.profileEditHintTitled('الشبح')), findsOneWidget);
    // Numbers: matches here, online, coins. No «فوز».
    expect(find.text(arStrings.profileStatHere), findsOneWidget);
    expect(find.text(arStrings.profileStatOnlineMatches), findsOneWidget);
    expect(find.text(arStrings.profileStatCoins), findsOneWidget);
    String value(Key key) => tester
        .widget<Text>(
          find
              .descendant(of: find.byKey(key), matching: find.byType(Text))
              .first,
        )
        .data!;
    expect(value(ProfileStats.hereKey), '12');
    expect(value(ProfileStats.onlineKey), '5');
    expect(value(ProfileStats.coinsKey), '340');
    // Rows, in order, each with its few words.
    final rows = find.descendant(
      of: find.byKey(ProfileRowList.listKey),
      matching: find.byType(ProfileRow),
    );
    expect(rows, findsNWidgets(4));
    expect(find.text(arStrings.friendsSheetTitle), findsOneWidget);
    expect(find.text(arStrings.profileFriendsCount(3)), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'two requests wait');
    expect(find.text(arStrings.authAccount), findsOneWidget);
    expect(find.text(arStrings.authGuestBadge), findsOneWidget);
    expect(find.text(arStrings.fileTabTitles), findsOneWidget);
    expect(find.text(arStrings.history), findsOneWidget);
    expect(find.text(arStrings.profileLastMatchYesterday), findsOneWidget);
    final tops = [
      for (var i = 0; i < 4; i++) tester.getTopLeft(rows.at(i)).dy,
    ];
    expect([...tops]..sort(), tops, reason: 'one under the other');
    expect(tester.takeException(), isNull);
  });

  testWidgets('an account says how it signed in', (tester) async {
    await pumpProfile(
      tester,
      account: const AccountProfile(
        signedIn: true,
        email: 'a@b.c',
        emailConfirmed: true,
        google: true,
      ),
    );
    expect(find.text(arStrings.profileAccountGoogle), findsOneWidget);
  });

  testWidgets('each row opens its own sheet from the bottom', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(ProfileScreen.friendsKey));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(FriendsSheetKeys.search), findsOneWidget);
    expect(find.text(arStrings.friendsSearchHint), findsOneWidget);
    await closeSheet(tester);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AccountSheet), findsOneWidget);
    expect(find.text(arStrings.accountGuestIntro), findsOneWidget);
    expect(find.text(arStrings.accountContinueGoogle), findsOneWidget);
    expect(find.text(arStrings.accountWithEmail), findsOneWidget);
    // «مش دلوقتي» closes it, and the guest stays a guest.
    await tester.tap(find.byKey(AccountSheet.notNowKey));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.byKey(ProfileScreen.titlesKey));
    await tester.pumpAndSettle();
    expect(find.byKey(TitlesSheet.sheetKey), findsOneWidget);
    expect(find.byKey(TitleEquipList.titleKey('kabir_elshella')), findsOneWidget);
    await closeSheet(tester);

    await tester.tap(find.byKey(ProfileIdentityHeader.headerKey));
    await tester.pumpAndSettle();
    expect(find.byKey(ProfileScreen.nameKey), findsOneWidget);
    expect(find.byKey(ProfileScreen.saveKey), findsOneWidget);
    await closeSheet(tester);

    // History is the full match log, not a sheet.
    await tester.tap(find.byKey(ProfileScreen.historyKey));
    await tester.pump();
    expect(history, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delete account stays reachable from the account sheet', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(AccountFooter.deleteKey));
    expect(find.byKey(AccountFooter.deleteKey), findsOneWidget);
    expect(find.text(arStrings.deleteAccountRow), findsOneWidget);
  });

  testWidgets('a friend request is accepted or declined by chips', (
    tester,
  ) async {
    await pumpProfile(tester);
    await tester.tap(find.byKey(ProfileScreen.friendsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(FriendsSheetKeys.accept('r2')));
    await tester.tap(find.byKey(FriendsSheetKeys.decline('r1')));
    expect(_Friends.responded, ['r2:true', 'r1:false']);
  });

  testWidgets('a friend at a table is joined from the sheet', (tester) async {
    await pumpProfile(tester);
    await tester.tap(find.byKey(ProfileScreen.friendsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arStrings.friendsJoin).first);
    await tester.pumpAndSettle();
    expect(joined, ['K7M2QP']);
  });

  testWidgets('the search looks by name and by room code', (tester) async {
    await pumpProfile(tester);
    await tester.tap(find.byKey(ProfileScreen.friendsKey));
    await tester.pumpAndSettle();
    expect(inList('ليلى'), findsOneWidget);
    await tester.enterText(find.byKey(FriendsSheetKeys.search), 'منى');
    await tester.pumpAndSettle();
    expect(inList('منى'), findsOneWidget);
    expect(inList('ليلى'), findsNothing);
    // A room code finds the friend sitting in it.
    await tester.enterText(find.byKey(FriendsSheetKeys.search), 'zz99');
    await tester.pumpAndSettle();
    expect(inList(_friend20), findsOneWidget);
    expect(inList('ليلى'), findsNothing);
    // Nobody: a short plain line, no advice.
    await tester.enterText(find.byKey(FriendsSheetKeys.search), 'qqq');
    await tester.pumpAndSettle();
    expect(find.text(arStrings.inviteSearchEmpty), findsOneWidget);
    await tester.tap(find.byKey(FriendsSheetKeys.clear));
    await tester.pumpAndSettle();
    expect(inList('ليلى'), findsOneWidget);
  });

  testWidgets('a long name keeps one line and its chips go under it', (
    tester,
  ) async {
    await pumpProfile(tester, size: const Size(360, 640));
    await tester.tap(find.byKey(ProfileScreen.friendsKey));
    await tester.pumpAndSettle();
    final name = find.text(_long).first;
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(paragraph.maxLines, 1);
    final chip = find.byKey(FriendsSheetKeys.accept('r1'));
    final nameBox = tester.getRect(name);
    final chipBox = tester.getRect(chip);
    expect(chipBox.top, greaterThanOrEqualTo(nameBox.bottom - 0.5));
    // The name takes the row's width; the chips do not squeeze it.
    final decline = tester.getRect(find.byKey(FriendsSheetKeys.decline('r1')));
    expect(decline.top, greaterThanOrEqualTo(nameBox.bottom - 0.5));
    expect(nameBox.width, greaterThan(chipBox.width));
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(360, 640),
    Size(390, 844),
    Size(640, 360),
  ]) {
    testWidgets(
      'nothing overflows or overlaps at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await pumpProfile(tester, size: size);
        expect(tester.takeException(), isNull);
        for (final key in [
          ProfileScreen.friendsKey,
          AccountCard.cardKey,
          ProfileScreen.titlesKey,
          ProfileIdentityHeader.headerKey,
        ]) {
          await tester.ensureVisible(find.byKey(key));
          await tester.tap(find.byKey(key));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$key');
          // The sheet stays inside the screen.
          final sheet = tester.getRect(find.byType(BottomSheet));
          expect(sheet.top, greaterThanOrEqualTo(0));
          expect(sheet.bottom, lessThanOrEqualTo(size.height + 0.5));
          expect(sheet.width, lessThanOrEqualTo(size.width + 0.5));
          await closeSheet(tester);
        }
        // The rows do not run into each other.
        final rows = find.byType(ProfileRow);
        for (var i = 0; i + 1 < rows.evaluate().length; i++) {
          final a = tester.getRect(rows.at(i));
          final b = tester.getRect(rows.at(i + 1));
          expect(a.bottom, lessThanOrEqualTo(b.top + 0.5));
        }
      },
    );
  }

  for (final (size, keyboard) in const [
    (Size(360, 640), 280.0),
    (Size(390, 844), 320.0),
    (Size(640, 360), 170.0),
  ]) {
    testWidgets(
      'the keyboard does not cover the search field or the results '
      'at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await pumpProfile(tester, size: size);
        await tester.tap(find.byKey(ProfileScreen.friendsKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(FriendsSheetKeys.search));
        await tester.pump();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
        final top = size.height - keyboard;
        final field = tester.getRect(find.byKey(FriendsSheetKeys.search));
        expect(field.bottom, lessThanOrEqualTo(top), reason: 'field is above');
        expect(field.top, greaterThanOrEqualTo(0));
        // The list is the area between the field and the keyboard.
        final list = tester.getRect(find.byKey(FriendsSheetKeys.list));
        expect(list.top, greaterThanOrEqualTo(field.bottom - 0.5));
        expect(list.bottom, lessThanOrEqualTo(top + 0.5));
        expect(list.height, greaterThan(40));
        // A typed search shows its hit inside that area.
        await tester.enterText(find.byKey(FriendsSheetKeys.search), 'ليلى');
        await tester.pumpAndSettle();
        final hit = tester.getRect(inList('ليلى'));
        expect(hit.bottom, lessThanOrEqualTo(top + 0.5));
        expect(hit.top, greaterThanOrEqualTo(field.bottom - 0.5));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('the account sheet also stands on top of the keyboard', (
    tester,
  ) async {
    await pumpProfile(tester, size: const Size(360, 640));
    await tester.tap(find.byKey(AccountCard.cardKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AccountSheet.createKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(AccountSheet.emailKey));
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byKey(AccountSheet.emailKey));
    expect(field.bottom, lessThanOrEqualTo(640 - 280));
    expect(DeckFormSheetFrame.handlesKeyboard(
      tester.element(find.byType(AccountSheet)),
    ), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the last match is told in a few plain words', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      localizedApp(Builder(builder: (c) {
        context = c;
        return const SizedBox.shrink();
      })),
    );
    final now = DateTime(2026, 10, 29, 12);
    String line(DateTime? last) => lastMatchLine(context, last, now);
    expect(line(null), arStrings.profileNoMatches);
    expect(line(DateTime(2026, 10, 29, 1)), arStrings.profileLastMatchToday);
    expect(line(DateTime(2026, 10, 28, 23)), arStrings.profileLastMatchYesterday);
    expect(line(DateTime(2026, 10, 27)), 'آخر ماتش من يومين');
    expect(line(DateTime(2026, 10, 24)), 'آخر ماتش من 5 أيام');
    expect(line(DateTime(2026, 10, 17)), 'آخر ماتش من 12 يوم');
  });
}
