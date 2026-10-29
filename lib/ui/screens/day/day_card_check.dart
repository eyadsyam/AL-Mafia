import 'package:flutter/material.dart';

import '../../../app/asset_constants.dart';
import '../../../engine/models/enums.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/card_art.dart';
import '../../widgets/pass_screen.dart';
import '../match_controller.dart';

Future<void> showDayCardCheck(
  BuildContext context, {
  required MatchController controller,
  required int seat,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _DayCardCheckScreen(controller: controller, seat: seat),
  ),
);

class _DayCardCheckScreen extends StatefulWidget {
  final MatchController controller;
  final int seat;
  const _DayCardCheckScreen({required this.controller, required this.seat});

  @override
  State<_DayCardCheckScreen> createState() => _DayCardCheckScreenState();
}

class _DayCardCheckScreenState extends State<_DayCardCheckScreen> {
  RoleRevealPayload? _card;

  Future<void> _open() async {
    final card = await widget.controller.cardCheck(widget.seat);
    if (mounted) setState(() => _card = card);
  }

  String _face(Role role) => switch (role) {
    Role.mafia => AppImages.cardFaceMafia,
    Role.silencer => AppImages.cardFaceSilencer,
    Role.doctor => AppImages.cardFaceDoctor,
    Role.detective => AppImages.cardFaceDetective,
    Role.elder => AppImages.cardFaceElder,
    Role.sniper => AppImages.cardFaceSniper,
    Role.citizen => AppImages.cardFaceCitizen,
  };

  @override
  Widget build(BuildContext context) {
    final card = _card;
    final players = widget.controller.snapshot.public.players;
    if (card == null) {
      return PassScreen(
        targetName: players[widget.seat].name,
        subtitle: context.l10n.myCard,
        onConfirmed: _open,
      );
    }

    final spacing = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    final alreadyRevealed = widget.controller.snapshot.revealedElderSeats
        .contains(widget.seat);
    return Scaffold(
      backgroundColor: colors.surfaceBase,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(spacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              Expanded(
                child: CardArt(
                  image: _face(card.role),
                  radius: context.radii.card,
                ),
              ),
              SizedBox(height: spacing.md),
              Text(
                EngineCopy.roleName(context.l10n, card.role),
                style: type.title.copyWith(color: colors.textPrimary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.xs),
              Text(
                EngineCopy.roleDescription(context.l10n, card.role),
                style: type.body.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing.md),
              SizedBox(
                height: spacing.xxl,
                child: card.role == Role.elder
                    ? FilledButton(
                        onPressed: alreadyRevealed
                            ? null
                            : () async {
                                await widget.controller.revealElder(
                                  widget.seat,
                                );
                                if (context.mounted)
                                  Navigator.of(context).pop();
                              },
                        child: Text(
                          alreadyRevealed
                              ? context.l10n.elderRevealedMark
                              : context.l10n.elderRevealAction,
                        ),
                      )
                    : const SizedBox.expand(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
