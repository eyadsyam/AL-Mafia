import 'dart:js_interop';

@JS('Intl.DateTimeFormat')
extension type _DateTimeFormat._(JSObject _) implements JSObject {
  external factory _DateTimeFormat();
  external _Resolved resolvedOptions();
}

extension type _Resolved._(JSObject _) implements JSObject {
  external String? get timeZone;
}

/// The browser's IANA zone name, or null when it will not say.
String? browserTimeZone() {
  try {
    return _DateTimeFormat().resolvedOptions().timeZone;
  } catch (_) {
    return null;
  }
}
