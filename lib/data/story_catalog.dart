import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

import '../stories/story_model.dart';

class StoryCatalog {
  const StoryCatalog({AssetBundle? bundle}) : _bundle = bundle;

  final AssetBundle? _bundle;

  static const assetPaths = [
    'assets/stories/qahwet_el_moallem.json',
    'assets/stories/farah_el_sotouh.json',
    'assets/stories/el_gazzar.json',
    'assets/stories/beit_el_3eila.json',
    'assets/stories/mahal_el_dahab.json',
    'assets/stories/el_atr_el_akheer.json',
    'assets/stories/mat7af_el_zamalek.json',
    'assets/stories/khaznet_el_bank.json',
    'assets/stories/el_arousa.json',
    'assets/stories/sayyad_el_borollos.json',
    'assets/stories/el_madina_el_gam3eya.json',
    'assets/stories/el_akh_el_taw2am.json',
    'assets/stories/shoqaq_el_tamleek.json',
    'assets/stories/el_sheikh_el_mo3aleg.json',
    'assets/stories/mazad_el_3arabeyat.json',
    'assets/stories/waraqet_el_yanaseeb.json',
    'assets/stories/cinema_rivoli.json',
    'assets/stories/fondo2_shepheard.json',
    'assets/stories/matba3et_el_gornal.json',
    'assets/stories/2asr_garden_city.json',
    'assets/stories/el_oda_el_mafoola.json',
    'assets/stories/el_asansir.json',
    'assets/stories/el_shahed_el_a3ma.json',
    'assets/stories/el_gareema_elly_ma7asaletsh.json',
  ];

  /// Loads every case in parallel; one that fails to read or decode is
  /// skipped (and logged) instead of failing the whole hub.
  ///
  /// From the app's own bundle the answer is read once per process and kept
  /// (the cases never change while it runs), so the app can [prefetch] it
  /// after Home settles and the first Stories visit opens without a pause.
  Future<List<StoryDefinition>> load() {
    final bundle = _bundle;
    if (bundle != null) return _read(bundle);
    return _app ??= _read(rootBundle).then((stories) {
      if (stories.isEmpty) _app = null; // nothing read: try again next time
      return stories;
    });
  }

  static Future<List<StoryDefinition>>? _app;

  /// Starts [load] for the app's bundle without waiting for it.
  static void prefetch() =>
      const StoryCatalog().load().then<void>((_) {}, onError: (_) {});

  static Future<List<StoryDefinition>> _read(AssetBundle bundle) async {
    final loaded = await Future.wait([
      for (final path in assetPaths)
        () async {
          try {
            return StoryDefinition.decode(await bundle.loadString(path));
          } on Object catch (error) {
            debugPrint('story skipped: $path ($error)');
            return null;
          }
        }(),
    ]);
    final stories = [
      for (final story in loaded)
        if (story != null) story,
    ];
    stories.sort((a, b) => a.number.compareTo(b.number));
    return stories;
  }
}
