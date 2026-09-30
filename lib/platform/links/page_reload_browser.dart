import 'package:web/web.dart' as web;

void reloadPage() {
  try {
    web.window.location.reload();
  } catch (_) {
    /* The tab stays where it was; the player can reload it by hand. */
  }
}
