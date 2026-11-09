import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/directory_settings.dart';
import 'package:mafia_master/ui/social/friends.dart';

import '../support/localized.dart';

class _Friends extends FriendsController {
  _Friends(this.me);
  final DirectoryMe me;
  @override
  Future<FriendsState?> build() async => FriendsState(me: me);
}

class _Api extends DirectoryApi {
  _Api(super.ref, this.answer);
  final (DirectoryMe?, HandleRefusal?) answer;
  int calls = 0;
  @override
  Future<(DirectoryMe?, HandleRefusal?)> setHandle(String handle) async {
    calls++;
    return answer;
  }
}

void main() {
  Future<_Api> pump(
    WidgetTester tester,
    DirectoryMe me, {
    (DirectoryMe?, HandleRefusal?) answer = (null, null),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendsProvider.overrideWith(() => _Friends(me)),
          directoryApiProvider.overrideWith((ref) => _Api(ref, answer)),
        ],
        child: localizedApp(
          Scaffold(
            body: SingleChildScrollView(
              // The online door has read the friends list before this draws.
              child: Consumer(
                builder: (context, ref, _) {
                  ref.watch(friendsProvider);
                  return const DirectorySettings();
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    // Read the friends state so the settings draw (the real door does this).
    return ProviderScope.containerOf(
          tester.element(find.byType(DirectorySettings)),
        ).read(directoryApiProvider)
        as _Api;
  }

  testWidgets('a locked username is read-only with its note and no save', (
    tester,
  ) async {
    await pump(
      tester,
      const DirectoryMe(handle: 'salma_ali', handleLocked: true),
    );
    expect(find.byKey(DirectorySettings.handleField), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(DirectorySettings.handleField))
          .readOnly,
      isTrue,
    );
    expect(find.text(arStrings.profileHandleLocked), findsOneWidget);
    expect(find.byKey(DirectorySettings.handleSave), findsNothing);
  });

  testWidgets('an auto-assigned username can still be saved once', (
    tester,
  ) async {
    await pump(tester, const DirectoryMe(handle: 'player123'));
    expect(
      tester
          .widget<TextField>(find.byKey(DirectorySettings.handleField))
          .readOnly,
      isFalse,
    );
    expect(find.byKey(DirectorySettings.handleSave), findsOneWidget);
    expect(find.text(arStrings.profileHandleLocked), findsNothing);
  });

  testWidgets('after a successful save the field locks', (tester) async {
    final api = await pump(
      tester,
      const DirectoryMe(handle: 'player123'),
      answer: (
        const DirectoryMe(handle: 'salma_ali', handleLocked: true),
        null,
      ),
    );
    await tester.enterText(
      find.byKey(DirectorySettings.handleField),
      'salma_ali',
    );
    await tester.tap(find.byKey(DirectorySettings.handleSave));
    await tester.pump();
    await tester.pump();
    expect(api.calls, 1);
    expect(find.byKey(DirectorySettings.handleSave), findsNothing);
    expect(find.text(arStrings.profileHandleLocked), findsOneWidget);
  });

  testWidgets('HANDLE_LOCKED from the server locks the field', (tester) async {
    await pump(
      tester,
      const DirectoryMe(handle: 'player123'),
      answer: (null, HandleRefusal.locked),
    );
    await tester.enterText(
      find.byKey(DirectorySettings.handleField),
      'other_name',
    );
    await tester.tap(find.byKey(DirectorySettings.handleSave));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(DirectorySettings.handleSave), findsNothing);
    expect(find.text(arStrings.profileHandleLocked), findsOneWidget);
  });
}
