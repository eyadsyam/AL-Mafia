/// Doc 13 §5's preset chips and doc 14 Part 5's five groups — plus the bug
/// they both sit next to.
///
/// # The bug this file exists to keep fixed
///
/// The settings screen used to hold one `late` field per control and rebuild a
/// fresh `MatchSettings(...)` on save out of exactly those eight. Every field
/// it had no control for was silently reset to its default by the act of
/// opening settings and pressing save. A host who turned something off got it
/// back, and nothing anywhere said so.
///
/// The fix is structural (one settings object, edited in place), so the test
/// for it is structural too: hand the screen settings in which *every*
/// non-default field is non-default, press save without touching anything, and
/// require the object that comes back to be the object that went in. That
/// property matters more now, not less: doc 14 removed a dozen controls from
/// this screen, and every field they used to write is a field that now passes
/// through untouched.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/widgets/settings_kit.dart';
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/presets.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';

import '../support/localized.dart';

/// Settings with nothing at its default, including the many this screen no
/// longer draws.
const MatchSettings _unusual = MatchSettings(
  bulletsEnabled: false,
  quietNightEnabled: false,
  selfProtectEnabled: false,
  pressureCurveEnabled: false,
  revealNightVictimRole: true,
  interfaceHintsEnabled: false,
  playHintsEnabled: false,
  postMatchCoachingEnabled: false,
  midDiscussionConfrontation: true,
  discussionSeconds: 180,
  whisperEnabled: true,
  revealWhisperContent: true,
  openingRoundEnabled: true,
  survivorConfrontationEnabled: true,
  confrontationSeconds: 60,
  openVoting: true,
  traceEnabled: false,
  confrontationEnabled: false,
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required MatchSettings initial,
    required void Function(MatchSettings) onSave,
    int? playerCount,
    Map<Role, int>? roleCounts,
    void Function(Map<Role, int>)? onRoleCounts,
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
            playerCount: playerCount,
            roleCounts: roleCounts,
            onRoleCounts: onRoleCounts,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Scrolls [key] into view and taps it. The screen scrolls, and so does a
  /// real host.
  Future<void> tapAt(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await tester.pump();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(arStrings.save));
    await tester.pump();
    await tester.tap(find.text(arStrings.save));
    await tester.pump();
  }

  testWidgets('saving without touching anything changes nothing', (
    tester,
  ) async {
    MatchSettings? saved;
    await pump(tester, initial: _unusual, onSave: (s) => saved = s);
    await save(tester);

    expect(saved, isNotNull);
    expect(saved, _unusual);
  });

  testWidgets('editing one control changes exactly that control', (
    tester,
  ) async {
    MatchSettings? saved;
    await pump(tester, initial: _unusual, onSave: (s) => saved = s);

    await tapAt(tester, SettingsScreen.toggle('abstain'));
    await save(tester);

    expect(saved, _unusual.copyWith(abstainAllowed: !_unusual.abstainAllowed));
  });

  group('doc 14 Part 5 — five groups, and a description on every switch', () {
    testWidgets('all five section titles are on the screen', (tester) async {
      await pump(tester, initial: const MatchSettings(), onSave: (_) {});
      for (final title in [
        arStrings.settingsSectionPace,
        arStrings.settingsSectionInformation,
        arStrings.settingsSectionReveal,
        arStrings.settingsSectionVoting,
        arStrings.settingsSectionAudio,
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
    });

    testWidgets('the controls doc 14 removed are not on this screen', (
      tester,
    ) async {
      await pump(tester, initial: const MatchSettings(), onSave: (_) {});
      // The bullet master and its four per-role switches, and the hint reset.
      // Their fields survive — the round-trip test above proves it — but a host
      // has no reason to be shown any of them.
      for (final field in [
        'bullets',
        'quietNight',
        'selfProtect',
        'openFile',
        'testify',
        'interfaceHints',
      ]) {
        expect(
          find.byKey(SettingsScreen.toggle(field)),
          findsNothing,
          reason: field,
        );
      }
    });

    testWidgets('the online-only rows say so', (tester) async {
      await pump(tester, initial: const MatchSettings(), onSave: (_) {});
      // Doc 14 Part 5: *"greyed with the note «في الأونلاين بس»"*. Named, not
      // hidden — a host who cannot find the whisper switch concludes the app
      // lost it.
      expect(
        find.textContaining(arStrings.settingsOnlineOnly),
        findsAtLeastNWidgets(3),
      );
    });

    testWidgets('«اسم واحد» is off by default', (tester) async {
      // Doc 14 §4.2. The round it replaced was imposed on every table.
      expect(const MatchSettings().openingRoundEnabled, isFalse);

      await pump(tester, initial: const MatchSettings(), onSave: (_) {});
      final row = find.byKey(SettingsScreen.toggle('openingRound'));
      await tester.ensureVisible(row);
      expect(tester.widget<Switch>(row).value, isFalse);
    });
  });

  group('doc 13 §5 — the preset chips', () {
    testWidgets('tapping one writes its rows and leaves the rest', (
      tester,
    ) async {
      MatchSettings? saved;
      Map<Role, int>? counts;
      await pump(
        tester,
        initial: _unusual,
        playerCount: 9,
        roleCounts: const {Role.mafia: 2, Role.citizen: 7},
        onRoleCounts: (c) => counts = c,
        onSave: (s) => saved = s,
      );

      await tapAt(tester, SettingsScreen.presetChip(MatchPreset.fast));
      await save(tester);

      final fast = MatchPreset.fast.settings;
      expect(saved!.speechSeconds, fast.speechSeconds);
      expect(saved!.discussionSeconds, fast.discussionSeconds);
      expect(saved!.bulletsEnabled, fast.bulletsEnabled);
      expect(saved!.revealNightVictimRole, fast.revealNightVictimRole);
      expect(saved!.pressureCurveEnabled, fast.pressureCurveEnabled);

      // And the rows «سريعة» does not speak for are untouched.
      expect(saved!.openVoting, _unusual.openVoting);
      expect(saved!.confrontationSeconds, _unusual.confrontationSeconds);
      expect(
        saved!.survivorConfrontationEnabled,
        _unusual.survivorConfrontationEnabled,
      );

      // The split it implies went back to the caller, not into the settings.
      expect(counts, MatchPreset.fast.roleCounts(9));
    });

    testWidgets('«قاسية» is not offered to a table of six', (tester) async {
      // Two Mafia in six with no Doctor is close to four matches in five for
      // the Mafia, and one Mafia in six is «كلاسيكية». There is no integer in
      // between, so the preset is simply absent at that count.
      await pump(tester, initial: _unusual, playerCount: 6, onSave: (_) {});
      expect(
        find.byKey(SettingsScreen.presetChip(MatchPreset.brutal)),
        findsNothing,
      );
      expect(
        find.byKey(SettingsScreen.presetChip(MatchPreset.classic)),
        findsOneWidget,
      );
    });

    testWidgets('editing a row after tapping a chip puts the chip out', (
      tester,
    ) async {
      await pump(
        tester,
        initial: MatchPreset.classic.settings,
        playerCount: 9,
        onSave: (_) {},
      );

      SettingsSegment chipFor(MatchPreset p) => tester.widget<SettingsSegment>(
        find.byKey(SettingsScreen.presetChip(p)),
      );
      expect(chipFor(MatchPreset.classic).selected, isTrue);

      // Take the pressure curve out. The match is now nobody's preset, and the
      // chip says so on its own — there is no stored "current preset" to go
      // stale, only a derived one.
      await tapAt(tester, SettingsScreen.toggle('pressureCurve'));

      expect(chipFor(MatchPreset.classic).selected, isFalse);
    });
  });
}
