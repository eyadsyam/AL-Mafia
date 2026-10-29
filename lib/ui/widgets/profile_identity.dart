import 'package:flutter/material.dart';

import '../../engine/models/player.dart';
import '../economy/cosmetic_paint.dart';
import '../l10n_ext.dart';
import '../theme/mafia_theme.dart';
import 'gender_picker.dart';
import 'player_avatar.dart';
import 'settings_kit.dart';

/// The player's identity as the room will see it: the avatar it draws, the
/// name, and how the app addresses them. One form for the first-run identity
/// page and for Profile, so the same question is asked the same way.
///
/// The address is a labelled choice on the settings kit's track, not the
/// compact glyphs of [GenderPicker]: here it is required (the continue button
/// waits for it), so the screen has to say what it is and why it is asked.
/// The glyphs stay on the offline add-players row, where space is the limit.
/// The option keys are [GenderPicker]'s, so one key names the choice
/// everywhere.
class ProfileIdentityFields extends StatelessWidget {
  final TextEditingController name;
  final Key nameKey;
  final PlayerGender gender;
  final ValueChanged<PlayerGender>? onGender;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<String>? onSubmitted;
  final double avatarDiameter;
  final bool autofocusName;

  /// False where the screen draws the avatar itself (the profile's file photo).
  final bool showAvatar;

  /// The name on one side and the address choice on the other, for a window
  /// too short to stack them (a phone on its side).
  final bool sideBySide;

  /// Store truth: the frame and nameplate this player equipped, drawn on the
  /// avatar and on the name exactly as the table draws them. Null for none.
  final String? frame;
  final String? plate;

  const ProfileIdentityFields({
    super.key,
    required this.name,
    required this.nameKey,
    required this.gender,
    required this.onGender,
    required this.avatarDiameter,
    this.autofocusName = false,
    this.showAvatar = true,
    this.sideBySide = false,
    this.onNameChanged,
    this.onSubmitted,
    this.frame,
    this.plate,
  });

  static const Key platePreviewKey = ValueKey('profile_plate_preview');

  static const int maxNameLength = 20;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    final nameField = TextField(
      key: nameKey,
      controller: name,
      autofocus: autofocusName,
      scrollPadding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + s.xl,
      ),
      maxLength: maxNameLength,
      textInputAction: TextInputAction.done,
      onChanged: onNameChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(labelText: l.onlineYourName),
    );
    final avatar = Center(
      child: CosmeticFrameRing(
        frame: frame,
        diameter: avatarDiameter,
        child: PlayerAvatar(
          name: name.text,
          gender: gender,
          diameter: avatarDiameter,
        ),
      ),
    );
    final platePreview = Padding(
      key: platePreviewKey,
      padding: EdgeInsets.only(bottom: s.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l.profilePlatePreview,
            style: context.typography.caption.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          SizedBox(width: s.sm),
          Flexible(
            child: CosmeticNameplate(
              name: name.text.trim(),
              plate: plate,
              style: context.typography.body,
            ),
          ),
        ],
      ),
    );
    final showPlate = plate != null && name.text.trim().isNotEmpty;
    final address = SettingsSegments<PlayerGender>(
      label: l.profileAddressLabel,
      hint: l.profileAddressHint,
      value: gender,
      options: [
        (PlayerGender.male, l.playerMale, GenderPicker.maleKey),
        (PlayerGender.female, l.playerFemale, GenderPicker.femaleKey),
      ],
      onChanged: onGender,
    );
    if (sideBySide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [nameField, if (showPlate) platePreview],
            ),
          ),
          SizedBox(width: s.lg),
          Expanded(child: address),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        nameField,
        SizedBox(height: s.sm),
        if (showAvatar) ...[avatar, SizedBox(height: s.md)],
        if (showPlate) platePreview,
        address,
      ],
    );
  }
}
