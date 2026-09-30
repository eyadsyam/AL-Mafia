import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_reload_stub.dart'
    if (dart.library.js_interop) 'page_reload_browser.dart'
    as impl;

/// Reloads the web page, which is how the web build "updates": the new
/// bundle is fetched when the page is fetched again. Does nothing off the web.
typedef PageReloader = void Function();

final pageReloaderProvider = Provider<PageReloader>((ref) => impl.reloadPage);
