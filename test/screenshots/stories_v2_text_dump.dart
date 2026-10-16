/// Dumps every text the players see when five people play the Stories V2
/// case «قهوة المعلم», with a screenshot of each screen, for the owner's
/// text-editing page. **Not a test** (no `_test` suffix, asserts nothing).
///
///     flutter test test/screenshots/stories_v2_text_dump.dart
///
/// Writes `build/stories_v2_editor/texts.json` and one
/// `build/stories_v2_editor/png/<id>.png` per screen (a separate Python step
/// turns those into `screens/<id>.jpg`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/data/story_v2_memory.dart';
import 'package:mafia_master/platform/narration_controller.dart';
import 'package:mafia_master/stories/story_model.dart';
import 'package:mafia_master/stories/story_progress.dart';
import 'package:mafia_master/stories/v2/table.dart';
import 'package:mafia_master/stories/v2/world.dart';
import 'package:mafia_master/ui/screens/stories/stories_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_about_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_lobby_screen.dart';
import 'package:mafia_master/ui/screens/stories/v2/story_table_screen.dart';

import '../support/localized.dart';

const _phone = Size(412, 915);
const _out = 'build/stories_v2_editor';
const _long = Timeout(Duration(minutes: 10));

const _worldPath = 'assets/stories_v2/qahwet_el_moallem.json';
final _world = StoryWorld.decode(File(_worldPath).readAsStringSync());
final _cafe = StoryDefinition.decode(
  File('assets/stories/qahwet_el_moallem.json').readAsStringSync(),
);
const _names = ['أحمد', 'مريم', 'كريم', 'ياسمين', 'عمر'];
const _seed = 11;

class _Silent implements NarrationPlayer {
  final _d = StreamController<Duration>.broadcast();
  @override
  Stream<Duration> get positions => const Stream.empty();
  @override
  Stream<Duration> get durations => _d.stream;
  @override
  Stream<void> get completions => const Stream.empty();
  @override
  Future<void> start(String assetKey) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

Future<void> _fonts() async {
  const fonts = {
    'Roboto': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'IBM Plex Sans Arabic': 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
    'Bebas Neue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Cairo': 'assets/fonts/Cairo-Variable.ttf',
    'Aref Ruqaa': 'assets/fonts/ArefRuqaa-Bold.ttf',
    'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
  };
  for (final entry in fonts.entries) {
    final loader = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
    await loader.load();
  }
}

// ---- what is on screen ------------------------------------------------------

class _Shown {
  _Shown(this.text, this.rect, {required this.scrolls});
  final String text;
  final Rect rect;

  /// Inside a scroll viewport (the page's own content), not a bar or footer.
  final bool scrolls;
}

class _Screen {
  _Screen(this.id, this.label, this.who, this.texts);
  final String id;
  final String label;
  final String? who;
  final List<String> texts;
}

/// Icon glyphs are drawn as one-character RichTexts in an icon font.
bool _isIcon(RichText widget, String text) {
  final family = widget.text.style?.fontFamily ?? '';
  if (family.endsWith('MaterialIcons') || family.endsWith('CupertinoIcons')) {
    return true;
  }
  return text.runes.every((r) => r >= 0xE000 && r <= 0xF8FF);
}

/// Whether a player can see any of [rect]: inside the screen, inside every
/// scroll viewport above it (a built-but-clipped row is not on screen) and not
/// faded out (a text field's hint stays built, at opacity 0, once it is
/// filled).
bool _isShown(RenderBox box, Rect rect, Rect screen) {
  var shown = rect;
  RenderObject? up = box.parent;
  while (up != null) {
    if (up is RenderBox && up is RenderAbstractViewport) {
      shown = shown.intersect(up.localToGlobal(Offset.zero) & up.size);
    }
    if (up is RenderOpacity && up.opacity == 0) return false;
    if (up is RenderAnimatedOpacity && up.opacity.value == 0) return false;
    up = up.parent;
  }
  shown = shown.intersect(screen);
  return shown.width > 0.5 && shown.height > 0.5;
}

bool _inViewport(RenderBox box) {
  RenderObject? up = box.parent;
  while (up != null) {
    if (up is RenderAbstractViewport) return true;
    up = up.parent;
  }
  return false;
}

Rect _screenRect(WidgetTester tester) =>
    Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);

/// Every RichText on stage in this frame that intersects the screen, in
/// reading order: top to bottom (rows within 6 px are one row), then right to
/// left. [scope] narrows it to one subtree (a bottom sheet).
List<_Shown> _visibleTexts(WidgetTester tester, Finder? scope) {
  final screen = _screenRect(tester);
  final finder = scope == null
      ? find.byType(RichText)
      : find.descendant(of: scope, matching: find.byType(RichText));
  final items = <_Shown>[];
  for (final element in finder.evaluate()) {
    final widget = element.widget as RichText;
    final text = widget.text.toPlainText().trim();
    if (text.isEmpty || _isIcon(widget, text)) continue;
    final box = element.renderObject;
    if (box is! RenderBox || !box.attached || !box.hasSize) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (!_isShown(box, rect, screen)) continue;
    items.add(_Shown(text, rect, scrolls: _inViewport(box)));
  }
  items.sort((a, b) => a.rect.top.compareTo(b.rect.top));
  final rows = <List<_Shown>>[];
  for (final item in items) {
    if (rows.isNotEmpty && item.rect.top - rows.last.first.rect.top <= 6) {
      rows.last.add(item);
    } else {
      rows.add([item]);
    }
  }
  return [
    for (final row in rows)
      ...(row..sort((a, b) => b.rect.right.compareTo(a.rect.right))),
  ];
}

List<ScrollableState> _scrollables(Finder? scope, Axis axis) {
  final finder = scope == null
      ? find.byType(Scrollable)
      : find.descendant(of: scope, matching: find.byType(Scrollable));
  return [
    for (final e in finder.evaluate())
      if (e is StatefulElement &&
          e.state is ScrollableState &&
          (e.state as ScrollableState).widget.axis == axis)
        e.state as ScrollableState,
  ];
}

bool _hasRoom(ScrollPosition p) =>
    p.hasContentDimensions && p.maxScrollExtent >= 1;

/// The texts on this screen: the first screenful, then the rest of the page
/// scrolled through (and any horizontal strip on it), each pass read with the
/// same on-screen rule. Bars above the page come first and footers last;
/// everything is put back where it was.
Future<List<String>> _collect(WidgetTester tester, Finder? scope) async {
  final pages = [
    for (final st in _scrollables(scope, Axis.vertical))
      if (_hasRoom(st.position)) st,
  ];
  Rect? page;
  if (pages.isNotEmpty) {
    final box = pages.first.context.findRenderObject()! as RenderBox;
    page = box.localToGlobal(Offset.zero) & box.size;
  }
  final head = <String>[];
  final body = <String>[];
  final foot = <String>[];
  void add() {
    for (final item in _visibleTexts(tester, scope)) {
      if (head.contains(item.text) ||
          body.contains(item.text) ||
          foot.contains(item.text)) {
        continue;
      }
      final bar = page != null && !item.scrolls;
      if (bar && item.rect.bottom <= page.top + 1) {
        head.add(item.text);
      } else if (bar && item.rect.top >= page.bottom - 1) {
        foot.add(item.text);
      } else {
        body.add(item.text);
      }
    }
  }

  Future<void> across() async {
    final screen = _screenRect(tester);
    for (final st in _scrollables(scope, Axis.horizontal)) {
      final p = st.position;
      if (!_hasRoom(p)) continue;
      final box = st.context.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (!screen.overlaps(box.localToGlobal(Offset.zero) & box.size)) continue;
      final home = p.pixels;
      for (
        var guard = 0;
        p.pixels < p.maxScrollExtent - 0.5 && guard < 60;
        guard++
      ) {
        p.jumpTo(
          math.min(p.pixels + p.viewportDimension * 0.8, p.maxScrollExtent),
        );
        await tester.pump(const Duration(milliseconds: 50));
        add();
      }
      p.jumpTo(home);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  add();
  await across();
  if (pages.isNotEmpty) {
    final p = pages.first.position;
    final home = p.pixels;
    for (
      var guard = 0;
      p.pixels < p.maxScrollExtent - 0.5 && guard < 60;
      guard++
    ) {
      p.jumpTo(
        math.min(p.pixels + p.viewportDimension * 0.8, p.maxScrollExtent),
      );
      await tester.pump(const Duration(milliseconds: 50));
      add();
      await across();
    }
    p.jumpTo(home);
    await tester.pump(const Duration(milliseconds: 50));
  }
  return [...head, ...body, ...foot];
}

// ---- where a text comes from -------------------------------------------------

class _Leaf {
  _Leaf(this.path, this.key, this.value, this.segments);
  final String path;
  final String key;
  final String value;
  final List<String> segments;

  static final _technical = RegExp(r'^[\x21-\x7E]+$');
  static const _notText = {'id', 'gender', 'image', 'openingAudio', 'format'};

  /// Prose the app can show: not an id, a flag, an asset path or an
  /// identifier.
  bool get isText => !_notText.contains(key) && !_technical.hasMatch(value);

  /// Prose the owner may still want to edit when no screen showed it. The
  /// world's `marks` (their names and matching words) are never shown, so
  /// they are not offered for editing here.
  bool get isEditable =>
      isText &&
      key != 'category' &&
      (segments.isEmpty || segments[0] != 'marks');
}

List<_Leaf> _leaves(Object? node) {
  final out = <_Leaf>[];
  void walk(Object? n, List<String> path, String key) {
    if (n is Map) {
      for (final e in n.entries) {
        walk(e.value, [...path, '${e.key}'], '${e.key}');
      }
    } else if (n is List) {
      for (final (i, v) in n.indexed) {
        final id = v is Map && v['id'] is String ? v['id'] as String : '$i';
        walk(v, [...path, id], key);
      }
    } else if (n is String) {
      out.add(_Leaf('story:${path.join('.')}', key, n, path));
    }
  }

  walk(node, const [], '');
  return out;
}

class _ArbPattern {
  _ArbPattern(this.key, this.regex, this.literal);
  final String key;
  final RegExp regex;
  final int literal;
}

class _Sourcer {
  _Sourcer(Map<String, Object?> ar, Map<String, Object?> en, this.leaves) {
    final holder = RegExp(r'\{(\w+)\}');
    for (final e in ar.entries) {
      final value = e.value;
      if (e.key.startsWith('@') || value is! String) continue;
      if (!value.contains('{')) {
        _exact.putIfAbsent(value, () => []).add(e.key);
        continue;
      }
      if (value.contains(', plural') || value.contains(', select')) continue;
      final meta = en['@${e.key}'];
      final holders = meta is Map ? meta['placeholders'] : null;
      var source = '';
      var last = 0;
      var literal = 0;
      for (final m in holder.allMatches(value)) {
        final chunk = value.substring(last, m.start);
        literal += chunk.replaceAll(RegExp(r'\s'), '').length;
        source += RegExp.escape(chunk);
        final spec = holders is Map ? holders[m.group(1)] : null;
        final type = spec is Map ? spec['type'] : null;
        source += type == 'int' || type == 'double' || type == 'num'
            ? r'[\d٠-٩]+(?:[.,٫٬][\d٠-٩]+)*'
            : '(.+?)';
        last = m.end;
      }
      final tail = value.substring(last);
      literal += tail.replaceAll(RegExp(r'\s'), '').length;
      source += RegExp.escape(tail);
      if (literal < 2) continue;
      _patterns.add(
        _ArbPattern(e.key, RegExp('^$source\$', dotAll: true), literal),
      );
    }
    _patterns.sort((a, b) => b.literal.compareTo(a.literal));
    for (final leaf in leaves.where((l) => l.isText)) {
      _worldExact.putIfAbsent(leaf.value, () => leaf.path);
    }
    _byLength = [
      for (final l in leaves)
        if (l.isText) l,
    ]..sort((a, b) => b.value.length.compareTo(a.value.length));
  }

  final List<_Leaf> leaves;
  final _exact = <String, List<String>>{};
  final _patterns = <_ArbPattern>[];
  final _worldExact = <String, String>{};
  late final List<_Leaf> _byLength;

  /// Keys that hold the same words and that the screen's own code both asks
  /// for: the pick between them is a guess.
  final ambiguous = <String, List<String>>{};

  static int _rank(String key) =>
      key.startsWith('sv2') ? 0 : (key.startsWith('stories') ? 1 : 2);

  /// The best of [keys]: the ones this screen's code asks for, then Stories
  /// V2 keys, then file order.
  String _pick(String text, List<String> keys, Set<String>? region) {
    var pool = keys;
    if (region != null) {
      final near = [
        for (final k in keys)
          if (region.contains(k)) k,
      ];
      if (near.isNotEmpty) pool = near;
    }
    if (pool.length > 1) ambiguous[text] = pool;
    var best = pool.first;
    for (final k in pool.skip(1)) {
      if (_rank(k) < _rank(best)) best = k;
    }
    return best;
  }

  /// Where [text] on screen [screenId] comes from. The order: the app's own
  /// words, a world string that is the whole text, a placeholder line the
  /// screen's code builds, a line assembled from world strings, and last any
  /// placeholder line (a text-shaped template such as «{name} كان {role}» also
  /// fits sentences of the story, so it only gets a say when nothing else
  /// does).
  String of(String text, String screenId) {
    final region = _regionKeys(screenId);
    final keys = _exact[text];
    if (keys != null) return 'arb:${_pick(text, keys, region)}';
    final path = _worldExact[text];
    if (path != null) return path;
    final matches = [
      for (final p in _patterns)
        if (p.regex.hasMatch(text)) p,
    ];
    final near = [
      for (final p in matches)
        if (region == null || region.contains(p.key)) p,
    ];
    if (near.isNotEmpty) return 'arb:${_pickPattern(text, near, region)}';
    // Lines assembled from several world strings: longest first, and a
    // string already found inside a longer one is not counted again.
    var left = text;
    final found = <(int, String)>[];
    for (final leaf in _byLength) {
      if (!left.contains(leaf.value)) continue;
      found.add((text.indexOf(leaf.value), leaf.path));
      left = left.replaceAll(leaf.value, '\u0000' * leaf.value.length);
    }
    if (found.isNotEmpty) {
      found.sort((a, b) => a.$1.compareTo(b.$1));
      return found.map((f) => f.$2).join('+');
    }
    if (matches.isNotEmpty) {
      return 'arb:${_pickPattern(text, matches, region)}';
    }
    return '';
  }

  String _pickPattern(
    String text,
    List<_ArbPattern> found,
    Set<String>? region,
  ) {
    final most = found.first.literal;
    return _pick(text, [
      for (final p in found)
        if (p.literal == most) p.key,
    ], region);
  }
}

// ---- which code builds which screen ---------------------------------------------

const _lobbyFile = 'lib/ui/screens/stories/v2/story_lobby_screen.dart';
const _tableFile = 'lib/ui/screens/stories/v2/story_table_screen.dart';
const _aboutFile = 'lib/ui/screens/stories/v2/story_about_screen.dart';
const _hubFile = 'lib/ui/screens/stories/stories_screen.dart';
const _kitFile = 'lib/ui/screens/stories/v2/lamp_kit.dart';

/// Per screen group: the files, and the members of a file that build it
/// (null = the whole file).
const _builders = <String, List<(String, Set<String>?)>>{
  's01_about': [(_aboutFile, null)],
  's02_hub': [(_hubFile, null), (_kitFile, null)],
  's03_file': [
    (_lobbyFile, {'_file', 'build', 'showStoryCard'}),
    (_kitFile, null),
  ],
  's04_count': [
    (_lobbyFile, {'_namesPage', '_submitNames'}),
  ],
  's05_names': [
    (_lobbyFile, {'_namesPage', '_submitNames'}),
  ],
  's06_how': [
    (_lobbyFile, {'_howTo', '_cards'}),
  ],
  's07_cast': [
    (_tableFile, {'_cast'}),
  ],
  's08_pass': [
    (_tableFile, {'_handoff'}),
  ],
  's08_card': [
    (_tableFile, {'_card'}),
  ],
  's08_secret': [
    (_tableFile, {'_card', '_secret', '_secretLines'}),
  ],
  's09_desk': [
    (_tableFile, {'_desk', '_replay'}),
    (_lobbyFile, {'build', 'showStoryCard'}),
    (_kitFile, null),
  ],
  's10_found': [
    (_tableFile, {'_showFound'}),
  ],
  's11_decision': [
    (_tableFile, {'_decision', '_option'}),
  ],
  's12_reveal': [
    (_tableFile, {'_reveal'}),
  ],
  's13_result': [
    (_tableFile, {'_result', '_mark', '_roleChip'}),
  ],
  's14_exit': [
    (_tableFile, {'_exitSheet'}),
  ],
};

/// s08_3_pass -> s08_pass, s06_how_2 -> s06_how.
String _group(String id) => id
    .replaceFirstMapped(
      RegExp(r'^(s\d\d)_\d+_(\w+)$'),
      (m) => '${m[1]}_${m[2]}',
    )
    .replaceFirst(RegExp(r'_\d+$'), '');

final _keysByMemberCache = <String, Map<String, Set<String>>>{};

/// The ARB keys (`l.key`, `context.l10n.key`) each member of a source file
/// asks for.
Map<String, Set<String>> _keysByMember(String path) =>
    _keysByMemberCache.putIfAbsent(path, () {
      final out = <String, Set<String>>{};
      final declaration = RegExp(r'^ {0,2}(?:[A-Za-z]|\([\w, ]+\)\s)');
      final name = RegExp(r'(_?[A-Za-z]\w*)(?:<[^()]*>)?\s*\(');
      final used = RegExp(r'\b(?:l|l10n)\.(\w+)');
      var member = '';
      for (final line in File(path).readAsLinesSync()) {
        if (declaration.hasMatch(line)) {
          final m = name.firstMatch(line);
          if (m != null) member = m.group(1)!;
        }
        for (final m in used.allMatches(line)) {
          out.putIfAbsent(member, () => {}).add(m.group(1)!);
        }
      }
      return out;
    });

/// The ARB keys the code behind [screenId] asks for; null when unknown.
Set<String>? _regionKeys(String screenId) {
  final parts = _builders[_group(screenId)];
  if (parts == null) return null;
  return {
    for (final (file, members) in parts)
      for (final e in _keysByMember(file).entries)
        if (members == null || members.contains(e.key)) ...e.value,
  };
}

// ---- the run -------------------------------------------------------------------

void main() {
  final png = Directory('$_out/png')..createSync(recursive: true);
  Directory('$_out/screens').createSync(recursive: true);
  final screens = <_Screen>[];

  tearDownAll(() {
    final ar =
        jsonDecode(File('lib/app/l10n/app_ar.arb').readAsStringSync())
            as Map<String, Object?>;
    final en =
        jsonDecode(File('lib/app/l10n/app_en.arb').readAsStringSync())
            as Map<String, Object?>;
    final raw = jsonDecode(File(_worldPath).readAsStringSync());
    final leaves = _leaves(raw);
    final sourcer = _Sourcer(ar, en, leaves);

    var total = 0;
    final empty = <String>[];
    final screenJson = <Map<String, Object?>>[];
    for (final s in screens) {
      final texts = <Map<String, Object?>>[];
      for (final (i, t) in s.texts.indexed) {
        final source = sourcer.of(t, s.id);
        total++;
        if (source.isEmpty) empty.add('${s.id}: $t');
        texts.add({
          'id': 't${(i + 1).toString().padLeft(2, '0')}',
          'text': t,
          'source': source,
        });
      }
      screenJson.add({
        'id': s.id,
        'label': s.label,
        'who': ?s.who,
        'image': 'screens/${s.id}.jpg',
        'texts': texts,
      });
    }

    final table = StoryTable.deal(world: _world, players: _names, seed: _seed);
    final shown = [for (final s in screens) ...s.texts];
    final rest = <Map<String, Object?>>[];
    void group(String id, String label, bool Function(_Leaf) belongs) {
      final texts = <Map<String, Object?>>[];
      for (final leaf in leaves) {
        if (!leaf.isEditable || !belongs(leaf)) continue;
        if (shown.any((t) => t.contains(leaf.value))) continue;
        texts.add({
          'id': 't${(texts.length + 1).toString().padLeft(2, '0')}',
          'text': leaf.value,
          'source': leaf.path,
        });
      }
      if (texts.isNotEmpty) {
        rest.add({'id': id, 'label': label, 'texts': texts});
      }
    }

    for (final s in _world.suspects) {
      group(
        'r_${s.id}',
        table.seatOf(s.id) == null
            ? '${s.name} (مش في القعدة دي)'
            : '${s.name}: كلام بيظهر في قعدات تانية',
        (l) =>
            l.segments.length > 1 &&
            l.segments[0] == 'suspects' &&
            l.segments[1] == s.id,
      );
    }
    for (final p in _world.places) {
      group(
        'r_${p.id}',
        p.name,
        (l) =>
            l.segments.length > 1 &&
            l.segments[0] == 'places' &&
            l.segments[1] == p.id,
      );
    }
    group(
      'r_story',
      'القصة',
      (l) =>
          l.segments.isEmpty ||
          (l.segments[0] != 'suspects' && l.segments[0] != 'places'),
    );

    final restCount = rest.fold<int>(
      0,
      (n, g) => n + (g['texts']! as List<Object?>).length,
    );
    File('$_out/texts.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'story': {'id': _world.id, 'title': _world.title},
        'players': _names,
        'screens': screenJson,
        'rest': rest,
      }),
    );
    stdout
      ..writeln(
        'SCREENS ${screens.length}  TEXTS $total  NO-SOURCE ${empty.length}',
      )
      ..writeln('REST GROUPS ${rest.length}  REST TEXTS $restCount');
    for (final s in screens) {
      stdout.writeln('  ${s.id} ${s.texts.length}');
    }
    for (final e in empty) {
      stdout.writeln('NOSRC $e');
    }
    sourcer.ambiguous.forEach(
      (text, keys) => stdout.writeln('AMBIGUOUS $text -> $keys'),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> start(WidgetTester tester, Widget child) async {
    await tester.runAsync(_fonts);
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('shot'),
        child: ProviderScope(child: localizedApp(child)),
      ),
    );
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('shot')),
    );
    final image = boundary.toImageSync(pixelRatio: 1);
    await tester.runAsync(() async {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(
        '${png.path}/$name.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
    image.dispose();
  }

  /// One screen: its picture first (the top of the page), then its texts.
  Future<void> capture(
    WidgetTester tester,
    String id,
    String label, {
    String? who,
    Finder? scope,
  }) async {
    await shot(tester, id);
    screens.add(_Screen(id, label, who, await _collect(tester, scope)));
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    if (find.byKey(key).evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(find.byKey(key));
    await tester.pump();
    await tester.tap(find.byKey(key));
    await settle(tester);
  }

  Future<void> hold(WidgetTester tester) async {
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(StoryTableScreen.holdKey)),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await settle(tester);
  }

  NarrationController narration() => NarrationController(_Silent(), web: false);

  StoryTable deal() =>
      StoryTable.deal(world: _world, players: _names, seed: _seed);

  Widget tableScreen(StoryTable table) => StoryTableScreen(
    table: table,
    seed: _seed,
    narration: narration(),
    onExit: () {},
    onPlayAgain: () {},
  );

  testWidgets('about', timeout: _long, (tester) async {
    await start(tester, StoryAboutScreen(onDone: () {}));
    await capture(tester, 's01_about', 'عن القصص');
  });

  testWidgets('hub', timeout: _long, (tester) async {
    await start(
      tester,
      StoriesHub(
        stories: [_cafe],
        progress: const StoryProgress(),
        onBack: () {},
        onStart: (_, _) {},
        worldIds: {_world.id},
        onOpenWorld: (_) {},
        onHowTo: () {},
      ),
    );
    await capture(tester, 's02_hub', 'القضايا');
  });

  testWidgets('lobby', timeout: _long, (tester) async {
    await start(
      tester,
      StoryLobbyScreen(
        world: _world,
        coverImage: _cafe.coverImage,
        narration: narration(),
        memory: MemoryStoryV2Memory(about: true),
        onExit: () {},
        onPlay: (_) async {},
      ),
    );
    await capture(tester, 's03_file', 'ملف القضية');
    await tap(tester, StoryLobbyScreen.friendsKey);
    await capture(tester, 's04_count', 'كام واحد هيلعب؟');
    for (final (i, name) in _names.indexed) {
      final field = find.byKey(StoryLobbyScreen.nameKey(i));
      if (field.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          field,
          200,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.enterText(field, name);
      await tester.pump();
    }
    final page = tester.state<ScrollableState>(find.byType(Scrollable).first);
    page.position.jumpTo(0);
    await settle(tester);
    await capture(tester, 's05_names', 'الأسامي');
    await tap(tester, StoryLobbyScreen.continueKey);
    const how = [
      'إزاي نلعب: صفحة ١',
      'إزاي نلعب: صفحة ٢',
      'إزاي نلعب: صفحة ٣',
      'إزاي نلعب: صفحة ٤',
    ];
    for (final (i, label) in how.indexed) {
      await capture(tester, 's06_how_${i + 1}', label);
      if (i + 1 < how.length) await tap(tester, StoryLobbyScreen.nextKey);
    }
  });

  testWidgets('five at the table', timeout: _long, (tester) async {
    final table = deal();
    await start(tester, tableScreen(table));
    await capture(tester, 's07_cast', 'مين هيلعب مين');
    await tap(tester, StoryTableScreen.beginKey);
    for (final (i, seat) in table.seats.indexed) {
      final n = i + 1;
      final p = seat.player;
      await capture(tester, 's08_${n}_pass', 'الموبايل مع $p');
      await tap(tester, StoryTableScreen.openKey);
      await capture(
        tester,
        's08_${n}_card',
        'كارت $p',
        who: '$p بيقراه بصوت عالي',
      );
      await hold(tester);
      await capture(tester, 's08_${n}_secret', 'سر $p', who: '$p بس');
      await tap(tester, StoryTableScreen.hideKey);
    }
    await capture(tester, 's09_desk', 'مكتب المحقق');
    for (var k = 0; k < 3; k++) {
      final place = _world.places[k];
      await tap(tester, StoryTableScreen.placeKey(place.id));
      await capture(
        tester,
        's10_found_${k + 1}',
        'تفتيش: ${place.name}',
        scope: find.byType(BottomSheet),
      );
      await tap(tester, StoryTableScreen.foundBackKey);
    }
    await tap(tester, StoryTableScreen.decideKey);
    await tap(tester, StoryTableScreen.pickKey(table.culpritId));
    await capture(tester, 's11_decision', 'قرار المحقق');
    await tap(tester, StoryTableScreen.confirmKey);
    await capture(tester, 's12_reveal', 'مين اللي عملها');
    await tap(tester, StoryTableScreen.resultKey);
    await capture(tester, 's13_result', 'النتيجة');
  });

  testWidgets('leave the case', timeout: _long, (tester) async {
    await start(tester, tableScreen(deal()));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await settle(tester);
    await capture(
      tester,
      's14_exit',
      'لو حد داس رجوع',
      scope: find.byType(BottomSheet),
    );
  });
}
