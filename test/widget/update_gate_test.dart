import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app_build.dart';
import 'package:mafia_master/app/update_gate.dart';
import 'package:mafia_master/platform/links/page_reload.dart';

import '../support/localized.dart';

Widget _host({
  required MinBuild minimum,
  UpdateSurface surface = UpdateSurface.android,
  int build = 10,
  List<Override> extra = const [],
  Widget child = const Scaffold(body: Center(child: Text('GAME'))),
}) => ProviderScope(
  overrides: [
    minBuildFetchProvider.overrideWithValue(() async => minimum),
    updateSurfaceProvider.overrideWithValue(surface),
    appBuildNumberProvider.overrideWithValue(build),
    ...extra,
  ],
  child: localizedApp(UpdateGate(child: child)),
);

void main() {
  test('the gate never signs anybody in, anonymously or otherwise', () {
    // The minimum is public config read with the bare key; a launch must not
    // create an anonymous user to ask it (20261001000100).
    final source = File('lib/app/update_gate.dart').readAsStringSync();
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');
    for (final forbidden in [
      'ensureSession',
      'signInAnonymously',
      'signInWith',
      'signUp',
    ]) {
      expect(code.contains(forbidden), isFalse, reason: forbidden);
    }
  });

  group('the rule', () {
    test('the default blocks nothing, and the build is the pubspec one', () {
      expect(
        MinBuild.none.blocks(kAppBuildNumber, UpdateSurface.android),
        isFalse,
      );
      expect(MinBuild.none.blocks(kAppBuildNumber, UpdateSurface.web), isFalse);
      final version = RegExp(
        r'^version:\s*\S+\+(\d+)\s*$',
        multiLine: true,
      ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1)!;
      expect(
        int.parse(version),
        kAppBuildNumber,
        reason: 'lib/app/app_build.dart must match the +build in pubspec.yaml',
      );
    });

    test('only a build below the minimum is blocked', () {
      const min = MinBuild(android: 11, web: 12);
      expect(min.blocks(10, UpdateSurface.android), isTrue);
      expect(min.blocks(11, UpdateSurface.android), isFalse);
      expect(min.blocks(12, UpdateSurface.android), isFalse);
      expect(min.blocks(11, UpdateSurface.web), isTrue);
      expect(min.blocks(12, UpdateSurface.web), isFalse);
      expect(min.blocks(1, UpdateSurface.other), isFalse);
    });

    test('an unreadable answer is no minimum', () {
      expect(MinBuild.fromJson(null).android, 0);
      expect(MinBuild.fromJson('nope').web, 0);
      expect(MinBuild.fromJson({'android': -5, 'web': 'x'}).android, 0);
      final read = MinBuild.fromJson({'android': 11, 'web': 12});
      expect((read.android, read.web), (11, 12));
    });
  });

  testWidgets('no minimum: the app is untouched', (tester) async {
    await tester.pumpWidget(_host(minimum: MinBuild.none));
    await tester.pumpAndSettle();
    expect(find.text('GAME'), findsOneWidget);
    expect(find.byKey(UpdateGate.sheetKey), findsNothing);
  });

  testWidgets('a build at the minimum is untouched', (tester) async {
    await tester.pumpWidget(
      _host(minimum: const MinBuild(android: 10), build: 10),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateGate.sheetKey), findsNothing);
  });

  testWidgets('below the minimum: «حدّث التطبيق» with the Play button', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(
        minimum: const MinBuild(android: 11),
        extra: [storeOpenerProvider.overrideWithValue(() async => opened++)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    expect(find.text(arStrings.updateRequiredTitle), findsOneWidget);
    expect(find.text(arStrings.updateRequiredBody), findsOneWidget);
    expect(find.byKey(UpdateGate.reloadKey), findsNothing);
    await tester.tap(find.byKey(UpdateGate.storeKey));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('it blocks: nothing underneath can be tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        minimum: const MinBuild(android: 11),
        child: Scaffold(
          body: Center(
            child: TextButton(onPressed: () => taps++, child: const Text('GO')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('GO'), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
    // The scrim cannot be dismissed by tapping outside the sheet either.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
  });

  testWidgets('web: the button reloads the page', (tester) async {
    var reloads = 0;
    await tester.pumpWidget(
      _host(
        minimum: const MinBuild(web: 11),
        surface: UpdateSurface.web,
        extra: [pageReloaderProvider.overrideWithValue(() => reloads++)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(arStrings.updateRequiredReload), findsOneWidget);
    expect(find.byKey(UpdateGate.storeKey), findsNothing);
    await tester.tap(find.byKey(UpdateGate.reloadKey));
    await tester.pump();
    expect(reloads, 1);
  });

  testWidgets('the other platform is never blocked', (tester) async {
    await tester.pumpWidget(
      _host(
        minimum: const MinBuild(android: 99, web: 99),
        surface: UpdateSurface.other,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateGate.sheetKey), findsNothing);
  });

  testWidgets('raising the sheet does not remount the app underneath', (
    tester,
  ) async {
    final state = _Counter();
    await tester.pumpWidget(
      _host(
        minimum: const MinBuild(android: 11),
        child: Scaffold(body: _Counting(state)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    expect(state.inits, 1, reason: 'the router must keep its state');
  });
}

class _Counter {
  int inits = 0;
}

class _Counting extends StatefulWidget {
  final _Counter counter;
  const _Counting(this.counter);
  @override
  State<_Counting> createState() => _CountingState();
}

class _CountingState extends State<_Counting> {
  @override
  void initState() {
    super.initState();
    widget.counter.inits++;
  }

  @override
  Widget build(BuildContext context) => const Text('GAME');
}
