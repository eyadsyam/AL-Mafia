import 'package:flutter/foundation.dart' show kIsWeb;

import 'audio_backend.dart' show PluginNarrationPlayer;
import 'narration_controller.dart';
import 'narration_player_stub.dart'
    if (dart.library.js_interop) 'narration_player_web.dart'
    as browser;

/// The Stories narrator's player for this platform: a plain browser
/// `<audio>` started inside the tap on the web, the audio package elsewhere.
NarrationPlayer createNarrationPlayer({bool web = kIsWeb}) =>
    web ? browser.createBrowserNarrationPlayer() : PluginNarrationPlayer();
