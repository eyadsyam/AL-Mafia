import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/push/push_service.dart';
import 'package:mafia_master/ui/economy/economy_capabilities.dart';
import 'package:mafia_master/ui/social/directory.dart';
import 'package:mafia_master/ui/social/push_prompt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An invite reaches a closed app only on a device that registered before it
/// was sent, so registration cannot wait for the player to invite somebody.
class _Push implements PushService {
  _Push({this.platform = 'android', this.granted = false});
  @override
  final String? platform;
  bool granted;
  int asks = 0;
  @override
  bool get needsInstall => false;
  @override
  Future<void> init() async {}
  @override
  Future<bool> askPermission() async {
    asks++;
    return granted = true;
  }

  @override
  Future<bool> isGranted() async => granted;
  @override
  Future<String?> token() async => 'token-${'x' * 30}';
  @override
  Stream<PushOpen> get opened => const Stream.empty();
  @override
  Stream<void> get foreground => const Stream.empty();
  @override
  Future<PushOpen?> initialOpen() async => null;
}

class _Api extends DirectoryApi {
  _Api(super.ref);
  static int registered = 0;
  @override
  Future<void> registerPush(String token, String platform) async =>
      registered++;
}

void main() {
  late _Push push;

  /// One app session: a fresh container is a fresh process.
  Future<PushPrompt> session({bool pushOn = true}) async {
    final container = ProviderContainer(
      overrides: [
        pushServiceProvider.overrideWithValue(push),
        directoryApiProvider.overrideWith(_Api.new),
        economyCapabilitiesProvider.overrideWith(
          (ref) async => EconomyCapabilities(
            friends: true,
            directory: true,
            pushInvites: pushOn,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(economyCapabilitiesProvider.future);
    return container.read(pushPromptProvider);
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _Api.registered = 0;
  });

  test('a device that already allows notifications registers silently', () async {
    push = _Push(granted: true);
    await (await session()).onPlayerReady();
    expect(push.asks, 0);
    expect(_Api.registered, 1);
  });

  test('Android asks once, from the second session, never the first', () async {
    push = _Push();
    final first = await session();
    await first.onPlayerReady();
    await first.onPlayerReady();
    expect(push.asks, 0, reason: 'never on first launch');
    expect(_Api.registered, 0);

    await (await session()).onPlayerReady();
    expect(push.asks, 1, reason: 'second session');
    expect(_Api.registered, 1);

    await (await session()).onPlayerReady();
    expect(push.asks, 1, reason: 'asked once');
    expect(_Api.registered, 2, reason: 'the token is refreshed every session');
  });

  test('the web never prompts outside a tap', () async {
    push = _Push(platform: 'web');
    await (await session()).onPlayerReady();
    await (await session()).onPlayerReady();
    expect(push.asks, 0);
    expect(_Api.registered, 0);
  });

  test('an explicit «no» in settings and a server switch off both win', () async {
    push = _Push(granted: true);
    SharedPreferences.setMockInitialValues({PushPrompt.onKey: false});
    await (await session()).onPlayerReady();
    expect(_Api.registered, 0);

    SharedPreferences.setMockInitialValues({});
    await (await session(pushOn: false)).onPlayerReady();
    expect(_Api.registered, 0);
  });
}
