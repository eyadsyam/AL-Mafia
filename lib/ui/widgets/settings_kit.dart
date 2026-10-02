import 'package:flutter/material.dart';

import '../../platform/reduce_motion.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';

/// One look for every settings surface in the app — the general settings
/// from Home, the offline match setup, and the online room settings
/// (owner, 2026-09-24: «صحح وأعد تشكيل شاشة الإعدادات… والأونلاين برضو»).
///
/// ## The pieces
///
/// * [SettingsPanel] — a raised card with an icon badge and a title. Each
///   group of related settings is one panel, so a host scanning the screen
///   reads six headings rather than twenty rows.
/// * [SettingsSwitchRow] — a genuine on/off. The whole row is the target.
/// * [SettingsSegments] — a choice between a few named values: times, modes,
///   the language. One track with a gold thumb that slides to the choice.
/// * [SettingsLinkRow] — opens something else (help, store, a document).
///
/// Every row keeps its sentence of description. Doc 14 Part 5: *"a setting
/// nobody understands is a setting nobody uses."*
class SettingsPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  /// Hairlines between rows. Off for a panel of links, some of which may
  /// render nothing on a given build (a store that is not configured).
  final bool divided;

  const SettingsPanel({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
    this.divided = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;

    return Container(
      margin: EdgeInsets.only(bottom: spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radii.card),
        border: Border.all(color: colors.borderSubtle),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              colors.accentGold.withValues(alpha: SettingsTokens.panelGlow),
              colors.surfaceRaised,
            ),
            colors.surfaceRaised,
          ],
        ),
        boxShadow: context.elevation.level1,
      ),
      padding: EdgeInsets.fromLTRB(
        spacing.md,
        spacing.md,
        spacing.md,
        spacing.sm,
      ),
      // The rows' ink belongs on the panel, not on a Material under it.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SettingsBadge(icon: icon),
                SizedBox(width: spacing.sm + spacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: type.title.copyWith(color: colors.textPrimary),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: type.caption.copyWith(color: colors.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing.sm),
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0 && divided)
                Divider(color: colors.borderSubtle, height: spacing.sm + 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// A gold icon in a softly lit round well.
class SettingsBadge extends StatelessWidget {
  final IconData icon;
  final bool small;

  const SettingsBadge({super.key, required this.icon, this.small = false});

  @override
  Widget build(BuildContext context) => SettingsBadgeFrame(
    small: small,
    child: Icon(
      icon,
      size: small ? SettingsTokens.linkIconSize : SettingsTokens.iconSize,
      color: context.colors.accentGold,
    ),
  );
}

/// The round well itself, for a badge that is not an icon (the coin).
class SettingsBadgeFrame extends StatelessWidget {
  final Widget child;
  final bool small;

  const SettingsBadgeFrame({super.key, required this.child, this.small = true});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = small ? SettingsTokens.linkBadge : SettingsTokens.iconBadge;
    final wash = colors.accentGold.withValues(alpha: SettingsTokens.badgeWash);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: wash,
        border: Border.all(color: wash),
      ),
      child: child,
    );
  }
}

/// The label and its sentence, with an optional pill after the label.
class _Label extends StatelessWidget {
  final String label;
  final String? hint;
  final String? pill;
  final bool enabled;

  const _Label({
    required this.label,
    this.hint,
    this.pill,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: spacing.sm,
          runSpacing: spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              label,
              style: type.body.copyWith(
                color: enabled ? colors.textPrimary : colors.textMuted,
              ),
            ),
            if (pill != null) SettingsPill(text: pill!),
          ],
        ),
        if (hint != null && hint!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              hint!,
              style: type.caption.copyWith(color: colors.textMuted),
            ),
          ),
      ],
    );
  }
}

/// A small gold-washed tag — «في الأونلاين بس».
class SettingsPill extends StatelessWidget {
  final String text;
  const SettingsPill({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.sm,
        vertical: spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: colors.accentGold.withValues(alpha: SettingsTokens.badgeWash),
        borderRadius: BorderRadius.circular(context.radii.button),
      ),
      child: Text(
        text,
        style: context.typography.caption.copyWith(color: colors.accentGold),
      ),
    );
  }
}

/// A genuine on/off. The whole row toggles; [switchKey] names the switch.
class SettingsSwitchRow extends StatelessWidget {
  final Key? switchKey;
  final String label;
  final String? hint;
  final String? pill;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchRow({
    super.key,
    this.switchKey,
    required this.label,
    this.hint,
    this.pill,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return InkWell(
      borderRadius: BorderRadius.circular(context.radii.button),
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Row(
          children: [
            Expanded(
              child: _Label(
                label: label,
                hint: hint,
                pill: pill,
                enabled: onChanged != null,
              ),
            ),
            SizedBox(width: spacing.sm),
            Switch(key: switchKey, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// One option of a [SettingsSegments].
typedef SettingsOption<T> = (T value, String label, Key? key);

/// A choice between a few named values, on one track with a sliding thumb.
class SettingsSegments<T> extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? pill;
  final T value;
  final List<SettingsOption<T>> options;

  /// Null disables every option (e.g. while a change is being saved).
  final ValueChanged<T>? onChanged;

  const SettingsSegments({
    super.key,
    this.label,
    this.hint,
    this.pill,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final radii = context.radii;
    final type = context.typography;
    final motion = context.motion;
    final reduced = ReduceMotion.of(context);

    final index = options.indexWhere((o) => o.$1 == value);
    final n = options.length;
    final x = n <= 1 || index < 0 ? 0.0 : -1 + 2 * index / (n - 1);
    final duration = reduced ? Duration.zero : motion.standard;
    const inset = SettingsTokens.segmentInset;
    final thumbRadius = BorderRadius.circular(radii.button - inset);

    final track = Container(
      constraints: const BoxConstraints(
        minHeight: SettingsTokens.segmentHeight,
      ),
      // No padding here: each option's hit area runs the full track height
      // (the 48 dp target); only the lit thumb keeps the inset.
      decoration: BoxDecoration(
        color: colors.surfaceBase,
        borderRadius: BorderRadius.circular(radii.button),
        border: Border.all(color: colors.borderSubtle),
      ),
      // Ink is painted by the nearest Material, which is otherwise *under*
      // this track's fill; a transparent one here keeps the ripple visible.
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            if (index >= 0)
              Positioned.fill(
                child: AnimatedAlign(
                  alignment: AlignmentDirectional(x, 0),
                  duration: duration,
                  curve: motion.standardCurve,
                  child: FractionallySizedBox(
                    widthFactor: 1 / n,
                    heightFactor: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(inset),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.accentGold,
                          borderRadius: thumbRadius,
                          boxShadow: context.elevation.level1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                for (final (option, text, key) in options)
                  Expanded(
                    child: SettingsSegment(
                      key: key,
                      label: text,
                      selected: option == value,
                      radius: thumbRadius,
                      onTap: onChanged == null || option == value
                          ? null
                          : () => onChanged!(option),
                      style: type.body,
                      duration: duration,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (label == null) return track;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Label(label: label!, hint: hint, pill: pill),
          SizedBox(height: spacing.sm),
          track,
        ],
      ),
    );
  }
}

/// One tappable option on a [SettingsSegments] track. Public so a test can
/// ask which option is lit without reading colours.
class SettingsSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final BorderRadius radius;
  final TextStyle style;
  final Duration duration;

  const SettingsSegment({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.radius,
    required this.style,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: SettingsTokens.segmentHeight,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.xs,
              vertical: spacing.sm,
            ),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: duration,
                style: style.copyWith(
                  color: selected ? colors.surfaceBase : colors.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : style.fontWeight,
                ),
                textAlign: TextAlign.center,
                child: Text(label, maxLines: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens something else: help, the store, a document.
class SettingsLinkRow extends StatelessWidget {
  final IconData? icon;
  final Widget? leading;
  final String label;
  final String? hint;
  final VoidCallback? onTap;

  const SettingsLinkRow({
    super.key,
    this.icon,
    this.leading,
    required this.label,
    this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    return InkWell(
      borderRadius: BorderRadius.circular(context.radii.button),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: Row(
          children: [
            leading ??
                SettingsBadge(icon: icon ?? Icons.circle_outlined, small: true),
            SizedBox(width: spacing.sm + spacing.xs),
            Expanded(
              child: _Label(label: label, hint: hint),
            ),
            Icon(Icons.chevron_right, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}

/// A quiet heading between groups of panels.
class SettingsHeading extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SettingsHeading({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final spacing = context.spacing;
    final type = context.typography;
    return Padding(
      padding: EdgeInsets.only(
        top: spacing.sm,
        bottom: spacing.sm + spacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: type.headline.copyWith(color: colors.accentGold)),
          if (subtitle != null)
            Padding(
              padding: EdgeInsets.only(top: spacing.xs),
              child: Text(
                subtitle!,
                style: type.caption.copyWith(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}
