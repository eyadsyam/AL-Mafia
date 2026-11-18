import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/invite_share.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/economy/council.dart';
import 'package:mafia_master/ui/screens/online/nobody_waiting_card.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/push_prompt.dart';

import '../support/localized.dart';

class _Directory extends DirectoryApi {
  _Directory(super.ref, {this.on = false});
  bool on;
  Object? failure;
  final sets = <bool>[];

  @override
  Future<bool> watchRoomsStatus() async => on;

  @override
  Future<bool> watchRooms(bool value) async {
    if (failure != null) throw failure!;
    sets.add(value);
    return on = value;
  }
}

class _Push extends PushPrompt {
  _Push(super.ref, {required this.allowed, this.already = false});
  final bool allowed;
  final bool already;
  int asked = 0;

  @override
  Future<bool> isOn() async => already;

  @override
  Future<bool> setOn(bool on) async {
    asked++;
    return allowed;
  }
}

class _NoInvite extends InviteController {
  @override
  Future<InviteStatus> build() async => throw StateError('no invite');
}

void main() {
  late _Directory directory;
  late _Push push;
  final shared = <String>[];

  Future<void> open(
    WidgetTester tester, {
    bool on = false,
    bool allowed = true,
    bool already = false,
  }) async {
    shared.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          directoryApiProvider.overrideWith((ref) {
            return directory = _Directory(ref, on: on);
          }),
          pushPromptProvider.overrideWith((ref) {
            return push = _Push(ref, allowed: allowed, already: already);
          }),
          inviteProvider.overrideWith(_NoInvite.new),
          inviteSharerProvider.overrideWithValue(
            InviteSharer(
              share: (params) async {
                shared.add(params.text ?? '');
                throw UnsupportedError('no sheet');
              },
              copy: (text) async => true,
            ),
          ),
        ],
        child: localizedApp(const Scaffold(body: NobodyWaitingCard())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('title and two actions; share copies when there is no sheet', (
    tester,
  ) async {
    await open(tester);
    expect(find.text(arStrings.onlineNobodyWaiting), findsOneWidget);
    expect(find.text(arStrings.onlineShareWithFriends), findsOneWidget);
    expect(find.text(arStrings.onlineRemindMe), findsOneWidget);
    await tester.tap(find.byKey(NobodyWaitingCard.shareKey));
    await tester.pumpAndSettle();
    expect(shared, hasLength(1));
    expect(find.text(arStrings.shareTextCopied), findsOneWidget);
  });

  testWidgets('remind me asks, turns the watch on, shows the row; cancel off', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.byKey(NobodyWaitingCard.remindKey));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(directory.sets, [true]);
    expect(find.text(arStrings.onlineRemindOn), findsOneWidget);
    expect(find.byKey(NobodyWaitingCard.remindKey), findsNothing);

    await tester.tap(find.byKey(NobodyWaitingCard.cancelKey));
    await tester.pumpAndSettle();
    expect(directory.sets, [true, false]);
    expect(find.byKey(NobodyWaitingCard.remindKey), findsOneWidget);
  });

  testWidgets('declining notifications does nothing else', (tester) async {
    await open(tester, allowed: false);
    await tester.tap(find.byKey(NobodyWaitingCard.remindKey));
    await tester.pumpAndSettle();
    expect(push.asked, 1);
    expect(directory.sets, isEmpty);
    expect(find.byKey(NobodyWaitingCard.remindKey), findsOneWidget);
  });

  testWidgets('already allowed: no question; a watch already on shows the row', (
    tester,
  ) async {
    await open(tester, already: true);
    await tester.tap(find.byKey(NobodyWaitingCard.remindKey));
    await tester.pumpAndSettle();
    expect(push.asked, 0);
    expect(directory.sets, [true]);

    await open(tester, on: true);
    expect(find.byKey(NobodyWaitingCard.remindOnKey), findsOneWidget);
  });

  testWidgets('a failed tap keeps the button and says so', (tester) async {
    await open(tester, already: true);
    directory.failure = const BackendException('UNREACHABLE', 'down');
    await tester.tap(find.byKey(NobodyWaitingCard.remindKey));
    await tester.pumpAndSettle();
    expect(find.byKey(NobodyWaitingCard.remindKey), findsOneWidget);
    expect(find.text(arStrings.errOffline), findsOneWidget);
  });
}
