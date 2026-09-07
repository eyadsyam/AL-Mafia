/// The room invite (doc 12 §3.1).
///
/// *"A single button producing a deep link plus a fallback text. This is the
/// primary growth loop — make it one tap."*
///
/// ## Why the shared link is https and not the custom scheme
///
/// `mafiamaster://` opens the app for somebody who has it and is inert for
/// everybody else — a dead end at the one moment the room is trying to grow.
/// The site is the same Flutter app, so [webLink] opens the room in the
/// recipient's browser whether or not they have ever heard of it: the code is
/// already answered and they are asked only for a name and a gender.
///
/// The custom scheme stays because the installed Android app registers it. It
/// is simply not the thing a host sends.
///
/// [text] still puts the code in words. Some chat clients strip links and
/// others read them aloud; six characters survive both.
abstract final class RoomInvite {
  static const String scheme = 'mafiamaster';
  static const String host = 'online';

  /// Where the web build is published — `--base-href /AL-Mafia/` in
  /// `tool/build_web.ps1`. The hash is not decoration: GitHub Pages cannot
  /// rewrite `/join/CODE` to `index.html`, so the router runs on the default
  /// hash strategy and the link has to carry it.
  static const String site = 'https://eyadsyam.github.io/AL-Mafia/';

  /// The link a host actually shares. Opens the room anywhere.
  static String webLink(String code) => '$site#/join/${code.toUpperCase()}';

  /// The deep link for a room code.
  ///
  /// Shaped so that `Uri.path` is the router's own path: go_router matches on
  /// the path and ignores the host, so this arrives as `/join/CODE`.
  static String link(String code) =>
      '$scheme://$host/join/${code.toUpperCase()}';

  /// The message a host sends. One line, the code in it, and the link after.
  static String text(String invitation, String code) =>
      '$invitation\n${webLink(code)}';
}
