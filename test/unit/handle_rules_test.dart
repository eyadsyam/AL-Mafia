import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/account/handle_rules.dart';

/// The client rules mirror the server's `directory_set_handle` check and
/// `directory_free_handle` suggestion; these pin the client side.
void main() {
  group('handlePattern', () {
    test('accepts Latin, digits, underscore and Arabic, 3 to 20 long', () {
      for (final ok in ['abc', 'Eyad_99', 'سيد_المافيا', 'لاعب٧', 'a' * 20]) {
        expect(handlePattern.hasMatch(ok), isTrue, reason: ok);
      }
    });

    test('refuses too short, too long, spaces and symbols', () {
      for (final bad in ['ab', 'a' * 21, 'two words', 'dash-ed', '@eyad', '']) {
        expect(handlePattern.hasMatch(bad), isFalse, reason: bad);
      }
    });
  });

  group('suggestHandle', () {
    test('spaces become one underscore, symbols go', () {
      expect(suggestHandle('  Eyad   Syam! '), 'Eyad_Syam');
      expect(suggestHandle('سيد المافيا'), 'سيد_المافيا');
    });

    test('keeps at most 16 characters', () {
      expect(suggestHandle('abcdefghijklmnopqrstuvwxyz'), 'abcdefghijklmnop');
    });

    test('falls back to player when fewer than 3 are left', () {
      expect(suggestHandle(''), 'player');
      expect(suggestHandle('!!'), 'player');
      expect(suggestHandle('a.b'), 'player');
    });

    test('every suggestion passes the handle rule', () {
      for (final name in ['Eyad Syam', 'نور', '', '***', 'x' * 40]) {
        expect(
          handlePattern.hasMatch(suggestHandle(name)),
          isTrue,
          reason: name,
        );
      }
    });
  });
}
