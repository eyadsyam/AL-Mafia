import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_world_catalog.dart';
import 'package:mafia_master/stories/v2/world.dart';

/// The server deals V2 culprits from `story_v2_suspects`; a bundled world
/// and those rows must name the same suspects, answers and partners, or a
/// server pick would be unplayable or a right answer unpaid.
void main() {
  final rows = <String, Map<String, List<String?>>>{};
  final insert = RegExp(
    r'insert into public\.story_v2_suspects\([^)]*\) values(.*?)on conflict',
    dotAll: true,
  );
  final row = RegExp(
    r"\('([a-z0-9_]+)','([a-z0-9_]+)','([a-z0-9_]+)','([a-z0-9_]+)',"
    r"(?:'([a-z0-9_]+)'|null)\)",
  );
  for (final file in Directory('supabase/migrations').listSync()) {
    if (!file.path.endsWith('.sql')) continue;
    final sql = File(file.path).readAsStringSync();
    for (final block in insert.allMatches(sql)) {
      for (final m in row.allMatches(block.group(1)!)) {
        (rows[m.group(1)!] ??= {})[m.group(2)!] = [
          m.group(3),
          m.group(4),
          m.group(5),
        ];
      }
    }
  }

  test('every bundled world is in the asset list', () {
    final files = [
      for (final f in Directory('assets/stories_v2').listSync())
        if (f.path.endsWith('.json')) f.path.replaceAll(r'\', '/'),
    ]..sort();
    expect([...StoryWorldCatalog.assetPaths]..sort(), files);
  });

  for (final path in StoryWorldCatalog.assetPaths) {
    test('$path matches the server rows', () {
      final world = StoryWorld.decode(File(path).readAsStringSync());
      final seeded = rows[world.id];
      expect(seeded, isNotNull, reason: 'no story_v2_suspects rows');
      expect(seeded!.keys.toSet(), {for (final s in world.suspects) s.id});
      for (final suspect in world.suspects) {
        expect(seeded[suspect.id], [
          suspect.guilty.motive.id,
          suspect.guilty.method.id,
          suspect.guilty.partner?.partnerId,
        ], reason: suspect.id);
      }
    });
  }
}
