import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_group.dart';
import 'package:mafia_master/engine/bots/bot_brain.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:mafia_master/ui/economy/pass_table_dress.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/setup/add_players_screen.dart';
import 'package:mafia_master/ui/screens/setup/bot_match_sheet.dart';
import 'package:mafia_master/ui/screens/setup/optional_roles.dart';
import 'package:mafia_master/ui/screens/setup/player_name.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';
import 'package:mafia_master/ui/screens/setup/roles_screen.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import 'package:mafia_master/ui/screens/setup/setup_draft.dart';
import 'package:mafia_master/ui/widgets/deck/deck_public.dart' show DeckChip;

import '../support/artwork.dart';
import '../support/localized.dart';

/// Fixes in the one-phone setup flow: roster, names, roles and presets.
class _Owns extends WalletController {
  final Set<String> codes;
  _Owns(this.codes);

  @override
  Future<WalletState?> build() async => WalletState(
    balance: 0,
    catalog: const [],
    owned: codes,
    equipped: const {},
    history: const [],
  );
}

PlayerGroup _group(List<String> names, {int id = 1}) => PlayerGroup(
  id: id,
  name: 'شلة',
  memberNames: names,
  createdAt: DateTime(2026),
  lastPlayedAt: DateTime(2026),
);

void main() {
  void phone(WidgetTester tester, [Size size = const Size(430, 932)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('player names', () {
    test('invisible characters are stripped before any check', () {
      expect(cleanPlayerName('\u200b\u200f \u202e'), isEmpty);
      expect(cleanPlayerName('  A\u200bli   Z  '), 'Ali Z');
      expect(sameNameFold('Ali', ' ali\u200b'), isTrue);
    });
  });

  group('SetupDraft', () {
    test('the roster outlives the roles step; a different group drops it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(setupDraftProvider.notifier);
      final a = _group(['a', 'b', 'c', 'd', 'e'], id: 1);
      n.setGroup(a);
      n.setRoster(['a', 'b', 'c', 'd', 'e', 'guest'], {'b'});
      expect(c.read(setupDraftProvider).roster, hasLength(6));
      expect(c.read(setupDraftProvider).absent, {'b'});
      n.setGroup(a);
      expect(c.read(setupDraftProvider).roster, hasLength(6));
      n.setGroup(_group(['x', 'y', 'z', 'u', 'v'], id: 2));
      expect(c.read(setupDraftProvider).roster, isEmpty);
      expect(c.read(setupDraftProvider).absent, isEmpty);
    });

    test('a new match clears the roster', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(setupDraftProvider.notifier);
      n.setRoster(['a'], {'a'});
      n.resetForNewMatch();
      expect(c.read(setupDraftProvider).roster, isEmpty);
    });
  });

  group('AddPlayersScreen', () {
    Future<void> pump(
      WidgetTester tester, {
      List<String> names = const [],
      Set<String> absent = const {},
      PlayerGroup? group,
      List<PlayerGroup> saved = const [],
      void Function(List<String>, Set<String>)? onRoster,
      ValueChanged<Map<String, PlayerGender>>? onGenders,
      Map<String, PlayerGender> genders = const {},
    }) async {
      phone(tester);
      await tester.pumpWidget(
        localizedApp(
          AddPlayersScreen(
            onBack: () {},
            onNext: (_) {},
            initialNames: names,
            initialAbsent: absent,
            initialGenders: genders,
            group: group,
            savedGroups: saved,
            onRosterChanged: onRoster,
            onGendersChanged: onGenders,
          ),
        ),
      );
      await loadArtwork(tester);
      await tester.pumpAndSettle();
    }

    Future<void> add(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.tap(find.byKey(AddPlayersScreen.addButton));
      await tester.pumpAndSettle();
    }

    testWidgets('a player named «empty» does not collide with the empty seat', (
      tester,
    ) async {
      await pump(tester, names: ['empty', 'b', 'c']);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('seat_card_empty')), findsOneWidget);
      expect(find.byKey(const ValueKey('seat_slot_empty')), findsOneWidget);
    });

    testWidgets('invisible-only names add nobody; duplicates ignore case', (
      tester,
    ) async {
      final seen = <List<String>>[];
      await pump(tester, onRoster: (p, _) => seen.add(p));
      await add(tester, '\u200b\u200b\u200f');
      expect(seen, isEmpty);
      await add(tester, 'Ali');
      await add(tester, 'ali');
      await add(tester, 'ALI');
      expect(seen.last, ['Ali', 'ali 2', 'ALI 3']);
    });

    testWidgets('the name field holds twenty characters', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'x' * 30);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLength, 20);
      expect(field.controller!.text.length, 20);
    });

    testWidgets('initial roster, order and absences are honoured', (
      tester,
    ) async {
      final group = _group(['a', 'b', 'c', 'd', 'e']);
      final seen = <(List<String>, Set<String>)>[];
      await pump(
        tester,
        names: ['b', 'a', 'c', 'd', 'e', 'guest'],
        absent: {'c'},
        group: group,
        onRoster: (p, a) => seen.add((p, a)),
      );
      // Toggling one attendance reports the whole roster, order intact.
      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(1)));
      await tester.pumpAndSettle();
      expect(seen.last.$1, ['b', 'a', 'c', 'd', 'e', 'guest']);
      expect(seen.last.$2, {'c', 'b'});
    });

    testWidgets('removing a guest prunes their gender', (tester) async {
      Map<String, PlayerGender>? last;
      await pump(
        tester,
        names: ['a', 'b', 'c'],
        genders: {
          'a': PlayerGender.male,
          'b': PlayerGender.female,
          'c': PlayerGender.male,
        },
        onGenders: (g) => last = Map.of(g),
      );
      await tester.tap(find.byKey(const ValueKey('delete_player_2')));
      await tester.pumpAndSettle();
      expect(last, isNotNull);
      expect(last!.containsKey('b'), isFalse);
      expect(last!.keys.toSet(), {'a', 'c'});
    });

    testWidgets('picking a group appends guests; un-picking keeps the table', (
      tester,
    ) async {
      final g = _group(['m1', 'm2', 'm3']);
      final seen = <(List<String>, Set<String>)>[];
      await pump(tester, saved: [g], onRoster: (p, a) => seen.add((p, a)));
      await add(tester, 'Zed');
      await tester.tap(find.byType(DeckChip).first);
      await tester.pumpAndSettle();
      expect(seen.last.$1, ['m1', 'm2', 'm3', 'Zed']);
      // Mark a member away, then un-pick the group: nothing is cleared.
      await tester.tap(find.byKey(AddPlayersScreen.attendanceToggleFor(2)));
      await tester.pumpAndSettle();
      expect(seen.last.$2, {'m2'});
      await tester.tap(find.byType(DeckChip).first);
      await tester.pumpAndSettle();
      expect(seen.last.$1, ['m1', 'm2', 'm3', 'Zed']);
      expect(seen.last.$2, {'m2'});
    });
  });

  group('host frame', () {
    testWidgets(
      'two seats that fold to the host name: only seat one wears it',
      (tester) async {
        String? first;
        String? second;
        await tester.pumpWidget(
          localizedApp(
            HostIdentityScope(
              hostName: 'Ali',
              frame: 'frame_gilded',
              plate: null,
              child: Builder(
                builder: (outer) => HostIdentityScope.seated(
                  outer,
                  const ['Ali', 'ali', 'Mona'],
                  Builder(
                    builder: (c) {
                      first = HostIdentityScope.frameFor(c, 'Ali', seat: 1);
                      second = HostIdentityScope.frameFor(c, 'ali', seat: 2);
                      return const SizedBox();
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        expect(first, 'frame_gilded');
        expect(second, isNull);
      },
    );
  });

  group('RolesScreen', () {
    Future<({List<Map<Role, int>> dealt, List<Set<OptionalRole>> on})> pump(
      WidgetTester tester, {
      int players = 8,
      Set<String> owns = const {},
      Map<Role, int>? initial,
    }) async {
      phone(tester);
      final dealt = <Map<Role, int>>[];
      final on = <Set<OptionalRole>>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [walletProvider.overrideWith(() => _Owns(owns))],
          child: localizedApp(
            RolesScreen(
              playerCount: players,
              initialCounts: initial,
              onBack: () {},
              onNext: dealt.add,
              onOptionalRoles: on.add,
            ),
          ),
        ),
      );
      await loadArtwork(tester);
      await tester.pumpAndSettle();
      return (dealt: dealt, on: on);
    }

    bool lit(WidgetTester tester, String code) =>
        tester.widget<DeckChip>(find.byKey(RolesScreen.preset(code))).selected;

    testWidgets('reopens the split the host left, bought role included', (
      tester,
    ) async {
      final out = await pump(
        tester,
        owns: {'role_elder'},
        initial: {
          Role.mafia: 2,
          Role.detective: 1,
          Role.doctor: 1,
          Role.elder: 1,
          Role.citizen: 3,
        },
      );
      expect(lit(tester, 'normal'), isTrue);
      await tester.tap(find.byKey(RolesScreen.nextButton));
      expect(out.dealt.single[Role.elder], 1);
      expect(out.dealt.single[Role.citizen], 3);
      expect(out.on.single, {OptionalRole.elder});
    });

    testWidgets('a hand-edited split reopens as custom', (tester) async {
      await pump(
        tester,
        initial: {
          Role.mafia: 3,
          Role.detective: 1,
          Role.doctor: 1,
          Role.citizen: 3,
        },
      );
      expect(lit(tester, 'custom'), isTrue);
      expect(lit(tester, 'normal'), isFalse);
    });

    testWidgets('a split for another table size is ignored', (tester) async {
      await pump(tester, players: 8, initial: {Role.mafia: 1, Role.citizen: 5});
      expect(lit(tester, 'normal'), isTrue);
    });

    testWidgets('a bought-role switch does not turn the preset to custom', (
      tester,
    ) async {
      await pump(tester, owns: {'role_elder'});
      expect(lit(tester, 'normal'), isTrue);
      final sw = find.byKey(RoleDealGrid.plus(Role.elder));
      await tester.ensureVisible(sw);
      await tester.tap(sw);
      await tester.pumpAndSettle();
      expect(lit(tester, 'normal'), isTrue);
    });

    testWidgets('Next drops a role the wallet does not own', (tester) async {
      final out = await pump(
        tester,
        owns: {},
        initial: {
          Role.mafia: 2,
          Role.detective: 1,
          Role.doctor: 1,
          Role.sniper: 1,
          Role.citizen: 3,
        },
      );
      await tester.tap(find.byKey(RolesScreen.nextButton));
      expect(out.on.single, isEmpty);
      expect(out.dealt.single.containsKey(Role.sniper), isFalse);
      expect(out.dealt.single[Role.citizen], 4);
    });
  });

  group('SettingsScreen presets', () {
    Future<void> pump(
      WidgetTester tester, {
      required MatchSettings initial,
      required Map<Role, int> counts,
      required void Function(MatchSettings) onSave,
      required void Function(Map<Role, int>) onCounts,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: localizedApp(
            SettingsScreen(
              initial: initial,
              onSave: onSave,
              onBack: () {},
              playerCount: 10,
              roleCounts: counts,
              onRoleCounts: onCounts,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('a preset keeps the bought roles that were on', (tester) async {
      Map<Role, int>? counts;
      MatchSettings? saved;
      await pump(
        tester,
        initial: const MatchSettings(elderEnabled: true),
        counts: const {
          Role.mafia: 2,
          Role.detective: 1,
          Role.doctor: 1,
          Role.elder: 1,
          Role.citizen: 5,
        },
        onSave: (s) => saved = s,
        onCounts: (c) => counts = c,
      );
      // The split with the bought role still reads as the classic preset.
      final classic = find.byKey(
        SettingsScreen.presetChip(MatchPreset.classic),
      );
      expect(classic, findsOneWidget);
      await tester.tap(
        find.byKey(SettingsScreen.presetChip(MatchPreset.brutal)),
      );
      await tester.pump();
      expect(counts, isNotNull);
      expect(counts![Role.elder], 1);
      expect(counts!.values.fold<int>(0, (a, b) => a + b), 10);
      await tester.ensureVisible(find.byKey(SettingsScreen.saveButton));
      await tester.tap(find.byKey(SettingsScreen.saveButton));
      await tester.pump();
      expect(saved!.elderEnabled, isTrue);
    });
  });

  group('bot match settings', () {
    test('saved defaults are the base; the preset goes on top', () {
      const saved = MatchSettings(
        narrationEnabled: false,
        scoreEnabled: false,
        identityHoldSeconds: 8,
        elderEnabled: true,
      );
      const pick = (
        players: 10,
        preset: MatchPreset.brutal,
        level: BotLevel.normal,
        roles: <OptionalRole>{OptionalRole.sniper},
      );
      final s = pick.settingsOver(saved);
      // The player own choices survive...
      expect(s.narrationEnabled, isFalse);
      expect(s.scoreEnabled, isFalse);
      expect(s.identityHoldSeconds, 8);
      // ...the preset speaks for the shape of the game...
      expect(s.speechSeconds, MatchPreset.brutal.settings.speechSeconds);
      expect(
        s.discussionSeconds,
        MatchPreset.brutal.settings.discussionSeconds,
      );
      // ...and only the roles picked for this table are on.
      expect(s.sniperEnabled, isTrue);
      expect(s.elderEnabled, isFalse);
    });
  });
}
