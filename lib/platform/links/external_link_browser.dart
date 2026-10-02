import 'package:web/web.dart' as web;

/// Called synchronously inside the tap, so no popup blocker treats it as
/// unsolicited. A real hyperlink (`<a target=_blank>`) clicked for the
/// player, which mobile browsers open as a link rather than a pop-up.
/// `noopener`: the payment page gets no handle on the game tab.
bool openExternal(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  try {
    final link = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = uri.toString()
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    web.document.body?.append(link);
    link.click();
    link.remove();
    return true;
  } catch (_) {
    return false;
  }
}
