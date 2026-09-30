import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/transport/online_backend.dart';
import 'package:mafia_master/ui/fun/launch_events.dart';

import '../support/fake_backend.dart';
import '../support/localized.dart';

void main() {
  late FakeBackend backend;
  setUp(() => backend = FakeBackend(roomId: 'r', state: roomState(), players: roster(5)));

  test('reads the stamps of a finished room', () async {
    backend.responders['economy'] = (_) => {'enabled': true, 'events': ['launch_night', 7]};
    expect(await fetchLaunchEventStamps(backend, 'r'), ['launch_night']);
    expect(backend.calls.single.body, {'action': 'eventResult', 'roomId': 'r'});
  });

  test('disabled, junk or a refusal is simply no stamp', () async {
    backend.responders['economy'] = (_) => {'enabled': false};
    expect(await fetchLaunchEventStamps(backend, 'r'), isEmpty);
    backend.responders['economy'] = (_) => {'enabled': true, 'events': 'x'};
    expect(await fetchLaunchEventStamps(backend, 'r'), isEmpty);
    backend.refusals['economy'] = const BackendException('NOT_MEMBER', 'no');
    expect(await fetchLaunchEventStamps(backend, 'r'), isEmpty);
  });

  testWidgets('public result stamp renders the painted art', (tester) async {
    await tester.pumpWidget(localizedApp(
      const LaunchEventStamp(code: 'launch_night'),
    ));
    final image = tester.widget<Image>(find.descendant(
      of: find.byKey(LaunchEventStamp.stampKey('launch_night')),
      matching: find.byType(Image),
    ));
    expect((image.image as AssetImage).assetName,
        'assets/images/launch/event_stamp.webp');
  });
}
