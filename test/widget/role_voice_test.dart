import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/app/asset_constants.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/screens/setup/role_deal_grid.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

/// The deal by sound as well as by pictures (owner, 2026-10-29): every role's
/// card can be heard from its big card, in the match narrator's voice — and
/// never while the phone is in a player's hand.
void main() {
  const listen = ValueKey('role_sheet_listen');

  test('every role has its clip, for the app and for the web', () {
    for (final role in Role.values) {
      final ogg = AppRoleVoice.of(role.name);
      expect(File(ogg).existsSync(), isTrue, reason: ogg);
      expect(
        File(ogg.replaceFirst('.ogg', '.mp3')).existsSync(),
        isTrue,
        reason: 'Safari plays no ogg',
      );
    }
  });

  test('the folder is shipped with the app', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- assets/voice/roles/'),
    );
  });

  Future<AudioDirector> open(WidgetTester tester, Role role) async {
    await loadArtwork(tester);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final audio = AudioDirector();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [audioDirectorProvider.overrideWithValue(audio)],
        child: localizedApp(
          Scaffold(
            body: RoleDealGrid(
              cards: [RoleDealSpec(role: role, name: role.name, count: 1)],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(RoleDealGrid.count(role)));
    await tester.pumpAndSettle();
    return audio;
  }

  for (final role in Role.values) {
    testWidgets('«اسمع» on the ${role.name} card says that card', (
      tester,
    ) async {
      final audio = await open(tester, role);
      await tester.tap(find.byKey(listen));
      expect(audio.emittedRoleVoices, [AppRoleVoice.of(role.name)]);
    });
  }

  testWidgets('muted, or with narration off, it says nothing', (tester) async {
    final audio = await open(tester, Role.elder);
    audio.muted = true;
    await tester.tap(find.byKey(listen));
    audio
      ..muted = false
      ..narrationEnabled = false;
    await tester.tap(find.byKey(listen));
    expect(audio.emittedRoleVoices, isEmpty);
  });

  test('never while the phone is in a hand', () {
    final audio = AudioDirector()..setLocation(PhoneLocation.inHand);
    audio.sayRole(AppRoleVoice.of(Role.mafia.name));
    expect(audio.emittedRoleVoices, isEmpty);
    audio.setLocation(PhoneLocation.onTable);
    audio.sayRole(AppRoleVoice.of(Role.mafia.name));
    expect(audio.emittedRoleVoices, hasLength(1));
  });
}
