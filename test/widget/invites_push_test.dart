import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/online/invite_sheet.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/ui/social/incoming_invite.dart';
import 'package:mafia_master/ui/social/invite_privacy.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/localized.dart';

const _rows = [
  DirectoryRow(
    handle: 'nour_hassan',
    name: 'نور حسن',
    gender: 'female',
    level: 12,
    presence: DirectoryPresence.online,
    frame: 'frame_gilded',
    plate: 'plate_ember',
  ),
  DirectoryRow(handle: 'karim', name: 'كريم', level: 3),
];

class _Api extends DirectoryApi {
  _Api(super.ref);
  final searches = <String>[];
  final filters = <DiscoverFilter?>[];
  final invited = <String>[];
  final responded = <String>[];
  String? respondWith = 'K7M2QP';
  List<IncomingInvite> inboxRows = const [];

  @override
  Future<DirectoryPage> search(String query, {int page = 0}) async {
    searches.add(query);
    return const DirectoryPage(_rows);
  }

  @override
  Future<DirectoryPage> discover(DiscoverFilter? filter, {int page = 0}) async {
    filters.add(filter);
    return const DirectoryPage(_rows, more: true);
  }

  @override
  Future<bool> inviteHandle(String handle, String roomId) async {
    invited.add(handle);
    return true;
  }

  @override
  Future<List<IncomingInvite>> inbox() async => inboxRows;

  @override
  Future<String?> respond(String inviteId, {required bool accept}) async {
    responded.add(inviteId);
    return respondWith;
  }

  @override
  Future<void> registerPush(String token, String platform) async {}
}

class _Friends extends FriendsController {
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson({
    'friends': [
      {
        'id': 'f1',
        'name': 'ليلى',
        'gender': 'female',
        'frame': 'frame_moonlit',
        'presence': {'state': 'lobby', 'code': 'ABCDEF', 'players': 3},
      },
    ],
  });
  @override
  Future<void> refresh() async {}
  @override
  Future<bool> invite(String id, String roomId) async => true;
}

class _Push implements PushService {
  int asks = 0;
  PushOpen? initial;
  @override
  String? get platform => 'android';
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async {
    asks++;
    return true;
  }

  @override
  Future<String?> token() async => 'token-${'x' * 30}';
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => initial;
}

class _Alert extends InviteAlert {
  _Alert(super.ref);
  static int rings = 0;
  @override
  Future<void> ring() async => rings++;
}

const _invite = IncomingInvite(
  id: 'inv-1',
  code: 'K7M2QP',
  name: 'إياد',
  handle: 'eyad',
  frame: 'frame_crimson',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _Api api;
  late _Push push;

  List<Override> overrides({bool pushOn = true}) => [
    directoryApiProvider.overrideWith((ref) => api = _Api(ref)),
    friendsProvider.overrideWith(_Friends.new),
    pushServiceProvider.overrideWithValue(push),
    inviteAlertProvider.overrideWith(_Alert.new),
    economyCapabilitiesProvider.overrideWith(
      (ref) async => EconomyCapabilities(
        friends: true,
        directory: true,
        pushInvites: pushOn,
      ),
    ),
  ];

  setUp(() {
    push = _Push();
    _Alert.rings = 0;
  });

  Future<void> sheet(
    WidgetTester tester, {
    required double width,
    Locale locale = const Locale('ar'),
  }) async {
    tester.view.physicalSize = Size(width, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(
          Scaffold(
            body: InviteSheet(visible: true, roomId: 'room-1', onDismiss: () {}),
          ),
          locale: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 430.0]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets('invite sheet: three tabs at ${width.toInt()} px, '
          '${locale.languageCode}', (tester) async {
        await sheet(tester, width: width, locale: locale);
        // Friends.
        expect(find.byKey(InviteSheet.rowKey('f1')), findsOneWidget);
        await tester.tap(find.byKey(InviteSheet.buttonKey('f1')));
        await tester.pumpAndSettle();
        expect(find.byKey(InviteSheet.buttonKey('f1')), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Search by name: debounced, one request, rows with identity.
        await tester.tap(find.byKey(InviteSheet.tabKey(1)));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(InviteSheet.searchField), 'نو');
        await tester.enterText(find.byKey(InviteSheet.searchField), 'نور');
        await tester.pump(InviteTokens.searchDebounce);
        await tester.pumpAndSettle();
        expect(api.searches, ['نور']);
        expect(find.byKey(InviteSheet.rowKey('nour_hassan')), findsOneWidget);
        await tester.tap(find.byKey(InviteSheet.buttonKey('nour_hassan')));
        await tester.pumpAndSettle();
        expect(api.invited, ['nour_hassan']);
        final l = locale.languageCode == 'ar' ? arStrings : enStrings;
        expect(find.text(l.inviteSent), findsOneWidget);
        // A second tap does not send twice.
        await tester.tap(find.byKey(InviteSheet.buttonKey('nour_hassan')));
        await tester.pumpAndSettle();
        expect(api.invited, ['nour_hassan']);

        // People near you, with its four chips.
        await tester.tap(find.byKey(InviteSheet.tabKey(2)));
        await tester.pumpAndSettle();
        expect(api.filters, [null]);
        for (final f in DiscoverFilter.values) {
          expect(find.byKey(InviteSheet.filterKey(f)), findsOneWidget);
        }
        await tester.tap(find.byKey(InviteSheet.filterKey(DiscoverFilter.near)));
        await tester.pumpAndSettle();
        expect(api.filters, [null, DiscoverFilter.near]);
        expect(find.text(l.inviteMore), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('permission is asked in context only, once', (tester) async {
    final key = GlobalKey<IncomingInviteHostState>();
    var open = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(
          StatefulBuilder(
            builder: (context, set) => IncomingInviteHost(
              key: key,
              onJoin: (_) {},
              child: Scaffold(
                body: Stack(
                  children: [
                    TextButton(
                      onPressed: () => set(() => open = true),
                      child: const Text('open'),
                    ),
                    InviteSheet(
                      visible: open,
                      roomId: 'r',
                      onDismiss: () => set(() => open = false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Launch: the capabilities are read (by something else) and still no
    // prompt.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold)),
    );
    await container.read(economyCapabilitiesProvider.future);
    await tester.pumpAndSettle();
    expect(push.asks, 0, reason: 'never on first launch');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(push.asks, 1, reason: 'first time the invite sheet opens');

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(push.asks, 1, reason: 'asked once');
  });

  testWidgets('permission is not asked while push is off on the server', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(pushOn: false),
        child: localizedApp(
          Consumer(
            builder: (context, ref, _) {
              ref.watch(economyCapabilitiesProvider);
              return const Scaffold(
                body: InviteSheet(visible: true, roomId: 'r', onDismiss: _noop),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(push.asks, 0);
  });

  testWidgets('an invite waits through a private phase, then pops with its '
      'knock', (tester) async {
    final key = GlobalKey<IncomingInviteHostState>();
    final joined = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(
          IncomingInviteHost(
            key: key,
            onJoin: joined.add,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('home')),
    );
    container.read(privateMomentProvider.notifier).state = true;
    key.currentState!.enqueue(_invite);
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.popupKey), findsNothing);
    expect(_Alert.rings, 0, reason: 'no sound over a private phase');

    container.read(privateMomentProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.popupKey), findsOneWidget);
    expect(find.text(arStrings.inviteIncomingBody('إياد')), findsOneWidget);
    expect(_Alert.rings, 1);

    // A private phase coming back hides it again, without a second knock.
    container.read(privateMomentProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.popupKey), findsNothing);
    container.read(privateMomentProvider.notifier).state = false;
    await tester.pumpAndSettle();
    expect(_Alert.rings, 1);

    await tester.tap(find.byKey(IncomingInvitePopup.enterKey));
    await tester.pumpAndSettle();
    expect(api.responded, ['inv-1']);
    expect(joined, ['K7M2QP']);
    expect(find.byKey(IncomingInvitePopup.popupKey), findsNothing);
  });

  testWidgets('«بعدين» closes it and it does not pop again', (tester) async {
    final key = GlobalKey<IncomingInviteHostState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(
          IncomingInviteHost(
            key: key,
            onJoin: (_) {},
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.text('home')),
    );
    await container.read(economyCapabilitiesProvider.future);
    key.currentState!.enqueue(_invite);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(IncomingInvitePopup.laterKey));
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.popupKey), findsNothing);

    api.inboxRows = const [_invite];
    await key.currentState!.poll();
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.popupKey), findsNothing);
  });

  testWidgets('a room that started meanwhile says so instead of an error', (
    tester,
  ) async {
    final key = GlobalKey<IncomingInviteHostState>();
    final joined = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: localizedApp(
          IncomingInviteHost(
            key: key,
            onJoin: joined.add,
            child: const Scaffold(body: Text('home')),
          ),
        ),
      ),
    );
    ProviderScope.containerOf(
      tester.element(find.text('home')),
    ).read(directoryApiProvider);
    api.respondWith = null;
    key.currentState!.enqueue(_invite);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(IncomingInvitePopup.enterKey));
    await tester.pumpAndSettle();
    expect(find.byKey(IncomingInvitePopup.goneKey), findsOneWidget);
    expect(joined, isEmpty);
  });

  group('deep link from a notification payload', () {
    test('only a well-formed invite payload opens anything', () {
      final open = PushOpen.fromData({
        'kind': 'invite',
        'code': 'k7m2qp',
        'inviteId': 'inv-1',
        'fromName': 'إياد',
        'fromHandle': 'eyad',
      });
      expect(open?.code, 'K7M2QP');
      expect(open?.inviteId, 'inv-1');
      expect(PushOpen.fromData({'kind': 'invite', 'code': '../x'}), isNull);
      expect(PushOpen.fromData({'kind': 'role', 'code': 'K7M2QP'}), isNull);
      expect(PushOpen.fromData({}), isNull);
    });

    testWidgets('a cold start from a notification goes straight to the join '
        'flow', (tester) async {
      final joined = <String>[];
      push.initial = PushOpen.fromData({
        'kind': 'invite',
        'code': 'K7M2QP',
        'inviteId': 'inv-9',
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: localizedApp(
            IncomingInviteHost(
              onJoin: joined.add,
              child: const Scaffold(body: Text('home')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.responded, ['inv-9']);
      expect(joined, ['K7M2QP']);
    });

    testWidgets('a tap on a notification for a closed room shows the '
        'friendly notice', (tester) async {
      final key = GlobalKey<IncomingInviteHostState>();
      final joined = <String>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(),
          child: localizedApp(
            IncomingInviteHost(
              key: key,
              onJoin: joined.add,
              child: const Scaffold(body: Text('home')),
            ),
          ),
        ),
      );
      ProviderScope.containerOf(
      tester.element(find.text('home')),
    ).read(directoryApiProvider);
    api.respondWith = null;
      await key.currentState!.openFromPush(
        const PushOpen(kind: 'invite', code: 'K7M2QP', inviteId: 'inv-2'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(RoomGoneNotice.noticeKey), findsOneWidget);
      expect(find.text(arStrings.inviteRoomGone), findsOneWidget);
      expect(joined, isEmpty);
    });
  });
}

void _noop() {}
