import 'package:flutter/services.dart';

import '../stories/story_model.dart';

class StoryCatalog {
  const StoryCatalog({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  static const assetPaths = [
    'assets/stories/qahwet_el_moallem.json',
    'assets/stories/el_oda_el_mafoola.json',
    'assets/stories/el_atr_el_akheer.json',
    'assets/stories/cinema_rivoli.json',
    'assets/stories/el_asansir.json',
    'assets/stories/el_shahed_el_a3ma.json',
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
