import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/night/night_action_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';

import '../support/localized.dart';

/// **The Doctor's own tile says the same thing on every night of the match.**
///
/// ## Why this is a test and not a comment
///
/// The tile used to read the Doctor's own name while the self-protection was
/// available and «احمي نفسك حالا» once it had been spent. Both halves are
/// defensible on their own and the pair is not: the *label itself* then
/// announces whether the ability is still there. Anybody who has held the phone
/// once knows what an unspent tile looks like, so the wording became a second,
/// louder copy of the state that the dimming and the lock already carry — and
/// unlike them it is a word a screen reader will read out loud at a table.
///
/// So the label is fixed and the state is drawn. This file holds that: one
/// string before and after, never a player's name, and the tile still present,
/// still the same size and no longer tappable once it is gone.
///
/// The grid *geometry* under the same rule is covered by
/// `night_grid_symmetry_test`; this is about the word.
void main() {
  const names = ['أحمد', 'ليلى', 'سالم', 'ندى', 'عمر', 'فاطمة', 'كريم'];
  const roleCounts = {
    Role.mafia: 2,
    Role.doctor: 1,
    Role.detective: 1,
    Role.citizen: 3,
  };

  late ProviderContainer container;
  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  /// Starts a match, deals it, and stops on the Doctor's night turn.
  ///
  /// Walks the controller rather than the widget tree: the choreography of
  /// holding and swiping is somebody else's suite, and this one only needs the
  /// Doctor to be the seat holding the phone.
  Future<int> openDoctorsTurn({bool spendSelfProtect = false}) async {
    controller().startMatch(
      names: names,
      roleCounts: roleCounts,
      settings: const MatchSettings(),
      seed: 7,
    );

    // The deal. Each card is asked for, looked at, and passed on — and the one
    // that comes back a Doctor is the seat this test is about.
    var doctorSeat = -1;
    while (controller().snapshot.currentActorSeat != null) {
      await controller().revealCurrentRole();
      final reveal = container.read(matchControllerProvider)?.reveal;
      if (reveal?.role == Role.doctor) doctorSeat = reveal!.seat;
      controller().confirmRevealed();
    }
    expect(doctorSeat, isNot(-1), reason: 'no seat was dealt the Doctor');

    if (spendSelfProtect) {
      // Night one, spent on themselves. Every other actor takes an ordinary
      // turn so the night closes and a second one can open.
      controller().beginNight();
      await _playNight(controller(), selfProtectSeat: doctorSeat);
      // Morning, day and vote, back around to night two.
      await _throughTheDay(controller());
    }

    controller().beginNight();
    while (controller().snapshot.currentActorSeat != doctorSeat) {
      await _actOnce(controller());
    }
    await controller().openActorTurn();
    return doctorSeat;
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

    // The turn's own gate. Nothing of the grid exists until the holder has
    // said the phone is theirs, so every assertion below would otherwise be
    // passing against an empty screen.
    final pad = find.byKey(TurnShell.holdPad);
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(NightGridTile), findsWidgets);
  }

  /// The words the Doctor's tile carries, from the shipped copy.
  final selfProtect = EngineCopy.nightSpecial(arStrings, Role.doctor);

  /// Every label currently on the grid.
  List<String> labelsOn(WidgetTester tester) => [
    for (final t in tester.widgetList<NightGridTile>(
      find.byType(NightGridTile),
    ))
      t.choice.label,
  ];

  String labelOf(WidgetTester tester, Finder tile) =>
      tester.widget<NightGridTile>(tile).choice.label;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  testWidgets('the tile reads the self-protection words, not the Doctor', (
    tester,
  ) async {
    final seat = await openDoctorsTurn();
    await pumpNight(tester);

    final tile = find.byKey(NightGrid.tile(seat));
    expect(tile, findsOneWidget);
    expect(labelOf(tester, tile), selfProtect);
    // Rendered, not merely configured: the tile draws its label inside a
    // `Text.rich` beside the diamond, so the assertion has to look through it.
    expect(
      find.descendant(
        of: tile,
        matching: find.textContaining(selfProtect, findRichText: true),
      ),
      findsOneWidget,
    );
    // Their own name is nowhere on the grid. The special tile stands in the
    // place their seat would have taken, so this covers the whole screen.
    expect(labelsOn(tester), isNot(contains(names[seat])));
  });

  testWidgets('the same words after it has been spent, dimmed and locked', (
    tester,
  ) async {
    final seat = await openDoctorsTurn(spendSelfProtect: true);
    await pumpNight(tester);

    final tile = find.byKey(NightGrid.tile(seat));
    expect(tile, findsOneWidget, reason: 'a spent tile never disappears');
    expect(
      labelOf(tester, tile),
      selfProtect,
      reason: 'the label must not change when the ability is gone',
    );
    expect(labelsOn(tester), isNot(contains(names[seat])));

    final widget = tester.widget<NightGridTile>(tile);
    expect(
      widget.choice.spent,
      isTrue,
      reason: 'the spent state is drawn, not said',
    );
    expect(
      widget.onTap,
      isNull,
      reason: 'a spent tile that still accepts taps is a second use',
    );
  });

  testWidgets('the Doctor is never offered a night off', (tester) async {
    await openDoctorsTurn();
    await pumpNight(tester);

    // The other three roles end their grid with "nobody tonight". The Doctor's
    // last tile is the self-protection, so the skip sentinel is not on screen
    // at all: protection is mandatory, and a tile that let them decline would
    // be the engine and the grid disagreeing.
    expect(find.byKey(NightGrid.tile(NightChoice.skipSeat)), findsNothing);
    expect(
      labelsOn(tester),
      isNot(contains(EngineCopy.nightSpecial(arStrings, Role.mafia))),
    );
  });
}

/// Submits one legal action for whoever currently holds the phone.
Future<void> _actOnce(MatchController controller, {int? target}) async {
  await controller.openActorTurn();
  final seat = controller.snapshot.currentActorSeat;
  if (seat == null) return;
  final players = controller.snapshot.public.players;
  final choice =
      target ??
      players
          .firstWhere((p) => p.status == PlayerStatus.alive && p.seat != seat)
          .seat;
  final turn = controller.state?.actorTurn;
  if (turn == null) return;
  await controller.submitNightAction(
    kind: nightActionFor(turn.actorRole),
    targetSeat: choice,
    // Protecting your own seat is the once-per-match bullet, and the engine
    // refuses it unless the caller says so — which is exactly the rule the
    // tile draws.
    useBullet: choice == seat,
  );
  controller.passTurn();
}

Future<void> _playNight(
  MatchController controller, {
  required int selfProtectSeat,
}) async {
  while (controller.snapshot.currentActorSeat != null) {
    final seat = controller.snapshot.currentActorSeat!;
    await _actOnce(controller, target: seat == selfProtectSeat ? seat : null);
  }
}

/// Night one's morning, argument and ballot, ending back at the pre-night
/// lobby. Nobody is voted out — every ballot is an abstention — so the roster
/// stays whole and night two has the same seats as night one.
Future<void> _throughTheDay(MatchController controller) async {
  controller.resolveNight();
  // Straight from the morning to the argument: day one's «اسم واحد» round is
  // its own surface and this test has no business walking it.
  controller.beginDiscussion();
  controller.beginVoting();
  while (controller.snapshot.currentActorSeat != null) {
    await controller.submitVote(targetSeat: null);
  }
  controller.resolveDayVote();
  controller.winCheck();
}
