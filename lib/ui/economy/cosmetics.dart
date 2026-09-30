import 'package:flutter/material.dart';

import '../../app/asset_constants.dart';
import '../../app/l10n/app_localizations.dart';
import '../../engine/models/enums.dart' show GamePhase;
import '../theme/design_tokens.dart';

/// What the store sells: presentation only (docs/CLAUDE-UX-ECONOMY-NEXT.md
/// §89). Nothing in this file can change a rule, a vote, a role or an outcome,
/// and the engine never imports it.
///
/// The server's catalog decides what is on sale and at what price; this file
/// decides how each code looks and sounds. A code the server lists but this
/// build cannot draw is not shown (an older app never offers content it
/// cannot deliver), and a code this build knows but the server does not list
/// is not for sale.
enum CosmeticKind { frame, nameplate, presentationPack, narratorPack, bundle }

enum CosmeticSlot { frame, nameplate, roomPack, narrator }

extension CosmeticSlotWire on CosmeticSlot {
  String get wire => switch (this) {
    CosmeticSlot.frame => 'frame',
    CosmeticSlot.nameplate => 'nameplate',
    CosmeticSlot.roomPack => 'room_pack',
    CosmeticSlot.narrator => 'narrator',
  };
}

/// The public beats a narrator or a pack may mark. None of them is private:
/// the night beat is shown to every device at once, in neutral colours.
enum NarrationBeat { night, morning, discussion, voting, result }

/// A frame: its drawn art ([artCode], whose empty centre is [aperture] of the
/// image width), and the vector rings drawn only if the art cannot load.
@immutable
class FrameStyle {
  final Color outer;
  final Color inner;
  final String artCode;
  final double aperture;
  const FrameStyle(this.outer, this.inner, this.artCode, this.aperture);
}

/// A nameplate: its drawn art, whose ornamented ends are [cap] of the width
/// and whose flat field is [field] of the height, the name colour [onArt] on
/// that field, and the vector plate drawn only if the art cannot load.
@immutable
class PlateStyle {
  final Color fill;
  final Color border;
  final Color text;
  final String artCode;
  final double cap;
  final double field;
  final Color onArt;
  const PlateStyle(
    this.fill,
    this.border,
    this.text,
    this.artCode, {
    required this.cap,
    required this.field,
    required this.onArt,
  });
}

enum PackTransition { candle, sweep, moonlight }

@immutable
class PresentationPack {
  final String code;
  final List<double> grade;
  final Color veil;
  final String overlay;
  final PackTransition transition;
  final String introSound;
  final String outroSound;
  final String Function(AppLocalizations) intro;
  final String Function(AppLocalizations) outro;
  const PresentationPack({
    required this.code,
    required this.grade,
    required this.veil,
    required this.overlay,
    required this.transition,
    required this.introSound,
    required this.outroSound,
    required this.intro,
    required this.outro,
  });
}

/// How a narrator pack's line looks: its own ground, rule, ink, type and the
/// marker drawn beside every line. The spoken voice (F16) is one free voice
/// for everybody; a pack is its words and this look, never a voice.
@immutable
class NarratorLook {
  final Color ground;
  final Color rule;
  final Color ink;
  final bool italic;
  final IconData marker;

  /// The marker's art, once the build bundles it (see `RasterOr`); [marker]
  /// stays the fallback (and the only option) until then.
  final String? markerAsset;
  const NarratorLook({
    required this.ground,
    required this.rule,
    required this.ink,
    required this.italic,
    required this.marker,
    this.markerAsset,
  });
}

@immutable
class NarratorPack {
  final String code;
  final String accent;
  final String Function(AppLocalizations, NarrationBeat) line;
  final NarratorLook look;
  const NarratorPack({
    required this.code,
    required this.accent,
    required this.line,
    required this.look,
  });
}

@immutable
class CosmeticItem {
  final String code;
  final CosmeticKind kind;
  final CosmeticSlot? slot;
  final String Function(AppLocalizations) name;
  final String Function(AppLocalizations) description;
  const CosmeticItem({
    required this.code,
    required this.kind,
    required this.slot,
    required this.name,
    required this.description,
  });
}

String _storyteller(AppLocalizations l, NarrationBeat beat) => switch (beat) {
  NarrationBeat.night => l.narratorNight,
  NarrationBeat.morning => l.narratorMorning,
  NarrationBeat.discussion => l.narratorDiscussion,
  NarrationBeat.voting => l.narratorVoting,
  NarrationBeat.result => l.narratorResult,
};

// Every narrator speaks only to the beat itself: never who died, who is
// suspected or how the vote went. The same line reaches every device.
String _keeper(AppLocalizations l, NarrationBeat beat) => switch (beat) {
  NarrationBeat.night => l.narratorKeeperNight,
  NarrationBeat.morning => l.narratorKeeperMorning,
  NarrationBeat.discussion => l.narratorKeeperDiscussion,
  NarrationBeat.voting => l.narratorKeeperVoting,
  NarrationBeat.result => l.narratorKeeperResult,
};

String _noir(AppLocalizations l, NarrationBeat beat) => switch (beat) {
  NarrationBeat.night => l.narratorNoirNight,
  NarrationBeat.morning => l.narratorNoirMorning,
  NarrationBeat.discussion => l.narratorNoirDiscussion,
  NarrationBeat.voting => l.narratorNoirVoting,
  NarrationBeat.result => l.narratorNoirResult,
};

abstract final class Cosmetics {
  static final Map<String, CosmeticItem> items = {
    for (final item in <CosmeticItem>[
      CosmeticItem(
        code: 'frame_gilded',
        kind: CosmeticKind.frame,
        slot: CosmeticSlot.frame,
        name: (l) => l.cosmeticFrameGilded,
        description: (l) => l.cosmeticFrameGildedDesc,
      ),
      CosmeticItem(
        code: 'frame_crimson',
        kind: CosmeticKind.frame,
        slot: CosmeticSlot.frame,
        name: (l) => l.cosmeticFrameCrimson,
        description: (l) => l.cosmeticFrameCrimsonDesc,
      ),
      CosmeticItem(
        code: 'frame_moonlit',
        kind: CosmeticKind.frame,
        slot: CosmeticSlot.frame,
        name: (l) => l.cosmeticFrameMoonlit,
        description: (l) => l.cosmeticFrameMoonlitDesc,
      ),
      // The Starter Bundle's own frame: sold nowhere else, drawn in code.
      CosmeticItem(
        code: 'frame_council_seal',
        kind: CosmeticKind.frame,
        slot: CosmeticSlot.frame,
        name: (l) => l.cosmeticFrameSeal,
        description: (l) => l.cosmeticFrameSealDesc,
      ),
      // Earned by settling ten referrals; never listed for coin purchase.
      CosmeticItem(
        code: 'frame_invite',
        kind: CosmeticKind.frame,
        slot: CosmeticSlot.frame,
        name: (l) => l.cosmeticFrameInvite,
        description: (l) => l.cosmeticFrameInviteDesc,
      ),
      CosmeticItem(
        code: 'plate_noir',
        kind: CosmeticKind.nameplate,
        slot: CosmeticSlot.nameplate,
        name: (l) => l.cosmeticPlateNoir,
        description: (l) => l.cosmeticPlateNoirDesc,
      ),
      CosmeticItem(
        code: 'plate_gilded',
        kind: CosmeticKind.nameplate,
        slot: CosmeticSlot.nameplate,
        name: (l) => l.cosmeticPlateGilded,
        description: (l) => l.cosmeticPlateGildedDesc,
      ),
      CosmeticItem(
        code: 'plate_ember',
        kind: CosmeticKind.nameplate,
        slot: CosmeticSlot.nameplate,
        name: (l) => l.cosmeticPlateEmber,
        description: (l) => l.cosmeticPlateEmberDesc,
      ),
      CosmeticItem(
        code: 'pack_midnight_manor',
        kind: CosmeticKind.presentationPack,
        slot: CosmeticSlot.roomPack,
        name: (l) => l.cosmeticPackManor,
        description: (l) => l.cosmeticPackManorDesc,
      ),
      CosmeticItem(
        code: 'pack_old_town',
        kind: CosmeticKind.presentationPack,
        slot: CosmeticSlot.roomPack,
        name: (l) => l.cosmeticPackOldTown,
        description: (l) => l.cosmeticPackOldTownDesc,
      ),
      CosmeticItem(
        code: 'pack_moonlit_archive',
        kind: CosmeticKind.presentationPack,
        slot: CosmeticSlot.roomPack,
        name: (l) => l.cosmeticPackArchive,
        description: (l) => l.cosmeticPackArchiveDesc,
      ),
      CosmeticItem(
        code: 'narrator_storyteller',
        kind: CosmeticKind.narratorPack,
        slot: CosmeticSlot.narrator,
        name: (l) => l.cosmeticNarratorStoryteller,
        description: (l) => l.cosmeticNarratorStorytellerDesc,
      ),
      CosmeticItem(
        code: 'narrator_keeper',
        kind: CosmeticKind.narratorPack,
        slot: CosmeticSlot.narrator,
        name: (l) => l.cosmeticNarratorKeeper,
        description: (l) => l.cosmeticNarratorKeeperDesc,
      ),
      CosmeticItem(
        code: 'narrator_noir',
        kind: CosmeticKind.narratorPack,
        slot: CosmeticSlot.narrator,
        name: (l) => l.cosmeticNarratorNoir,
        description: (l) => l.cosmeticNarratorNoirDesc,
      ),
      CosmeticItem(
        code: 'bundle_council',
        kind: CosmeticKind.bundle,
        slot: null,
        name: (l) => l.cosmeticBundleCouncil,
        description: (l) => l.cosmeticBundleCouncilDesc,
      ),
      CosmeticItem(
        code: 'bundle_identity',
        kind: CosmeticKind.bundle,
        slot: null,
        name: (l) => l.cosmeticBundleIdentity,
        description: (l) => l.cosmeticBundleIdentityDesc,
      ),
      CosmeticItem(
        code: 'bundle_nocturne',
        kind: CosmeticKind.bundle,
        slot: null,
        name: (l) => l.cosmeticBundleNocturne,
        description: (l) => l.cosmeticBundleNocturneDesc,
      ),
    ])
      item.code: item,
  };

  static const Map<String, FrameStyle> frames = {
    'frame_gilded': FrameStyle(
      CosmeticTokens.frameGildedOuter,
      CosmeticTokens.frameGildedInner,
      'frame_gilded',
      CosmeticTokens.frameGildedAperture,
    ),
    'frame_crimson': FrameStyle(
      CosmeticTokens.frameCrimsonOuter,
      CosmeticTokens.frameCrimsonInner,
      'frame_crimson',
      CosmeticTokens.frameCrimsonAperture,
    ),
    'frame_moonlit': FrameStyle(
      CosmeticTokens.frameMoonlitOuter,
      CosmeticTokens.frameMoonlitInner,
      'frame_moonlit',
      CosmeticTokens.frameMoonlitAperture,
    ),
    'frame_council_seal': FrameStyle(
      CouncilLifeTokens.sealOuter,
      CouncilLifeTokens.sealInner,
      'frame_council_seal',
      CosmeticTokens.frameCrimsonAperture,
    ),
    'frame_invite': FrameStyle(
      CosmeticTokens.frameGildedOuter,
      CosmeticTokens.frameMoonlitInner,
      'frame_invite',
      CosmeticTokens.frameGildedAperture,
    ),
  };

  static const Map<String, PlateStyle> plates = {
    'plate_noir': PlateStyle(
      CosmeticTokens.plateNoirFill,
      CosmeticTokens.plateNoirBorder,
      CosmeticTokens.plateNoirText,
      'plate_noir',
      cap: CosmeticTokens.plateNoirCap,
      field: CosmeticTokens.plateNoirField,
      onArt: CosmeticTokens.plateNoirArtText,
    ),
    'plate_gilded': PlateStyle(
      CosmeticTokens.plateGildedFill,
      CosmeticTokens.plateGildedBorder,
      CosmeticTokens.plateGildedText,
      'plate_gilded',
      cap: CosmeticTokens.plateGildedCap,
      field: CosmeticTokens.plateGildedField,
      onArt: CosmeticTokens.plateGildedArtText,
    ),
    'plate_ember': PlateStyle(
      CosmeticTokens.plateEmberFill,
      CosmeticTokens.plateEmberBorder,
      CosmeticTokens.plateEmberText,
      'plate_ember',
      cap: CosmeticTokens.plateEmberCap,
      field: CosmeticTokens.plateEmberField,
      onArt: CosmeticTokens.plateEmberArtText,
    ),
  };

  static final Map<String, PresentationPack> packs = {
    'pack_midnight_manor': PresentationPack(
      code: 'pack_midnight_manor',
      grade: CosmeticTokens.gradeMidnightManor,
      veil: CosmeticTokens.manorVeil,
      overlay: AppCouncilArt.fogOverlay,
      transition: PackTransition.candle,
      introSound: AppAudio.nightFalls,
      outroSound: AppAudio.win,
      intro: (l) => l.packManorIntro,
      outro: (l) => l.packManorOutro,
    ),
    'pack_old_town': PresentationPack(
      code: 'pack_old_town',
      grade: CosmeticTokens.gradeOldTown,
      veil: CosmeticTokens.oldTownVeil,
      overlay: AppCouncilArt.lightMote,
      transition: PackTransition.sweep,
      introSound: AppAudio.confrontationSwell,
      outroSound: AppAudio.morning,
      intro: (l) => l.packOldTownIntro,
      outro: (l) => l.packOldTownOutro,
    ),
    'pack_moonlit_archive': PresentationPack(
      code: 'pack_moonlit_archive',
      grade: CosmeticTokens.gradeMoonlitArchive,
      veil: CosmeticTokens.archiveVeil,
      overlay: AppCouncilArt.fogOverlay,
      transition: PackTransition.moonlight,
      introSound: AppAudio.cardFlip,
      outroSound: AppAudio.morning,
      intro: (l) => l.packArchiveIntro,
      outro: (l) => l.packArchiveOutro,
    ),
  };

  static final Map<String, NarratorPack> narrators = {
    'narrator_storyteller': const NarratorPack(
      code: 'narrator_storyteller',
      accent: AppAudio.speakerChange,
      line: _storyteller,
      look: NarratorLook(
        ground: StoreTruthTokens.storytellerGround,
        rule: StoreTruthTokens.storytellerRule,
        ink: StoreTruthTokens.storytellerInk,
        italic: true,
        marker: Icons.auto_stories_rounded,
        markerAsset: 'assets/images/store_v2/narrator_mark_storyteller.webp',
      ),
    ),
    'narrator_keeper': const NarratorPack(
      code: 'narrator_keeper',
      accent: AppAudio.cardFlip,
      line: _keeper,
      look: NarratorLook(
        ground: StoreTruthTokens.keeperGround,
        rule: StoreTruthTokens.keeperRule,
        ink: StoreTruthTokens.keeperInk,
        italic: false,
        marker: Icons.key_rounded,
        markerAsset: 'assets/images/store_v2/narrator_mark_keeper.webp',
      ),
    ),
    'narrator_noir': const NarratorPack(
      code: 'narrator_noir',
      accent: AppAudio.confrontationSwell,
      line: _noir,
      look: NarratorLook(
        ground: StoreTruthTokens.noirGround,
        rule: StoreTruthTokens.noirRule,
        ink: StoreTruthTokens.noirInk,
        italic: false,
        marker: Icons.nightlight_round,
        markerAsset: 'assets/images/store_v2/narrator_mark_noir.webp',
      ),
    ),
  };

  /// Bundle contents, mirrored from the server catalog for previews only.
  static const Map<String, List<String>> bundles = {
    'bundle_council': [
      'pack_midnight_manor',
      'pack_old_town',
      'narrator_storyteller',
    ],
    'bundle_identity': [
      'frame_gilded',
      'frame_crimson',
      'frame_moonlit',
      'plate_noir',
      'plate_gilded',
      'plate_ember',
    ],
    'bundle_nocturne': [
      'pack_moonlit_archive',
      'frame_moonlit',
      'plate_noir',
      'narrator_keeper',
    ],
  };

  /// Whether this build can draw [code].
  static bool knows(String code) => items.containsKey(code);
}

/// Doc 05 rule 3: purchased colour never reaches a night or reveal surface.
/// Frames, plates and packs draw only in the public phases (and the lobby).
bool cosmeticsVisibleIn(GamePhase phase) => switch (phase) {
  GamePhase.distributing ||
  GamePhase.preNightLobby ||
  GamePhase.night ||
  GamePhase.nightResolving => false,
  _ => true,
};

/// The narration beat a phase opens, or null for phases that have none.
NarrationBeat? beatFor(GamePhase phase) => switch (phase) {
  GamePhase.night => NarrationBeat.night,
  GamePhase.morning => NarrationBeat.morning,
  GamePhase.discussion => NarrationBeat.discussion,
  GamePhase.voting => NarrationBeat.voting,
  GamePhase.result => NarrationBeat.result,
  _ => null,
};
