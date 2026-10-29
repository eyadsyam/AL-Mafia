import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/app_build.dart';
import 'package:mafia_master/app/router.dart' show Routes;
import 'package:mafia_master/app/update_gate.dart';
import 'package:mafia_master/platform/links/page_reload.dart';
import 'package:mafia_master/ui/social/invite_privacy.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

class _MemCache implements UpdatePolicyCache {
  UpdatePolicy? stored;
  int saves = 0;
  _MemCache([this.stored]);
  @override
  Future<UpdatePolicy?> load() async => stored;
  @override
  Future<void> save(UpdatePolicy policy) async {
    stored = policy;
    saves++;
  }
}

/// A policy as an old build of the server (or this one) would answer.
UpdatePolicy _policy({
  int minAndroid = 0,
  int minWeb = 0,
  int latestAndroid = 0,
  int latestWeb = 0,
}) => UpdatePolicy(
  min: MinBuild(android: minAndroid, web: minWeb),
  latestAndroid: latestAndroid,
  latestWeb: latestWeb,
);

const _screen = Scaffold(body: Center(child: Text('GAME')));

Widget _host({
  UpdatePolicy? policy,
  UpdateSurface surface = UpdateSurface.android,
  int build = 10,
  ValueNotifier<String>? path,
  _MemCache? cache,
  List<Override> extra = const [],
  Widget child = _screen,
}) {
  final where = path ?? ValueNotifier<String>(Routes.home);
  return ProviderScope(
    overrides: [
      updatePolicyFetchProvider.overrideWithValue(() async => policy),
      updatePolicyCacheProvider.overrideWithValue(cache ?? _MemCache()),
      updateSurfaceProvider.overrideWithValue(surface),
      appBuildNumberProvider.overrideWithValue(build),
      ...extra,
    ],
    child: localizedApp(
      UpdateGate(
        currentPath: () => where.value,
        routeChanges: where,
        child: child,
      ),
    ),
  );
}

Future<void> _size(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('the gate never signs anybody in, anonymously or otherwise', () {
    // The policy is public config read with the bare key; a launch must not
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
        UpdatePolicy.none.blocks(kAppBuildNumber, UpdateSurface.android),
        isFalse,
      );
      expect(
        UpdatePolicy.none.blocks(kAppBuildNumber, UpdateSurface.web),
        isFalse,
      );
      expect(
        UpdatePolicy.none.offersSoft(kAppBuildNumber, UpdateSurface.android),
        isFalse,
      );
      expect(UpdatePolicy.none.bannerMode, BannerMode.perScreen);
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
      final p = _policy(minAndroid: 11, minWeb: 12);
      expect(p.blocks(10, UpdateSurface.android), isTrue);
      expect(p.blocks(11, UpdateSurface.android), isFalse);
      expect(p.blocks(12, UpdateSurface.android), isFalse);
      expect(p.blocks(11, UpdateSurface.web), isTrue);
      expect(p.blocks(12, UpdateSurface.web), isFalse);
      expect(p.blocks(1, UpdateSurface.other), isFalse);
    });

    test('soft is min <= build < latest, never when blocked', () {
      final p = _policy(minAndroid: 10, latestAndroid: 12, latestWeb: 12);
      expect(p.offersSoft(9, UpdateSurface.android), isFalse, reason: 'hard');
      expect(p.offersSoft(10, UpdateSurface.android), isTrue);
      expect(p.offersSoft(11, UpdateSurface.android), isTrue);
      expect(p.offersSoft(12, UpdateSurface.android), isFalse);
      expect(p.offersSoft(11, UpdateSurface.web), isTrue);
      expect(p.offersSoft(11, UpdateSurface.other), isFalse);
    });

    test('an unreadable answer is no policy, and never throws', () {
      expect(UpdatePolicy.fromJson(null), UpdatePolicy.none);
      expect(UpdatePolicy.fromJson('nope'), UpdatePolicy.none);
      final bad = UpdatePolicy.fromJson(const {
        'min_build_android': -5,
        'min_build_web': 'x',
        'latest_build_android': double.nan,
        'latest_build_web': double.infinity,
        'banner_mode': 7,
      });
      expect(bad, UpdatePolicy.none);
      expect(MinBuild.fromJson(const {'android': -5, 'web': 'x'}).android, 0);
    });

    test('an old server (no new columns) reads as nothing newer', () {
      final old = UpdatePolicy.fromJson(const {
        'min_build_android': 11,
        'min_build_web': 12,
      });
      expect((old.min.android, old.min.web), (11, 12));
      expect((old.latestAndroid, old.latestWeb), (0, 0));
      expect(old.bannerMode, BannerMode.perScreen);
      expect(old.offersSoft(20, UpdateSurface.android), isFalse);
    });

    test('banner mode: shell is known, anything else is per screen', () {
      expect(
        UpdatePolicy.fromJson(const {'banner_mode': 'shell'}).bannerMode,
        BannerMode.shell,
      );
      expect(
        UpdatePolicy.fromJson(const {'banner_mode': 'per_screen'}).bannerMode,
        BannerMode.perScreen,
      );
      expect(
        UpdatePolicy.fromJson(const {'banner_mode': 'sideways'}).bannerMode,
        BannerMode.perScreen,
      );
    });

    test('the cache round-trips a policy', () {
      const p = UpdatePolicy(
        min: MinBuild(android: 3, web: 4),
        latestAndroid: 18,
        latestWeb: 19,
        bannerMode: BannerMode.shell,
      );
      expect(UpdatePolicy.fromJson(p.toJson()), p);
    });
  });

  group('hard', () {
    testWidgets('no policy: the app is untouched', (tester) async {
      await tester.pumpWidget(_host(policy: UpdatePolicy.none));
      await tester.pumpAndSettle();
      expect(find.text('GAME'), findsOneWidget);
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('a build at the minimum is untouched', (tester) async {
      await tester.pumpWidget(
        _host(policy: _policy(minAndroid: 10), build: 10),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
    });

    testWidgets('below the minimum: «حدّث التطبيق» with the Play button', (
      tester,
    ) async {
      final launched = <Uri>[];
      await tester.pumpWidget(
        _host(
          policy: _policy(minAndroid: 11),
          extra: [
            storeLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return true;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
      expect(find.text(arStrings.updateRequiredTitle), findsOneWidget);
      expect(find.text(arStrings.updateRequiredBody), findsOneWidget);
      expect(find.text(arStrings.updateRequiredStore), findsOneWidget);
      expect(find.byKey(UpdateGate.reloadKey), findsNothing);
      expect(
        find.byKey(UpdateGate.laterKey),
        findsNothing,
        reason: 'no way out',
      );
      await tester.tap(find.byKey(UpdateGate.storeKey));
      await tester.pumpAndSettle();
      expect(launched.map((u) => u.scheme), ['market']);
      expect(find.byKey(UpdateGate.failedKey), findsNothing);
    });

    testWidgets('it blocks on any screen, and nothing underneath taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          policy: _policy(minAndroid: 11),
          path: ValueNotifier<String>(Routes.match),
          child: Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('GO'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
      await tester.tap(find.text('GO'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
      // Tapping outside the content cannot dismiss it either.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    });

    testWidgets('web: the button reloads the page', (tester) async {
      var reloads = 0;
      await tester.pumpWidget(
        _host(
          policy: _policy(minWeb: 11),
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
          policy: _policy(minAndroid: 99, minWeb: 99, latestAndroid: 99),
          surface: UpdateSurface.other,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('raising the screen does not remount the app underneath', (
      tester,
    ) async {
      final state = _Counter();
      await tester.pumpWidget(
        _host(
          policy: _policy(minAndroid: 11),
          child: Scaffold(body: _Counting(state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
      expect(state.inits, 1, reason: 'the router must keep its state');
    });
  });

  group('soft', () {
    testWidgets('at Home: «فيه نسخة جديدة», dismissed with «بعدين»', (
      tester,
    ) async {
      await tester.pumpWidget(_host(policy: _policy(latestAndroid: 12)));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
      expect(find.text(arStrings.updateSoftTitle), findsOneWidget);
      expect(find.text(arStrings.updateSoftBody), findsOneWidget);
      expect(find.text(arStrings.updateSoftNow), findsOneWidget);
      expect(find.text(arStrings.updateSoftLater), findsOneWidget);
      expect(find.text(arStrings.updateStoreFailed), findsNothing);

      await tester.tap(find.byKey(UpdateGate.laterKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      expect(find.text('GAME'), findsOneWidget);
    });

    testWidgets('«بعدين»: the screen fades away untappable, the app is free', (
      tester,
    ) async {
      await tester.pumpWidget(_host(policy: _policy(latestAndroid: 12)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateGate.laterKey));
      await tester.pump();
      await tester.pump(DeckTokens.sheetExit ~/ 2);
      // Mid-fade: still drawn, but it takes no taps, and the app underneath
      // is no longer held.
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byKey(UpdateGate.softKey),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsWidgets,
      );
      expect(
        find.ancestor(
          of: find.text('GAME'),
          matching: find.byWidgetPredicate(
            (w) => w is IgnorePointer && w.ignoring,
          ),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('reduced motion: the screen only fades, no scale', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(policy: _policy(latestAndroid: 12)));
      await tester.pump();
      await tester.pump();
      expect(
        find.ancestor(
          of: find.byKey(UpdateGate.softKey),
          matching: find.byType(ScaleTransition),
        ),
        findsNothing,
      );
      await tester.pump(DeckTokens.reduced);
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
    });

    testWidgets('system back: «بعدين» on the soft screen, leaves on the hard', (
      tester,
    ) async {
      await tester.pumpWidget(_host(policy: _policy(latestAndroid: 12)));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      expect(find.text('GAME'), findsOneWidget);

      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(policy: _policy(minAndroid: 11)));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(calls, contains('SystemNavigator.pop'));
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    });

    testWidgets('once per launch: «بعدين» is final, even back at Home', (
      tester,
    ) async {
      final path = ValueNotifier<String>(Routes.home);
      await tester.pumpWidget(
        _host(policy: _policy(latestAndroid: 12), path: path),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateGate.laterKey));
      await tester.pumpAndSettle();
      path.value = Routes.players;
      await tester.pumpAndSettle();
      path.value = Routes.home;
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('not off Home; it waits, and shows once when Home arrives', (
      tester,
    ) async {
      final path = ValueNotifier<String>(Routes.players);
      await tester.pumpWidget(
        _host(policy: _policy(latestAndroid: 12), path: path),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      for (final off in [Routes.match, Routes.lobby, Routes.online]) {
        path.value = off;
        await tester.pumpAndSettle();
        expect(find.byKey(UpdateGate.softKey), findsNothing, reason: off);
      }
      path.value = Routes.home;
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
    });

    testWidgets('it leaves when the app leaves Home, and does not return', (
      tester,
    ) async {
      final path = ValueNotifier<String>(Routes.home);
      await tester.pumpWidget(
        _host(policy: _policy(latestAndroid: 12), path: path),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
      path.value = Routes.lobby; // e.g. an invite taken from inside the app
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      path.value = Routes.home;
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('never over a private moment', (tester) async {
      await tester.pumpWidget(
        _host(
          policy: _policy(latestAndroid: 12),
          extra: [privateMomentProvider.overrideWith((_) => true)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('without a router (no path), it is never shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            updatePolicyFetchProvider.overrideWithValue(
              () async => _policy(latestAndroid: 12),
            ),
            updatePolicyCacheProvider.overrideWithValue(_MemCache()),
            updateSurfaceProvider.overrideWithValue(UpdateSurface.android),
            appBuildNumberProvider.overrideWithValue(10),
          ],
          child: localizedApp(const UpdateGate(child: _screen)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('nothing newer announced (latest 0, or at or below): nothing', (
      tester,
    ) async {
      await tester.pumpWidget(_host(policy: _policy()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      await tester.pumpWidget(
        _host(policy: _policy(latestAndroid: 10), build: 10),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
    });

    testWidgets('an old server without the new columns: nothing', (
      tester,
    ) async {
      final old = UpdatePolicy.fromJson(const {
        'min_build_android': 5,
        'min_build_web': 5,
      });
      await tester.pumpWidget(_host(policy: old));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
    });

    testWidgets('below the minimum the hard screen wins over soft', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(policy: _policy(minAndroid: 11, latestAndroid: 12)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      expect(find.byKey(UpdateGate.laterKey), findsNothing);
    });

    testWidgets('web: reload, no store line', (tester) async {
      var reloads = 0;
      await tester.pumpWidget(
        _host(
          policy: _policy(latestWeb: 12),
          surface: UpdateSurface.web,
          extra: [pageReloaderProvider.overrideWithValue(() => reloads++)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
      expect(find.text(arStrings.updateSoftBody), findsNothing);
      expect(find.byKey(UpdateGate.storeKey), findsNothing);
      await tester.tap(find.byKey(UpdateGate.reloadKey));
      await tester.pump();
      expect(reloads, 1);
    });
  });

  group('the Play button', () {
    Future<List<Uri>> run(
      WidgetTester tester,
      Future<bool> Function(Uri uri) answer, {
      UpdatePolicy? policy,
    }) async {
      final tried = <Uri>[];
      await tester.pumpWidget(
        _host(
          policy: policy ?? _policy(latestAndroid: 12),
          extra: [
            storeLauncherProvider.overrideWithValue((uri) {
              tried.add(uri);
              return answer(uri);
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(UpdateGate.storeKey));
      await tester.pumpAndSettle();
      return tried;
    }

    testWidgets('market: first, and nothing more when it opens', (
      tester,
    ) async {
      final tried = await run(tester, (_) async => true);
      expect(tried.map((u) => u.toString()), [
        'market://details?id=com.mafiamaster.mafia_master',
      ]);
      expect(find.byKey(UpdateGate.failedKey), findsNothing);
    });

    testWidgets('market refused: the https page is tried next', (tester) async {
      final tried = await run(tester, (uri) async => uri.scheme == 'https');
      expect(tried.map((u) => u.toString()), [
        'market://details?id=com.mafiamaster.mafia_master',
        'https://play.google.com/store/apps/details?id=com.mafiamaster.mafia_master',
      ]);
      expect(find.byKey(UpdateGate.failedKey), findsNothing);
    });

    testWidgets('market throws: the https page is still tried', (tester) async {
      final tried = await run(tester, (uri) async {
        if (uri.scheme == 'market') throw StateError('no handler');
        return true;
      });
      expect(tried.length, 2);
      expect(find.byKey(UpdateGate.failedKey), findsNothing);
    });

    testWidgets('both fail: the line stays in the sheet, with «بعدين»', (
      tester,
    ) async {
      final tried = await run(tester, (_) async => false);
      expect(tried.length, 2);
      expect(find.byKey(UpdateGate.failedKey), findsOneWidget);
      expect(find.text(arStrings.updateStoreFailed), findsOneWidget);
      expect(find.text(arStrings.updateSoftNow), findsOneWidget);
      expect(find.byKey(UpdateGate.laterKey), findsOneWidget);
      // Not a snackbar: it does not go away on its own.
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(UpdateGate.failedKey), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('both throw, on the hard screen: the line shows too', (
      tester,
    ) async {
      final tried = await run(
        tester,
        (_) async => throw StateError('no handler'),
        policy: _policy(minAndroid: 11),
      );
      expect(tried.length, 2);
      expect(find.byKey(UpdateGate.failedKey), findsOneWidget);
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    });

    testWidgets('a later success clears the line', (tester) async {
      var ok = false;
      await run(tester, (_) async => ok);
      expect(find.byKey(UpdateGate.failedKey), findsOneWidget);
      ok = true;
      await tester.tap(find.byKey(UpdateGate.storeKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.failedKey), findsNothing);
    });
  });

  group('the cached policy', () {
    testWidgets('offline with a cached hard block: still blocked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(policy: null, cache: _MemCache(_policy(minAndroid: 11))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsOneWidget);
    });

    testWidgets('offline with a cached soft policy: soft at Home', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(policy: null, cache: _MemCache(_policy(latestAndroid: 12))),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.softKey), findsOneWidget);
    });

    testWidgets('offline and nothing cached: never blocks', (tester) async {
      await tester.pumpWidget(_host(policy: null, cache: _MemCache()));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
      expect(find.byKey(UpdateGate.softKey), findsNothing);
      expect(find.text('GAME'), findsOneWidget);
    });

    testWidgets('an answer from the server is kept, and beats the cache', (
      tester,
    ) async {
      final cache = _MemCache(_policy(minAndroid: 11));
      // The server lifted the minimum since: no block, and the cache follows.
      await tester.pumpWidget(_host(policy: _policy(), cache: cache));
      await tester.pumpAndSettle();
      expect(find.byKey(UpdateGate.sheetKey), findsNothing);
      expect(cache.saves, 1);
      expect(cache.stored, _policy());
    });

    testWidgets('the banner mode follows the answer (and the cache)', (
      tester,
    ) async {
      const answer = UpdatePolicy(bannerMode: BannerMode.shell);
      await tester.pumpWidget(_host(policy: answer));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('GAME')),
      );
      expect(container.read(bannerModeProvider), BannerMode.shell);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(policy: null, cache: _MemCache(answer)));
      await tester.pumpAndSettle();
      final again = ProviderScope.containerOf(
        tester.element(find.text('GAME')),
      );
      expect(again.read(bannerModeProvider), BannerMode.shell);
    });

    testWidgets('the banner mode defaults to per screen', (tester) async {
      await tester.pumpWidget(_host(policy: null));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.text('GAME')),
      );
      expect(container.read(bannerModeProvider), BannerMode.perScreen);
    });
  });

  group('no overflow', () {
    for (final size in const [Size(360, 640), Size(640, 360)]) {
      for (final soft in [false, true]) {
        testWidgets('${soft ? "soft" : "hard"} at ${size.width.toInt()}x'
            '${size.height.toInt()}, with the failure line', (tester) async {
          await _size(tester, size);
          await tester.pumpWidget(
            _host(
              policy: soft
                  ? _policy(latestAndroid: 12)
                  : _policy(minAndroid: 11),
              extra: [
                storeLauncherProvider.overrideWithValue((_) async => false),
              ],
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(UpdateGate.storeKey));
          await tester.pumpAndSettle();
          expect(find.byKey(UpdateGate.failedKey), findsOneWidget);
          expect(tester.takeException(), isNull);
          // Everything is reachable: scrolled to the end, the last control is
          // on screen.
          final last = soft ? UpdateGate.laterKey : UpdateGate.failedKey;
          await tester.ensureVisible(find.byKey(last));
          await tester.pumpAndSettle();
          final box = tester.getRect(find.byKey(last));
          expect(box.bottom, lessThanOrEqualTo(size.height));
          expect(box.left, greaterThanOrEqualTo(0));
          expect(box.right, lessThanOrEqualTo(size.width));
        });
      }
    }
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
