import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/ui/screens/setup/settings_screen.dart';
import '../support/localized.dart';

void main() {
  for (final save in [false, true]) {
    testWidgets('audio previews immediately; save=$save controls retention', (
      tester,
    ) async {
      final previews = <MatchSettings>[];
      MatchSettings? saved;
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        localizedApp(
          SettingsScreen(
            initial: const MatchSettings.defaults(),
            onAudioPreview: previews.add,
            onSave: (value) => saved = value,
            onBack: () {},
          ),
        ),
      );
      final music = find.byKey(SettingsScreen.toggle('score'));
      await tester.ensureVisible(music);
      await tester.tap(music);
      await tester.pump();
      expect(previews.last.scoreEnabled, isFalse);
      final mute = find.byKey(SettingsScreen.toggle('muteAll'));
      await tester.ensureVisible(mute);
      await tester.tap(mute);
      await tester.pump();
      expect(previews.last.muteAllAudio, isTrue);
      if (save) {
        await tester.tap(find.byKey(SettingsScreen.saveButton));
        expect(saved!.muteAllAudio, isTrue);
        expect(saved!.scoreEnabled, isFalse);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      expect(previews.last.muteAllAudio, save);
      expect(previews.last.scoreEnabled, !save);
    });
  }
}
