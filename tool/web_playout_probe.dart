// Browser autoplay regression: no microphone, no fake media permissions.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;
import 'package:mafia_master/platform/voice/web_playout_browser.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SizedBox.shrink());
  final report = web.document.createElement('pre')..id = 'voice-runtime-result'..textContent = 'RUNNING';
  web.document.body!.append(report);
  final audio = web.HTMLAudioElement()..id = 'audio_RTCVideoRenderer-98765';
  // A small PCM WAV exercises the browser's ordinary audible-media policy.
  final bytes = List<int>.filled(8044, 0);
  void text(int at, String value) { bytes.setRange(at, at + value.length, value.codeUnits); }
  void number(int at, int value, int count) {
    for (var i = 0; i < count; i++) { bytes[at + i] = (value >> (i * 8)) & 255; }
  }
  text(0,'RIFF'); number(4,8036,4); text(8,'WAVEfmt '); number(16,16,4);
  number(20,1,2); number(22,1,2); number(24,8000,4); number(28,8000,4);
  number(32,1,2); number(34,8,2); text(36,'data'); number(40,8000,4);
  for (var i = 44; i < bytes.length; i++) { bytes[i] = 128; }
  audio..src = 'data:audio/wav;base64,${base64Encode(bytes)}'..loop = true;
  web.document.body!.append(audio);
  final blocked = !await resumeWebPlayout(98765);
  final ready = web.document.createElement('div')..id = 'playout-retry-needed'..textContent = 'ready';
  web.document.body!.append(ready);
  for (var i = 0; i < 100 && audio.paused; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  final recovered = !audio.paused;
  forgetWebPlayout(98765);
  audio.pause(); audio.remove(); ready.remove();
  report.textContent = jsonEncode({'status': blocked && recovered ? 'PASS' : 'FAIL',
    'autoplayInitiallyBlocked': blocked, 'recoveredOnUserGesture': recovered});
}
