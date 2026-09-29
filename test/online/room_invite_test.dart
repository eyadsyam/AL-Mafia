import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/room_invite.dart';

/// The invite is the one link in this project whose correctness lives in four
/// files at once: the Dart that builds it, the manifest that claims it, the
/// asset-links file that proves the claim, and the host that serves the path.
///
/// None of those import each other, so nothing fails loudly when one of them
/// moves. Renaming the Vercel project and forgetting the manifest does not
/// break a build — it silently turns every invite back into "opens a browser",
/// which is exactly the failure the App Link was added to remove, and which
/// only shows up on somebody else's phone. Hence a test that reads the other
/// three files as text.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final assetLinks =
      jsonDecode(File('web/.well-known/assetlinks.json').readAsStringSync())
          as List<dynamic>;
  final invite = Uri.parse(RoomInvite.webLink('k7m2qp'));

  test('the shared link is an https link on the published domain', () {
    expect(invite.scheme, 'https');
    expect(invite.host, 'almafia.vercel.app');
    // A path, not a fragment: Android drops everything after `#` before it
    // matches an intent filter, so a hash link can never open the app.
    expect(invite.fragment, isEmpty);
    expect(invite.path, '/join/K7M2QP');
  });

  test('Android claims exactly the links the app builds', () {
    expect(manifest, contains('android:autoVerify="true"'));
    expect(manifest, contains('android:scheme="https"'));
    expect(manifest, contains('android:host="${invite.host}"'));
    expect(manifest, contains('android:pathPrefix="/join/"'));
  });

  test('the custom scheme still resolves to the router path', () {
    expect(Uri.parse(RoomInvite.link('k7m2qp')).path, '/join/K7M2QP');
    expect(manifest, contains('android:scheme="${RoomInvite.scheme}"'));
  });

  test(
    'the asset-links file names this package, the Play signing key and the upload key',
    () {
      final target = (assetLinks.single as Map)['target'] as Map;
      expect(target['namespace'], 'android_app');
      expect(target['package_name'], 'com.mafiamaster.mafia_master');
      final fingerprints = target['sha256_cert_fingerprints'] as List;
      // Play re-signs what it installs, so the Play app-signing key must be
      // listed or no store install ever verifies; the upload key keeps
      // sideloaded release builds working too.
      expect(fingerprints, hasLength(2));
      expect(fingerprints.toSet(), hasLength(2));
      // 32 bytes, colon-separated, uppercase hex — the shape Android compares
      // against. A truncated or lowercase value verifies against nothing.
      for (final fingerprint in fingerprints) {
        expect(
          fingerprint,
          matches(RegExp(r'^([0-9A-F]{2}:){31}[0-9A-F]{2}$')),
        );
      }
    },
  );

  test('the invite text carries the code in words as well as in the link', () {
    final text = RoomInvite.text(
      'العب معانا مافيا. كود الأوضة: K7M2QP',
      'k7m2qp',
    );
    expect(text, contains('K7M2QP'));
    expect(text, contains(RoomInvite.webLink('K7M2QP')));
  });

  test('a room link carries and parses the sharer referral code', () {
    final link = Uri.parse(
      RoomInvite.webLink('k7m2qp', referralCode: '43d4yug'),
    );
    expect(link.path, '/join/K7M2QP');
    expect(link.queryParameters['ref'], '43D4YUG');
    expect(RoomInvite.referral(link), '43D4YUG');
    expect(
      Uri.parse(
        RoomInvite.link('k7m2qp', referralCode: '43d4yug'),
      ).queryParameters['ref'],
      '43D4YUG',
    );
  });

  test(
    'invalid referral data is omitted instead of sharing a broken offer',
    () {
      expect(
        Uri.parse(RoomInvite.webLink('K7M2QP', referralCode: 'IIIIIII')).query,
        isEmpty,
      );
      expect(RoomInvite.referral(Uri.parse('/join/K7M2QP?ref=BAD')), isNull);
    },
  );
}
