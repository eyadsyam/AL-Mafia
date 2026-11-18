import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/screens/match_route.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

class _FailingRepository extends MemoryMatchRepository {
  _FailingRepository(this.failures) : super(MemoryMatchStore());

  int failures;
  final written = <Match>[];

  @override
  Future<void> persistStep(Match match) async {
    written.add(match);
    if (failures-- > 0) throw StateError('private match contents');
    await super.persistStep(match);
  }
}

void main() {
  Future<(ProviderContainer, MatchController)> mount(
    WidgetTester tester,
    _FailingRepository repository,
  ) async {
    final container = ProviderContainer(
      overrides: [matchRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final controller = container.read(matchControllerProvider.notifier);
    controller.startMatch(
      names: const ['A', 'B', 'C', 'D', 'E', 'F', 'G'],
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      },
      settings: const MatchSettings(),
      seed: 7,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(MatchRoute(onExit: () {}, onAnalytics: () {})),
      ),
    );
    return (container, controller);
  }

  testWidgets('retry writes the current match without blocking the callback', (
    tester,
  ) async {
    final repository = _FailingRepository(1);
    final (_, controller) = await mount(tester, repository);
    tester.widget<MatchFlow>(find.byType(MatchFlow)).onStepCommitted!();
    expect(repository.written, hasLength(1));

    final newer = controller.engine.match.copyWith(phase: GamePhase.morning);
    controller.adoptMatch(newer);
    await tester.pump(ReliabilityTokens.persistRetry);
    await tester.pump();

    expect(repository.written, hasLength(2));
    expect(repository.written.last.phase, GamePhase.morning);
    expect((await repository.loadActiveMatch())?.phase, GamePhase.morning);
  });

  testWidgets('second failure reports only the error type', (tester) async {
    final repository = _FailingRepository(2);
    await mount(tester, repository);
    final messages = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message != null) messages.add(message);
    };

    tester.widget<MatchFlow>(find.byType(MatchFlow)).onStepCommitted!();
    await tester.pump(ReliabilityTokens.persistRetry);
    await tester.pump();

    debugPrint = previous;
    expect(repository.written, hasLength(2));
    expect(messages, ['persistStep retry failed: StateError']);
    expect(messages.single, isNot(contains('private match contents')));
  });
}
