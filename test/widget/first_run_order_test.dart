import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/platform/metrics.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/ui/account/onboarding_account_step.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/widgets/deck/deck_buttons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/first_run_steps.dart';
import '../support/localized.dart';

/// Records every touch of the backend; answers nothing else.
class _Recording implements OnlineBackend {
  final List<String> touches = [];

  @override
  String? userId;

  @override
  Future<String> ensureSession() async {
    touches.add('ensureSession');
    return userId ??= 'u-test';
  }

  @override
  Future<Map<String, dynamic>> call(
    String function,
    Map<String, dynamic> body,
  ) async {
    touches.add(function);
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    touches.add(invocation.memberName.toString());
    throw UnimplementedError();
  }
}

class _Harness {
  final backend = _Recording();
  int factoryCalls = 0;
  final sent = <String>[];

  List<Override> get overrides => [
    accountsAvailableProvider.overrideWithValue(true),
    accountProfileProvider.overrideWith(
      (ref) => Stream.value(AccountProfile.guest),
    ),
    onlineBackendFactoryProvider.overrideWithValue(() async {
      factoryCalls++;
      return backend;
    }),
    economyCapabilitiesProvider.overrideWith(
      (ref) async => const EconomyCapabilities(metrics: true),
    ),
    metricsClientProvider.overrideWithValue(
      MetricsClient(
        enabled: () async => true,
        send: (body) async => sent.add(body['prop'] as String),
      ),
    ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('terms come right after the intro; continue waits for the box', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: localizedApp(const FirstRunScreen()),
      ),
    );
    await passIntro(tester);
    expect(find.byKey(FirstRunScreen.agreeKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.googleKey), findsNothing);
    expect(find.byKey(FirstRunScreen.boyKey), findsNothing);
    BoneButton continueButton() =>
        tester.widget<BoneButton>(find.byKey(FirstRunScreen.continueKey));
    expect(continueButton().onPressed, isNull);
    await tapKey(tester, FirstRunScreen.agreeKey);
    expect(continueButton().onPressed, isNotNull);
  });

  testWidgets('no backend call before the terms are accepted', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: localizedApp(const FirstRunScreen()),
      ),
    );
    await passIntro(tester);
    expect(h.factoryCalls, 0);
    await tapKey(tester, FirstRunScreen.agreeKey);
    expect(h.factoryCalls, 0, reason: 'ticking is not accepting');
    expect(h.backend.touches, isEmpty);
    await tapKey(tester, FirstRunScreen.continueKey);
    await tester.pumpAndSettle();
    expect(h.backend.touches, contains('ensureSession'));
    expect(h.backend.touches, contains('player_safety'));
  });

  testWidgets('the five first_run counts arrive in order', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: localizedApp(const FirstRunScreen()),
      ),
    );
    await passIntro(tester);
    await acceptTerms(tester);
    await tapKey(tester, FirstRunScreen.guestKey);
    await tapKey(tester, FirstRunScreen.boyKey);
    await typeName(tester, 'Eyad');
    await tapKey(tester, FirstRunScreen.continueKey);
    await tester.pumpAndSettle();
    expect(h.sent, ['terms', 'account', 'kind', 'name', 'done']);
    expect((await ProfileStore().load())!.name, 'Eyad');
  });

  testWidgets('termsOnly shows only the terms step and counts only terms', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      ProfileStore.profileKey: '{"name":"Old","gender":"female"}',
    });
    final h = _Harness();
    await tester.pumpWidget(
      ProviderScope(
        overrides: h.overrides,
        child: localizedApp(const SetupRequired(child: Text('HOME'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(FirstRunScreen.agreeKey), findsOneWidget);
    expect(find.byKey(FirstRunScreen.dotsKey), findsNothing);
    expect(find.byKey(FirstRunScreen.googleKey), findsNothing);
    expect(find.byKey(FirstRunScreen.boyKey), findsNothing);
    expect(find.byKey(FirstRunScreen.nameKey), findsNothing);
    await acceptTerms(tester);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(h.sent, ['terms']);
  });
}
