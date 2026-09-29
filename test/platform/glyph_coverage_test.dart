import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every character the app draws must be in a bundled face
/// (IBM Plex Sans Arabic / Cairo / Bebas Neue), or it draws as an empty box
/// wherever the platform has no fallback for it — a web build before its
/// fallback font arrives, a phone without the symbol font, and every
/// screenshot the store listing is made from. «⏱», «▸», «◈», «✓», «←» and
/// «≈» all did.
///
/// The coverage below is IBM Plex Sans Arabic's own character map (the body
/// face), read once with fontTools. Emoji are allowed only in the reactions,
/// where the system emoji font is the intended face.
bool _covered(int c) =>
    c < 0x80 ||
    (c >= 0xA0 && c <= 0xFF) ||
    (c >= 0x600 && c <= 0x6FF) ||
    (c >= 0x750 && c <= 0x77F) ||
    (c >= 0x8A0 && c <= 0x8FF) ||
    const {
      0x2010, 0x2013, 0x2014, 0x2015, 0x2018, 0x2019, 0x201A, 0x201C, //
      0x201D, 0x201E, 0x2020, 0x2021, 0x2022, 0x2026, 0x2030, 0x2039,
      0x203A, 0x2044, 0x20AC, 0x2212,
      // Invisible: bidi marks and isolates, joiners, the emoji selector.
      0x200C, 0x200D, 0x200E, 0x200F, 0x2066, 0x2067, 0x2068, 0x2069,
      0xFE0F,
    }.contains(c) ||
    (c >= 0xFB50 && c <= 0xFDFF) ||
    (c >= 0xFE70 && c <= 0xFEFF);

const _emojiFiles = {'lib/ui/fun/reactions.dart'};

/// A line with its comment removed (a `//` outside a string literal).
String _code(String line) {
  var quote = '';
  for (var i = 0; i < line.length - 1; i++) {
    final ch = line[i];
    if (quote.isEmpty && (ch == "'" || ch == '"')) {
      quote = ch;
    } else if (quote.isNotEmpty && ch == quote && line[i - 1] != r'\') {
      quote = '';
    } else if (quote.isEmpty && ch == '/' && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

void main() {
  test('every drawn character is in a bundled font', () {
    final files = [
      ...Directory('lib').listSync(recursive: true).whereType<File>().where(
        (f) =>
            f.path.endsWith('.dart') &&
            !f.path.contains('case_of_day') &&
            !f.path.contains('app_localizations'),
      ),
      File('lib/app/l10n/app_ar.arb'),
      File('lib/app/l10n/app_en.arb'),
    ];
    final missing = <String>[];
    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = path.endsWith('.arb') ? lines[i] : _code(lines[i]);
        for (final rune in code.runes) {
          if (_covered(rune)) continue;
          if (_emojiFiles.contains(path) && rune >= 0x2600) continue;
          missing.add(
            '$path:${i + 1} U+${rune.toRadixString(16).toUpperCase()} '
            '${String.fromCharCode(rune)}',
          );
        }
      }
    }
    expect(missing, isEmpty);
  });
}
