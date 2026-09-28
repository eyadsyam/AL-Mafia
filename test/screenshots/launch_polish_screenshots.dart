/// Renders the 1.0.1+10 launch-polish screens (History as case files, the
/// mode choice with painted marks) for the owner to look at.
///
/// **Not a test** (no `_test` suffix, asserts nothing), like
/// `update101_screenshots.dart`.
///
///     flutter test test/screenshots/launch_polish_screenshots.dart
///
/// Writes to `build/screens_launch/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:mafia_master/data/character_bonds.dart';
import 'package:mafia_master/data/memory_match_repository.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/ui/fun/character_dossiers.dart';
import 'package:mafia_master/ui/fun/characters_screen.dart';
import 'package:mafia_master/ui/widgets/warmup_gate.dart';
import 'package:mafia_master/ui/account/account_sheet.dart';
import 'package:mafia_master/transport/account_auth.dart';
import 'package:mafia_master/ui/social/friends.dart';
import 'package:mafia_master/data/online_match_history.dart';
import 'package:mafia_master/data/repository_provider.dart';
import 'package:mafia_master/ui/screens/postgame/history_screen.dart';
import 'package:mafia_master/ui/screens/setup/mode_screen.dart';

import '../support/localized.dart';
import '../support/scripted_match.dart';

const _phone = Size(390, 844);

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final out = Directory('build/screens_launch')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    List<Override> overrides = const [],
    Locale locale = const Locale('ar'),
  }) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(
          overrides: overrides,
          child: localizedApp(child, locale: locale),
        ),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate()) {
          await precacheImage(
            (element.widget as Image).image,
            element,
          ).timeout(const Duration(seconds: 2), onTimeout: () {});
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump(const Duration(milliseconds: 300));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('${out.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  testWidgets('history — case files', (tester) async {
    SharedPreferences.setMockInitialValues({
      OnlineMatchHistory.storageKey:
          '[{"roomId":"r1","names":["ليلى","كريم","سارة","عمر","نور"],"winner":"mafia","days":3}]',
    });
    final store = MemoryMatchStore();
    for (final seed in [3, 7]) {
      final engine = scriptedMatch(
        playToEnd: true,
        seed: seed,
        createdAt: DateTime(2026, 9, 20 + seed),
      );
      await tester.runAsync(
        () => MemoryMatchRepository(store).persistStep(engine.match),
      );
    }
    await shoot(
      tester,
      'history_ar',
      HistoryScreen(onOpen: (_) {}, onBack: () {}),
      overrides: [
        matchRepositoryProvider.overrideWithValue(MemoryMatchRepository(store)),
      ],
    );
  });

  testWidgets('history — empty', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'history_empty_ar',
      HistoryScreen(onOpen: (_) {}, onBack: () {}),
      overrides: [
        matchRepositoryProvider.overrideWithValue(
          MemoryMatchRepository(MemoryMatchStore()),
        ),
      ],
    );
  });

  testWidgets('mode choice', (tester) async {
    await shoot(
      tester,
      'mode_ar',
      ModeScreen(onBack: () {}, onPlayOnline: () {}, onPlayOffline: () {}),
    );
  });

  String ledgerJson() {
    var ledger = CharacterBondLedger.empty;
    for (var i = 0; i < 9; i++) {
      ledger = progressCharacterBonds(
        ledger,
        CharacterBondCase(
          receiptId: 'local-$i',
          completedAt: DateTime.utc(2026, 9, 1 + i),
          winner: i.isEven ? engine.Alignment.town : engine.Alignment.mafia,
          roles: i < 2
              ? {engine.Role.mafia, engine.Role.detective, engine.Role.citizen}
              : engine.Role.values.toSet(),
          survivingRoles: {engine.Role.citizen, engine.Role.doctor},
          momentRole: engine.Role.detective,
        ),
      );
    }
    return jsonEncode(ledger.toJson());
  }

  for (final role in [engine.Role.mafia, engine.Role.detective]) {
    testWidgets('characters — ${role.name}', (tester) async {
      SharedPreferences.setMockInitialValues({
        CharacterBondStore.storageKey: ledgerJson(),
      });
      await shoot(
        tester,
        'characters_${role.name}_ar',
        CharactersScreen(onBack: () {}, initial: role),
      );
    });
  }

  testWidgets('dossier strip + home whisper', (tester) async {
    SharedPreferences.setMockInitialValues({
      CharacterBondStore.storageKey: ledgerJson(),
    });
    await shoot(
      tester,
      'dossier_strip_ar',
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              BondHomeLine(onTap: () {}),
              CharacterDossiers(onOpen: () {}),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('letter arrived', (tester) async {
    await shoot(
      tester,
      'letter_arrived_ar',
      const Scaffold(
        body: Center(
          child: BondLetterArrivedCard(
            arrival: BondLetterArrival(
              receiptId: 'x',
              role: engine.Role.doctor,
              tier: 2,
            ),
          ),
        ),
      ),
    );
  });

  testWidgets('first-launch preparation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'warmup_ar',
      const WarmupGate(child: Scaffold(body: SizedBox.expand())),
      overrides: [warmupEnabledProvider.overrideWithValue(true)],
    );
    // Let the preparation's give-up timer run out before the tree goes.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  });

  testWidgets('account sheet — guest', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'account_guest_ar',
      const Scaffold(body: AccountSheet()),
      overrides: [
        accountProfileProvider.overrideWith(
          (ref) => Stream.value(AccountProfile.guest),
        ),
      ],
    );
  });

  testWidgets('account sheet — sign up', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await shoot(
      tester,
      'account_signup_ar',
      const Scaffold(body: AccountSheet(initial: AccountStep.signUp)),
      overrides: [
        accountProfileProvider.overrideWith(
          (ref) => Stream.value(AccountProfile.guest),
        ),
      ],
    );
  });

  testWidgets('friends sheet', (tester) async {
    await shoot(
      tester,
      'friends_ar',
      Scaffold(body: FriendsSheet(onJoin: (_) {})),
      overrides: [friendsProvider.overrideWith(_ShotFriends.new)],
    );
  });
}

class _ShotFriends extends FriendsController {
  @override
  Future<FriendsState?> build() async => FriendsState.fromJson({
    'friends': [
      {'id': 'a', 'name': 'ليلى', 'gender': 'female',
       'presence': {'state': 'lobby', 'code': 'K7M2QP', 'players': 4}},
      {'id': 'b', 'name': 'كريم', 'gender': 'male', 'presence': {'state': 'playing'}},
      {'id': 'f', 'name': 'يوسف', 'gender': 'male'},
    ],
    'incoming': [{'id': 'c', 'name': 'سارة', 'gender': 'female'}],
    'recent': [{'id': 'e', 'name': 'نور', 'gender': 'female', 'matches': 3}],
    'invites': [{'roomId': 'r', 'code': 'ABCDEF', 'name': 'ليلى'}],
  });
  @override
  Future<void> refresh() async {}
}
