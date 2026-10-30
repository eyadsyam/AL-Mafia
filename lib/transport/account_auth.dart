import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/online_session_store.dart';
import '../ui/theme/design_tokens.dart' show AccountTokens;
import 'account_service.dart';
import 'native_google.dart';

/// Where an OAuth sign-in returns to on a phone. Registered in the Android
/// manifest and in the project's allowed redirect URLs.
const oauthRedirect = 'mafiamaster://login-callback';

/// Where a Google sign-in returns to: the app on a phone; on the web, the
/// site the player is on. The project's Site URL used to decide the web case,
/// and a player on one domain returned to the other lost the PKCE verifier
/// kept in the first one's storage — the sign-in silently failed. (Must be
/// in the allowed redirect URLs; when it is not, Supabase falls back to the
/// Site URL, which is the old behaviour.)
String get _oauthReturn => kIsWeb ? '${Uri.base.origin}/' : oauthRedirect;

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

  /// The native account picker; null where only the browser flow exists.
  final NativeGoogle? _native;

  /// Whether the guest on this device has something to lose — coins, a bought
  /// role or look. Null where nobody can say (then the guest has nothing).
  final Future<bool> Function()? _guestStake;

  AccountAuth(
    this._auth, {
    required Future<void> Function() ensureSession,
    NativeGoogle? native,
    Future<bool> Function()? guestStake,
  }) : _ensureSession = ensureSession,
       _native = native,
       _guestStake = guestStake;

  /// A guest who would leave coins or items behind by becoming another
  /// account is asked first. An unanswerable question counts as a yes: the
  /// price of asking is one tap, the price of not asking is their coins.
  Future<bool> _guestWouldLoseSomething() async {
    final stake = _guestStake;
    if (stake == null) return false;
    try {
      return await stake();
    } catch (_) {
      return true;
    }
  }

  /// The native picker first (a bottom sheet, no browser, no redirect). `true`
  /// when it finished — signed in or linked — or the player backed out; `false`
  /// when it cannot be used here and the browser flow should take over.
  /// A refusal by the server (the Google account is another player's) is
  /// thrown, not swallowed, so the player hears it.
  Future<bool> _nativeGoogle(GoTrueClient auth, {required bool link}) async {
    final native = _native;
    if (native == null) return false;
    final NativeGoogleToken token;
    try {
      token = await native.pick();
    } on NativeGoogleCancelled {
      // Backing out of the picker is a choice, not a failure: nothing to say.
      return true;
    } catch (_) {
      return false;
    }
    final user = auth.currentUser;
    if (link && user != null && user.isAnonymous) {
      try {
        await auth.linkIdentityWithIdToken(
          provider: OAuthProvider.google,
          idToken: token.idToken,
          accessToken: token.accessToken,
        );
        return true;
      } on AuthException catch (error) {
        // That Google account is already a player: the player meant that
        // account, so the same picker answer signs in to it — unless this
        // guest would leave coins or items behind, who chooses first.
        if (codeFor(error) != 'EMAIL_TAKEN') rethrow;
        if (await _guestWouldLoseSomething()) {
          throw const AccountFailure('EMAIL_TAKEN');
        }
      }
    }
    await auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: token.idToken,
      accessToken: token.accessToken,
    );
    return true;
  }

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
  ///
  /// A refusal read from a return link carries the server's code in
  /// `statusCode` (its `error_code`) and a generic one (`server_error`) in
  /// `code`, so both are read: reading only `code` turned «that Google
  /// account already exists» into «the service is down».
  static String codeFor(AuthException error) {
    final code = '${error.code ?? ''} ${error.statusCode ?? ''}'.toLowerCase();
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
        code.contains('email_address_taken') ||
        message.contains('already linked to another user') ||
        message.contains('already been registered')) {
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
    // The email also carries a link; opened, it is a return like Google's.
    await markPendingReturn();
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

  /// Google. A guest links Google to the identity they already have (same
  /// user id, so every coin and item stays). Returns once the browser has
  /// been opened; the session arrives through [changes] when the player comes
  /// back. If that Google account already belongs to another player the
  /// refusal also arrives there, as `EMAIL_TAKEN`, and the player chooses:
  /// [googleSignIn] to that account, or stay the guest. (The server only
  /// refuses on the way back, so the fallback below is for an older server
  /// that refused up front.)
  Future<void> google() => _guard(() async {
    final auth = await _auth();
    await _ensureSession();
    if (await _nativeGoogle(auth, link: true)) return;
    final redirect = _oauthReturn;
    await markPendingReturn();
    final user = auth.currentUser;
    if (user != null && user.isAnonymous) {
      try {
        await auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: redirect,
          authScreenLaunchMode: LaunchMode.externalApplication,
          queryParams: const {'prompt': 'select_account'},
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
      queryParams: const {'prompt': 'select_account'},
    );
  });

  /// «نسيت كلمة السر»: emails a 6-digit code (and a link). The link returns to
  /// the app on a phone and to this same site on the web, where the browser
  /// that asked holds the sign-in's verifier; [passwordRecoveries] then opens
  /// the new-password step.
  Future<void> sendReset(String email) => _guard(() async {
    final auth = await _auth();
    await markPendingReturn();
    await auth.resetPasswordForEmail(
      cleanEmail(email),
      redirectTo: _oauthReturn,
    );
  });

  /// Each time a password-reset link signs this device in: the next thing the
  /// player needs is a new password.
  Stream<void> passwordRecoveries() async* {
    final GoTrueClient auth;
    try {
      auth = await _auth();
    } catch (_) {
      return;
    }
    yield* auth.onAuthStateChange
        .where((state) => state.event == AuthChangeEvent.passwordRecovery)
        .map((_) {})
        .handleError((Object _) {});
  }

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

  Future<void> ensureGuestSession() => _guard(() async {
    await _ensureSession();
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
  Future<void> googleSignIn() => _googleSignIn(null);

  Future<void> googleSignInForAccount(String email) => _googleSignIn(email);

  Future<void> _googleSignIn(String? loginHint) => _guard(() async {
    final auth = await _auth();
    if (await _nativeGoogle(auth, link: false)) return;
    await markPendingReturn();
    await auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthReturn,
      authScreenLaunchMode: LaunchMode.externalApplication,
      queryParams: {
        'prompt': 'select_account',
        if (loginHint != null) 'login_hint': loginHint,
      },
    );
  });

  static const switchKey = 'mafia.account.google_switch.v1';

  /// How long after one automatic switch a second refusal is left to the
  /// player instead: a server that kept refusing would otherwise bounce the
  /// browser forever.
  static const switchCooldown = Duration(minutes: 2);

  /// A guest's Google link came back refused because that Google account is
  /// already a player's. The player tapped Google to be that player, so this
  /// signs in to it, no second question. `false` when it already did so a
  /// moment ago, or when the guest has coins or items they would leave
  /// behind; the caller then offers the choice (switch or stay a guest).
  Future<bool> switchToTakenGoogle() async {
    if (await _guestWouldLoseSomething()) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(switchKey);
      if (last != null && now - last < switchCooldown.inMilliseconds) {
        return false;
      }
      await prefs.setInt(switchKey, now);
    } catch (_) {
      return false;
    }
    await googleSignIn();
    return true;
  }

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

  static bool _rememberApplied = false;

  /// Lets a test run [applyRemember] as a fresh launch.
  @visibleForTesting
  static void resetRememberForTest() => _rememberApplied = false;

  static const pendingReturnKey = 'mafia.account.pending_return.v1';

  /// Marks a sign-in that is about to leave for a browser (Google, an email
  /// link). On the web its return is a new launch, and [applyRemember] would
  /// otherwise sign the account it brings back straight out again.
  static Future<void> markPendingReturn() async {
    try {
      await (await SharedPreferences.getInstance()).setInt(
        pendingReturnKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      /* Without the mark, «تذكّرني» off still applies; nothing else changes. */
    }
  }

  /// Whether [address] is a sign-in coming back: the PKCE code, a token in the
  /// fragment, a one-time token hash, or the error the provider sent back.
  static bool looksLikeAuthReturn(Uri address) {
    final query = address.queryParameters;
    final fragment = address.fragment;
    return query.containsKey('code') ||
        query.containsKey('token_hash') ||
        query.containsKey('error') ||
        fragment.contains('access_token=') ||
        fragment.contains('error=');
  }

  /// Whether this launch is the return of a recent [markPendingReturn]. The
  /// mark is used once.
  static Future<bool> _returning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(pendingReturnKey);
      if (at == null) return false;
      await prefs.remove(pendingReturnKey);
      final age = DateTime.now().millisecondsSinceEpoch - at;
      return age >= 0 && age < AccountTokens.pendingReturn.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Called once per launch when the client boots: an account that asked not
  /// to be remembered is signed out. Guests are always kept (their session is
  /// their only key to their coins), and so is an account that is just coming
  /// back from the browser it was sent to ([markPendingReturn]) or that has an
  /// online match to go back to.
  ///
  /// Once per *process*: the backend factory runs this on every call, so an
  /// account that unticked «تذكرني» used to be signed out by the next server
  /// call after signing in — a Google return undone a second later.
  ///
  /// [authReturn]: this launch's address carries a sign-in coming back from a
  /// browser ([looksLikeAuthReturn], read before Supabase tidies it). The
  /// pending-return mark counts only then, so a reset email requested and
  /// never opened does not keep a remember-off account signed in. A phone has
  /// no address to read and always passes true: there the mark's fifteen
  /// minutes and its single use are the whole guard.
  static Future<void> applyRemember(
    GoTrueClient auth, {
    bool authReturn = false,
  }) async {
    if (_rememberApplied) return;
    _rememberApplied = true;
    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;
    if (authReturn && await _returning()) return;
    if (await remember()) return;
    // A match the app was killed in the middle of: signed out here, the seat
    // would be asked for again as a new guest, refused, and its way back
    // deleted. The account stays for this launch; the pointer goes when the
    // match does, and the launch after that signs it out. Only this account's
    // own seat counts: another account's pointer is no match of this one's.
    if ((await OnlineSessionStore.load())?.belongsTo(user.id) ?? false) return;
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
  final String? userId;
  final String? email;
  final bool emailConfirmed;
  final bool google;
  final bool password;
  final DateTime? since;

  /// The name the sign-in provider knows (Google's full name), offered as the
  /// first-run name. Shown to nobody else from here.
  final String? name;

  const AccountProfile({
    required this.signedIn,
    this.userId,
    this.email,
    this.emailConfirmed = false,
    this.google = false,
    this.password = false,
    this.since,
    this.name,
  });

  /// Whether [other] is a different identity, not just a refreshed token.
  bool differs(AccountProfile other) =>
      signedIn != other.signedIn ||
      userId != other.userId ||
      email != other.email;

  static const guest = AccountProfile(signedIn: false);

  static AccountProfile of(User? user) {
    if (user == null || user.isAnonymous) return guest;
    final providers = <String>{
      for (final identity in user.identities ?? const <UserIdentity>[])
        identity.provider,
    };
    return AccountProfile(
      signedIn: true,
      userId: user.id,
      email: user.email,
      emailConfirmed: user.emailConfirmedAt != null,
      google: providers.contains('google'),
      password: providers.contains('email'),
      since: DateTime.tryParse(user.createdAt),
      name: _metadataName(user.userMetadata),
    );
  }

  static String? _metadataName(Map<String, dynamic>? metadata) {
    for (final key in const ['full_name', 'name']) {
      final value = metadata?[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}
