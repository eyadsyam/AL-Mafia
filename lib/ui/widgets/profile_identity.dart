import 'package:flutter/material.dart';

import '../../engine/models/player.dart';
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

  const ProfileIdentityFields({
    super.key,
    required this.name,
    required this.nameKey,
    required this.gender,
    required this.onGender,
    required this.avatarDiameter,
    this.onNameChanged,
    this.onSubmitted,
  });

  static const int maxNameLength = 20;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PlayerAvatar(
            name: name.text,
            gender: gender,
            diameter: avatarDiameter,
          ),
        ),
        SizedBox(height: s.md),
        TextField(
          key: nameKey,
          controller: name,
          maxLength: maxNameLength,
          textInputAction: TextInputAction.done,
          onChanged: onNameChanged,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(labelText: l.onlineYourName),
        ),
        SettingsSegments<PlayerGender>(
          label: l.profileAddressLabel,
          hint: l.profileAddressHint,
          value: gender,
          options: [
            (PlayerGender.male, l.playerMale, GenderPicker.maleKey),
            (PlayerGender.female, l.playerFemale, GenderPicker.femaleKey),
          ],
          onChanged: onGender,
        ),
      ],
    );
  }
}
