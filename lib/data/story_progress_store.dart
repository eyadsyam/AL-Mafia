import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../stories/story_progress.dart';

abstract interface class StoryProgressStore {
  Future<StoryProgress> load();
  Future<void> save(StoryProgress progress);
}

class SharedPreferencesStoryProgressStore implements StoryProgressStore {
  static const storageKey = 'mafia.storyProgress.v1';

  const SharedPreferencesStoryProgressStore();

  @override
  Future<StoryProgress> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return const StoryProgress();
    try {
      return StoryProgress.fromJson(
        (jsonDecode(raw) as Map<Object?, Object?>).cast<String, Object?>(),
      );
    } on Object {
      return const StoryProgress();
    }
  }

  @override
  Future<void> save(StoryProgress progress) async {
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(progress.toJson()),
    );
  }
}

class MemoryStoryProgressStore implements StoryProgressStore {
  MemoryStoryProgressStore([this.value = const StoryProgress()]);

  StoryProgress value;

  @override
  Future<StoryProgress> load() async => value;

  @override
  Future<void> save(StoryProgress progress) async => value = progress;
}
