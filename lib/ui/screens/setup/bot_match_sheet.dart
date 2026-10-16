import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/asset_constants.dart';
import '../../../data/player_profile.dart' show playerProfileProvider;
import '../../../engine/bots/bot_brain.dart';
import '../../../engine/models/enums.dart' show Role;
import '../../../engine/models/match_settings.dart';
import '../../../engine/models/player.dart' show PlayerGender;
import '../../../engine/presets.dart';
export '../../../data/bot_names.dart';
import '../../l10n_ext.dart';
import '../../theme/design_tokens.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/deck/card_fan.dart';
import '../../widgets/deck/deck_public.dart';
import '../../widgets/deck/seat_card.dart';
import 'optional_roles.dart';
import 'setup_draft.dart';
import 'role_rows.dart';

/// What the player picked for a table against bots.
typedef BotMatchPick = ({
  int players,
  MatchPreset preset,
  BotLevel level,
  Set<OptionalRole> roles,
});

const _minPlayers = 5;
const _maxPlayers = 12;

/// The split and the settings a [BotMatchPick] starts a match with. The bought
/// roles count only where the table can take them, so a pick made at one size
/// and left at another never builds a split the engine refuses.
extension BotMatchSetup on BotMatchPick {
  Set<OptionalRole> get effectiveRoles {
    final base = preset.roleCounts(players);
    return OptionalRole.usable(
      roles,
      players: players,
      mafia: base[Role.mafia] ?? 0,
      citizens: base[Role.citizen] ?? 0,
    );
  }

  Map<Role, int> get roleCounts =>
      OptionalRole.apply(preset.roleCounts(players), effectiveRoles);

  MatchSettings get settings =>
      OptionalRole.flags(preset.settings, effectiveRoles);

  /// The settings the match starts with: the player saved defaults (narration,
  /// audio, hold time, everything the preset does not speak for) with the
  /// preset shape of the game laid on top and the bought roles switched on.
  MatchSettings settingsOver(MatchSettings defaults) =>
      OptionalRole.flags(preset.applyTo(defaults), effectiveRoles);
}

/// «العب ضد الكمبيوتر»: table size, level, and the roles, in a dealt sheet.
Future<BotMatchPick?> showBotMatchSheet(BuildContext context) {
  final pick = ValueNotifier<BotMatchPick>((
    players: 8,
    preset: MatchPreset.classic,
    level: BotLevel.normal,
    roles: const <OptionalRole>{},
  ));
  return showDeckSheet<BotMatchPick>(
    context: context,
    title: context.l10n.modeBotsTitle,
    body: (_) => BotMatchBody(pick: pick),
    primary: Builder(
      builder: (context) => ValueListenableBuilder(
        valueListenable: pick,
        builder: (context, value, _) => BoneButton(
          key: BotMatchBody.startKey,
          label: context.l10n.botSheetStart,
          onPressed: () => Navigator.of(context).pop(value),
        ),
      ),
    ),
  );
}

/// The sheet's body, over the pick it edits.
class BotMatchBody extends ConsumerStatefulWidget {
  static const startKey = ValueKey('bot_match_start');
  static const minusKey = ValueKey('bot_players_minus');
  static const plusKey = ValueKey('bot_players_plus');
  static const tableKey = ValueKey('bot_table');
  static const rolesLineKey = ValueKey('bot_roles_line');
  static Key levelKey(BotLevel level) => ValueKey('bot_level_${level.name}');
  static Key presetKey(MatchPreset preset) =>
      ValueKey('bot_preset_${preset.name}');

  final ValueNotifier<BotMatchPick> pick;
  const BotMatchBody({super.key, required this.pick});

  @override
  ConsumerState<BotMatchBody> createState() => _BotMatchBodyState();
}

class _BotMatchBodyState extends ConsumerState<BotMatchBody> {
  bool _rolesOpen = false;

  BotMatchPick get _pick => widget.pick.value;

  /// Whether the narrator will speak: the saved defaults decide, not the
  /// preset, and a master mute silences it too.
  bool _narrated(BotMatchPick pick) {
    final s = pick.settingsOver(ref.watch(setupDraftProvider).settings);
    return s.narrationEnabled && !s.muteAllAudio;
  }

  void _set(BotMatchPick next) => widget.pick.value = next;

  /// Changes some of the pick, from what it is now (never from a stale build).
  void _with({
    int? players,
    MatchPreset? preset,
    BotLevel? level,
    Set<OptionalRole>? roles,
  }) => _set((
    players: players ?? _pick.players,
    preset: preset ?? _pick.preset,
    level: level ?? _pick.level,
    roles: roles ?? _pick.roles,
  ));

  void _resize(int players) {
    // «قاسية» is not offered below eight; a smaller table falls back.
    final preset = _pick.preset.availableFor(players)
        ? _pick.preset
        : MatchPreset.classic;
    _with(players: players, preset: preset);
  }

  @override
  void initState() {
    super.initState();
    widget.pick.addListener(_changed);
  }

  @override
  void dispose() {
    widget.pick.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final type = context.typography;
    final colors = context.colors;
    final pick = _pick;
    final base = pick.preset.roleCounts(pick.players);
    final gender =
        ref.watch(playerProfileProvider).valueOrNull?.gender ??
        PlayerGender.unspecified;

    final cards = <FanCard>[
      FanCard(
        id: 'you',
        front: true,
        lift: BotTokens.tableLift,
        child: _YouCard(gender: gender, label: l.botYou),
      ),
      for (var i = 1; i < pick.players; i++)
        FanCard(id: 'bot$i', child: const _BackCard()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l.botSheetBody,
          style: DeckTokens.meta(type).copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: s.md),
        Row(
          children: [
            Expanded(
              child: Text(
                l.botTableLabel,
                style: DeckTokens.meta(type).copyWith(color: DeckTokens.muted),
              ),
            ),
            RoleStepper(
              label: l.botTableLabel,
              value: pick.players,
              minusButtonKey: BotMatchBody.minusKey,
              plusButtonKey: BotMatchBody.plusKey,
              onMinus: pick.players > _minPlayers
                  ? () => _resize(_pick.players - 1)
                  : null,
              onPlus: pick.players < _maxPlayers
                  ? () => _resize(_pick.players + 1)
                  : null,
            ),
          ],
        ),
        KeyedSubtree(
          key: BotMatchBody.tableKey,
          child: CardFan(
            cards: cards,
            cardSize: BotTokens.tableCard,
            step: BotTokens.tableStep,
            height: BotTokens.tableHeight,
          ),
        ),
        SizedBox(height: s.md),
        Text(
          l.botSheetLevel,
          style: DeckTokens.meta(type).copyWith(color: DeckTokens.muted),
        ),
        SizedBox(height: s.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final v in BotLevel.values) ...[
                if (v != BotLevel.values.first)
                  const SizedBox(width: BotTokens.levelGap),
                Expanded(
                  child: _LevelCard(
                    key: BotMatchBody.levelKey(v),
                    face: switch (v) {
                      BotLevel.easy => AppImages.cardFaceCitizen,
                      BotLevel.normal => AppImages.cardFaceDetective,
                      BotLevel.hard => AppImages.cardFaceMafia,
                    },
                    name: switch (v) {
                      BotLevel.easy => l.botLevelEasy,
                      BotLevel.normal => l.botLevelNormal,
                      BotLevel.hard => l.botLevelHard,
                    },
                    hint: switch (v) {
                      BotLevel.easy => l.botLevelEasyHint,
                      BotLevel.normal => l.botLevelNormalHint,
                      BotLevel.hard => l.botLevelHardHint,
                    },
                    selected: pick.level == v,
                    onTap: () => _with(level: v),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: s.sm),
        InkWell(
          key: BotMatchBody.rolesLineKey,
          onTap: () => setState(() => _rolesOpen = !_rolesOpen),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: DeckTokens.chip),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    (_narrated(pick) ? l.botRolesLine : l.botRolesLineMuted)(
                      EngineCopy.presetName(l, pick.preset),
                    ),
                    textAlign: TextAlign.center,
                    style: DeckTokens.meta(
                      type,
                    ).copyWith(color: colors.textSecondary),
                  ),
                ),
                Icon(
                  _rolesOpen ? Icons.expand_less : Icons.expand_more,
                  size: DeckTokens.icon,
                  color: DeckTokens.silverLight,
                ),
              ],
            ),
          ),
        ),
        if (_rolesOpen) ...[
          SizedBox(height: s.sm),
          Wrap(
            spacing: s.sm,
            runSpacing: s.sm,
            children: [
              for (final p in MatchPreset.values)
                Opacity(
                  opacity: p.availableFor(pick.players)
                      ? 1
                      : DeckTokens.disabledAlpha,
                  child: IgnorePointer(
                    ignoring: !p.availableFor(pick.players),
                    child: DeckChip(
                      key: BotMatchBody.presetKey(p),
                      label: EngineCopy.presetName(l, p),
                      selected: pick.preset == p,
                      onSelected: (_) => _with(preset: p),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: s.xs),
          Text(
            EngineCopy.presetHint(l, pick.preset),
            style: type.caption.copyWith(color: DeckTokens.muted),
          ),
          SizedBox(height: s.md),
          Text(
            l.rolesMore,
            style: DeckTokens.meta(type).copyWith(color: DeckTokens.muted),
          ),
          SizedBox(height: s.sm),
          OptionalRoleRows(
            players: pick.players,
            mafia: base[Role.mafia] ?? 0,
            citizens: base[Role.citizen] ?? 0,
            selected: pick.effectiveRoles,
            onChanged: (role, on) => _with(
              roles: {..._pick.effectiveRoles}
                ..remove(role)
                ..addAll(on ? {role} : const <OptionalRole>{}),
            ),
          ),
        ],
      ],
    );
  }
}

/// Your card at the computer's table: your own portrait, «إنت» on it.
class _YouCard extends StatelessWidget {
  final PlayerGender gender;
  final String label;
  const _YouCard({required this.gender, required this.label});

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return SeatCardFrame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ResizeImage(
              AssetImage(SeatCard.defaultAvatar(gender)),
              height: (BotTokens.tableCard.height * dpr).round(),
              policy: ResizeImagePolicy.fit,
            ),
            fit: BoxFit.contain,
            alignment: Alignment.bottomCenter,
            gaplessPlayback: true,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: SeatTokens.inset),
              child: Text(
                label,
                maxLines: 1,
                style: DeckTokens.meta(context.typography).copyWith(
                  fontSize: BotTokens.youLabel,
                  height: 1.6,
                  color: DeckTokens.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A computer seat: the Mafia card's back.
class _BackCard extends StatelessWidget {
  const _BackCard();

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return SeatCardFrame(
      child: Image(
        image: ResizeImage(
          const AssetImage(AppImages.cardBack),
          width:
              (BotTokens.tableCard.width * dpr * DeckTokens.artDecodeHeadroom)
                  .round(),
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}

/// One level of the computer: a face, a name and how it plays. The chosen one
/// stands a little higher, with a bone rim.
class _LevelCard extends StatelessWidget {
  final String face;
  final String name;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  const _LevelCard({
    super.key,
    required this.face,
    required this.name,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.typography;
    final s = context.spacing;
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = BorderRadius.circular(context.radii.card);
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedSlide(
        offset: Offset(0, selected ? -BotTokens.levelLift : 0),
        duration: still ? Duration.zero : BotTokens.levelMove,
        curve: Curves.easeOutCubic,
        child: DeckPress(
          child: Material(
            color: colors.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: selected
                  ? const BorderSide(
                      color: DeckTokens.bone,
                      width: DeckTokens.selectedRim,
                    )
                  : BorderSide(
                      color: DeckTokens.bone.withValues(
                        alpha: DeckTokens.hairlineAlpha,
                      ),
                    ),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: radius),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(s.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArtWindow(
                      asset: face,
                      size: DeckTokens.windowList,
                      focus: ModeTokens.faceFocus,
                      zoom: ModeTokens.faceZoom,
                      dimmed: !selected,
                    ),
                    Text(
                      name,
                      style: DeckTokens.card(
                        type,
                      ).copyWith(color: colors.textPrimary),
                    ),
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: type.caption.copyWith(
                        color: selected
                            ? colors.textSecondary
                            : DeckTokens.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
