import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/timeline_event.dart';
import 'package:mafia_master/transport/room_codec.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/night/morning_screen.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/elder_reveal_card.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';

/// The Elder reveals himself at night (owner, 2026-11-19): his own special
/// tile reads «اكشف نفسي الصبح» until he has revealed, the next morning the
/// table is told, a dead Elder reveals nothing, and the grid is the same grid.
void main() {
  const names = ['أحمد', 'ليلى', 'سالم', 'ندى', 'عمر', 'فاطمة', 'كريم'];
  const roleCounts = {
    Role.mafia: 2,
    Role.elder: 1,
    Role.citizen: 4,
  };
  const settings = MatchSettings(elderEnabled: true, abstainAllowed: true);

  late ProviderContainer container;
  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  int seatOf(Role role) =>
      controller().engine.match.players.indexWhere((p) => p.role == role);

  Future<void> deal() async {
    controller().startMatch(
      names: names,
      roleCounts: roleCounts,
      settings: settings,
      seed: 7,
    );
    while (controller().snapshot.currentActorSeat != null) {
      await controller().revealCurrentRole();
      controller().confirmRevealed();
    }
  }

  /// Takes the turn of the seat holding the phone. [pick] names what each
  /// role does; the default is to choose nobody.
  Future<void> turn({
    bool reveal = false,
    int? mafiaTarget,
  }) async {
    await controller().openActorTurn();
    final t = controller().state!.actorTurn!;
    if (t.actorRole == Role.mafia && mafiaTarget != null) {
      await controller().submitNightAction(
        kind: NightActionKind.mafiaVote,
        targetSeat: mafiaTarget,
      );
    } else {
      await controller().skipNightAction(
        revealElder: reveal && t.actorRole == Role.elder,
      );
    }
    controller().passTurn();
  }

  Future<void> night({bool reveal = false, int? mafiaTarget}) async {
    while (controller().snapshot.currentActorSeat != null) {
      await turn(reveal: reveal, mafiaTarget: mafiaTarget);
    }
  }

  Future<void> pumpNight(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: NightActionScreen(onNightComplete: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final pad = find.byKey(TurnShell.holdPad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(NightGridTile), findsWidgets);
  }

  /// The special tile and every tile's rect, for the seat now holding the phone.
  ({NightGridTile special, List<Rect> rects}) grid(WidgetTester tester) {
    final tiles = tester.widgetList<NightGridTile>(find.byType(NightGridTile));
    return (
      special: tiles.firstWhere((t) => t.choice.special),
      rects: [
        for (final e in find.byType(NightGridTile).evaluate())
          tester.getRect(find.byWidget(e.widget)),
      ],
    );
  }

  test('reveal at night: ElderRevealed on the morning, weight 3 at the vote',
      () async {
    await deal();
    final elder = seatOf(Role.elder);
    controller().beginNight();
    await night(reveal: true);
    expect(controller().engine.isElderRevealed(elder), isFalse);

    final report = controller().resolveNight();
    expect(report.elderRevealedSeat, elder);
    expect(controller().snapshot.revealedElderSeats, {elder});
    expect(controller().engine.voteWeightFor(elder), 3);
    final event = controller().engine.match.eventLog
        .whereType<ElderRevealed>()
        .single;
    expect(event.phaseRef.phase, GamePhase.morning);
    expect(event.phaseRef.number, controller().engine.match.dayNumber);
  });

  test('no reveal chosen: nothing is announced', () async {
    await deal();
    controller().beginNight();
    await night();
    final report = controller().resolveNight();
    expect(report.elderRevealedSeat, isNull);
    expect(controller().snapshot.revealedElderSeats, isEmpty);
    expect(controller().engine.voteWeightFor(seatOf(Role.elder)), 1);
  });

  test('the Elder killed the same night reveals nothing', () async {
    await deal();
    final elder = seatOf(Role.elder);
    controller().beginNight();
    await night(reveal: true, mafiaTarget: elder);
    final report = controller().resolveNight();
    expect(report.victimSeats, contains(elder));
    expect(report.elderRevealedSeat, isNull);
    expect(controller().snapshot.revealedElderSeats, isEmpty);
    expect(controller().engine.match.eventLog.whereType<ElderRevealed>(),
        isEmpty);
  });

  /// A fresh match stopped on the first turn of [role], drawn.
  Future<({NightGridTile special, List<Rect> rects})> gridFor(
    WidgetTester tester,
    Role role,
  ) async {
    await tester.pumpWidget(const SizedBox());
    container = ProviderContainer();
    addTearDown(container.dispose);
    await deal();
    controller().beginNight();
    while (controller().engine.match.players[
            controller().snapshot.currentActorSeat!].role !=
        role) {
      await turn();
    }
    await controller().openActorTurn();
    await pumpNight(tester);
    return grid(tester);
  }

  testWidgets('the Elder tile offers the reveal, in the same grid shape as the citizen', (
    tester,
  ) async {
    final elderGrid = await gridFor(tester, Role.elder);
    expect(
      elderGrid.special.choice.label,
      EngineCopy.nightSpecial(arStrings, Role.elder, elderReveals: true),
    );
    expect(elderGrid.special.choice.label, arStrings.nightElderRevealTile);
    expect(elderGrid.special.choice.seat, NightChoice.skipSeat);

    final citizenGrid = await gridFor(tester, Role.citizen);
    expect(citizenGrid.special.choice.label, arStrings.nightSpecialCitizen);
    expect(citizenGrid.rects.length, elderGrid.rects.length);
    expect(citizenGrid.rects, elderGrid.rects);
  });

  testWidgets('a revealed Elder is back on the citizen words', (tester) async {
    await deal();
    final elder = seatOf(Role.elder);
    controller().beginNight();
    await night(reveal: true);
    controller().resolveNight();
    controller().beginDiscussion();
    controller().beginVoting();
    while (controller().snapshot.currentActorSeat != null) {
      await controller().submitVote(targetSeat: null);
    }
    controller().resolveDayVote();
    controller().winCheck();
    controller().beginNight();
    while (controller().snapshot.currentActorSeat != elder) {
      await turn();
    }
    await controller().openActorTurn();
    await pumpNight(tester);
    expect(grid(tester).special.choice.label, arStrings.nightSpecialCitizen);
  });

  testWidgets('the morning card names the Elder and his three votes', (
    tester,
  ) async {
    Future<void> pump(String? name) => tester.pumpWidget(
      localizedApp(
        MorningScreen(
          dayNumber: 1,
          victimName: null,
          someoneSavedUnnamed: false,
          elderRevealedName: name,
          onContinue: () {},
        ),
      ),
    );
    await pump('ليلى');
    expect(find.byType(ElderRevealCard), findsOneWidget);
    expect(find.text(arStrings.morningElderRevealed('ليلى')), findsOneWidget);
    expect(find.text(arStrings.morningElderWeight), findsOneWidget);
    await pump(null);
    expect(find.byType(ElderRevealCard), findsNothing);
  });

  test('the online morning payload carries the seat only when there is one', () {
    final withSeat = morningFromJson({
      'victimSeats': <int>[],
      'elderRevealedSeat': 3,
    });
    expect(withSeat?.elderRevealedSeat, 3);
    expect(morningFromJson({'victimSeats': <int>[]})?.elderRevealedSeat,
        isNull);
  });
}
