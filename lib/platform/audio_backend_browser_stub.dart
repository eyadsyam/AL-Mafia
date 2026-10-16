import 'audio_backend.dart';

/// Only the web build has browser media elements; elsewhere the audio
/// package plays everything (`platformAudioBackend`).
AudioBackend createBrowserAudioBackend() =>
    throw UnsupportedError('the browser audio backend exists only on the web');
