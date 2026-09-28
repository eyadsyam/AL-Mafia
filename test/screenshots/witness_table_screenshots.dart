/// Renders the dead's view of the table (owner, 2026-09-28) for review.
/// **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/witness_table_screenshots.dart
///
/// Writes to `build/screens_witness/`.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/transport/online_transport.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/online/online_table_flow.dart';
import 'package:mafia_master/ui/screens/online/table/table_scene.dart';
import 'package:mafia_master/ui/screens/online/witness/witness_layer.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

const _names = ['إياد', 'كريم', 'سارة', 'يوسف', 'ليلى', 'حسن', 'نور', 'طارق'];

Map<String, dynamic> _view({bool extra = false}) => {
  'roles': [
    for (final (seat, role) in [
      (0, 'citizen'),
      (1, 'mafia'),
      (2, 'doctor'),
      (3, 'citizen'),
      (4, 'detective'),
      (5, 'citizen'),
      (6, 'mafia'),
      (7, 'citizen'),
    ])
      {'seat': seat, 'role': role},
  ],
  'actions': [
    {'night': 3, 'seat': 1, 'action': 'kill', 'targetSeat': 4},
    {'night': 3, 'seat': 2, 'action': 'protect', 'targetSeat': 3},
    {'night': 3, 'seat': 4, 'action': 'investigate', 'targetSeat': 6},
  ],
  'whispers': [
    {
      'id': 'w1',
      'day': 3,
      'fromSeat': 1,
      'toSeat': 6,
      'text': 'خلّي بالك، سارة شكلها دكتورة',
    },
    if (extra)
      {
        'id': 'w2',
        'day': 3,
        'fromSeat': 4,
        'toSeat': 2,
        'text': 'أنا متأكد إن طارق مافيا، صوّت معايا',
      },
  ],
};

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
  final out = Directory('build/screens_witness')..createSync(recursive: true);

  Future<void> scene(
    WidgetTester tester,
    String name, {
    Future<void> Function(WidgetTester, FakeBackend)? then,
  }) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = const Size(390, 844) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final backend = FakeBackend(
      roomId: 'room-1',
      state: roomState(
        phase: 'discussion',
        phaseNumber: 3,
        endsAt: DateTime.now().add(const Duration(minutes: 5)),
        serverNow: DateTime.now(),
      ),
      players: [
        for (var seat = 0; seat < _names.length; seat++)
          RoomPlayer(
            userId: 'u$seat',
            seat: seat,
            name: _names[seat],
            alive: seat != 0 && seat != 5,
            lastSeen: DateTime.now(),
          ),
      ],
      own: const OwnSeat(seat: 0, role: 'citizen', alive: false),
      userId: 'u0',
    )..responses['witness_view'] = _view();
    final transport = await OnlineTransport.connect(
      backend: backend,
      roomId: 'room-1',
      heartbeatInterval: Duration.zero,
    );
    final container = ProviderContainer(
      overrides: [
        gameTransportProvider.overrideWithValue(transport),
        audioDirectorProvider.overrideWithValue(AudioDirector()),
      ],
    );
    container.read(matchControllerProvider.notifier).adoptSnapshot();
    addTearDown(() async {
      container.dispose();
      await transport.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: UncontrolledProviderScope(
          container: container,
          child: localizedApp(
            OnlineTableFlow(
              onExit: () {},
              onAnalytics: () {},
              onStepCommitted: () {},
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 16; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
    if (then != null) await then(tester, backend);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump(const Duration(milliseconds: 400));
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
    // Let the flow's clocks run out before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the table, as the dead see it', (tester) async {
    await scene(tester, '01_table');
  });

  testWidgets('news arrives', (tester) async {
    await scene(
      tester,
      '02_news',
      then: (tester, backend) async {
        backend.responses['witness_view'] = _view(extra: true);
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pump(const Duration(seconds: 1));
        }
      },
    );
  });

  testWidgets('a seat, opened', (tester) async {
    await scene(
      tester,
      '03_dossier',
      then: (tester, _) async {
        await tester.tap(find.byKey(TableScene.seatKey(4)));
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('a whisper, opened', (tester) async {
    await scene(
      tester,
      '04_letter',
      then: (tester, _) async {
        await tester.tap(find.byKey(const ValueKey('witness_letter_w1')));
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  testWidgets('the graveyard chat', (tester) async {
    await scene(
      tester,
      '05_chat',
      then: (tester, _) async {
        await tester.tap(find.byKey(WitnessDock.chat));
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
