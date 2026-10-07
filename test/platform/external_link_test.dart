import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/links/external_link.dart';

void main() {
  test('a reserved link commits once and cancellation opens nothing', () async {
    var opened = 0;
    var cancelled = 0;
    final committed = ExternalLinkReservation(
      commit: () {
        opened++;
        return true;
      },
      cancel: () => cancelled++,
    );
    expect(await committed.commit(), isTrue);
    expect(await committed.commit(), isFalse);
    expect(opened, 1);

    final refused = ExternalLinkReservation(
      commit: () {
        opened++;
        return true;
      },
      cancel: () => cancelled++,
    );
    refused.cancel();
    expect(await refused.commit(), isFalse);
    expect(opened, 1);
    expect(cancelled, 1);
  });

  test('web reserves in the tap and falls back to the same tab', () {
    final source = File(
      'lib/platform/links/external_link_browser.dart',
    ).readAsStringSync();
    expect(source, contains("web.window.open('', '_blank')"));
    expect(source, contains('web.window.location.href = uri.toString()'));
    expect(source, contains('reserved?.close()'));
  });

  test('native links leave Flutter through the external application', () {
    final source = File(
      'lib/platform/links/external_link_stub.dart',
    ).readAsStringSync();
    expect(source, contains('LaunchMode.externalApplication'));
  });
}
