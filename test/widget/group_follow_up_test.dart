import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/memory_player_group_repository.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/data/player_group_provider.dart';
import 'package:mafia_master/ui/screens/setup/group_follow_up.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';

import '../support/localized.dart';

/// The two questions that can only be answered once the match is over.
///
/// "Should Karim join the group?" and "should tonight's seating order stick?"
/// are both unanswerable at setup time — you cannot know whether Karim is a
/// regular until the evening has happened. So they are asked at the end, and
/// both default to *no change*: a host who dismisses them, or never sees them,
/// keeps the group exactly as it was.
void main() {
  const friday = ['Ahmed', 'Fatima', 'Salem', 'Laila', 'Omar', 'Nada'];

  late ProviderContainer container;
  late MemoryPlayerGroupStore store;
  late PlayerGroup saved;

  /// Puts a group in the store and a finished match's roster in the draft.
  Future<void> pumpFollowUp(
    WidgetTester tester, {
    required List<String> played,
  }) async {
    store = MemoryPlayerGroupStore();
    final repository = MemoryPlayerGroupRepository(store);
    final id = await repository.saveGroup(
      PlayerGroup.create(
        name: 'شلة الجمعة',
        memberNames: friday,
        now: DateTime.utc(2026, 8, 1),
      ),
    );
    saved = (await repository.listGroups()).single;

    container = ProviderContainer(
      overrides: [
        playerGroupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    container.read(setupDraftProvider.notifier)
      ..setGroup(saved.copyWith(id: id))
      ..setNames(played);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The child stands in for the result screen. Nothing about this
        // behaviour depends on what is underneath it, which is the point of it
        // being a wrapper.
        child: localizedApp(
          const GroupFollowUp(child: Scaffold(body: SizedBox.shrink())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<PlayerGroup> reload() async =>
      (await MemoryPlayerGroupRepository(store).listGroups()).single;

  group('guests', () {
    testWidgets('a guest is offered to the group and joins when accepted',
        (tester) async {
      await pumpFollowUp(tester, played: [...friday, 'Karim']);

      expect(find.text('تضيفهم للمجموعة؟'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_follow_up_accept')));
      await tester.pumpAndSettle();

      final group = await reload();
      expect(group.memberNames, orderedEquals([...friday, 'Karim']));
    });

    testWidgets('declining leaves the group exactly as it was', (tester) async {
      await pumpFollowUp(tester, played: [...friday, 'Karim']);

      await tester.tap(find.byKey(const ValueKey('group_follow_up_dismiss')));
      await tester.pumpAndSettle();

      final group = await reload();
      expect(group.memberNames, orderedEquals(friday));
    });

    testWidgets('nothing is asked when the roster is unchanged',
        (tester) async {
      await pumpFollowUp(tester, played: friday);

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a night that changed nothing must not interrupt the result '
              'screen to say so');
    });

    testWidgets('an absence alone asks nothing', (tester) async {
      // Someone was away. That is not a change to the group, and the host must
      // not be prompted about it — being prompted invites "yes", and "yes"
      // would be the deletion this feature exists to avoid.
      await pumpFollowUp(
        tester,
        played: const ['Ahmed', 'Salem', 'Laila', 'Omar', 'Nada'],
      );

      expect(find.byType(AlertDialog), findsNothing);
      expect((await reload()).memberNames, orderedEquals(friday));
    });
  });

  group('seating order', () {
    const reseated = ['Fatima', 'Ahmed', 'Salem', 'Laila', 'Omar', 'Nada'];

    testWidgets('a changed order is offered and saved when accepted',
        (tester) async {
      await pumpFollowUp(tester, played: reseated);

      expect(find.text('تحفظ ترتيب القعدة الجديد؟'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_follow_up_accept')));
      await tester.pumpAndSettle();

      expect((await reload()).memberNames, orderedEquals(reseated));
    });

    testWidgets('declining keeps the old order', (tester) async {
      await pumpFollowUp(tester, played: reseated);

      await tester.tap(find.byKey(const ValueKey('group_follow_up_dismiss')));
      await tester.pumpAndSettle();

      expect((await reload()).memberNames, orderedEquals(friday));
    });

    testWidgets('an absent member keeps their slot when the order is saved',
        (tester) async {
      // Fatima (seat 2) is away; Salem and Ahmed swapped. Saving the new order
      // must not drop Fatima — she was not there to be reordered, so she stays
      // where she was.
      await pumpFollowUp(
        tester,
        played: const ['Salem', 'Ahmed', 'Laila', 'Omar', 'Nada'],
      );

      expect(find.text('تحفظ ترتيب القعدة الجديد؟'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group_follow_up_accept')));
      await tester.pumpAndSettle();

      final group = await reload();
      expect(group.memberNames, contains('Fatima'),
          reason: 'saving a seating order may never cost an absent member '
              'their place in the group');
      expect(group.memberNames, hasLength(friday.length));
      expect(group.memberNames.indexOf('Salem'),
          lessThan(group.memberNames.indexOf('Ahmed')));
    });
  });

  testWidgets('the question is asked once and not again on rebuild',
      (tester) async {
    await pumpFollowUp(tester, played: [...friday, 'Karim']);
    await tester.tap(find.byKey(const ValueKey('group_follow_up_dismiss')));
    await tester.pumpAndSettle();

    // The result screen is rebuilt — the host went to analytics and came back,
    // or the engine emitted a new frame.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(container.read(setupDraftProvider).group, isNull,
        reason: 'the draft holds the group only until the question has been '
            'asked; leaving it attached is how a dismissed prompt comes back');
  });

  testWidgets('a group deleted during the match is not resurrected by the '
      'prompt', (tester) async {
    // Saving is an upsert, so accepting a follow-up about a group that was
    // deleted mid-match would put it straight back — the host deletes a roster,
    // plays the night, taps "ضيف", and finds it in the list again.
    await pumpFollowUp(tester, played: [...friday, 'Karim']);
    await container.read(playerGroupsProvider.notifier).delete(saved.id);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('group_follow_up_accept')));
    await tester.pumpAndSettle();

    expect(await MemoryPlayerGroupRepository(store).listGroups(), isEmpty,
        reason: 'the deleted group came back');
  });

  group('SetupDraft roster arithmetic', () {
    SetupDraft draftWith(List<String> names) => SetupDraft(
          names: names,
          group: PlayerGroup.create(
            name: 'g',
            memberNames: friday,
            now: DateTime.utc(2026, 8, 1),
          ),
        );

    test('guests are the names the group does not know', () {
      expect(draftWith([...friday, 'Karim']).guests, equals(['Karim']));
      expect(draftWith(friday).guests, isEmpty);
    });

    test('an absence is not a reorder', () {
      // The trap this guards: filtering the saved roster to who actually played
      // is what stops "everyone after Fatima shifted up one" reading as the
      // table having rearranged itself.
      expect(
        draftWith(const ['Ahmed', 'Salem', 'Laila', 'Omar', 'Nada'])
            .seatingOrderChanged,
        isFalse,
      );
    });

    test('a genuine swap is a reorder', () {
      expect(
        draftWith(const ['Fatima', 'Ahmed', 'Salem', 'Laila', 'Omar', 'Nada'])
            .seatingOrderChanged,
        isTrue,
      );
    });

    test('a guest on the end is not a reorder on its own', () {
      expect(draftWith([...friday, 'Karim']).seatingOrderChanged, isFalse);
    });

    test('with no group there is nothing to compare against', () {
      const draft = SetupDraft(names: friday);
      expect(draft.guests, isEmpty);
      expect(draft.playedMembers, isEmpty);
      expect(draft.seatingOrderChanged, isFalse);
    });
  });
}
