import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'account_service.dart';

/// Where an OAuth sign-in returns to on a phone. Registered in the Android
/// manifest and in the project's allowed redirect URLs.
const oauthRedirect = 'mafiamaster://login-callback';

/// A full account: password, Google, sign in and out, forgotten passwords,
/// and «تذكرني».
///
/// Built on the same rule as email protection ([AccountService]): a guest who
/// creates an account keeps their user id — the email (and then a password)
/// is attached to the anonymous identity, or Google is *linked* to it — so no
/// coin, rank or item has to move. Signing in to an account that already
/// exists elsewhere is the one step that changes identity, and the UI says
/// so before it happens.
class AccountAuth {
  final Future<GoTrueClient> Function() _auth;
  final Future<void> Function() _ensureSession;

  AccountAuth(this._auth, {required Future<void> Function() ensureSession})
    : _ensureSession = ensureSession;

  static const rememberKey = 'mafia.account.remember.v1';
  static const minPassword = 8;

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String cleanEmail(String email) {
    final value = email.trim().toLowerCase();
    if (!_email.hasMatch(value) || value.length > 254) {
      throw const AccountFailure('INVALID_EMAIL');
    }
    return value;
  }

  static String checkPassword(String password) {
    if (password.length < minPassword || password.length > 72) {
      throw const AccountFailure('WEAK_PASSWORD');
    }
    return password;
  }

  Future<T> _guard<T>(Future<T> Function() step) async {
    try {
      return await step();
    } on AccountFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AccountFailure(codeFor(error));
    } catch (_) {
      throw const AccountFailure('UNAVAILABLE');
    }
  }

  /// The failure code the UI speaks for an auth refusal. Public and pure so
  /// it can be tested without a server.
  static String codeFor(AuthException error) {
    final code = (error.code ?? '').toLowerCase();
    final message = error.message.toLowerCase();
    if (code.contains('invalid_credentials') ||
        message.contains('invalid login credentials')) {
      return 'WRONG_PASSWORD';
    }
    if (code.contains('email_not_confirmed')) return 'NOT_CONFIRMED';
    if (code.contains('weak_password')) return 'WEAK_PASSWORD';
    if (code.contains('same_password')) return 'SAME_PASSWORD';
    if (code.contains('identity_already_exists') ||
        code.contains('email_exists') ||
        code.contains('user_already_exists') ||
        code.contains('email_address_taken')) {
      return 'EMAIL_TAKEN';
    }
    if (code.contains('otp') || code.contains('token')) return 'INVALID_CODE';
    if (error.statusCode == '429' || code.contains('rate_limit')) {
      return 'RATE_LIMITED';
    }
    if (code.contains('provider_disabled') ||
        code.contains('manual_linking_disabled')) {
      return 'PROVIDER_OFF';
    }
    return 'UNAVAILABLE';
  }

  /// Who is signed in, as the account screens need it.
  Future<AccountProfile> profile() async {
    try {
      return AccountProfile.of((await _auth()).currentUser);
    } catch (_) {
      return AccountProfile.guest;
    }
  }

  /// Guest → account, step 1: attach [email] (a 6-digit code is emailed).
  /// The password is set once the email is confirmed ([finishSignUp]).
  Future<void> startSignUp(String email, String password) => _guard(() async {
    final clean = cleanEmail(email);
    checkPassword(password);
    final auth = await _auth();
    await _ensureSession();
    await auth.updateUser(UserAttributes(email: clean));
  });

  /// Step 2: the emailed code confirms the address; then the password.
  Future<AccountProfile> finishSignUp(
    String email,
    String code,
    String password,
  ) => _guard(() async {
    final auth = await _auth();
    await auth.verifyOTP(
      email: cleanEmail(email),
      token: code.trim(),
      type: OtpType.emailChange,
    );
    await auth.updateUser(UserAttributes(password: checkPassword(password)));
    return AccountProfile.of(auth.currentUser);
  });

  /// The same step when the player opened the email's link instead: the
  /// server already confirmed the address; only the password is left.
  Future<AccountProfile> finishSignUpByLink(String email, String password) =>
      _guard(() async {
        final auth = await _auth();
        try {
          await auth.refreshSession();
        } on AuthException {
          /* The server's answer below decides. */
        }
        final user = (await auth.getUser()).user;
        if (user == null ||
            user.emailConfirmedAt == null ||
            user.email?.toLowerCase() != cleanEmail(email)) {
          throw const AccountFailure('LINK_PENDING');
        }
        await auth.updateUser(
          UserAttributes(password: checkPassword(password)),
        );
        return AccountProfile.of(auth.currentUser);
      });

  /// Sends the confirmation code again.
  Future<void> resendSignUp(String email) => _guard(() async {
    final auth = await _auth();
    await auth.resend(type: OtpType.emailChange, email: cleanEmail(email));
  });

  /// Signs in to an existing account (this device's guest identity is left).
  Future<AccountProfile> signIn(String email, String password) =>
      _guard(() async {
        final auth = await _auth();
        final response = await auth.signInWithPassword(
          email: cleanEmail(email),
          password: password,
        );
        return AccountProfile.of(response.user);
      });

  /// Google. A guest links Google to the identity they already have; if that
  /// Google account already belongs to another player, this signs in to it.
  /// Returns once the browser has been opened; the session arrives through
  /// [changes] when the player comes back.
  Future<void> google() => _guard(() async {
    final auth = await _auth();
    final redirect = kIsWeb ? null : oauthRedirect;
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        await auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: redirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        return;
      } on AuthException catch (error) {
        if (codeFor(error) != 'EMAIL_TAKEN') rethrow;
      }
    }
    await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  });

  /// «نسيت كلمة السر»: emails a 6-digit code (and a link).
  Future<void> sendReset(String email) => _guard(() async {
    final auth = await _auth();
    await auth.resetPasswordForEmail(
      cleanEmail(email),
      redirectTo: kIsWeb ? null : oauthRedirect,
    );
  });

  /// The code signs in; the new password is set in the same step.
  Future<AccountProfile> finishReset(
    String email,
    String code,
    String password,
  ) => _guard(() async {
    final auth = await _auth();
    checkPassword(password);
    await auth.verifyOTP(
      email: cleanEmail(email),
      token: code.trim(),
      type: OtpType.recovery,
    );
    await auth.updateUser(UserAttributes(password: password));
    return AccountProfile.of(auth.currentUser);
  });

  Future<void> changePassword(String password) => _guard(() async {
    final auth = await _auth();
    await auth.updateUser(UserAttributes(password: checkPassword(password)));
  });

  /// Signs out. The next online step starts a fresh guest identity.
  Future<void> signOut() => _guard(() async {
    await (await _auth()).signOut();
  });

  Stream<AccountProfile> changes() async* {
    final GoTrueClient auth;
    try {
      auth = await _auth();
    } catch (_) {
      return;
    }
    yield* profileChanges(auth.onAuthStateChange, () => auth.currentUser);
  }

  /// Every auth change as the profile it leaves behind.
  ///
  /// A Google return that failed — the account is already another player's,
  /// the link expired — arrives on this stream, not from the call that opened
  /// the browser. It used to reach the screens as a raw SDK error, which they
  /// could not read, so the player came back to a sheet that said nothing
  /// (D1). It now arrives as the same [AccountFailure] a direct call throws.
  static Stream<AccountProfile> profileChanges(
    Stream<AuthState> states,
    User? Function() current,
  ) => states
      .map((state) => AccountProfile.of(state.session?.user ?? current()))
      .handleError((Object error) {
        if (error is AccountFailure) throw error;
        throw AccountFailure(
          error is AuthException ? codeFor(error) : 'UNAVAILABLE',
        );
      });

  /// Google, straight to sign-in: the choice a guest makes after learning the
  /// Google account already belongs to another player. This device leaves the
  /// guest identity for that account.
  Future<void> googleSignIn() => _guard(() async {
    final auth = await _auth();
    await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : oauthRedirect,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  });

  /// «تذكرني», on by default.
  static Future<bool> remember() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(rememberKey) ??
          true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setRemember(bool value) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(rememberKey, value);
    } catch (_) {
      /* Falls back to remembering, the default. */
    }
  }

  /// Called once per launch when the client boots: an account that asked not
  /// to be remembered is signed out. Guests are always kept (their session is
  /// their only key to their coins).
  static Future<void> applyRemember(GoTrueClient auth) async {
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    if (await remember()) return;
    try {
      await auth.signOut();
    } catch (_) {
      /* Signed out next launch instead. */
    }
  }
}

/// The signed-in identity as the profile shows it.
class AccountProfile {
  final bool signedIn;
  final String? email;
  final bool emailConfirmed;
  final bool google;
  final bool password;
  final DateTime? since;

  const AccountProfile({
    required this.signedIn,
    this.email,
    this.emailConfirmed = false,
    this.google = false,
    this.password = false,
    this.since,
  });

  static const guest = AccountProfile(signedIn: false);

  static AccountProfile of(User? user) {
    if (user == null || user.isAnonymous) return guest;
    final providers = <String>{
      for (final identity in user.identities ?? const <UserIdentity>[])
        identity.provider,
    };
    return AccountProfile(
      signedIn: true,
      email: user.email,
      emailConfirmed: user.emailConfirmedAt != null,
      google: providers.contains('google'),
      password: providers.contains('email'),
      since: DateTime.tryParse(user.createdAt),
    );
  }
}
