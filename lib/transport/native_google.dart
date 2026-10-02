import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// The Google *web* OAuth client the Supabase Google provider is configured
/// with. The native picker asks Google for an ID token addressed to it, so
/// Supabase accepts the token. Public by design (it names the client, it
/// grants nothing). Override with `--dart-define=GOOGLE_WEB_CLIENT_ID=…`.
const googleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '893004749085-9iji96c9ft1g7nuu8jomvgnbm0pls9pm.apps.googleusercontent.com',
);

/// What the native account picker hands back.
class NativeGoogleToken {
  final String idToken;
  final String? accessToken;
  const NativeGoogleToken(this.idToken, {this.accessToken});
}

/// The player closed the picker. Not an error: nothing is shown.
class NativeGoogleCancelled implements Exception {
  const NativeGoogleCancelled();
}

/// The bottom-sheet Google account picker (Credential Manager on Android).
///
/// [pick] returns the tokens, throws [NativeGoogleCancelled] when the player
/// backs out, and throws anything else when the picker cannot be used on
/// this device — the caller then falls back to the browser flow.
abstract class NativeGoogle {
  Future<NativeGoogleToken> pick();

  /// A picker for this platform, or null where only the browser flow exists
  /// (the web, desktop).
  static NativeGoogle? forPlatform() {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return const PluginNativeGoogle();
      default:
        return null;
    }
  }
}

class PluginNativeGoogle implements NativeGoogle {
  const PluginNativeGoogle();

  static Future<void>? _ready;

  @override
  Future<NativeGoogleToken> pick() async {
    _ready ??= GoogleSignIn.instance.initialize(
      serverClientId: googleWebClientId,
    );
    await _ready;
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('NO_ID_TOKEN');
      }
      return NativeGoogleToken(idToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const NativeGoogleCancelled();
      }
      rethrow;
    }
  }
}
