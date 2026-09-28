/// Renders the 1.1 screens built since the brainstorm, for the owner to look
/// at. **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/update11_screenshots.dart
///
/// Writes to `build/screens_update11/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/engine/models/enums.dart' hide Alignment;
import 'package:mafia_master/engine/views.dart' hide VoteTally;
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/transport/account_service.dart';
import 'package:mafia_master/transport/game_snapshot.dart';
import 'package:mafia_master/transport/witness_channel.dart';
import 'package:mafia_master/ui/economy/account_protection.dart';
import 'package:mafia_master/ui/screens/admin/safety_admin_screen.dart';
import 'package:mafia_master/ui/screens/day/whisper_compose_screen.dart';
import 'package:mafia_master/ui/screens/online/online_session.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_panel.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

const _phone = Size(390, 844);

const _names = ['أمينة', 'كريم', 'سارة', 'يوسف', 'ليلى', 'حسن', 'نور', 'طارق'];

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

GameSnapshot _snapshot({Set<int> dead = const {0, 5}}) => GameSnapshot(
  public: PublicMatchView(
    phase: GamePhase.discussion,
    dayNumber: 3,
    players: [
      for (var seat = 0; seat < _names.length; seat++)
        PublicPlayer(
          seat: seat,
          name: _names[seat],
          status: dead.contains(seat) ? PlayerStatus.dead : PlayerStatus.alive,
        ),
    ],
  ),
  viewerSeat: 0,
);

void main() {
  final out = Directory('build/screens_update11')..createSync(recursive: true);

  Future<void> shoot(
    WidgetTester tester,
    String name,
    Widget child, {
    List<Override> overrides = const [],
    Future<void> Function(WidgetTester)? before,
  }) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(overrides: overrides, child: localizedApp(child)),
      ),
    );
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (before != null) await before(tester);
    await tester.pump(const Duration(seconds: 1));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${out.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('F21a — the dead read the whispers', (tester) async {
    const table = WitnessTable(
      roles: {
        0: Role.citizen,
        1: Role.mafia,
        2: Role.doctor,
        3: Role.citizen,
        4: Role.detective,
        5: Role.citizen,
        6: Role.mafia,
        7: Role.citizen,
      },
      actions: [
        WitnessAction(night: 3, seat: 1, action: 'kill', targetSeat: 4),
        WitnessAction(night: 3, seat: 2, action: 'protect', targetSeat: 4),
        WitnessAction(night: 3, seat: 4, action: 'investigate', targetSeat: 6),
        WitnessAction(night: 3, seat: 3, action: 'suspect', targetSeat: 1),
      ],
      whispers: [
        WitnessWhisper(
          id: 'w1',
          day: 2,
          fromSeat: 1,
          toSeat: 6,
          text: 'خلّي بالك، سارة شكلها دكتورة',
          masked: false,
        ),
        WitnessWhisper(
          id: 'w2',
          day: 3,
          fromSeat: 4,
          toSeat: 3,
          text: 'أنا متأكد إن طارق مافيا، صوّت معايا',
          masked: false,
        ),
        WitnessWhisper(
          id: 'w3',
          day: 3,
          fromSeat: 7,
          toSeat: 2,
          text: null,
          masked: true,
        ),
      ],
    );
    await shoot(
      tester,
      '01_witness_whispers',
      Scaffold(body: WitnessPanel(snapshot: _snapshot(), table: table)),
      before: (tester) async {
        await tester.tap(find.text('الترابيزة'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('F21a — the disclosure at the composer', (tester) async {
    await shoot(
      tester,
      '02_whisper_composer_disclosure',
      Scaffold(
        body: SafeArea(
          child: WhisperComposeScreen(
            players: _snapshot().public.players,
            fromSeat: 1,
            witnessed: true,
            onSend: (_, _, _) {},
            onCancel: () {},
          ),
        ),
      ),
    );
  });

  testWidgets('F11 — the owner review queue', (tester) async {
    final backend = FakeBackend(roomId: 'r', state: roomState(), players: roster(2))
      ..responses['player_safety'] = {
        'items': [
          {
            'id': '11111111-1111-4111-8111-111111111111',
            'category': 'harassment',
            'context': 'lobby',
            'status': 'pending',
            'createdAt': '2026-09-28T19:40:00Z',
            'details': 'بيشتم الناس في اللوبي وبيكرر نفس الكلام',
            'evidence': {
              'roomCode': 'KDXQ7M',
              'roomTitle': 'قعدة الخميس',
              'targetName': 'زياد',
              'targetSeat': 3,
            },
            'targetOpenReports': 3,
            'targetActioned': 1,
            'targetRestrictions': <String>[],
            'note': '',
          },
          {
            'id': '22222222-2222-4222-8222-222222222222',
            'category': 'inappropriate_name',
            'context': 'result',
            'status': 'pending',
            'createdAt': '2026-09-28T18:05:00Z',
            'details': '',
            'evidence': {
              'roomCode': 'PRTW4N',
              'roomTitle': '',
              'targetName': 'xX_Mafia_Xx',
              'targetSeat': 6,
            },
            'targetOpenReports': 1,
            'targetActioned': 0,
            'targetRestrictions': ['voice'],
            'note': '',
          },
        ],
        'next': null,
      };
    await shoot(
      tester,
      '03_safety_admin_queue',
      const SafetyAdminScreen(web: true),
      overrides: [
        onlineBackendFactoryProvider.overrideWithValue(() async => backend),
        accountStatusProvider.overrideWith(
          (ref) async =>
              const AccountStatus(recoverable: true, email: 'owner@example.test'),
        ),
      ],
    );
  });
}
