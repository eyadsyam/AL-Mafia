import '../../widgets/language_picker.dart';
import '../../widgets/setup_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/intro_gate.dart';
import '../../../data/player_profile.dart';
import '../../../engine/models/player.dart';
import '../../l10n_ext.dart';
import '../../theme/mafia_theme.dart';
import '../../widgets/gender_picker.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/textured_surface.dart';

class ProfileRequired extends ConsumerWidget {
  final Widget child;
  const ProfileRequired({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (IntroGate.pendingOf(context)) return const _Waiting();
    final profile = ref.watch(playerProfileProvider);
    return profile.when(
      data: (value) => value == null ? const ProfileScreen() : child,
      loading: () => const _Waiting(),
      error: (_, __) => const ProfileScreen(),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class ProfileScreen extends ConsumerStatefulWidget {
  final VoidCallback? onSaved;
  const ProfileScreen({super.key, this.onSaved});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  PlayerGender _gender = PlayerGender.unspecified;
  bool _saving = false;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    final profile = ref.read(playerProfileProvider).valueOrNull;
    _name = TextEditingController(text: profile?.name ?? '');
    _gender = profile?.gender ?? PlayerGender.unspecified;
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
    final s = context.spacing;
    final l = context.l10n;
    return Scaffold(
      body: AppBackdrop(
        child: SetupEntrance(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(s.screenMargin),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: s.maxContentWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LanguagePicker(),
                      SizedBox(height: s.lg),
                      Center(
                        child: PlayerAvatar(
                          name: _name.text,
                          gender: _gender,
                          diameter: s.xl * 3,
                        ),
                      ),
                      SizedBox(height: s.lg),
                      Text(
                        l.profileTitle,
                        style: context.typography.headline,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: s.sm),
                      Text(
                        l.profileHint,
                        style: context.typography.body,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: s.lg),
                      TextField(
                        key: const ValueKey('profile_name'),
                        controller: _name,
                        maxLength: 20,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l.onlineYourName,
                          suffixIcon: GenderPicker(
                            value: _gender,
                            onChanged: (v) => setState(() => _gender = v),
                          ),
                        ),
                      ),
                      if (_failed)
                        Text(
                          l.profileSaveFailed,
                          style: context.typography.body.copyWith(
                            color: context.colors.accentCrimson,
                          ),
                        ),
                      SizedBox(height: s.md),
                      FilledButton(
                        key: const ValueKey('profile_save'),
                        onPressed:
                            _saving ||
                                _name.text.trim().isEmpty ||
                                _gender == PlayerGender.unspecified
                            ? null
                            : _save,
                        child: Text(l.continueAction),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
