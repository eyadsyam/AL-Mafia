import 'package:web/web.dart' as web;

/// Called synchronously inside the tap, so no popup blocker treats it as
/// unsolicited. `noopener`: the payment page gets no handle on the game tab.
bool openExternal(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
    return true;
  } catch (_) {
    return false;
  }
}
