import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_catalog.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.good, this.bad);
  final String good;
  final Set<String> bad;

  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (bad.contains(key)) return '{not json';
    if (key == StoryCatalog.assetPaths.last) throw StateError('missing');
    return good;
  }
}

void main() {
  test('one bad or missing story is skipped, the rest still load', () async {
    final good = File(
      'assets/stories/qahwet_el_moallem.json',
    ).readAsStringSync();
    final catalog = StoryCatalog(
      bundle: _Bundle(good, {StoryCatalog.assetPaths.first}),
    );
    final stories = await catalog.load();
    expect(stories, hasLength(StoryCatalog.assetPaths.length - 2));
  });
}
