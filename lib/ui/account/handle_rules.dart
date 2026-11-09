import 'package:flutter/widgets.dart';

/// Arabic letters (U+0621 to U+064A) and Arabic digits (U+0660 to U+0669), as
/// a character-class range. Built from code points so no Arabic text sits in
/// the source (the l10n rule).
final String _arabic =
    '${String.fromCharCode(0x0621)}-${String.fromCharCode(0x064A)}'
    '${String.fromCharCode(0x0660)}-${String.fromCharCode(0x0669)}';

/// What the server accepts as a username (`directory_set_handle`): Latin
/// letters, digits, underscore, Arabic letters and digits, 3 to 20 of them.
final handlePattern = RegExp('^[A-Za-z0-9_$_arabic]{3,20}\$');

final _notAllowed = RegExp('[^A-Za-z0-9_$_arabic]');

/// A first suggestion from a display name, the same way the server derives
/// one: spaces become underscores, anything else outside the allowed letters
/// goes, at most 16 characters, «player» when too little is left.
String suggestHandle(String name) {
  var base = name
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(_notAllowed, '');
  if (base.characters.length > 16) {
    base = base.characters.take(16).toString();
  }
  return base.characters.length < 3 ? 'player' : base;
}
