import 'package:supabase_flutter/supabase_flutter.dart';

import 'online_backend.dart';
import 'supabase_backend.dart';

/// Who this device is, for the purposes of keeping coins.
class AccountStatus {
  /// A confirmed email is attached: the wallet survives uninstall and a new
  /// phone. Anonymous identities do not, and can be cleaned up when idle.
  final bool recoverable;
  final String? email;
  const AccountStatus({required this.recoverable, this.email});

  static const anonymous = AccountStatus(recoverable: false);
}

/// Why an account step did not go through.
class AccountFailure implements Exception {
  /// INVALID_EMAIL | EMAIL_TAKEN | INVALID_CODE | RATE_LIMITED | UNAVAILABLE
  /// | LINK_PENDING (the emailed link has not been opened yet)
  /// | LINK_ELSEWHERE (the link signed in a browser, not this app)
  final String code;
  const AccountFailure(this.code);
}

/// Optional account protection (docs/CLAUDE-UX-ECONOMY-NEXT.md §90).
///
/// Free play never needs it. Linking turns the current anonymous identity
/// into a permanent one by confirming an email with a one-time code, keeping
/// the same user id, so nothing is migrated and nothing is lost. Recovery on
/// another device signs in to that same identity with a new code. No password
/// is ever asked for or stored by the game.
abstract class AccountService {
  Future<AccountStatus> status();

  /// Sends a code to [email] to attach it to this identity.
  Future<void> requestLink(String email);
  Future<AccountStatus> confirmLink(String email, String code);

  /// Sends a sign-in code for an identity that already has [email].
  ///
  /// [redirectTo] is where the email's link lands (the web admin page); the
  /// server ignores it unless it is in the project's allowed redirect URLs.
  Future<void> requestRecovery(String email, {String? redirectTo});
  Future<AccountStatus> confirmRecovery(String email, String code);

  /// The email may carry a link instead of a code (the stock Supabase
  /// templates). Opening it confirms the email change on the server, even in
  /// a browser, so this re-reads the identity and succeeds once it has
  /// [email] confirmed; LINK_PENDING otherwise.
  Future<AccountStatus> confirmLinkByLink(String email);

  /// A recovery link signs in whichever browser opens it, never this app on
  /// another device. Succeeds only when this client already holds that
  /// signed-in session (the web page the link landed on); LINK_ELSEWHERE
  /// otherwise, and the code is the way in.
  Future<AccountStatus> confirmRecoveryByLink(String email);

  /// Every sign-in change seen by this client, including a session the web
  /// build picks up from the emailed link in its URL.
  Stream<AccountStatus> changes();
}

class SupabaseAccountService implements AccountService {
  final Future<GoTrueClient> Function() _auth;
  final Future<void> Function() _ensureSession;

  SupabaseAccountService(Future<OnlineBackend> Function() backend)
    : this.withAuth(
        () async {
          final value = await backend();
          if (value is! SupabaseBackend) {
            throw const AccountFailure('UNAVAILABLE');
          }
          return value.client.auth;
        },
        ensureSession: () async => (await backend()).ensureSession(),
      );

  /// Over an auth client directly (tests hand in a fake one).
  SupabaseAccountService.withAuth(
    this._auth, {
    Future<void> Function()? ensureSession,
  }) : _ensureSession = ensureSession ?? (() async {});

  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String _clean(String email) {
    final value = email.trim().toLowerCase();
    if (!_email.hasMatch(value) || value.length > 254) {
      throw const AccountFailure('INVALID_EMAIL');
    }
    return value;
  }

  static AccountStatus _of(User? user) => user == null
      ? AccountStatus.anonymous
      : AccountStatus(
          recoverable:
              !user.isAnonymous &&
              user.email != null &&
              user.emailConfirmedAt != null,
          email: user.email,
        );

  Future<T> _guard<T>(Future<T> Function() step) async {
    try {
      return await step();
    } on AccountFailure {
      rethrow;
    } on AuthException catch (error) {
      final code = error.code ?? '';
      if (code.contains('email_exists') ||
          code.contains('email_address_taken')) {
        throw const AccountFailure('EMAIL_TAKEN');
      }
      if (code.contains('otp') || code.contains('token')) {
        throw const AccountFailure('INVALID_CODE');
      }
      if (error.statusCode == '429' || code.contains('rate_limit')) {
        throw const AccountFailure('RATE_LIMITED');
      }
      throw const AccountFailure('UNAVAILABLE');
    } catch (_) {
      throw const AccountFailure('UNAVAILABLE');
    }
  }

  @override
  Future<AccountStatus> status() async {
    try {
      return _of((await _auth()).currentUser);
    } catch (_) {
      return AccountStatus.anonymous;
    }
  }

  @override
  Future<void> requestLink(String email) => _guard(() async {
    final auth = await _auth();
    await _ensureSession();
    await auth.updateUser(UserAttributes(email: _clean(email)));
  });

  @override
  Future<AccountStatus> confirmLink(String email, String code) =>
      _guard(() async {
        final auth = await _auth();
        await auth.verifyOTP(
          email: _clean(email),
          token: code.trim(),
          type: OtpType.emailChange,
        );
        return _of(auth.currentUser);
      });

  @override
  Future<void> requestRecovery(String email, {String? redirectTo}) =>
      _guard(() async {
        final auth = await _auth();
        await auth.signInWithOtp(
          email: _clean(email),
          shouldCreateUser: false,
          emailRedirectTo: redirectTo,
        );
      });

  @override
  Future<AccountStatus> confirmRecovery(String email, String code) =>
      _guard(() async {
        final auth = await _auth();
        await auth.verifyOTP(
          email: _clean(email),
          token: code.trim(),
          type: OtpType.email,
        );
        return _of(auth.currentUser);
      });

  /// The identity as the server has it now. `getUser` reads the server;
  /// `refreshSession` carries the change into this client's session. A
  /// refresh refused (an old token) still leaves the server's answer.
  Future<User?> _fresh(GoTrueClient auth) async {
    if (auth.currentSession == null) return auth.currentUser;
    try {
      await auth.refreshSession();
    } on AuthException {
      // The server's own answer below still decides.
    }
    try {
      return (await auth.getUser()).user ?? auth.currentUser;
    } on AuthException {
      return auth.currentUser;
    }
  }

  @override
  Future<AccountStatus> confirmLinkByLink(String email) => _guard(() async {
    final wanted = _clean(email);
    final auth = await _auth();
    final status = _of(await _fresh(auth));
    if (status.recoverable && status.email?.toLowerCase() == wanted) {
      return status;
    }
    throw const AccountFailure('LINK_PENDING');
  });

  @override
  Future<AccountStatus> confirmRecoveryByLink(String email) =>
      _guard(() async {
        final wanted = _clean(email);
        final auth = await _auth();
        final status = _of(await _fresh(auth));
        if (status.recoverable && status.email?.toLowerCase() == wanted) {
          return status;
        }
        throw const AccountFailure('LINK_ELSEWHERE');
      });

  @override
  Stream<AccountStatus> changes() async* {
    final GoTrueClient auth;
    try {
      auth = await _auth();
    } catch (_) {
      return;
    }
    yield* auth.onAuthStateChange.map(
      (state) => _of(state.session?.user ?? auth.currentUser),
    );
  }
}
