import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/l10n_ext.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// **The online private role card, and who asks for it.**
///
/// ## Why this file exists
///
/// Offline, a screen walks the seats and asks for each one's card in turn.
/// Online there is no such screen and no phone to pass: five clients sit in the
/// `reveal` phase at the same moment, and each one has to ask for its own card
/// itself. Nothing did. `revealCurrentRole` existed, was correct, and had no
/// production caller — so the deal completed on the server, the room moved to
/// `reveal`, and every phone showed the table backs and «مستني المسؤول»
/// forever. A real five-player match on the production backend is what found
/// it, because compiling code and passing engine tests both looked fine.
///
/// The night has the same shape and the same hole: `openActorTurn` had callers
/// in the offline flow only, so an online player who still owed a move was
/// shown «مستني باقي اللاعبين» — told to wait for himself — and the match could
/// not go past night one.
///
/// The tests below are the halves of that: the private view must arrive without
/// anybody tapping anything, in both phases; it must be *this device's* and no
/// information at all about anybody else's; and the ask has to survive the
/// first snapshot of a phase arriving before the answer is ready, which is the
/// race a real match on the production backend actually hit.
void main() {
  late FakeBackend backend;
  late OnlineTransport transport;
  late ProviderContainer container;

  /// A room already dealt and sitting in `reveal`, seen from [seat].
  Future<void> pumpTable(
    WidgetTester tester, {
    int seat = 1,
    String? role = 'mafia',
    List<String> teammateNames = const [],
    String phase = 'reveal',
    bool acted = false,
  }) async {
    backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: phase,
        // A night with a deadline draws a countdown in the middle of the
        // table. Without one the centre falls back to «مستني باقي اللاعبين»,
        // which is also the footer's waiting copy — and an assertion that
        // cannot tell the two apart is not an assertion about the footer.
        endsAt: phase == 'night' ? DateTime.utc(2026, 9, 2, 12, 2) : null,
      ),
      players: roster(5),
      own: OwnSeat(
        seat: seat,
        role: role,
        teammateNames: teammateNames,
        actedThisNight: acted,
      ),
      userId: 'u$seat',
    );
    transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          OnlineTableFlow(
            onExit: () {},
            onAnalytics: () {},
            onStepCommitted: () {},
          ),
        ),
      ),
    );
    // One frame to build, one to run the post-frame ask, one to render its
    // result. Nothing here is a tap: the point is that the card arrives on its
    // own.
    await tester.pump();
    await tester.pump();
    await tester.pump();
  }

  /// The reveal, without `pumpAndSettle`.
  ///
  /// The table never stops scheduling frames underneath the card — the
  /// connection weather and the seat ring are both continuous — so settling
  /// here never returns. Every wait below is a measured pump instead.
  ///
  /// The swipe is measured against the card widget's own bounds rather than
  /// the drawn card's, because that is what [RoleCard] measures its threshold
  /// against, and online the card widget is the whole screen.
  Future<void> revealWithoutSettling(WidgetTester tester) async {
    await tester.confirmIdentity(settle: false);
    await tester.pump(const Duration(seconds: 1));

    final slot = tester.getRect(find.byKey(RoleCard.slotCard));
    final step = slot.width * 0.09;
    final gesture = await tester.startGesture(
      Offset(slot.left + step, slot.center.dy),
    );
    await tester.pump();
    // Twelve steps rather than the shared helper's six. The threshold is a
    // fraction of the *card widget*, and online that widget is the whole
    // screen while the drawn card is about half of it — so a swipe sized to
    // the drawing falls just short of the rule the card actually applies.
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(Offset(step, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('the private card appears without anybody asking for it', (
    tester,
  ) async {
    await pumpTable(tester);

    final card = find.byKey(const ValueKey('online-role-card-1'));
    expect(card, findsOneWidget);
    expect(find.byKey(RoleCard.holdPad), findsOneWidget);
    // The seat's own name on the card, and no other seat's. `roster` names
    // seats A…E; the name also appears on the seat ring underneath, which is
    // public, so the assertion is scoped to the card itself.
    expect(find.descendant(of: card, matching: find.text('B')), findsOneWidget);
    for (final other in const ['A', 'C', 'D', 'E']) {
      expect(
        find.descendant(of: card, matching: find.text(other)),
        findsNothing,
        reason: 'seat $other is not this device',
      );
    }
  });

  testWidgets('holding and flipping shows this device its own role', (
    tester,
  ) async {
    await pumpTable(tester, seat: 2, role: 'doctor');

    await revealWithoutSettling(tester);

    // The countdown line exists only while the card is face up, so its
    // presence — not the text, which is in the tree behind the card back too —
    // is what proves the card actually turned over.
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text(arStrings.roleDoctor), findsOneWidget);
    // No other role is on the screen. A card that named two roles would be a
    // card that told you something about somebody else.
    for (final other in [
      arStrings.roleMafia,
      arStrings.roleDetective,
      arStrings.roleCitizen,
    ]) {
      expect(find.text(other), findsNothing);
    }
  });

  testWidgets('the transport refuses every seat that is not this device', (
    tester,
  ) async {
    await pumpTable(tester, seat: 3, role: 'detective');

    // The client asks for its own seat and gets an answer; the same call for
    // any other seat is refused at the transport, so a patched screen asking
    // the wrong question still learns nothing.
    expect((await transport.secretsFor(3))?.role, Role.detective);
    for (final other in const [0, 1, 2, 4]) {
      expect(await transport.secretsFor(other), isNull);
    }
  });

  testWidgets('a dismissed card is not handed straight back', (tester) async {
    await pumpTable(tester);

    await revealWithoutSettling(tester);
    await tester.awaitPassUnlocked();
    await tester.tap(find.byKey(RoleCard.dismiss));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    // The room is still in `reveal` — the host has not moved it on — and this
    // device has stopped looking. The ask is once per distribution, so the
    // card does not reappear underneath the player.
    expect(find.byKey(const ValueKey('online-role-card-1')), findsNothing);
  });

  testWidgets('no card is pulled in a phase that is not the deal', (
    tester,
  ) async {
    await pumpTable(tester, phase: 'discuss');

    expect(find.byKey(RoleCard.holdPad), findsNothing);
    expect(find.byKey(const ValueKey('online-role-card-1')), findsNothing);
  });

  testWidgets('the card still arrives when the role lands a beat late', (
    tester,
  ) async {
    // The real failure. A phase change reaches the client as a push; the row
    // carrying its role is only re-read by the resync that push triggers, so
    // the first snapshot of the deal can legitimately have no role on it. One
    // attempt spent there used to be the only attempt there ever was.
    await pumpTable(tester, seat: 1, role: null);
    expect(find.byKey(RoleCard.holdPad), findsNothing);

    backend.setOwn(const OwnSeat(seat: 1, role: 'mafia'));
    await transport.resync();
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const ValueKey('online-role-card-1')), findsOneWidget);
  });

  testWidgets('the night offers this device its own move, unasked', (
    tester,
  ) async {
    await pumpTable(tester, seat: 1, role: 'doctor', phase: 'night');

    // Not «مستني باقي اللاعبين»: this seat has not acted, so the confirm is
    // its own, and the prompt is the one its role is asked.
    expect(find.byKey(OnlineTableFlow.confirmAction), findsOneWidget);
    expect(
      find.text(EngineCopy.nightPrompt(arStrings, Role.doctor)),
      findsOneWidget,
    );
    expect(find.text(arStrings.onlineWaitingForTheRest), findsNothing);
  });

  testWidgets('a seat that has already acted is left waiting', (tester) async {
    await pumpTable(
      tester,
      seat: 1,
      role: 'doctor',
      phase: 'night',
      acted: true,
    );

    expect(find.text(arStrings.onlineWaitingForTheRest), findsOneWidget);
    expect(find.byKey(OnlineTableFlow.confirmAction), findsNothing);
  });
}
