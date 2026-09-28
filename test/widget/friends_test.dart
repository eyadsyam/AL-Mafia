import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/social/friends.dart';

import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';


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
      'name': 'كريم',
      'presence': {'state': 'playing'},
    },
  ],
  'incoming': [
    {'id': 'c', 'name': 'سارة'},
  ],
  'outgoing': [
    {'id': 'd', 'name': 'عمر'},
  ],
  'recent': [
    {'id': 'd', 'name': 'عمر', 'matches': 3},
    {'id': 'e', 'name': 'نور', 'matches': 1},
  ],
  'invites': [
    {'roomId': 'r', 'code': 'ABCDEF', 'name': 'ليلى'},
  ],
});

class _Fixed extends FriendsController {
  @override
  Future<FriendsState?> build() async => _sample;
  @override
  Future<void> refresh() async {}
}

/// Counts refreshes; the first read has no invite, later reads have one.
class _Counting extends FriendsController {
  static int refreshes = 0;
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson(const {});
  @override
  Future<void> refresh() async {
    refreshes++;
    state = AsyncData(_sample);
  }
}

void main() {
  testWidgets('D5: invites arrive while the door is in front, not in the background', (
    tester,
  ) async {
    _Counting.refreshes = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendsProvider.overrideWith(_Counting.new)],
        child: localizedApp(Scaffold(body: FriendsStrip(onJoin: (_) {}))),
      ),
    );
    await tester.pump();
    expect(find.byKey(FriendsStrip.inviteKey('ABCDEF')), findsNothing);
    await tester.pump(FriendsTokens.inviteRefresh);
    expect(_Counting.refreshes, 1);
    await tester.pump();
    expect(find.byKey(FriendsStrip.inviteKey('ABCDEF')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(FriendsTokens.inviteRefresh * 3);
    expect(_Counting.refreshes, 1, reason: 'nothing is asked in the background');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(_Counting.refreshes, 2, reason: 'asked at once on resume');
    await tester.pump(FriendsTokens.inviteRefresh);
    expect(_Counting.refreshes, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(FriendsTokens.inviteRefresh * 2);
    expect(_Counting.refreshes, 3, reason: 'the timer leaves with the strip');
  });

  test('the status answer parses presence, requests and invites', () {
    expect(_sample.friends, hasLength(2));
    expect(_sample.friends.first.presence.place, FriendPlace.lobby);
    expect(_sample.friends.first.presence.code, 'K7M2QP');
    expect(_sample.friends.last.presence.place, FriendPlace.playing);
    expect(_sample.inLobby, 1);
    expect(_sample.incoming.single.name, 'سارة');
    expect(_sample.invites.single.code, 'ABCDEF');
    expect(FriendsState.fromJson({'friends': 'junk'}).friends, isEmpty);
  });

  testWidgets('the sheet offers join, accept and add, and an invite joins', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? joined;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendsProvider.overrideWith(_Fixed.new)],
        child: localizedApp(
          Scaffold(body: FriendsSheet(onJoin: (code) => joined = code)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ليلى عزمك على روم · ادخل'), findsOneWidget);
    expect(find.text('قبول'), findsOneWidget);
    expect(find.text('مستني رده'), findsOneWidget); // عمر: already asked
    expect(find.text('أضف'), findsOneWidget); // نور
    expect(find.text('في ماتش دلوقتي'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ادخل').first);
    await tester.pumpAndSettle();
    expect(joined, 'ABCDEF');
  });

  testWidgets('from the lobby, friends are invited rather than joined', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [friendsProvider.overrideWith(_Fixed.new)],
        child: localizedApp(
          Scaffold(body: FriendsSheet(onJoin: (_) {}, inviteRoomId: 'room')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('اعزم'), findsNWidgets(2));
    expect(find.text('ليلى عزمك على روم · ادخل'), findsNothing);
  });
}
