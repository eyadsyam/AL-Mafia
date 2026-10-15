import 'narration_controller.dart';

/// Only the web build has a browser `<audio>`; elsewhere the audio package
/// plays the narrator (`createNarrationPlayer`).
NarrationPlayer createBrowserNarrationPlayer() =>
    throw UnsupportedError('the browser narrator exists only on the web');
