import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/character_bonds.dart';
import 'package:mafia_master/engine/models/enums.dart' hide Alignment;
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/ui/fun/character_dossiers.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/scripted_match.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  CharacterBondLedger ledger() {
    var value = CharacterBondLedger.empty;
    for (var i = 0; i < 4; i++) {
      value = progressCharacterBonds(
        value,
        CharacterBondCase(
          receiptId: 'case-$i',
          completedAt: DateTime.utc(2026, 9, 20 + i),
          winner: i.isEven ? engine.Alignment.town : engine.Alignment.mafia,
          roles: Role.values.toSet(),
          survivingRoles: const {Role.doctor, Role.citizen},
          personalRole: Role.detective,
          momentRole: Role.detective,
          zeroDeaths: i == 3,
        ),
      );
    }
    return value;
  }

  Future<void> seedLedger() => CharacterBondStore().save(ledger());

  testWidgets('dossiers render all four portraits at 360px in Arabic', (
    tester,
  ) async {
    await seedLedger();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(
          const Scaffold(
            body: SingleChildScrollView(child: CharacterDossiers()),
          ),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(CharacterDossiers.sectionKey), findsOneWidget);
    expect(find.byType(BondPortraitArt), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dossiers render all four portraits at 360px in English', (
    tester,
  ) async {
    await seedLedger();
    await tester.binding.setSurfaceSize(const Size(360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: localizedApp(
          const Scaffold(
            body: SingleChildScrollView(child: CharacterDossiers()),
          ),
          locale: const Locale('en'),
        ),
      ),
    );
    await loadArtwork(tester);
    await tester.pumpAndSettle();

    expect(find.text('The Four Dossiers'), findsOneWidget);
    expect(find.byType(BondPortraitArt), findsNWidgets(4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home character copy keeps one fixed geometry across states', (
    tester,
  ) async {
    await seedLedger();
    final now = DateTime.utc(2026, 9, 24);
    Future<Size> draw(DateTime clock) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            characterBondClockProvider.overrideWithValue(() => clock),
          ],
          child: localizedApp(const Scaffold(body: BondHomeLine())),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byKey(BondHomeLine.lineKey));
    }

    final recent = await draw(now);
    final absent = await draw(now.add(BondTokens.inactiveAfter));
    expect(recent.height, BondTokens.homeLineHeight);
    expect(absent, recent);
  });

  testWidgets(
    'a local case is recorded only after the public result is shown',
    (tester) async {
      final engine = scriptedMatch(playToEnd: true);
      expect(engine.match.phase, GamePhase.result);
      final container = ProviderContainer(
        overrides: [
          matchEngineProvider.overrideWithValue(engine),
          economyCapabilitiesProvider.overrideWith(
            (ref) async => const EconomyCapabilities(
              fun: FunCapabilities(characterBonds: true, known: true),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(economyCapabilitiesProvider.future);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(const Scaffold(body: Text('before result'))),
        ),
      );
      expect(
        (await container.read(characterBondLedgerProvider.future)).isEmpty,
        isTrue,
      );

      final match = engine.match;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            ResultScreen(
              winner: match.outcome!.winner,
              rows: [
                for (final player in match.players)
                  ResultRow(
                    seat: player.seat,
                    name: player.name,
                    role: player.role,
                    eliminatedLabel: player.eliminatedOn?.toString(),
                  ),
              ],
              onHome: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final recorded = await container.read(characterBondLedgerProvider.future);
      expect(recorded.receipts.keys, contains('local-${match.id}'));
    },
  );
}
