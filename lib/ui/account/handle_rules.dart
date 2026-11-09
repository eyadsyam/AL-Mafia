import 'package:flutter/widgets.dart';

/// What the server accepts as a username (`directory_set_handle`).
final handlePattern = RegExp(r'^[A-Za-z0-9_ء-ي٠-٩]{3,20}$');

/// A first suggestion from a display name, the same way the server derives
/// one: spaces become underscores, anything else outside the allowed letters
/// goes, at most 16 characters, «player» when too little is left.
String suggestHandle(String name) {
  var base = name
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^A-Za-z0-9_ء-ي٠-٩]'), '');
  if (base.characters.length > 16) {
    base = base.characters.take(16).toString();
  }
  return base.characters.length < 3 ? 'player' : base;
}
