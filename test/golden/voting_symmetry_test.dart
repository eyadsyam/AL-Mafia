import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/day/voting_screen.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';

import '../support/localized.dart';

/// T038 / L-03 — the day ballot is structurally identical for every voter.
///
/// ## What "identical" has to mean here
///
/// The night screen can be compared byte-for-byte because every role sees the
/// same target list. A ballot cannot: each voter is excluded from their own
/// ballot, so the *names* legitimately differ. What must not differ is anything
/// that correlates with the voter's **role** — the tree, the control set, the
/// geometry, and the number of choices offered. This suite therefore renders
/// the same seat's ballot in matches where that seat holds each of the four
/// roles, and requires the frames to be byte-identical.
///
/// That is the leak that matters. A mafioso whose ballot looked even slightly
/// different from a citizen's would be identifiable by anyone who glanced over.
void main() {
  const surface = Size(390, 844);
  const names = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
  const boundaryKey = ValueKey('voting_boundary');

  /// Builds a match in which [seat] holds [role], then opens the day ballot and
  /// hands the phone to that seat.
  ///
  /// Roles are assigned directly rather than dealt, so the same seat can be
  /// given each role in turn while everything else stays fixed.
  // Re-pumping the same widget type at the same position would otherwise reuse
  // the previous `_VotingScreenState`, which has already passed its identity
  // gate — the second ballot in a test would render without a hold pad.
  var mountCounter = 0;

  Future<ProviderContainer> openBallot(
    WidgetTester tester, {
    required int seat,
    required Role role,
    bool allowAbstain = true,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(matchControllerProvider.notifier);
    controller.startMatch(
      names: names,
      roleCounts: const {
        Role.mafia: 2,
        Role.doctor: 1,
        Role.detective: 1,
        Role.citizen: 3,
      },
      settings: MatchSettings(abstainAllowed: allowAbstain),
      seed: 3,
    );

    // Force the seat under test onto the role under test, and park the match
    // directly in the voting phase.
    final engine = controller.engine;
    final players = [
      for (final p in engine.match.players)
        p.seat == seat ? p.copyWith(role: role) : p,
    ];
    controller.adoptMatch(engine.match.copyWith(
      players: players,
      phase: GamePhase.voting,
      currentActorSeat: seat,
    ));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: boundaryKey,
          child: localizedApp(VotingScreen(
              key: ValueKey('ballot-${mountCounter++}'),
              onVotingComplete: () {},
              allowAbstain: allowAbstain,
            )
          ),
        ),
      ),
    );

    // Pass the identity gate so the ballot itself is on screen.
    final pad = find.byType(HoldPad).first;
    final gesture = await tester.startGesture(tester.getCenter(pad));
    await tester.pump();
    await tester.pump(MafiaTiming.defaults.holdToReveal);
    await gesture.up();
    await tester.pumpAndSettle();

    return container;
  }

  Future<Uint8List> capture(WidgetTester tester) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    final bytes = await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        return data!.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    });
    return bytes!;
  }

  List<String> skeleton(WidgetTester tester) {
    final out = <String>[];
    void visit(Element element, int depth) {
      out.add('${'  ' * depth}${element.widget.runtimeType}');
      element.visitChildren((child) => visit(child, depth + 1));
    }

    visit(tester.element(find.byType(VotingScreen)), 0);
    return out;
  }

  group('L-03 ballot symmetry across the voter\'s role', () {
    final frames = <Role, Uint8List>{};
    final trees = <Role, List<String>>{};

    for (final role in Role.values) {
      testWidgets('renders seat 0\'s ballot as a ${role.name}', (tester) async {
        await openBallot(tester, seat: 0, role: role);
        frames[role] = await capture(tester);
        trees[role] = skeleton(tester);
      });
    }

    testWidgets('every role produces a byte-identical ballot', (tester) async {
      // Re-render inside this test so the group does not depend on the order
      // the framework happens to run the cases above in.
      final captured = <Role, Uint8List>{};
      final structures = <Role, List<String>>{};
      for (final role in Role.values) {
        await openBallot(tester, seat: 0, role: role);
        captured[role] = await capture(tester);
        structures[role] = skeleton(tester);
      }

      final reference = captured[Role.mafia]!;
      for (final role in Role.values) {
        expect(captured[role], equals(reference),
            reason: 'the ballot handed to a ${role.name} differs from a '
                'mafioso\'s — the voter\'s role is visible on screen');
        expect(structures[role], equals(structures[Role.mafia]!),
            reason: 'widget tree differs for ${role.name}');
      }
    });

    testWidgets('the ballot offers the same choices regardless of role',
        (tester) async {
      final counts = <Role, int>{};
      for (final role in Role.values) {
        await openBallot(tester, seat: 0, role: role);
        counts[role] = tester.widgetList(find.byType(PlayerTile)).length;
      }
      expect(counts.values.toSet(), hasLength(1),
          reason: 'candidate count varies with the voter\'s role: $counts');
      // Six others, all alive: the voter is excluded, nobody else is.
      expect(counts[Role.mafia], equals(names.length - 1));
    });

    testWidgets('every role is offered the same on-screen copy', (tester) async {
      // The pixel comparison above cannot see this. `flutter_test` renders
      // every glyph of its default font as the same box, so two different
      // strings of equal length produce identical bytes. Comparing the actual
      // strings closes that gap — a role-specific label would slip past a
      // pixel-only check.
      List<String> textOf(WidgetTester t) => [
            for (final w in t.widgetList<Text>(find.byType(Text)))
              if (w.data != null) w.data!,
          ]..sort();

      final copy = <Role, List<String>>{};
      for (final role in Role.values) {
        await openBallot(tester, seat: 0, role: role);
        copy[role] = textOf(tester);
      }
      for (final role in Role.values) {
        expect(copy[role], equals(copy[Role.mafia]!),
            reason: 'the ballot says something different to a ${role.name}');
      }
    });

    testWidgets('the comparison can detect a real difference', (tester) async {
      // Guards the suite against a capture that always returns the same bytes.
      // The difference has to be structural rather than textual, for the
      // glyph-shape reason described above — so toggle a control on and off.
      await openBallot(tester, seat: 0, role: Role.citizen, allowAbstain: true);
      final withAbstain = await capture(tester);
      await openBallot(tester, seat: 0, role: Role.citizen, allowAbstain: false);
      final withoutAbstain = await capture(tester);
      expect(withAbstain, isNot(equals(withoutAbstain)),
          reason: 'pixel capture is not sensitive to content changes');
    });
  });
}
