import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/western_digits.dart';

/// Every number in the app is written with Western digits, in Arabic too
/// (owner, 2026-11-11): never «3 من ٤» on one line.
void main() {
  test('locale-formatted text comes back in Western digits', () {
    expect(westernDigits('١١ نوفمبر ٢٠٢٦، ٩:٠٥'), '11 نوفمبر 2026، 9:05');
    expect(westernDigits('۳ من ۴'), '3 من 4');
    expect(westernDigits('3 من 4'), '3 من 4');
  });

  test('the Arabic copy holds no Arabic-Indic digit', () {
    final arb = File('lib/app/l10n/app_ar.arb').readAsStringSync();
    final found = RegExp('[٠-٩۰-۹]').allMatches(arb);
    expect(found, isEmpty, reason: 'write numbers as 0-9 in app_ar.arb');
  });
}
