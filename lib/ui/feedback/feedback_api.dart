import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_build.dart';
import '../screens/online/online_session.dart';

abstract class FeedbackApi {
  Future<void> submit(String kind, String body);
}

class OnlineFeedbackApi implements FeedbackApi {
  OnlineFeedbackApi(this.ref);
  final Ref ref;

  @override
  Future<void> submit(String kind, String body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    await backend.call('player_feedback', {
      'kind': kind,
      'body': body.trim(),
      'build': kAppBuildNumber,
      'platform': kIsWeb
          ? 'web'
          : switch (defaultTargetPlatform) {
              TargetPlatform.iOS => 'ios',
              _ => 'android',
            },
    });
  }
}

final feedbackApiProvider = Provider<FeedbackApi>(OnlineFeedbackApi.new);
