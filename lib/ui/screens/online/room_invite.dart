/// The room invite (doc 12 §3.1).
///
/// *"A single button producing a deep link plus a fallback text. This is the
/// primary growth loop — make it one tap."*
///
/// ## Why the shared link is https and not the custom scheme
///
/// `mafiamaster://` opens the app for somebody who has it and is inert for
/// everybody else — a dead end at the one moment the room is trying to grow.
/// [webLink] is an https App Link instead: the installed app is handed it
/// directly, and a phone without the app opens the same room on the site,
/// where the code is already answered and the visitor is asked only for a name
/// and a gender.
///
/// The custom scheme stays registered for anything that already carries it. It
/// is simply not the thing a host sends.
///
/// [text] still puts the code in words. Some chat clients strip links and
/// others read them aloud; six characters survive both.
abstract final class RoomInvite {
  static const String scheme = 'mafiamaster';
  static const String host = 'online';

  /// Where the web build is published — the Vercel project `almafia`, served
  /// from the domain root, with every unknown path rewritten to index.html.
  ///
  /// It used to be a GitHub Pages project site, which could not rewrite
  /// `/join/CODE` and so forced the router onto the hash strategy. That was
  /// also what kept the invite off App Links: Android strips the fragment
  /// before matching, so `#/join/CODE` can only ever open a browser.
  static const String site = 'https://almafia.vercel.app/';

  /// The link a host actually shares.
  ///
  /// One link, two outcomes, and the recipient chooses neither: Android
  /// verifies this domain against `.well-known/assetlinks.json` and hands the
  /// link to the installed app, and a phone without the app opens the same
  /// room on the site. Nobody is asked to know which they are.
  static String webLink(String code, {String? referralCode}) => Uri.parse(
    '${site}join/${code.toUpperCase()}',
  ).replace(queryParameters: _referralQuery(referralCode)).toString();

  /// The deep link for a room code.
  ///
  /// Shaped so that `Uri.path` is the router's own path: go_router matches on
  /// the path and ignores the host, so this arrives as `/join/CODE`.
  static String link(String code, {String? referralCode}) => Uri(
    scheme: scheme,
    host: host,
    path: '/join/${code.toUpperCase()}',
    queryParameters: _referralQuery(referralCode),
  ).toString();

  /// The message a host sends. One line, the code in it, and the link after.
  static String text(String invitation, String code, {String? referralCode}) =>
      '$invitation\n${webLink(code, referralCode: referralCode)}';

  static String? referral(Uri uri) {
    final code = uri.queryParameters['ref']?.trim().toUpperCase();
    return code != null &&
            RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$').hasMatch(code)
        ? code
        : null;
  }

  static Map<String, String>? _referralQuery(String? code) {
    final normalized = code?.trim().toUpperCase();
    return normalized != null &&
            RegExp(
              r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{7}$',
            ).hasMatch(normalized)
        ? {'ref': normalized}
        : null;
  }
}
