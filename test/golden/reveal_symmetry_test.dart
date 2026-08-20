import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// T038 / L-04 — the role card's face-down state, its bounds and its timing are
/// identical across roles.
///
/// ## What is and is not allowed to differ
///
/// The **front** face is supposed to differ: that is the whole point of the
/// card, and only its owner can see it. Everything an onlooker can observe must
/// not:
///
/// * the identity gate, before anything has been drawn — the screen a player
///   holds for twenty seconds while the table watches them hold it;
/// * the back face, before the flip — a face-down Mafia card and a face-down
///   Citizen card have to be the same picture;
/// * the card's bounds and the bottom control's bounds, in every phase — a card
///   that grew to fit a longer description would advertise the role from across
///   the table;
/// * when the card conceals itself, and when the pass control unlocks — a
///   Citizen who could hand the phone on while a Mafioso sat waiting would be
///   trivially readable from turn length alone (L-08).
void main() {
  const surface = Size(390, 844);
  const boundaryKey = ValueKey('reveal_boundary');

  var mountCounter = 0;

  Future<void> pumpCard(
    WidgetTester tester, {
    required Role role,
    List<String> teammates = const [],
    String playerName = 'Player',
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        // A fresh key per mount, so re-pumping inside one test really does
        // produce a new card at step 1 rather than reusing the last state.
        child: localizedApp(
          RoleCard(
            key: ValueKey('card-${mountCounter++}'),
            playerName: playerName,
            role: role,
            teammateNames: teammates,
            onDismissed: () {},
          ),
        ),
      ),
    );

    await loadArtwork(tester);
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

  /// The pixels of [rect] only, out of a full-surface capture.
  ///
  /// Needed because some assertions are about the *card* rather than the
  /// screen. The card conceals itself and the pass control appears in the same
  /// moment, so a whole-frame comparison across that boundary is comparing two
  /// things at once and fails for the uninteresting one.
  ///
  /// Logical and physical pixels coincide here: the test binding runs at device
  /// pixel ratio 1 and [surface] is set explicitly.
  List<int> region(Uint8List frame, Rect rect) {
    final out = <int>[];
    final left = rect.left.round();
    final right = rect.right.round();
    for (var y = rect.top.round(); y < rect.bottom.round(); y++) {
      final row = y * surface.width.round() * 4;
      out.addAll(frame.sublist(row + left * 4, row + right * 4));
    }
    return out;
  }

  /// Mounts, captures and discards one card before any frame is measured.
  ///
  /// [loadArtwork] handles the *decode*; this handles the first **rasterise**.
  /// They are separate steps and both matter: the first `toImage()` in a test is
  /// what pushes the decoded image through the raster cache, so a suite that only
  /// pre-decoded still had its first measured frame come out a few levels off and
  /// reported whichever role was pumped first as a leak.
  ///
  /// That diagnosis was confirmed by reordering the loop — put Citizen first and
  /// Citizen becomes the outlier while the other three stay byte-identical to
  /// each other, which no real role difference could do.
  Future<void> warmUpArtwork(WidgetTester tester) async {
    await pumpCard(tester, role: Role.citizen);
    await tester.confirmIdentity();
    await capture(tester);
  }

  group('L-04 the identity gate', () {
    testWidgets('is byte-identical for every role', (tester) async {
      // This is the screen the table looks at for the whole hold. It is drawn
      // before the card exists, so nothing on it *could* legitimately depend on
      // the role — which is exactly why it is worth proving that nothing does.
      await warmUpArtwork(tester);

      final frames = <Role, Uint8List>{};
      for (final role in Role.values) {
        await pumpCard(tester, role: role);
        frames[role] = await capture(tester);
      }

      for (final role in Role.values) {
        expect(frames[role], equals(frames[Role.mafia]!),
            reason: 'the identity gate differs for ${role.name}');
      }
    });
  });

  group('L-04 face-down card', () {
    testWidgets('is byte-identical for every role', (tester) async {
      await warmUpArtwork(tester);
      final frames = <Role, Uint8List>{};
      for (final role in Role.values) {
        await pumpCard(tester, role: role);
        await tester.confirmIdentity();
        frames[role] = await capture(tester);
      }

      for (final role in Role.values) {
        expect(frames[role], equals(frames[Role.mafia]!),
            reason: 'a face-down ${role.name} card is distinguishable from a '
                'face-down mafia card');
      }
    });

    testWidgets('a mafioso\'s back face does not hint at teammates',
        (tester) async {
      // The Mafia card is the only one carrying extra data. If its presence
      // changed the back face at all, the teammate list would be inferable
      // before the card was even turned over.
      await warmUpArtwork(tester);
      await pumpCard(tester, role: Role.mafia, teammates: const []);
      await tester.confirmIdentity();
      final alone = await capture(tester);

      await pumpCard(tester, role: Role.mafia, teammates: const ['X', 'Y']);
      await tester.confirmIdentity();
      final withTeam = await capture(tester);

      expect(withTeam, equals(alone));
    });

    testWidgets('the card conceals itself back to that same picture',
        (tester) async {
      // The auto-conceal is only worth having if what it returns to is the
      // shared back. A concealed card that kept any trace of the face would
      // hand the table the role a few seconds later instead of never.
      //
      // Scoped to the card, because the rest of the screen is *supposed* to
      // change across the conceal: that is the moment the pass control appears.
      await warmUpArtwork(tester);
      await pumpCard(tester, role: Role.mafia, teammates: const ['X', 'Y']);
      await tester.confirmIdentity();

      final card = tester.getRect(find.byKey(RoleCard.slotCard));
      final beforeFlip = region(await capture(tester), card);

      await tester.swipeToFlip();
      expect(region(await capture(tester), card), isNot(equals(beforeFlip)),
          reason: 'the swipe did not turn the card over');

      await tester.awaitConceal();
      expect(region(await capture(tester), card), equals(beforeFlip),
          reason: 'the concealed card is not the same picture as the '
              'face-down one');
    });

    testWidgets('the concealed screen is identical for every role',
        (tester) async {
      // The whole screen this time, pass control included. This is the state
      // the phone is in while it is being handed on, so it is the one the next
      // player and everyone else at the table actually look at.
      await warmUpArtwork(tester);

      final frames = <Role, Uint8List>{};
      for (final role in Role.values) {
        await pumpCard(
          tester,
          role: role,
          teammates: role == Role.mafia ? const ['X', 'Y'] : const [],
        );
        await tester.confirmIdentity();
        await tester.swipeToFlip();
        await tester.awaitConceal();
        frames[role] = await capture(tester);
      }

      for (final role in Role.values) {
        expect(frames[role], equals(frames[Role.mafia]!),
            reason: 'the concealed ${role.name} screen — the one handed across '
                'the table — is distinguishable from the mafia one');
      }
    });
  });

  group('L-04 geometry', () {
    testWidgets('card and control bounds are identical across roles, in every '
        'phase', (tester) async {
      final backCard = <Role, Rect>{};
      final backBottom = <Role, Rect>{};
      final upCard = <Role, Rect>{};
      final upBottom = <Role, Rect>{};
      final passCard = <Role, Rect>{};
      final passBottom = <Role, Rect>{};

      for (final role in Role.values) {
        await pumpCard(
          tester,
          role: role,
          // Give Mafia the longest possible content, so if anything were going
          // to stretch the layout, this is the case that would do it.
          teammates:
              role == Role.mafia ? const ['Aaaa', 'Bbbb', 'Cccc'] : const [],
        );

        await tester.confirmIdentity();
        backCard[role] = tester.getRect(find.byKey(RoleCard.slotCard));
        backBottom[role] = tester.getRect(find.byKey(RoleCard.slotBottom));

        await tester.swipeToFlip();
        upCard[role] = tester.getRect(find.byKey(RoleCard.slotCard));
        upBottom[role] = tester.getRect(find.byKey(RoleCard.slotBottom));

        await tester.awaitConceal();
        await tester.awaitPassUnlocked();
        passCard[role] = tester.getRect(find.byKey(RoleCard.slotCard));
        passBottom[role] = tester.getRect(find.byKey(RoleCard.slotBottom));
      }

      for (final role in Role.values) {
        expect(backCard[role], equals(backCard[Role.mafia]!),
            reason: 'face-down card bounds differ for ${role.name}');
        expect(backBottom[role], equals(backBottom[Role.mafia]!),
            reason: 'bottom control bounds differ for ${role.name} before the '
                'flip');
        expect(upCard[role], equals(upCard[Role.mafia]!),
            reason: 'face-up card bounds differ for ${role.name}');
        expect(upBottom[role], equals(upBottom[Role.mafia]!),
            reason: 'bottom control bounds differ for ${role.name} while '
                'revealed');
        expect(passCard[role], equals(passCard[Role.mafia]!),
            reason: 'concealed card bounds differ for ${role.name}');
        expect(passBottom[role], equals(passBottom[Role.mafia]!),
            reason: 'pass control bounds differ for ${role.name}');
      }

      // Nor may any phase resize anything. A card that changed size on reveal,
      // or a strip that grew when the pass button replaced the swipe hint,
      // would announce the state of a private turn to the whole table.
      expect(upCard[Role.mafia], equals(backCard[Role.mafia]));
      expect(passCard[Role.mafia], equals(backCard[Role.mafia]));
      expect(upBottom[Role.mafia], equals(backBottom[Role.mafia]));
      expect(passBottom[Role.mafia], equals(backBottom[Role.mafia]));
    });
  });

  group('L-04/L-08 timing', () {
    testWidgets('the card conceals itself at the same offset for every role',
        (tester) async {
      final window = MafiaTiming.defaults.autoRevealDuration;
      const epsilon = Duration(milliseconds: 50);

      // The progress line is the visible countdown, so its presence is the
      // observable form of "the card is still face up". Found by descent rather
      // than by text, so the assertion does not depend on a copy change.
      final countdown = find.descendant(
        of: find.byKey(RoleCard.progressLine),
        matching: find.byType(LinearProgressIndicator),
      );

      for (final role in Role.values) {
        await pumpCard(tester, role: role);
        await tester.confirmIdentity();
        await tester.swipeToFlip(settle: false);

        await tester.pump(window - epsilon);
        expect(countdown, findsOneWidget,
            reason: '${role.name} concealed itself early');

        await tester.pump(epsilon * 2);
        await tester.pumpAndSettle();
        expect(countdown, findsNothing,
            reason: '${role.name} did not conceal itself on schedule');
      }
    });

    testWidgets('the pass control unlocks at the same offset for every role',
        (tester) async {
      // Measured, not asserted against a constant. Comparing each role to a
      // number would pass four times over even if every role were late by the
      // same amount; comparing the roles to *each other* is the invariant that
      // actually matters, and it survives a change to the token.
      //
      // No `pumpAndSettle` anywhere in this loop: it advances the fake clock by
      // however long the residual animations happen to take, which is precisely
      // the quantity under measurement.
      final unlockedAfter = <Role, Duration>{};

      for (final role in Role.values) {
        await pumpCard(tester, role: role);
        expect(tester.passButtonVisible, isFalse,
            reason: 'pass must be locked at the identity gate (${role.name})');

        await tester.confirmIdentity(settle: false);
        await tester.swipeToFlip(settle: false);
        unlockedAfter[role] = await tester.awaitPassUnlocked();
      }

      for (final role in Role.values) {
        expect(unlockedAfter[role], equals(unlockedAfter[Role.mafia]),
            reason: 'the pass control unlocked ${unlockedAfter[role]} into a '
                '${role.name} turn and ${unlockedAfter[Role.mafia]} into a '
                'mafia one. Turn length is readable from across the table '
                '(L-08).');
      }

      // And it is a real wait, not an instant one — otherwise the equality
      // above would hold trivially at zero.
      expect(unlockedAfter[Role.mafia]!.inMilliseconds, greaterThan(200));
    });

    testWidgets('re-revealing does not extend or shorten the turn',
        (tester) async {
      // The player may swipe again as often as they like. If each re-reveal
      // pushed the pass control back, a player who looked twice would take
      // longer than one who looked once — and looking twice is not evenly
      // distributed across roles.
      await pumpCard(tester, role: Role.detective);
      await tester.confirmIdentity();

      await tester.swipeToFlip();
      await tester.awaitConceal();
      await tester.swipeToFlip();
      await tester.awaitConceal();

      // Two full reveal windows have already run — more than the turn floor —
      // so the control must be there without any further waiting at all.
      expect(tester.passButtonVisible, isTrue,
          reason: 'two reveals pushed the pass control past the turn floor');
    });
  });

  group('the suite is not vacuous', () {
    testWidgets('the front faces really do differ between roles',
        (tester) async {
      // If the flip were a no-op, every assertion above would pass while the
      // card told the player nothing. The default test font renders all glyphs
      // as identical boxes, so compare the strings rather than the pixels.
      List<String> textOf(WidgetTester t) => [
            for (final w in t.widgetList<Text>(find.byType(Text)))
              if (w.data != null && w.data!.isNotEmpty) w.data!,
          ]..sort();

      final copy = <Role, List<String>>{};
      for (final role in Role.values) {
        await pumpCard(tester, role: role);
        await tester.revealCard();
        copy[role] = textOf(tester);
      }

      final seen = <List<String>>[];
      for (final role in Role.values) {
        for (final other in seen) {
          expect(copy[role], isNot(equals(other)),
              reason: 'two roles show the same card front');
        }
        seen.add(copy[role]!);
      }
    });

    testWidgets('a swipe that falls short springs back', (tester) async {
      // The threshold has to be real. If any touch flipped the card, a player
      // who brushed the screen while handing the phone over would reveal
      // themselves to whoever was taking it.
      await pumpCard(tester, role: Role.mafia);
      await tester.confirmIdentity();
      final faceDown = await capture(tester);

      final box = tester.getRect(find.byKey(RoleCard.slotCard));
      final gesture =
          await tester.startGesture(Offset(box.left + 20, box.center.dy));
      // Well under the 30% threshold, and slowly enough not to read as a flick.
      for (var i = 0; i < 3; i++) {
        await gesture.moveBy(Offset(box.width * 0.03, 0));
        await tester.pump(const Duration(milliseconds: 80));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(await capture(tester), equals(faceDown),
          reason: 'a short swipe turned the card over');
    });
  });
}
