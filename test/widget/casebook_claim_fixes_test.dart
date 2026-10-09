import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/missions/casebook_data.dart';
import 'package:mafia_master/ui/missions/casebook_sheet.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/casebook_fixture.dart';
import '../support/fake_backend.dart';
import '../support/localized.dart';

class _Refuses extends FakeCasebookController {
  final String? code;
  _Refuses(this.code);

  @override
  Future<CaseGrant> claimMission({
    required bool weekly,
    required int slot,
  }) async {
    claims.add('daily:$slot');
    throw CaseClaimFailed(code);
  }
}

/// The real claim path over a build that skips the capability read.
class _Real extends CasebookController {
  int builds = 0;

  @override
  Future<Casebook> build() async {
    builds++;
    return Casebook.fromJson(casebookJson());
  }
}

void main() {
  Future<void> pump(WidgetTester tester, CasebookController c) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [casebookProvider.overrideWith(() => c)],
        child: localizedApp(const Scaffold(body: CasebookSheet())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a generic refusal says so', (tester) async {
    await pump(tester, _Refuses(null));
    await tester.tap(find.byKey(CasebookSheet.claimKey('d1')));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.casebookClaimError), findsOneWidget);
  });

  testWidgets('ALREADY_CLAIMED is quiet', (tester) async {
    await pump(tester, _Refuses('ALREADY_CLAIMED'));
    await tester.tap(find.byKey(CasebookSheet.claimKey('d1')));
    await tester.pumpAndSettle();
    expect(find.text(arStrings.casebookClaimError), findsNothing);
  });

  test('a claim whose answer was lost refreshes the hub', () async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    backend.responders['economy'] = (body) =>
        throw StateError('connection reset');
    final real = _Real();
    final c = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        casebookProvider.overrideWith(() => real),
      ],
    );
    addTearDown(c.dispose);
    await c.read(casebookProvider.future);
    final before = real.builds;
    await expectLater(
      c.read(casebookProvider.notifier).claimMission(weekly: false, slot: 1),
      throwsA(isA<CaseClaimFailed>()),
    );
    expect(real.builds, greaterThan(before));
  });

  test('a server refusal also refreshes', () async {
    final backend = FakeBackend(
      roomId: 'room',
      state: roomState(phase: 'lobby'),
      players: roster(5),
    );
    backend.responders['economy'] = (body) =>
        throw const BackendException('ALREADY_CLAIMED', 'taken');
    final real = _Real();
    final c = ProviderContainer(
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        casebookProvider.overrideWith(() => real),
      ],
    );
    addTearDown(c.dispose);
    await c.read(casebookProvider.future);
    final before = real.builds;
    await expectLater(
      c.read(casebookProvider.notifier).claimMission(weekly: false, slot: 1),
      throwsA(
        isA<CaseClaimFailed>().having((e) => e.code, 'code', 'ALREADY_CLAIMED'),
      ),
    );
    expect(real.builds, greaterThan(before));
  });
}
