// Each game keeps its own look (owner, 2026-10-09 «كل لعبة ليها هويتها»;
// 2026-10-16 «البرنامج كله بهوية لعبة المافيا و جزء القصص تحسه لعبة تانية
// جوا لعبة المافيا»). Mafia is Home's look everywhere; «قصص وتحقيقات» has
// its own palette, paper, stamps, Ruqaa and buttons, and starts only once
// it is tapped. The two share coins, rewards and identity-neutral pieces
// (spacing, radii, motion, the hold pad's mechanism, Semantics helpers).
//
// Plan: docs/plans/MAFIA-CORE-AUDIT-PLAN.md §7 (D13–D15).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Stories-only names a Mafia file must never use.
final _storiesOnly = RegExp(
  r'\b(StoryDeckTokens|StoryPalette|CaseFileTokens|CaseFilePaper|CaseStamp|'
  r'CaseStampDrop|CaseFileTabs|CaseFileSheet|StoriesLampTokens|StoryButton|'
  r'StoryRimButton)\b|StoryTokens\.ruqaa|Aref Ruqaa|screens/stories/widgets/',
);

/// Mafia's deck colours and pieces a Stories file must never use. Deck
/// motion, geometry and type helpers (`DeckTokens.slide`, `DeckTokens.meta`)
/// are identity-neutral and allowed, as are [DeckPress], [DeckRise] and the
/// hold pad.
final _mafiaOnly = RegExp(
  r'\bDeckTokens\.(ground|panel|raised|line|text|text2|muted|silver|'
  r'silverLight|bone|bonePressed|gold|goldLight|goldDeep|ink|seam|'
  r'verdictTown|verdictMafia)\b|'
  r'\b(BoneButton|RimButton|GoldButton|DeckScaffold|showDeckSheet|'
  r'DeckHeader|ArtCard|ArtWindow|DeckRow|DeckPanel|DeckSeal|DeckSealDrop|'
  r'DeckTabs|DeckTabPage)\b|widgets/deck/deck_public\.dart|'
  r'widgets/deck/deck_paper\.dart',
);

/// Files that hold both identities by design: the one token file, and the
/// router, which wraps the stories route in the stories palette.
const _bothAllowed = {'lib/ui/theme/design_tokens.dart', 'lib/app/router.dart'};

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _path(File f) => f.path.replaceAll(r'\', '/');

bool _isStories(String path) => path.startsWith('lib/ui/screens/stories/');

/// Comments may name the other identity (to say it is not used here).
String _code(File f) => f
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  test('Mafia screens never use the stories look', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib')) {
      final path = _path(file);
      if (_isStories(path) || _bothAllowed.contains(path)) continue;
      for (final m in _storiesOnly.allMatches(_code(file))) {
        offenders.add('$path: ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the stories never borrow Mafia deck colours or pieces', () {
    final offenders = <String>[];
    for (final file in _dartFiles('lib/ui/screens/stories')) {
      for (final m in _mafiaOnly.allMatches(_code(file))) {
        offenders.add('${_path(file)}: ${m.group(0)}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test("Mafia's public deck ground is Home's ground", () {
    final tokens = File('lib/ui/theme/design_tokens.dart').readAsStringSync();
    expect(
      tokens,
      contains('static const Color ground = AppColors.groundBase;'),
      reason: 'DeckTokens.ground must follow Home (D15)',
    );
  });

  test('the guard sees both sides (the patterns are live)', () {
    expect(_storiesOnly.hasMatch('CaseFilePaper('), isTrue);
    expect(_storiesOnly.hasMatch('StoryTokens.ruqaa(x)'), isTrue);
    expect(_mafiaOnly.hasMatch('DeckTokens.bone'), isTrue);
    expect(_mafiaOnly.hasMatch('BoneButton('), isTrue);
    expect(_mafiaOnly.hasMatch('DeckTokens.slide'), isFalse);
  });
}
