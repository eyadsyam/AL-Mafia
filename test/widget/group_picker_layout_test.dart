import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_player_group_repository.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_provider.dart';
import 'package:mafia_master/ui/screens/setup/group_picker_screen.dart';

import '../support/localized.dart';

/// The picker under names longer than anyone sensible would type.
///
/// Text scaling is pinned at 1.0 app-wide (see `app.dart` for why), so a
/// one-line bound with an ellipsis is a bound that actually holds rather than a
/// hope — which is exactly why it has to be the thing that gives. A row that
/// overflows instead prints a yellow-and-black stripe across the one screen a
/// host looks at while eight people wait.
void main() {
  /// Long enough to overflow any phone, in both scripts the app ships, plus the
  /// unspaced case — a single unbreakable token cannot wrap, so it is the one
  /// that catches a missing `overflow:`.
  const punishing = <String>[
    'شلة الجمعة بتاعة نادي الشمس والزمالك والمعادي وكل حتة تانية',
    'The Friday Night Mafia Regulars Who Always Argue About The Rules',
    'مجموعةطويلةجدابدونمسافاتخالصعشانتكسرالتنسيقلوفيهمشكلة',
  ];

  Future<void> pumpPicker(WidgetTester tester, List<String> names) async {
    final store = MemoryPlayerGroupStore();
    final repository = MemoryPlayerGroupRepository(store);
    for (final name in names) {
      await repository.saveGroup(
        PlayerGroup.create(
          name: name,
          memberNames: const ['A', 'B', 'C', 'D', 'E', 'F'],
          now: DateTime.utc(2026, 8, 1),
        ),
      );
    }

    final container = ProviderContainer(
      overrides: [playerGroupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          GroupPickerScreen(
            onSelect: (_) {},
            onNewGroup: () {},
            onBack: () {},
            onEmpty: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('long group names truncate rather than overflow', (tester) async {
    // A narrow, short phone — the worst case that ships.
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpPicker(tester, punishing);

    expect(tester.takeException(), isNull,
        reason: 'a RenderFlex overflow here paints a striped bar across the '
            'rematch screen');

    for (final name in punishing) {
      final text = tester.widget<Text>(find.text(name));
      expect(text.maxLines, equals(1));
      expect(text.overflow, equals(TextOverflow.ellipsis),
          reason: 'the name is what must yield — the play count beside it is '
              'short and fixed');
    }
  });

  testWidgets('the meta line survives four-digit play counts', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = MemoryPlayerGroupStore();
    final repository = MemoryPlayerGroupRepository(store);
    await repository.saveGroup(
      PlayerGroup(
        name: punishing.first,
        memberNames: List.generate(20, (i) => 'Player $i'),
        createdAt: DateTime.utc(2026, 1, 1),
        lastPlayedAt: DateTime.utc(2026, 8, 1),
        playCount: 9999,
      ),
    );

    final container = ProviderContainer(
      overrides: [playerGroupRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          GroupPickerScreen(
            onSelect: (_) {},
            onNewGroup: () {},
            onBack: () {},
            onEmpty: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty store never renders a list', (tester) async {
    // The picker is not supposed to be reachable with no groups; if it ever is,
    // it must bounce rather than show an empty list asking the host to choose
    // from nothing.
    var bounced = false;
    final container = ProviderContainer(
      overrides: [
        playerGroupRepositoryProvider
            .overrideWithValue(MemoryPlayerGroupRepository(
          MemoryPlayerGroupStore(),
        )),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          GroupPickerScreen(
            onSelect: (_) {},
            onNewGroup: () {},
            onBack: () {},
            onEmpty: () => bounced = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(GroupPickerScreen.list), findsNothing);
    expect(bounced, isTrue);
  });
}
