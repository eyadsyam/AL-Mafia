import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/player_profile.dart';
import 'package:mafia_master/engine/models/enums.dart';
import 'package:mafia_master/engine/models/match_settings.dart';
import 'package:mafia_master/engine/models/player.dart';
import 'package:mafia_master/platform/audio_director.dart';
import 'package:mafia_master/ui/economy/cosmetic_paint.dart';
import 'package:mafia_master/ui/economy/my_cosmetics.dart';
import 'package:mafia_master/ui/economy/wallet.dart';
import 'package:mafia_master/ui/screens/match_controller.dart';
import 'package:mafia_master/ui/screens/match_flow.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';
import 'package:mafia_master/ui/widgets/hold_pad.dart';
import 'package:mafia_master/ui/widgets/night_grid.dart';
import 'package:mafia_master/ui/widgets/player_tile.dart';
import 'package:mafia_master/ui/widgets/role_card.dart';
import 'package:mafia_master/ui/widgets/turn_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/artwork.dart';
import '../support/localized.dart';
import '../support/reveal_flow.dart';

/// P9: the narrator and room pack the host equipped are used by the one
/// engine's match flow whether the table is one phone or bots (Doc 05: the
/// same for every seat, never per role; nothing in a hand or at night).
class _Wallet extends WalletController {
  final Map<String, String> equipped;
  _Wallet(this.equipped);
  @override
  Future<WalletState?> build() async => WalletState(
    balance: 0,
    catalog: const [],
    owned: {...equipped.values},
    equipped: equipped,
    history: const [],
  );
}

class _Profile extends PlayerProfileController {
  @override
  Future<PlayerProfile?> build() async =>
      const PlayerProfile(name: 'إنت', gender: PlayerGender.male);
}

const _dress = {
  'room_pack': 'pack_moonlit_archive',
  'narrator': 'narrator_keeper',
};

void main() {
  const surface = Size(390, 844);
  const names = ['إنت', 'أمينة', 'كريم', 'سارة', 'يوسف', 'ليلى', 'حسن'];
  const counts = {
    Role.mafia: 2,
    Role.doctor: 1,
    Role.detective: 1,
    Role.citizen: 3,
  };

  late AudioDirector audio;
  late ProviderContainer container;
  MatchController controller() =>
      container.read(matchControllerProvider.notifier);

  Future<void> start(
    WidgetTester tester,
    Map<String, String> equipped, {
    required Set<int> botSeats,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await loadArtwork(tester);
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    audio = AudioDirector();
    container = ProviderContainer(
      overrides: [
        walletProvider.overrideWith(() => _Wallet(equipped)),
        playerProfileProvider.overrideWith(_Profile.new),
        audioDirectorProvider.overrideWithValue(audio),
      ],
    );
    addTearDown(container.dispose);
    await container.read(walletProvider.future);
    await container.read(playerProfileProvider.future);
    container.read(myCosmeticsProvider);
    controller().startMatch(
      names: names,
      roleCounts: counts,
      settings: const MatchSettings(discussionMode: DiscussionMode.free),
      seed: 3,
      botSeats: botSeats,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: localizedApp(
          MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: MatchFlow(onExit: () {}, onAnalytics: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('one phone: the equipped narrator speaks, nothing is dressed '
      'while the cards are dealt', (tester) async {
    await start(tester, _dress, botSeats: const {});
    expect(audio.activeVoice, 'narrator_keeper');
    expect(find.byType(PackBackdrop), findsNothing);
    expect(controller().engine.match.phase, GamePhase.distributing);
  });

  testWidgets('bots: the same narrator, the same private deal', (tester) async {
    await start(tester, _dress, botSeats: const {1, 2, 3, 4, 5, 6});
    expect(audio.activeVoice, 'narrator_keeper');
    expect(find.byType(PackBackdrop), findsNothing);
  });

  testWidgets('nothing equipped: the default voice, no pack', (tester) async {
    await start(tester, const {}, botSeats: const {1, 2, 3, 4, 5, 6});
    expect(audio.activeVoice, isNull);
    expect(find.byType(PackBackdrop), findsNothing);
  });

  testWidgets('bots: the equipped pack dresses the day, never the night', (
    tester,
  ) async {
    await start(tester, _dress, botSeats: const {1, 2, 3, 4, 5, 6});
    expect(find.byKey(MatchFlowState.presentationKey), findsOneWidget);
    await tester.confirmIdentity(hold: MafiaTiming.defaults.holdToReveal);
    await tester.swipeToFlip();
    await tester.awaitConceal();
    await tester.tap(find.byKey(RoleCard.dismiss));
    await tester.pumpAndSettle();
    GamePhase phase() => controller().engine.match.phase;
    var guard = 0;
    while (phase() != GamePhase.discussion && guard++ < 80) {
      await tester.pumpAndSettle();
      switch (phase()) {
        case GamePhase.night:
          expect(find.byType(PackBackdrop), findsNothing, reason: 'night');
          if (controller().engine.match.currentActorSeat == 0) {
            final pad = find.byType(HoldPad).first;
            final gesture = await tester.startGesture(tester.getCenter(pad));
            await tester.pump();
            await tester.pump(MafiaTiming.defaults.holdToReveal);
            await gesture.up();
            await tester.pumpAndSettle();
            await tester.tap(
              find
                  .byWidgetPredicate(
                    (w) => w is NightGridTile && w.onTap != null,
                  )
                  .first,
            );
            await tester.pump();
            await tester.pump(MafiaTiming.defaults.dwellGate);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(TurnShell.actionButton));
            await tester.pumpAndSettle();
            await tester.pump(MafiaTiming.defaults.turnFloor);
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(TurnShell.actionButton));
            await tester.pumpAndSettle();
          }
        case GamePhase.morning:
          if (find.text('ابدأ النقاش').evaluate().isNotEmpty) {
            await tester.tap(find.text('ابدأ النقاش'));
          }
        case GamePhase.openingRound
            when controller().engine.match.currentActorSeat == 0:
          await tester.tap(find.byType(PlayerTile).first);
        case GamePhase.confrontation:
          await tester.tap(find.text('خلصت'));
        default:
          break;
      }
      await tester.pump(
        MafiaMotion.defaults.dramatic +
            MafiaTiming.defaults.phaseHold +
            MafiaMotion.defaults.dramatic,
      );
    }
    await tester.pumpAndSettle();
    expect(phase(), GamePhase.discussion);
    expect(find.byType(PackBackdrop), findsWidgets);
  });
}
