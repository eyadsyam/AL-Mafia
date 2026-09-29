import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// F10 import closure: Partner, bonds and titles are absent — not merely
/// hidden — from every hand-off, reveal, night and live-seat surface, online
/// as well as pass-and-play. The titles/Partner file may only be reached from
/// Profile, the Casebook, Home, the lobby plate and the result.
void main() {
  const privateAndLiveRoots = <String>[
    'lib/ui/widgets/pass_screen.dart',
    'lib/ui/widgets/turn_shell.dart',
    'lib/ui/widgets/role_card.dart',
    'lib/ui/screens/night/night_action_screen.dart',
    'lib/ui/screens/distribution/role_reveal_screen.dart',
    // Online live seats and the online table's phase chrome.
    'lib/ui/screens/online/table/table_scene.dart',
    'lib/ui/screens/online/table/table_mood.dart',
    'lib/ui/screens/online/table/table_pulse.dart',
    'lib/ui/screens/online/table/connection_weather.dart',
  ];
  const banned = <String>[
    'lib/ui/social/titles_partner.dart',
    'lib/data/character_bonds.dart',
    'lib/ui/fun/character_dossiers.dart',
    // Store truth: a buyer's own identity, the «القعدة» dressing and the
    // purchase moment never reach a private surface either.
    'lib/ui/economy/my_cosmetics.dart',
    'lib/ui/economy/my_identity.dart',
    'lib/ui/economy/pass_table_dress.dart',
    'lib/ui/economy/purchase_reveal.dart',
    // Invites that reach the phone: the sheet, the popup, the directory and
    // the push plumbing are never reachable from a private surface (the popup
    // is drawn above the app and waits out private phases on its own).
    'lib/ui/screens/online/invite_sheet.dart',
    'lib/ui/social/incoming_invite.dart',
    'lib/ui/social/directory.dart',
    'lib/ui/social/directory_settings.dart',
    'lib/ui/social/push_prompt.dart',
    'lib/platform/push/push_service.dart',
    'lib/platform/push/firebase_push_service.dart',
  ];

  final importPattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);

  String? resolve(String directive, String from) {
    if (directive.startsWith('package:mafia_master/')) {
      return 'lib/${directive.substring('package:mafia_master/'.length)}';
    }
    if (directive.startsWith('package:') || directive.startsWith('dart:')) return null;
    final stack = <String>[];
    for (final segment in [
      ...from.substring(0, from.lastIndexOf('/')).split('/'),
      ...directive.split('/'),
    ]) {
      if (segment == '.' || segment.isEmpty) continue;
      if (segment == '..') {
        if (stack.isNotEmpty) stack.removeLast();
      } else {
        stack.add(segment);
      }
    }
    return stack.join('/');
  }

  // Doc 05: a push payload is a room code, the sender's name and handle and
  // the invite id. The push and invite files cannot even name a role or read
  // a match's private state.
  test('the push and invite files never import a role or a private view', () {
    const files = [
      'lib/platform/push/push_service.dart',
      'lib/platform/push/firebase_push_service.dart',
      'lib/ui/social/directory.dart',
      'lib/ui/social/incoming_invite.dart',
      'lib/ui/social/push_prompt.dart',
      'lib/ui/screens/online/invite_sheet.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final m in importPattern.allMatches(source)) {
        final target = m.group(1)!;
        expect(
          target.contains('engine/') &&
              !target.endsWith("engine/models/player.dart"),
          isFalse,
          reason: '$path imports $target',
        );
        expect(target, isNot(contains('transport/game_snapshot')));
        expect(target, isNot(contains('private')));
      }
      expect(RegExp(r'\brole\b').hasMatch(source), isFalse, reason: path);
    }
  });

  for (final root in privateAndLiveRoots) {
    test('$root never reaches titles, Partner or bonds', () {
      expect(File(root).existsSync(), isTrue, reason: 'renamed root: $root');
      final seen = <String>{};
      final queue = [root];
      while (queue.isNotEmpty) {
        final path = queue.removeLast();
        if (!seen.add(path)) continue;
        final file = File(path);
        if (!file.existsSync()) continue;
        for (final m in importPattern.allMatches(file.readAsStringSync())) {
          final target = resolve(m.group(1)!, path);
          if (target != null) queue.add(target);
        }
      }
      expect(seen.length, greaterThan(1), reason: 'the walk found nothing');
      for (final file in banned) {
        expect(seen, isNot(contains(file)), reason: '$root reaches $file');
      }
    });
  }
}
