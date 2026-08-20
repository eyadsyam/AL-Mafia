import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// Writes the role card to `tool/preview/` so the artwork can be reviewed with
/// the real emblem and the real type on top of it, instead of judged as a bare
/// image.
///
/// Deliberately **not** named `*_test.dart`, so `flutter test` does not collect
/// it: it asserts nothing and writes files, and neither belongs in the suite. Run
/// it by naming it:
///
///     flutter test test/preview/card_preview.dart
///
/// The type renders as boxes — `flutter_test` ships a stub font. This is for
/// judging artwork, composition and colour; verify type on a device.
void main() {
  const boundaryKey = ValueKey('preview_boundary');

  Future<void> shoot(WidgetTester tester, String name,
      {required Role role, required bool flipped}) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: localizedApp(
          RoleCard(
            playerName: 'ياسمين',
            role: role,
            teammateNames: role == Role.mafia ? const ['كريم', 'نور'] : const [],
            onDismissed: () {},
          ),
        ),
      ),
    );

    // Wait on the actual decode. Pumping a fixed number of times is not enough:
    // it silently produced a *transparent* card face here, so the screenshot
    // showed the card's own drop shadow through it and the artwork looked like a
    // flat black rectangle. The front only happened to look right because the
    // flip gave the decode extra frames to finish in.
    await loadArtwork(tester);

    if (flipped) {
      final gesture =
          await tester.startGesture(tester.getCenter(find.byKey(RoleCard.holdPad)));
      await tester.pump();
      await tester.pump(MafiaTiming.defaults.holdToReveal);
      await gesture.up();
      await tester.pumpAndSettle();
      await loadArtwork(tester);
    }

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
    await tester.runAsync(() async {
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      final file = File('tool/preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
    });
  }

  testWidgets('card back', (tester) async {
    await shoot(tester, 'role_card_back', role: Role.citizen, flipped: false);
  });

  testWidgets('card front', (tester) async {
    await shoot(tester, 'role_card_front', role: Role.detective, flipped: true);
  });
}
