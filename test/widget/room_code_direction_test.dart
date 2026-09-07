/// The room code is Latin, and the app is not.
///
/// # The bug
///
/// The lobby draws the code one character at a time so the letters can stagger
/// in (doc 12 §3.1) — a `Row` of six `Text` widgets rather than one `Text` of
/// six characters. A `Row` lays its children out along the ambient
/// `Directionality`, and this app's is RTL.
///
/// So the code went into the tree in order and came out of it mirrored. The
/// screen said `XQ2K7A` while «نسخ» put `A7K2QX` on the clipboard, and «مشاركة»
/// sent the right one — which is the worst shape a bug like this can take,
/// because the host reads the wrong code aloud to the room while the code they
/// *sent* works, and nobody can tell which half is lying.
///
/// # What is asserted
///
/// Not "the widget sets a flag". The characters' **screen positions**, left to
/// right, in an RTL app — which is the thing a player is actually looking at,
/// and the only form of this claim that a future refactor cannot quietly
/// satisfy while breaking.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/lobby_screen.dart';

import '../support/localized.dart';

void main() {
  /// The code as the eye reads it: characters sorted by where they landed.
  List<String> asDrawn(WidgetTester tester) {
    final glyphs = <(double, String)>[];
    for (final element in find
        .descendant(of: find.byKey(LobbyScreen.codeText), matching: find.byType(Text))
        .evaluate()) {
      final text = (element.widget as Text).data;
      if (text == null || text.isEmpty) continue;
      glyphs.add((tester.getTopLeft(find.byWidget(element.widget)).dx, text));
    }
    glyphs.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final g in glyphs) g.$2];
  }

  testWidgets('the code reads left to right in an RTL app', (tester) async {
    await tester.pumpWidget(localizedApp(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: _CodeProbe(code: 'A7K2QX'),
        ),
      ),
    ));
    // Every character is in the tree from the first frame; only opacity moves,
    // so nothing has to be pumped for the positions to be final.
    await tester.pump();

    expect(asDrawn(tester).join(), equals('A7K2QX'));
  });

  testWidgets('and the same way round in an LTR one', (tester) async {
    await tester.pumpWidget(localizedApp(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: _CodeProbe(code: 'A7K2QX')),
      ),
    ));
    await tester.pump();

    // The point of pinning the direction is that the answer stops depending on
    // the ambient one. Both cases, or it is not pinned.
    expect(asDrawn(tester).join(), equals('A7K2QX'));
  });
}

/// The lobby's staggered code, reachable without a room, a session or a server.
///
/// `_StaggeredCode` is private to `lobby_screen.dart`, which is right — it is
/// not a widget anything else should be building. It is reached here through
/// the same key the lobby hangs on it, so this test exercises the shipped
/// widget rather than a copy of it that could drift.
class _CodeProbe extends StatelessWidget {
  final String code;
  const _CodeProbe({required this.code});

  @override
  Widget build(BuildContext context) => LobbyScreen.codeProbe(context, code);
}
