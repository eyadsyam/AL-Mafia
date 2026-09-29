import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/enums.dart' as engine;
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/data/match_codec.dart';
import 'package:mafia_master/ui/screens/day/discussion_screen.dart';
import 'package:mafia_master/ui/screens/day/vote_result_screen.dart';
import 'package:mafia_master/ui/screens/night/morning_screen.dart';
import 'package:mafia_master/ui/screens/postgame/result_screen.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

void main() {
  test('tabletop defaults on and survives local settings persistence', () {
    const enabled = MatchSettings.defaults();
    expect(enabled.tabletopPresentation, isTrue);
    final disabled = enabled.copyWith(tabletopPresentation: false);
    expect(
      MatchCodec.decodeSettings(
        MatchCodec.encodeSettings(disabled),
      ).tabletopPresentation,
      isFalse,
    );
  });

  const players = [
    PublicPlayer(seat: 0, name: 'سلمى', status: PlayerStatus.alive),
    PublicPlayer(seat: 1, name: 'كريم', status: PlayerStatus.alive),
    PublicPlayer(seat: 2, name: 'نور', status: PlayerStatus.alive),
  ];

  for (final width in [320.0, 430.0]) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      testWidgets(
        'tabletop public phases fit at $width ${locale.languageCode}',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await tester.pumpWidget(
            localizedApp(
              MorningScreen(
                dayNumber: 2,
                victimName: players.first.name,
                someoneSavedUnnamed: false,
                tabletop: true,
                onContinue: () {},
              ),
              locale: locale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('morning_headline')))
                .style
                ?.fontSize,
            TabletopTokens.headlineFontSize,
          );

          await tester.pumpWidget(
            localizedApp(
              DiscussionScreen(
                mode: DiscussionMode.structured,
                alivePlayers: players,
                perSpeakerTime: const Duration(minutes: 1),
                tabletop: true,
                onFinished: () {},
              ),
              locale: locale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('phase_timer_text')))
                .style
                ?.fontSize,
            TabletopTokens.timerFontSize,
          );

          await tester.pumpWidget(
            localizedApp(
              VoteResultScreen(
                names: const {0: 'سلمى', 1: 'كريم', 2: 'نور'},
                tally: const {0: 1, 1: 2},
                eliminatedSeat: 1,
                eliminatedRole: Role.citizen,
                tabletop: true,
                onContinue: () {},
              ),
              locale: locale,
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('vote_result_headline')),
                )
                .style
                ?.fontSize,
            TabletopTokens.headlineFontSize,
          );

          await tester.pumpWidget(
            localizedApp(
              ResultScreen(
                winner: engine.Alignment.town,
                rows: const [
                  ResultRow(
                    seat: 0,
                    name: 'سلمى',
                    role: Role.detective,
                    eliminatedLabel: '—',
                  ),
                ],
                tabletop: true,
                onHome: () {},
              ),
              locale: locale,
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('result_winner_headline')),
                )
                .style
                ?.fontSize,
            TabletopTokens.winnerFontSize,
          );
        },
      );
    }
  }
}
