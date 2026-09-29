import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/asset_constants.dart';
import '../../../../engine/models/enums.dart' show Role;
import '../../../../transport/game_snapshot.dart';
import '../../../../transport/witness_channel.dart';
import '../../../economy/vault_kit.dart';
import '../../../l10n_ext.dart';
import '../../../theme/design_tokens.dart';
import '../../../theme/mafia_theme.dart';
import '../../../widgets/motion_sprite.dart';
import '../../../../platform/reduce_motion.dart';
import '../council/role_glyph.dart';
import 'witness_panel.dart';

/// What the dead see, on the table they were playing at (owner, 2026-09-28).
///
/// There is no witness screen and no side panel any more. An eliminated player
/// keeps the council they sat at: every seat wears its character's face, and
/// whatever happens arrives *on the table* — a light that flies from one seat
/// to another, a line of news under the header, a mark left on the seat it
/// happened to. Tapping a seat opens its dossier; tapping a sealed letter opens
/// the whisper. Everything else (the graveyard chat, your own record) opens
/// from the dock where the hand used to be.
///
/// Doc 05 is unchanged by any of this: the server answers `witness_view` only
/// to an eliminated seat, and nothing in this file is built for anybody else.

/// One thing that happened, as the dead are told about it.
class WitnessNews {
  final String id;
  final int fromSeat;
  final int toSeat;
  final WitnessAction? action;
  final WitnessWhisper? whisper;

  const WitnessNews._({
    required this.id,
    required this.fromSeat,
    required this.toSeat,
    this.action,
    this.whisper,
  });

  factory WitnessNews.action(WitnessAction a) => WitnessNews._(
    id: actionId(a),
    fromSeat: a.seat,
    toSeat: a.targetSeat,
    action: a,
  );

  factory WitnessNews.whisper(WitnessWhisper w) => WitnessNews._(
    id: 'w:${w.id}',
    fromSeat: w.fromSeat,
    toSeat: w.toSeat,
    whisper: w,
  );

  /// Night choices carry no id of their own; the choice is its identity.
  static String actionId(WitnessAction a) =>
      'a:${a.night}:${a.seat}:${a.action}:${a.targetSeat}';
}

/// What is new in [after] that [before] did not have, oldest first.
///
/// The first table a witness reads is the past, not news: it is already drawn
/// on the seats, and replaying it as a burst of lines would bury the one that
/// matters. So a null [before] yields nothing.
List<WitnessNews> witnessNewsSince(WitnessTable? before, WitnessTable after) {
  if (before == null) return const [];
  final seenActions = {for (final a in before.actions) WitnessNews.actionId(a)};
  final seenWhispers = {for (final w in before.whispers) w.id};
  return [
    for (final a in after.actions)
      if (!seenActions.contains(WitnessNews.actionId(a))) WitnessNews.action(a),
    for (final w in after.whispers)
      if (!seenWhispers.contains(w.id)) WitnessNews.whisper(w),
  ];
}

/// The mark each seat carries for the dead: a wax seal where an unopened
/// whisper landed today, else the mark of tonight's latest choice aimed at it.
Map<int, Widget> witnessSeatMarks({
  required GameSnapshot snapshot,
  required WitnessTable? table,
  required Set<String> opened,
  required ValueChanged<WitnessWhisper> onOpenLetter,
  required ValueChanged<int> onOpenSeat,
}) {
  if (table == null) return const {};
  final marks = <int, Widget>{};
  for (final a in table.actions.where((a) => a.night == snapshot.dayNumber)) {
    final role = table.roles[a.seat];
    if (role == null) continue;
    marks[a.targetSeat] = WitnessSeatMark(
      key: ValueKey('witness_mark_${a.targetSeat}'),
      glyph: glyphFor(role),
      hostile: a.action == 'kill',
      onTap: () => onOpenSeat(a.targetSeat),
    );
  }
  for (final w in table.whispers) {
    if (w.day != snapshot.dayNumber || opened.contains(w.id)) continue;
    marks[w.toSeat] = WitnessSeatMark(
      key: ValueKey('witness_letter_${w.id}'),
      sealed: true,
      onTap: () => onOpenLetter(w),
    );
  }
  return marks;
}

/// A small enamel disc on a seat's shoulder.
class WitnessSeatMark extends StatelessWidget {
  final String? glyph;
  final bool sealed;
  final bool hostile;
  final VoidCallback onTap;

  const WitnessSeatMark({
    super.key,
    required this.onTap,
    this.glyph,
    this.sealed = false,
    this.hostile = false,
  });

  @override
  Widget build(BuildContext context) {
    final rim = hostile ? VaultTokens.oxbloodLight : VaultTokens.gold;
    final disc = Container(
      width: CouncilTokens.witnessBadge,
      height: CouncilTokens.witnessBadge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VaultTokens.enamel,
        border: Border.all(color: rim, width: VaultTokens.chipRim),
        boxShadow: [
          BoxShadow(
            color: rim.withValues(alpha: VaultTokens.litGlowAlpha * 2),
            blurRadius: VaultTokens.litGlowBlur / 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: sealed
          ? Image.asset(
              AppCouncilArt.whisperSeal,
              width: CouncilTokens.witnessBadge,
              height: CouncilTokens.witnessBadge,
              excludeFromSemantics: true,
            )
          : ImageIcon(
              AssetImage(glyph!),
              size: CouncilTokens.witnessBadgeIcon,
              color: rim,
            ),
    );
    return Semantics(
      button: true,
      label: sealed ? context.l10n.witnessLetterOpen : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: sealed ? _Beat(child: disc) : disc,
      ),
    );
  }
}

/// A sealed letter breathes until it is opened. Still under reduced motion.
class _Beat extends StatefulWidget {
  final Widget child;
  const _Beat({required this.child});

  @override
  State<_Beat> createState() => _BeatState();
}

class _BeatState extends State<_Beat> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: VaultTokens.glint,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ReduceMotion.of(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      unawaited(_c.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(
      begin: 1,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

/// The line of news under the header: two faces, the arrow between them, the
/// sentence. One at a time; the flow feeds the queue.
class WitnessNewsLine extends StatelessWidget {
  final WitnessNews news;
  final WitnessTable table;
  final Map<int, String> names;
  final VoidCallback? onTap;

  static const Key key_ = ValueKey('witness_news');

  const WitnessNewsLine({
    super.key,
    required this.news,
    required this.table,
    required this.names,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.typography;
    final spacing = context.spacing;
    final from = names[news.fromSeat] ?? '';
    final to = names[news.toSeat] ?? '';
    final action = news.action;
    final line = action == null
        ? l10n.witnessWhisperLine(from, to)
        : witnessActionLine(context, action, from, to);
    final hostile = action?.action == 'kill';
    return GestureDetector(
      key: key_,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: VaultCard(
        lit: true,
        padding: EdgeInsets.symmetric(
          horizontal: spacing.md,
          vertical: spacing.sm,
        ),
        children: [
          Row(
            children: [
              _Face(role: table.roles[news.fromSeat]),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: spacing.xs),
                child: news.whisper != null
                    ? Image.asset(
                        AppCouncilArt.whisperSeal,
                        width: CouncilTokens.witnessBadge,
                        height: CouncilTokens.witnessBadge,
                        excludeFromSemantics: true,
                      )
                    : Icon(
                        Icons.east_rounded,
                        textDirection: Directionality.of(context),
                        size: CouncilTokens.witnessBadgeIcon,
                        color: hostile
                            ? VaultTokens.oxbloodLight
                            : VaultTokens.gold,
                      ),
              ),
              _Face(role: table.roles[news.toSeat]),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodySmall.emphasised.copyWith(
                    color: hostile
                        ? VaultTokens.oxbloodLight
                        : VaultTokens.goldLight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String witnessActionLine(
  BuildContext context,
  WitnessAction a,
  String actor,
  String target,
) {
  final l10n = context.l10n;
  return switch (a.action) {
    'kill' => l10n.witnessActionKill(actor, target),
    'protect' => l10n.witnessActionProtect(actor, target),
    'investigate' => l10n.witnessActionInvestigate(actor, target),
    _ => l10n.witnessActionSuspect(actor, target),
  };
}

class _Face extends StatelessWidget {
  final Role? role;
  final double size;
  const _Face({required this.role, this.size = CouncilTokens.witnessNewsFace});

  @override
  Widget build(BuildContext context) {
    final role = this.role;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: VaultTokens.enamel,
        border: Border.all(
          color: VaultTokens.gold.withValues(alpha: 0.8),
          width: VaultTokens.chipRim,
        ),
      ),
      child: role == null
          ? null
          : Padding(
              padding: const EdgeInsets.all(VaultTokens.chipRim),
              child: RoleFace(role: role, size: size),
            ),
    );
  }
}

/// A panel that rises inside the scene, over a dimmed table. Doc 12 §2.1: no
/// route and no dialog; the flow owns one nullable piece of state per popup.
class WitnessPopup extends StatelessWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final bool fill;

  static const Key scrim = ValueKey('witness_popup_scrim');

  const WitnessPopup({
    super.key,
    required this.child,
    required this.onDismiss,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final height =
        MediaQuery.sizeOf(context).height * CouncilTokens.witnessPopupMaxHeight;
    // Transparent Material: the graveyard's text field and the report
    // button need one, and the table flow is not inside a Scaffold.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: scrim,
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: ColoredBox(
                color: colors.surfaceBase.withValues(alpha: 0.72),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: ReduceMotion.of(context)
                      ? Duration.zero
                      : context.motion.band,
                  curve: context.motion.standardCurve,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * spacing.xl),
                      child: child,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: height),
                    child: fill
                        ? SizedBox(height: height, child: child)
                        : child,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A whisper, opened: the seal, who to whom, the words, and the flag.
class WitnessLetter extends StatefulWidget {
  final WitnessWhisper whisper;
  final WitnessTable table;
  final Map<int, String> names;
  final WitnessChannel? channel;

  static const Key report = ValueKey('witness_letter_report');

  const WitnessLetter({
    super.key,
    required this.whisper,
    required this.table,
    required this.names,
    this.channel,
  });

  @override
  State<WitnessLetter> createState() => _WitnessLetterState();
}

class _WitnessLetterState extends State<WitnessLetter> {
  bool _reported = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.typography;
    final spacing = context.spacing;
    final colors = context.colors;
    final w = widget.whisper;
    return VaultCard(
      lit: true,
      mainAxisSize: MainAxisSize.min,
      tag: l10n.witnessWhispersTitle,
      children: [
        Row(
          children: [
            _Face(role: widget.table.roles[w.fromSeat]),
            SizedBox(width: spacing.xs),
            // The seal presses down as the letter opens, then stays.
            MotionSprite(
              AppMotion.waxSealStamp,
              width: CouncilTokens.witnessSeal,
              once: MotionTokens.sealLength,
              after: Image.asset(
                AppCouncilArt.whisperSeal,
                width: CouncilTokens.witnessSeal,
                height: CouncilTokens.witnessSeal,
                excludeFromSemantics: true,
              ),
            ),
            SizedBox(width: spacing.xs),
            _Face(role: widget.table.roles[w.toSeat]),
            SizedBox(width: spacing.sm),
            Expanded(
              child: Text(
                l10n.witnessWhisperLine(
                  widget.names[w.fromSeat] ?? '',
                  widget.names[w.toSeat] ?? '',
                ),
                style: type.body.emphasised.copyWith(
                  color: VaultTokens.goldLight,
                ),
              ),
            ),
          ],
        ),
        const VaultDivider(),
        // Plain Text: markup in a message renders as the characters it is.
        Text(
          w.masked ? l10n.witnessWhisperMasked : w.text ?? '',
          style: (w.masked ? type.body : type.title).copyWith(
            color: w.masked ? colors.textMuted : colors.textPrimary,
          ),
        ),
        SizedBox(height: spacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _reported
              ? ClaimedMark(l10n.witnessWhisperReported)
              : TextButton.icon(
                  key: WitnessLetter.report,
                  style: vaultOutlineStyle(context),
                  onPressed: () async {
                    final done =
                        await widget.channel?.reportWhisper(w.id) ?? false;
                    if (done && mounted) setState(() => _reported = true);
                  },
                  icon: const Icon(Icons.flag_outlined),
                  label: Text(l10n.witnessWhisperReport),
                ),
        ),
      ],
    );
  }
}

/// One seat, opened: the character, the name, tonight's choices to and from
/// it, and today's whispers.
class WitnessDossier extends StatelessWidget {
  final int seat;
  final GameSnapshot snapshot;
  final WitnessTable table;
  final ValueChanged<WitnessWhisper> onOpenLetter;
  final VoidCallback? onManage;

  const WitnessDossier({
    super.key,
    required this.seat,
    required this.snapshot,
    required this.table,
    required this.onOpenLetter,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final type = context.typography;
    final spacing = context.spacing;
    final colors = context.colors;
    final names = {for (final p in snapshot.public.players) p.seat: p.name};
    final role = table.roles[seat];
    final night = snapshot.dayNumber;
    final choices = table.actions
        .where(
          (a) => a.night == night && (a.seat == seat || a.targetSeat == seat),
        )
        .toList();
    final whispers = table.whispers
        .where(
          (w) =>
              w.day == snapshot.dayNumber &&
              (w.fromSeat == seat || w.toSeat == seat),
        )
        .toList();
    return VaultCard(
      lit: true,
      mainAxisSize: MainAxisSize.min,
      children: [
        VaultHeading(
          leading: LampGlow(
            child: _Face(role: role, size: CouncilTokens.witnessDossierFace),
          ),
          title: names[seat] ?? '',
          subtitle: role == null ? null : EngineCopy.roleName(l10n, role),
          titleColor: VaultTokens.goldLight,
        ),
        const VaultDivider(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              if (choices.isEmpty && whispers.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: spacing.sm),
                  child: Text(
                    l10n.witnessSeatQuiet,
                    textAlign: TextAlign.center,
                    style: type.bodySmall.copyWith(color: colors.textMuted),
                  ),
                ),
              if (choices.isNotEmpty) ...[
                Text(
                  l10n.witnessNightTitle,
                  style: type.caption.copyWith(color: VaultTokens.gold),
                ),
                for (final a in choices)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: spacing.xs),
                    child: Row(
                      children: [
                        ImageIcon(
                          AssetImage(
                            glyphFor(table.roles[a.seat] ?? Role.citizen),
                          ),
                          size: CouncilTokens.witnessBadgeIcon,
                          color: a.action == 'kill'
                              ? VaultTokens.oxbloodLight
                              : VaultTokens.gold,
                        ),
                        SizedBox(width: spacing.sm),
                        Expanded(
                          child: Text(
                            witnessActionLine(
                              context,
                              a,
                              names[a.seat] ?? '',
                              names[a.targetSeat] ?? '',
                            ),
                            style: type.body.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (whispers.isNotEmpty) ...[
                SizedBox(height: spacing.sm),
                Text(
                  l10n.witnessWhispersTitle,
                  style: type.caption.copyWith(color: VaultTokens.gold),
                ),
                for (final w in whispers)
                  InkWell(
                    key: WitnessPanel.whisper(w.id),
                    onTap: () => onOpenLetter(w),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: spacing.xs),
                      child: Row(
                        children: [
                          Image.asset(
                            AppCouncilArt.whisperSeal,
                            width: CouncilTokens.witnessBadge,
                            height: CouncilTokens.witnessBadge,
                            excludeFromSemantics: true,
                          ),
                          SizedBox(width: spacing.sm),
                          Expanded(
                            child: Text(
                              l10n.witnessWhisperLine(
                                names[w.fromSeat] ?? '',
                                names[w.toSeat] ?? '',
                              ),
                              style: type.body.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (onManage != null) ...[
          SizedBox(height: spacing.sm),
          TextButton.icon(
            style: vaultOutlineStyle(context),
            onPressed: onManage,
            icon: const Icon(Icons.shield_outlined),
            label: Text(l10n.witnessManageSeat),
          ),
        ],
      ],
    );
  }
}

/// Where the hand was: the graveyard chat and your own record.
class WitnessDock extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onRecord;
  final int unread;

  static const Key chat = ValueKey('witness_dock_chat');
  static const Key record = ValueKey('witness_dock_record');

  const WitnessDock({
    super.key,
    required this.onChat,
    required this.onRecord,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    Widget button(Key key, IconData icon, String label, VoidCallback onTap) =>
        Expanded(
          child: VaultPress(
            child: TextButton.icon(
              key: key,
              style: vaultOutlineStyle(context),
              onPressed: onTap,
              icon: Icon(icon),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        );
    return Center(
      child: Row(
        children: [
          button(
            chat,
            unread > 0 ? Icons.mark_chat_unread_outlined : Icons.forum_outlined,
            l10n.witnessTabChat,
            onChat,
          ),
          SizedBox(width: spacing.sm),
          button(
            record,
            Icons.history_edu_outlined,
            l10n.witnessTabRecord,
            onRecord,
          ),
        ],
      ),
    );
  }
}
