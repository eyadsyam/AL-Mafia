import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/economy/council_hub.dart';

/// A shared council invite opens the installed app first: its link lives on
/// the verified host under a path the manifest claims, and the web shell hands
/// the same path to the app on Android.
void main() {
  test('the invite link is the site, /invite/, and the upper-cased code', () {
    expect(
      councilInviteLink('k7qm2xa'),
      'https://saidalmafia.com/invite/K7QM2XA',
    );
  });

  test('the manifest claims /join/, /invite/ and the root for App Links', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:pathPrefix="/join/"'));
    expect(manifest, contains('android:pathPrefix="/invite/"'));
    expect(manifest, contains('android:path="/"'));
  });

  test('the web shell hands game links to the app, never the legal pages', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('package=com.mafiamaster.mafia_master'));
    // Only game paths are handed over; /privacy and /delete-data
    // stay in the browser for reviewers and players alike.
    expect(index, contains(r'/^\/(join\/|room\/|invite\/|$)/.test(path)'));
  });
}
