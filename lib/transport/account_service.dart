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
  Future<void> requestRecovery(String email);
  Future<AccountStatus> confirmRecovery(String email, String code);
}

class SupabaseAccountService implements AccountService {
  final Future<OnlineBackend> Function() _backend;
  SupabaseAccountService(this._backend);

  Future<GoTrueClient> _auth() async {
    final backend = await _backend();
    if (backend is! SupabaseBackend) throw const AccountFailure('UNAVAILABLE');
    return backend.client.auth;
  }

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
    await (await _backend()).ensureSession();
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
  Future<void> requestRecovery(String email) => _guard(() async {
    final auth = await _auth();
    await auth.signInWithOtp(email: _clean(email), shouldCreateUser: false);
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
}
