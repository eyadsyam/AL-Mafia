library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/screens/day/vote_result_screen.dart';
import 'package:mafia_master/ui/screens/night/morning_screen.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';

import '../support/localized.dart';

const _phone = Size(390, 844);
const _players = [
  PublicPlayer(seat: 0, name: 'سلمى', status: PlayerStatus.alive),
  PublicPlayer(seat: 1, name: 'كريم', status: PlayerStatus.alive),
  PublicPlayer(seat: 2, name: 'نور', status: PlayerStatus.alive),
];

Future<void> _loadFonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Mono': 'assets/fonts/IBMPlexMono-Regular.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

void main() {
  final output = Directory('build/screens_tabletop')
    ..createSync(recursive: true);

  Future<void> shoot(WidgetTester tester, String name, Widget screen) async {
    await tester.runAsync(_loadFonts);
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('shot'), child: localizedApp(screen)),
    );
    await tester.pump(const Duration(milliseconds: 200));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${output.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  testWidgets('morning', (tester) async {
    await shoot(
      tester,
      '01_morning_ar',
      MorningScreen(
        dayNumber: 2,
        victimName: 'كريم',
        someoneSavedUnnamed: false,
        traceText: 'الأثر الوحيد المؤكد ظهر جنب الترابيزة.',
        tabletop: true,
        onContinue: () {},
      ),
    );
  });

  testWidgets('discussion', (tester) async {
    await shoot(
      tester,
      '02_discussion_ar',
      DiscussionScreen(
        mode: DiscussionMode.structured,
        alivePlayers: _players,
        perSpeakerTime: const Duration(minutes: 1),
        tabletop: true,
        onFinished: () {},
      ),
    );
  });

  testWidgets('vote result', (tester) async {
    await shoot(
      tester,
      '03_vote_result_ar',
      VoteResultScreen(
        names: const {0: 'سلمى', 1: 'كريم', 2: 'نور'},
        tally: const {0: 1, 1: 2},
        eliminatedSeat: 1,
        eliminatedRole: Role.citizen,
        tabletop: true,
        onContinue: () {},
      ),
    );
  });

  testWidgets('result', (tester) async {
    await shoot(
      tester,
      '04_result_ar',
      ResultScreen(
        winner: engine.Alignment.town,
        rows: const [
          ResultRow(
            seat: 0,
            name: 'سلمى',
            role: Role.detective,
            eliminatedLabel: 'كملت للآخر',
          ),
          ResultRow(
            seat: 1,
            name: 'كريم',
            role: Role.mafia,
            eliminatedLabel: 'اليوم التاني',
          ),
        ],
        tabletop: true,
        onHome: () {},
      ),
    );
  });
}
