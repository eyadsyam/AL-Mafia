import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'time_zone_stub.dart' if (dart.library.js_interop) 'time_zone_web.dart';

/// The device time-zone name (e.g. `Africa/Cairo`), for the coarse country
/// bucket of «ناس قريبة». No permission, no location, no IP: the browser's
/// Intl zone on the web, `TimeZone.getDefault()` on Android, and the zone
/// abbreviation elsewhere (which the server simply cannot place).
Future<String> deviceTimeZone() async {
  if (kIsWeb) return browserTimeZone() ?? DateTime.now().timeZoneName;
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final id = await const MethodChannel(
        'mafia_master/device',
      ).invokeMethod<String>('timeZone');
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
  }
  return DateTime.now().timeZoneName;
}

/// The device locale with its region when it has one (`ar-EG`).
String deviceLocaleTag() =>
    PlatformDispatcher.instance.locale.toLanguageTag();
