import 'package:flutter/services.dart';

import '../stories/story_model.dart';

class StoryCatalog {
  const StoryCatalog({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  static const assetPaths = [
    'assets/stories/qahwet_el_moallem.json',
    'assets/stories/el_oda_el_mafoola.json',
  ];

  Future<List<StoryDefinition>> load() async {
    final bundle = _bundle ?? rootBundle;
    final stories = <StoryDefinition>[];
    for (final path in assetPaths) {
      stories.add(StoryDefinition.decode(await bundle.loadString(path)));
    }
    stories.sort((a, b) => a.number.compareTo(b.number));
    return stories;
  }
}
