import '../../fun/founder_badge.dart';
import '../../widgets/setup_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/player_profile.dart';
import '../../../engine/models/player.dart';
import '../../economy/council_hub.dart' show LeaderboardVisibilitySwitch;
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/back_action.dart';
import '../../widgets/experience_surface.dart';
import '../../widgets/profile_identity.dart';
import '../../economy/waiting_banner.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;

  /// Where back goes. Null only where there is nowhere to go back to (the
  /// online door asking for a profile it does not have yet).
  final VoidCallback? onBack;
  const ProfileScreen({super.key, this.onSaved, this.onBack});

  static const Key nameKey = ValueKey('profile_name');
  static const Key saveKey = ValueKey('profile_save');

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  bool _saving = false;
  bool _failed = false;

  /// Whether the player has touched the form. A saved profile that arrives
  /// after the first frame fills it only while it is untouched.
  bool _edited = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _adopt(ref.read(playerProfileProvider).valueOrNull);
  }

  void _adopt(PlayerProfile? profile) {
    if (profile == null || _edited) return;
    _name.text = profile.name;
    _gender = profile.gender;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref
          .read(playerProfileProvider.notifier)
          .save(PlayerProfile(name: _name.text.trim(), gender: _gender));
      if (mounted) widget.onSaved?.call();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playerProfileProvider, (_, next) {
      setState(() => _adopt(next.valueOrNull));
    });
    final s = context.spacing;
    final l = context.l10n;
    final existing = ref.watch(playerProfileProvider).valueOrNull != null;
    final ready =
        !_saving &&
        _name.text.trim().isNotEmpty &&
        _gender != PlayerGender.unspecified;
    return Scaffold(
      body: ExperienceSurface(
        child: SetupEntrance(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.onBack != null)
                      Padding(
                        padding: EdgeInsets.all(s.sm),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: BackAction(onPressed: widget.onBack!),
                        ),
                      ),
                    // Phase 108: only when editing (never the first-run
                    // profile), at the top, far from the Save button.
                    if (widget.onBack != null) const WaitingBanner(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(s.screenMargin),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (MediaQuery.viewInsetsOf(context).bottom ==
                                0) ...[
                              // The first-run identity page's art: this is
                              // the same question, asked again later.
                              const ExperienceHero(
                                asset: ExperienceArt.invitation,
                                compact: true,
                              ),
                              SizedBox(height: s.lg),
                            ],
                            Semantics(
                              header: true,
                              child: Text(
                                l.profileTitle,
                                style: context.typography.headline,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: s.sm),
                            Text(
                              l.profileHint,
                              style: context.typography.body,
                              textAlign: TextAlign.center,
                            ),
                            // Phase 109: the permanent Founder badge, once
                            // earned. Editing only, like the banner above.
                            if (widget.onBack != null)
                              Padding(
                                padding: EdgeInsets.only(top: s.sm),
                                child: const Center(child: FounderBadge()),
                              ),
                            SizedBox(height: s.lg),
                            ProfileIdentityFields(
                              name: _name,
                              nameKey: ProfileScreen.nameKey,
                              gender: _gender,
                              avatarDiameter: s.xl * 2,
                              onGender: _saving
                                  ? null
                                  : (v) => setState(() {
                                      _edited = true;
                                      _gender = v;
                                    }),
                              onNameChanged: (_) =>
                                  setState(() => _edited = true),
                              onSubmitted: (_) {
                                if (ready) _save();
                              },
                            ),
                            // Phase 107: the player's leaderboard choice,
                            // shown only while the board exists.
                            const LeaderboardVisibilitySwitch(),
                            if (_failed)
                              Text(
                                l.profileSaveFailed,
                                style: context.typography.body.copyWith(
                                  color: context.colors.accentCrimson,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(s.screenMargin),
                      child: FilledButton(
                        key: ProfileScreen.saveKey,
                        onPressed: ready ? _save : null,
                        // An edit is saved; a first profile moves on.
                        child: Text(existing ? l.save : l.continueAction),
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
