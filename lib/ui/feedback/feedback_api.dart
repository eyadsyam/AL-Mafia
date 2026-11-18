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

/// «إيه رأيك في اللعبة؟»: one to five stars and an optional line, to the same
/// `player_feedback` endpoint under `action: 'rating'`.
abstract class RatingApi {
  Future<void> rate(int stars, String? body);
}

class OnlineRatingApi implements RatingApi {
  OnlineRatingApi(this.ref);
  final Ref ref;

  @override
  Future<void> rate(int stars, String? body) async {
    final backend = await ref.read(onlineBackendFactoryProvider)();
    await backend.ensureSession();
    final text = body?.trim() ?? '';
    await backend.call('player_feedback', {
      'action': 'rating',
      'stars': stars,
      if (text.isNotEmpty) 'body': text,
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

final ratingApiProvider = Provider<RatingApi>(OnlineRatingApi.new);
