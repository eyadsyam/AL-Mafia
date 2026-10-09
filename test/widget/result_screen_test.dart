import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/engine/models/enums.dart' show Role;
import 'package:mafia_master/ui/fun/match_awards.dart';
import 'package:mafia_master/ui/screens/postgame/match_file.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';

import '../support/artwork.dart';
import '../support/localized.dart';

const _rows = [
  ResultRow(seat: 0, name: 'انت', role: Role.detective),
  ResultRow(seat: 1, name: 'منة', role: Role.doctor),
  ResultRow(
    seat: 2,
    name: 'كريم',
    role: Role.mafia,
    eliminatedLabel: 'اليوم 2',
  ),
  ResultRow(
    seat: 3,
    name: 'سلمى',
    role: Role.citizen,
    eliminatedLabel: 'الليلة 1',
  ),
  ResultRow(
    seat: 4,
    name: 'يوسف',
    role: Role.silencer,
    eliminatedLabel: 'اليوم 3',
  ),
  ResultRow(seat: 5, name: 'نور', role: Role.elder),
  ResultRow(
    seat: 6,
    name: 'عمر',
    role: Role.sniper,
    eliminatedLabel: 'اليوم 1',
  ),
  ResultRow(seat: 7, name: 'هنا', role: Role.citizen),
];

const _file = MatchFile(
  days: 3,
  nights: [
    MatchFileNight(
      day: false,
      number: 1,
      lines: [
        MatchFileLine(MatchFileKind.killed, seats: [3]),
      ],
    ),
    MatchFileNight(
      day: true,
      number: 1,
      lines: [
        MatchFileLine(MatchFileKind.expelled, seats: [6], votes: 5),
      ],
    ),
    MatchFileNight(
      day: false,
      number: 2,
      lines: [
        MatchFileLine(MatchFileKind.saved, seats: [1]),
      ],
    ),
  ],
);

const _awards = [
  MatchAward(kind: AwardKind.mvp, seats: [1], names: ['منة']),
];

Widget _screen({
  engine.Alignment winner = engine.Alignment.town,
  int? viewerSeat = 0,
  List<ResultCoinRow> coins = const [
    ResultCoinRow(label: 'فزت على الكمبيوتر', coins: 25),
    ResultCoinRow(label: 'لقيت مافيا', coins: 10),
  ],
  MatchFile? file = _file,
  bool reduced = false,
  List<MatchAward> awards = const [],
  VoidCallback? onPlayAgain,
  VoidCallback? onAnalytics,
}) {
  final screen = ResultScreen(
    winner: winner,
    rows: _rows,
    viewerSeat: viewerSeat,
    coinRows: coins,
    matchFile: file,
    awards: awards,
    onPlayAgain: onPlayAgain,
    onAnalytics: onAnalytics,
    onHome: () {},
  );
  return localizedApp(
    reduced
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: screen,
            ),
          )
        : screen,
  );
}

void main() {
  for (final size in const [Size(360, 640), Size(430, 932)]) {
    for (final winner in engine.Alignment.values) {
      testWidgets('fits ${size.width.toInt()}x${size.height.toInt()} $winner', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _screen(winner: winner, onPlayAgain: () {}, onAnalytics: () {}),
        );
        await loadArtwork(tester);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(ResultScreen.playAgainKey), findsOneWidget);
        expect(find.byKey(ResultScreen.youKey), findsOneWidget);
        for (final r in _rows) {
          expect(
            find.byKey(ResultScreen.seatKey(r.seat), skipOffstage: false),
            findsOneWidget,
          );
        }
      });
    }
  }

  testWidgets('coins count up to the total under normal motion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_screen());
    await tester.pump();
    String total() => tester
        .widget<Text>(
          find.byKey(ResultScreen.coinTotalKey, skipOffstage: false),
        )
        .data!;
    expect(total(), '0');
    await tester.pumpAndSettle();
    expect(total(), '35');
  });

  testWidgets('reduced motion jumps straight to the end state', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_screen(reduced: true));
    await tester.pump();
    final total = tester.widget<Text>(
      find.byKey(ResultScreen.coinTotalKey, skipOffstage: false),
    );
    expect(total.data, '35');
    // The verdict, the stamp and the card are all there on the first frame.
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byKey(ResultScreen.stampKey),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
    expect(find.text('كنت محقق'), findsOneWidget);
  });

  testWidgets('no viewer seat means no «كنت …» card; no coins no earnings', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(viewerSeat: null, coins: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(ResultScreen.youKey), findsNothing);
    expect(
      find.byKey(ResultScreen.coinTotalKey, skipOffstage: false),
      findsNothing,
    );
  });

  testWidgets('stamp matches the winner', (tester) async {
    await tester.pumpWidget(_screen(winner: engine.Alignment.mafia));
    await tester.pumpAndSettle();
    expect(find.text('محدش وقفهم'), findsOneWidget);
    await tester.pumpWidget(_screen(winner: engine.Alignment.town));
    await tester.pumpAndSettle();
    expect(find.text('القضية اتقفلت'), findsOneWidget);
  });

  testWidgets('«ملف الماتش» opens from the result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_screen(reduced: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(ResultScreen.openFileKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ResultScreen.openFileKey));
    await tester.pumpAndSettle();
    expect(find.byKey(MatchFileSheet.shareKey), findsOneWidget);
    expect(find.text('المافيا قتلت سلمى'), findsOneWidget);
    // No award data: no MVP row, and nothing is made up.
    expect(find.byKey(MatchFileSheet.mvpKey), findsNothing);
  });

  testWidgets('the file lists the MVP and every night', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      localizedApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showMatchFile(
              context,
              file: _file,
              rows: _rows,
              awards: _awards,
              onShare: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(MatchFileSheet.mvpKey), findsOneWidget);
    expect(find.text('أحسن لاعب: منة'), findsOneWidget);
    expect(find.text('المافيا قتلت سلمى'), findsOneWidget);
    expect(find.text('الترابيزة طردت عمر بـ 5 أصوات'), findsOneWidget);
    expect(find.text('المافيا حاولت تقتل منة واتنقذ'), findsOneWidget);
    expect(find.byKey(MatchFileSheet.shareKey), findsOneWidget);
  });

  testWidgets('no file means no entry', (tester) async {
    await tester.pumpWidget(_screen(file: null));
    await tester.pumpAndSettle();
    expect(
      find.byKey(ResultScreen.openFileKey, skipOffstage: false),
      findsNothing,
    );
  });
}
