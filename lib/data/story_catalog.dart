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
  Future<List<StoryDefinition>> load() async {
    final bundle = _bundle ?? rootBundle;
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
