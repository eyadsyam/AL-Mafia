import '../../../../app/asset_constants.dart';
import '../../../../engine/models/enums.dart';

/// The mark a seat carries after the match is over — doc 15 §S-O13 beat 2.
///
/// ## Why a glyph and not the card
///
/// The beat this serves used to ask for all fifteen cards to rise and flip at
/// once. It could not be built: §1.3 retired the card at seat size because
/// *"the ornate engraving is beautiful at 300dp and mud at 60dp"*, §5 turned
/// that into a hard floor of 200dp, and fifteen cards at 200dp need 3000dp of
/// width on a screen that has 412.
///
/// The resolution separated the two things that beat was carrying. The drama
/// is simultaneity, which belongs to the rings — they turn over on the same
/// frame at every player count and have no size floor to break. The
/// legibility is the art, which belongs to the roster, where one card is shown
/// at a time at 280dp. This file is the first half: a mark that still reads at
/// 44dp, which is the smallest a ring gets at fifteen players.
///
/// ## Why it lives here and not in the painter
///
/// `council_band.dart` must not name a role, and there is a test that fails if
/// it ever does. The band takes an asset path it cannot interpret; the mapping
/// from a role to that path happens here, on the far side of the boundary, and
/// only ever with standings the server has already published.
String glyphFor(Role role) => switch (role) {
  Role.mafia => AppIcons.roleMafia,
  Role.doctor => AppIcons.roleDoctor,
  Role.detective => AppIcons.roleDetective,
  Role.citizen => AppIcons.roleCitizen,
};
