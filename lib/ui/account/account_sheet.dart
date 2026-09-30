import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/asset_constants.dart';
import '../../transport/account_auth.dart';
import '../../transport/account_service.dart' show AccountFailure;
import '../../transport/supabase_backend.dart';
import '../economy/account_protection.dart' show accountStatusProvider;
import '../economy/economy_capabilities.dart';
import '../economy/my_identity.dart';
import '../economy/wallet.dart';
import '../social/titles_partner.dart';
import '../l10n_ext.dart';
import '../screens/online/online_session.dart';
import '../theme/design_tokens.dart';
import '../theme/mafia_theme.dart';
import '../widgets/feathered_art.dart';
import 'account_footer.dart';
import '../../app/text_formatters.dart';

final accountAuthProvider = Provider<AccountAuth>((ref) {
  final backend = ref.read(onlineBackendFactoryProvider);
  return AccountAuth(() async {
    final value = await backend();
    if (value is! SupabaseBackend) throw const AccountFailure('UNAVAILABLE');
    return value.client.auth;
  }, ensureSession: () async => (await backend()).ensureSession());
});

/// The signed-in identity, refreshed on every auth change (a Google return,
/// a sign-out, a confirmed email).
final accountProfileProvider = StreamProvider<AccountProfile>((ref) async* {
  final auth = ref.read(accountAuthProvider);
  yield await auth.profile();
  yield* auth.changes();
});

/// Opens the account sheet: guest → create/sign in; account → manage.
Future<void> showAccountSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surfaceBase,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const FractionallySizedBox(
          heightFactor: AccountTokens.sheetHeight,
          child: AccountSheet(),
        ),
      ),
    );

enum AccountStep { hub, signUp, verify, signIn, forgot, forgotCode, password }

class AccountSheet extends ConsumerStatefulWidget {
  final AccountStep initial;
  const AccountSheet({super.key, this.initial = AccountStep.hub});

  static const googleKey = ValueKey('account_google');
  static const googleExistingKey = ValueKey('account_google_existing');
  static const createKey = ValueKey('account_create');
  static const haveKey = ValueKey('account_have');
  static const emailKey = ValueKey('account_email_field');
  static const passwordKey = ValueKey('account_password_field');
  static const confirmKey = ValueKey('account_password_confirm');
  static const codeKey = ValueKey('account_code_field');
  static const submitKey = ValueKey('account_submit');
  static const resendKey = ValueKey('account_resend');
  static const forgotKey = ValueKey('account_forgot');
  static const signOutKey = ValueKey('account_sign_out');
  static const rememberKey = ValueKey('account_remember');
  static const errorKey = ValueKey('account_error');

  @override
  ConsumerState<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends ConsumerState<AccountSheet> {
  late AccountStep _step = widget.initial;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  bool _remember = true;
  String? _error;
  String? _notice;

  /// A Google return said the account is already another player's; the sheet
  /// offers to sign in to it instead (D1).
  bool _googleTaken = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    AccountAuth.remember().then((v) {
      if (mounted) setState(() => _remember = v);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _go(AccountStep step) => setState(() {
    if (step == AccountStep.hub) {
      _timer?.cancel();
      _cooldown = 0;
    }
    _step = step;
    _error = null;
    _notice = null;
    _googleTaken = false;
  });

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = AccountTokens.resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  String _message(String code) {
    final l = context.l10n;
    return switch (code) {
      'INVALID_EMAIL' => l.accountErrorEmail,
      'EMAIL_TAKEN' => l.accountErrorTaken,
      'INVALID_CODE' => l.accountErrorCode,
      'RATE_LIMITED' => l.accountErrorRate,
      'LINK_PENDING' => l.accountErrorLinkPending,
      'WEAK_PASSWORD' => l.authWeakPassword,
      'WRONG_PASSWORD' => l.authWrongPassword,
      'NOT_CONFIRMED' => l.authNotConfirmed,
      'SAME_PASSWORD' => l.authSamePassword,
      'MISMATCH' => l.authMismatch,
      'PROVIDER_OFF' => l.authProviderOff,
      _ => l.accountErrorUnavailable,
    };
  }

  Future<void> _run(Future<void> Function(AccountAuth auth) step) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await step(ref.read(accountAuthProvider));
    } on AccountFailure catch (failure) {
      if (mounted) setState(() => _error = _message(failure.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whatever changed, every screen that shows the identity reads it again.
  Future<void> _refreshIdentity() async {
    ref.invalidate(accountStatusProvider);
    ref.invalidate(economyCapabilitiesProvider);
    // Re-read by whoever shows it next; a new identity has a new wallet.
    ref.invalidate(walletProvider);
  }

  void _checkPasswords() {
    if (_password.text != _confirm.text) {
      throw const AccountFailure('MISMATCH');
    }
  }

  @override
  Widget build(BuildContext context) {
    // A refusal that came back with the browser (D1) is said like any other.
    ref.listen<AsyncValue<AccountProfile>>(accountProfileProvider, (_, next) {
      final failure = next.error;
      if (!next.hasError || failure is! AccountFailure) return;
      setState(() {
        _busy = false;
        _notice = null;
        _googleTaken = failure.code == 'EMAIL_TAKEN';
        _error = _googleTaken
            ? context.l10n.authGoogleTaken
            : _message(failure.code);
      });
    });
    final profile =
        ref.watch(accountProfileProvider).valueOrNull ?? AccountProfile.guest;
    final s = context.spacing;
    return SafeArea(
      child: ListView(
        padding: EdgeInsets.all(s.screenMargin),
        children: [
          SizedBox(
            height: AccountTokens.heroHeight,
            child: FeatheredArt(
              feather: Feather.hero,
              child: Image.asset(
                AppImages.splashMask,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          // Store truth: who this account is at the table — the frame and
          // plate it equipped, its title, and its Partner (F10).
          SizedBox(height: s.sm),
          const Center(
            child: MyIdentityBadge(
              axis: Axis.vertical,
              diameter: StoreTruthTokens.sheetAvatar,
            ),
          ),
          const Center(child: EquippedTitleLine()),
          const TitleEquipList(),
          SizedBox(height: s.sm),
          const PartnerPicker(),
          ..._body(context, profile),
          if (_error != null) ...[
            SizedBox(height: s.sm),
            Text(
              _error!,
              key: AccountSheet.errorKey,
              textAlign: TextAlign.center,
              style: context.typography.bodySmall.copyWith(
                color: context.colors.accentCrimson,
              ),
            ),
            if (_googleTaken) ...[
              SizedBox(height: s.sm),
              OutlinedButton(
                key: AccountSheet.googleExistingKey,
                onPressed: _busy
                    ? null
                    : () => _run((auth) async {
                        await auth.googleSignIn();
                        if (!mounted) return;
                        setState(() {
                          _googleTaken = false;
                          _error = null;
                          _notice = context.l10n.authGoogleContinue;
                        });
                      }),
                child: Text(context.l10n.authGoogleUseExisting),
              ),
            ],
          ],
          if (_notice != null) ...[
            SizedBox(height: s.sm),
            Text(
              _notice!,
              textAlign: TextAlign.center,
              style: context.typography.bodySmall.copyWith(
                color: context.colors.accentGold,
              ),
            ),
          ],
          if (_step == AccountStep.hub) const AccountFooter(),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, AccountProfile profile) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;

    Widget title(String text, [String? sub]) => Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: type.headline.copyWith(color: colors.textPrimary),
        ),
        if (sub != null) ...[
          SizedBox(height: s.xs),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ],
        SizedBox(height: s.lg),
      ],
    );

    Widget emailField() => TextField(
      key: AccountSheet.emailKey,
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(labelText: l.authEmail),
    );

    Widget passwordField({
      Key key = AccountSheet.passwordKey,
      TextEditingController? controller,
      String? label,
      bool fresh = false,
    }) => Padding(
      padding: EdgeInsets.only(top: s.sm),
      child: TextField(
        key: key,
        controller: controller ?? _password,
        obscureText: _hidden,
        textDirection: TextDirection.ltr,
        autofillHints: [
          fresh ? AutofillHints.newPassword : AutofillHints.password,
        ],
        decoration: InputDecoration(
          labelText: label ?? l.authPassword,
          helperText: fresh ? l.authPasswordRule : null,
          suffixIcon: IconButton(
            tooltip: _hidden ? l.authShow : l.authHide,
            onPressed: () => setState(() => _hidden = !_hidden),
            icon: Icon(
              _hidden ? Icons.visibility_outlined : Icons.visibility_off,
            ),
          ),
        ),
      ),
    );

    Widget submit(String label, VoidCallback onPressed) => Padding(
      padding: EdgeInsets.only(top: s.lg),
      child: FilledButton(
        key: AccountSheet.submitKey,
        onPressed: _busy ? null : onPressed,
        child: _busy
            ? SizedBox.square(
                dimension: AccountTokens.progress,
                child: CircularProgressIndicator(
                  strokeWidth: AccountTokens.progressStroke,
                  color: colors.textPrimary,
                ),
              )
            : Text(label),
      ),
    );

    Widget back() => TextButton(
      onPressed: _busy ? null : () => _go(AccountStep.hub),
      child: Text(l.back),
    );

    Widget google() => OutlinedButton.icon(
      key: AccountSheet.googleKey,
      onPressed: _busy
          ? null
          : () => _run((auth) async {
              await auth.google();
              if (mounted) setState(() => _notice = l.authGoogleContinue);
            }),
      icon: const Icon(Icons.g_mobiledata_rounded),
      label: Text(l.authGoogle),
    );

    switch (_step) {
      case AccountStep.hub:
        if (profile.signedIn) return _manage(context, profile);
        return [
          title(l.authGuestTitle, l.authGuestBody),
          google(),
          SizedBox(height: s.sm),
          FilledButton(
            key: AccountSheet.createKey,
            onPressed: () => _go(AccountStep.signUp),
            child: Text(l.authCreate),
          ),
          SizedBox(height: s.sm),
          TextButton(
            key: AccountSheet.haveKey,
            onPressed: () => _go(AccountStep.signIn),
            child: Text(l.authHaveAccount),
          ),
        ];

      case AccountStep.signUp:
        return [
          title(l.authCreate, l.authCreateBody),
          emailField(),
          passwordField(fresh: true),
          passwordField(
            key: AccountSheet.confirmKey,
            controller: _confirm,
            label: l.authPasswordAgain,
            fresh: true,
          ),
          submit(
            l.authSendCode,
            () => _run((auth) async {
              _checkPasswords();
              await auth.startSignUp(_email.text, _password.text);
              _startCooldown();
              _go(AccountStep.verify);
            }),
          ),
          back(),
        ];

      case AccountStep.verify:
        return [
          title(l.authVerifyTitle, l.authVerifyBody(_email.text.trim())),
          _CodeField(controller: _code),
          submit(
            l.authVerify,
            () => _run((auth) async {
              await auth.finishSignUp(_email.text, _code.text, _password.text);
              await _refreshIdentity();
              _go(AccountStep.hub);
              if (mounted) setState(() => _notice = l.authWelcome);
            }),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => _run((auth) async {
                    await auth.finishSignUpByLink(_email.text, _password.text);
                    await _refreshIdentity();
                    _go(AccountStep.hub);
                  }),
            child: Text(l.accountLinkOpened),
          ),
          TextButton(
            key: AccountSheet.resendKey,
            onPressed: _busy || _cooldown > 0
                ? null
                : () => _run((auth) async {
                    await auth.resendSignUp(_email.text);
                    _startCooldown();
                    if (mounted) setState(() => _notice = l.authResent);
                  }),
            child: Text(
              _cooldown > 0 ? l.authResendIn(_cooldown) : l.authResend,
            ),
          ),
          back(),
        ];

      case AccountStep.signIn:
        return [
          title(l.authSignIn, l.authSignInBody),
          google(),
          SizedBox(height: s.md),
          emailField(),
          passwordField(),
          CheckboxListTile(
            key: AccountSheet.rememberKey,
            contentPadding: EdgeInsets.zero,
            value: _remember,
            onChanged: (v) {
              setState(() => _remember = v ?? true);
              AccountAuth.setRemember(_remember);
            },
            title: Text(l.authRemember),
          ),
          submit(
            l.authSignIn,
            () => _run((auth) async {
              await auth.signIn(_email.text, _password.text);
              await _refreshIdentity();
              _go(AccountStep.hub);
            }),
          ),
          TextButton(
            key: AccountSheet.forgotKey,
            onPressed: () => _go(AccountStep.forgot),
            child: Text(l.authForgot),
          ),
          back(),
        ];

      case AccountStep.forgot:
        return [
          title(l.authForgot, l.authForgotBody),
          emailField(),
          submit(
            l.authSendCode,
            () => _run((auth) async {
              await auth.sendReset(_email.text);
              _startCooldown();
              _go(AccountStep.forgotCode);
            }),
          ),
          back(),
        ];

      case AccountStep.forgotCode:
        return [
          title(l.authResetTitle, l.authVerifyBody(_email.text.trim())),
          _CodeField(controller: _code),
          passwordField(label: l.authNewPassword, fresh: true),
          passwordField(
            key: AccountSheet.confirmKey,
            controller: _confirm,
            label: l.authPasswordAgain,
            fresh: true,
          ),
          submit(
            l.authResetSave,
            () => _run((auth) async {
              _checkPasswords();
              await auth.finishReset(_email.text, _code.text, _password.text);
              await _refreshIdentity();
              _go(AccountStep.hub);
              if (mounted) setState(() => _notice = l.authPasswordChanged);
            }),
          ),
          TextButton(
            onPressed: _busy || _cooldown > 0
                ? null
                : () => _run((auth) async {
                    await auth.sendReset(_email.text);
                    _startCooldown();
                  }),
            child: Text(
              _cooldown > 0 ? l.authResendIn(_cooldown) : l.authResend,
            ),
          ),
          back(),
        ];

      case AccountStep.password:
        return [
          title(l.authChangePassword),
          passwordField(label: l.authNewPassword, fresh: true),
          passwordField(
            key: AccountSheet.confirmKey,
            controller: _confirm,
            label: l.authPasswordAgain,
            fresh: true,
          ),
          submit(
            l.authResetSave,
            () => _run((auth) async {
              _checkPasswords();
              await auth.changePassword(_password.text);
              _go(AccountStep.hub);
              if (mounted) setState(() => _notice = l.authPasswordChanged);
            }),
          ),
          back(),
        ];
    }
  }

  List<Widget> _manage(BuildContext context, AccountProfile profile) {
    final l = context.l10n;
    final s = context.spacing;
    final colors = context.colors;
    final type = context.typography;
    return [
      Text(
        profile.email ?? '',
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        style: type.title.copyWith(color: colors.textPrimary),
      ),
      SizedBox(height: s.xs),
      Text(
        [
          if (profile.emailConfirmed) l.authVerified,
          if (profile.google) l.authViaGoogle,
          if (profile.password) l.authViaPassword,
        ].join(l.listSeparator),
        textAlign: TextAlign.center,
        style: type.caption.copyWith(color: colors.accentGold),
      ),
      SizedBox(height: s.sm),
      Text(
        l.authSafe,
        textAlign: TextAlign.center,
        style: type.body.copyWith(color: colors.textSecondary),
      ),
      SizedBox(height: s.lg),
      SwitchListTile(
        key: AccountSheet.rememberKey,
        contentPadding: EdgeInsets.zero,
        value: _remember,
        onChanged: (v) {
          setState(() => _remember = v);
          AccountAuth.setRemember(v);
        },
        title: Text(l.authRemember),
      ),
      if (profile.email != null)
        OutlinedButton(
          onPressed: () => _go(AccountStep.password),
          child: Text(
            profile.password ? l.authChangePassword : l.authSetPassword,
          ),
        ),
      SizedBox(height: s.sm),
      TextButton(
        key: AccountSheet.signOutKey,
        onPressed: _busy
            ? null
            : () => _run((auth) async {
                await auth.signOut();
                await _refreshIdentity();
              }),
        child: Text(
          l.authSignOut,
          style: TextStyle(color: colors.accentCrimson),
        ),
      ),
    ];
  }
}

/// Six boxes' worth of digits in one field: paste-friendly, LTR, auto-fill.
class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  const _CodeField({required this.controller});

  @override
  Widget build(BuildContext context) => TextField(
    key: AccountSheet.codeKey,
    controller: controller,
    keyboardType: TextInputType.number,
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    autofillHints: const [AutofillHints.oneTimeCode],
    maxLength: AccountTokens.codeLength,
    inputFormatters: digitsOnly,
    style: context.typography.headline.copyWith(
      color: context.colors.accentGold,
    ),
    decoration: InputDecoration(
      counterText: '',
      hintText: '• • • • • •',
      labelText: context.l10n.authCode,
    ),
  );
}
