import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Native services used by screenshot tests. No audio or sensor data is emitted.
void installPlatformChannelMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const codec = StandardMethodCodec();

  void emptyEvent(String name) {
    messenger.setMockMessageHandler(
      name,
      (message) async => codec.encodeSuccessEnvelope(null),
    );
  }

  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/sensors/method'),
    (call) async => null,
  );
  for (final name in <String>[
    'accelerometer',
    'user_accel',
    'gyroscope',
    'magnetometer',
    'barometer',
  ]) {
    emptyEvent('dev.fluttercommunity.plus/sensors/$name');
  }

  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (call) async => null,
  );
  emptyEvent('xyz.luan/audioplayers.global/events');
  messenger.setMockMethodCallHandler(
    const MethodChannel('com.llfbandit.app_links/messages'),
    (call) async => null,
  );
  emptyEvent('com.llfbandit.app_links/events');
  messenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (call) async {
      if (call.method == 'create') {
        final args = call.arguments as Map<dynamic, dynamic>;
        emptyEvent('xyz.luan/audioplayers/events/${args['playerId']}');
      }
      if (call.method == 'getCurrentPosition' || call.method == 'getDuration') {
        return 0;
      }
      return null;
    },
  );
}
