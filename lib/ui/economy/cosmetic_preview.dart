import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../platform/audio_director.dart';
import '../l10n_ext.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import 'cosmetic_paint.dart';
import 'cosmetics.dart';
import 'store_art.dart';

/// The real content of [code], drawn the way the table draws it. A preview is
/// the item itself, never a picture of a promise.
class CosmeticPreview extends StatelessWidget {
  final String code;

  /// The player's current frame/plate, so an identity preview shows the pair.
  final Map<String, String> equipped;
  const CosmeticPreview({
    super.key,
    required this.code,
    this.equipped = const {},
  });

  @override
  Widget build(BuildContext context) {
    final item = Cosmetics.items[code];
    if (item == null) return const SizedBox.shrink();
    final l = context.l10n;
    return switch (item.kind) {
      CosmeticKind.frame => Center(
        child: SeatPreview(
          name: l.previewSampleName,
          frame: code,
          plate: equipped['nameplate'],
        ),
      ),
      CosmeticKind.nameplate => Center(
        child: SeatPreview(
          name: l.previewSampleName,
          frame: equipped['frame'],
          plate: code,
        ),
      ),
      CosmeticKind.presentationPack => PackPreview(
        pack: Cosmetics.packs[code]!,
      ),
      CosmeticKind.narratorPack => NarratorPreview(
        narrator: Cosmetics.narrators[code]!,
      ),
      CosmeticKind.bundle => _BundlePreview(code: code),
    };
  }
}

/// A public backdrop dressed by the pack, its transition on demand, and its
/// opening and closing lines with their sounds.
class PackPreview extends ConsumerStatefulWidget {
  final PresentationPack pack;
  const PackPreview({super.key, required this.pack});

  static const Key transitionButton = ValueKey('preview_transition');
  static const Key introSoundButton = ValueKey('preview_intro_sound');

  @override
  ConsumerState<PackPreview> createState() => _PackPreviewState();
}

class _PackPreviewState extends ConsumerState<PackPreview> {
  int _runs = 0;
  bool _outro = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final pack = widget.pack;
    final line = _outro ? pack.outro(l) : pack.intro(l);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.card),
          child: SizedBox(
            height: CosmeticTokens.previewHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PackBackdrop(
                  pack: pack,
                  child: Image.asset(
                    AppCouncilArt.backdropDay,
                    fit: BoxFit.cover,
                  ),
                ),
                PackTransitionOverlay(pack: pack, trigger: _runs),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.all(s.sm),
                    child: NarrationCaption(text: line),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: s.sm),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.previewIntro)),
            ButtonSegment(value: true, label: Text(l.previewOutro)),
          ],
          selected: {_outro},
          onSelectionChanged: (v) => setState(() => _outro = v.single),
        ),
        Wrap(
          spacing: s.sm,
          children: [
            TextButton.icon(
              key: PackPreview.transitionButton,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(l.previewTransition),
              onPressed: () => setState(() => _runs++),
            ),
            TextButton.icon(
              key: PackPreview.introSoundButton,
              icon: const Icon(Icons.volume_up_outlined),
              label: Text(l.previewSound),
              onPressed: () => ref
                  .read(audioDirectorProvider)
                  .playAccent(_outro ? pack.outroSound : pack.introSound),
            ),
          ],
        ),
      ],
    );
  }
}

/// Every line the narrator says, in the order a match reaches them.
class NarratorPreview extends ConsumerWidget {
  final NarratorPack narrator;
  const NarratorPreview({super.key, required this.narrator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: StoreTokens.detailArtHeight,
          child: StoreProductArt(code: narrator.code),
        ),
        SizedBox(height: context.spacing.sm),
        for (final beat in NarrationBeat.values)
          Padding(
            padding: EdgeInsets.only(bottom: context.spacing.xs),
            child: NarrationCaption(text: narrator.line(l, beat)),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.volume_up_outlined),
            label: Text(l.previewSound),
            onPressed: () =>
                ref.read(audioDirectorProvider).playAccent(narrator.accent),
          ),
        ),
      ],
    );
  }
}

/// The collection's cover, then exactly what it grants, each with its own
/// art: the box is a theme, the list is the product.
class _BundlePreview extends StatelessWidget {
  final String code;
  const _BundlePreview({required this.code});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final contents = Cosmetics.bundles[code] ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: StoreTokens.detailArtHeight,
          child: StoreProductArt(code: code),
        ),
        SizedBox(height: s.sm),
        Text(
          l.storeInside,
          style: context.typography.title.copyWith(
            color: context.colors.textPrimary,
          ),
        ),
        for (final part in contents)
          Padding(
            padding: EdgeInsets.only(top: s.sm),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: StoreTokens.thumbnail,
                  child: StoreProductArt(code: part),
                ),
                SizedBox(width: s.sm),
                Expanded(
                  child: Text(
                    Cosmetics.items[part]?.name(l) ?? part,
                    style: context.typography.body,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
