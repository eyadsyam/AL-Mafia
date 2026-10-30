import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/room_closed_notice.dart';

import '../support/localized.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, bool pending) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(roomClosedNoticeProvider.notifier).state = pending;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          const RoomClosedNotice(child: Scaffold(body: SizedBox())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('a player sent home by a closed room is told why, once', (
    tester,
  ) async {
    final container = await pump(tester, true);
    expect(find.text(arStrings.onlineRoomClosedByHost), findsOneWidget);
    expect(container.read(roomClosedNoticeProvider), isFalse);
  });

  testWidgets('an ordinary arrival at Home says nothing', (tester) async {
    await pump(tester, false);
    expect(find.byType(SnackBar), findsNothing);
  });
}
