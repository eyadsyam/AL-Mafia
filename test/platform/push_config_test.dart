import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/platform/push/web_push_config.dart';

/// The Firebase config the release ships with (project mafia-master-e0cf5),
/// read the way each platform reads it. Values are public identifiers; the
/// test never prints them.
const _package = 'com.mafiamaster.mafia_master';

Map<String, dynamic> _android() =>
    jsonDecode(File('android/app/google-services.json').readAsStringSync())
        as Map<String, dynamic>;

/// `self.MAFIA_FIREBASE = { key: "value", … };` from web/firebase-config.js,
/// comments removed — the object the page and the service worker load.
Map<String, Object?>? _web() {
  final source = File('web/firebase-config.js')
      .readAsLinesSync()
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');
  final assignment = RegExp(
    r'self\.MAFIA_FIREBASE\s*=\s*(null|\{[^}]*\})\s*;',
  ).firstMatch(source);
  expect(assignment, isNotNull, reason: 'firebase-config.js assigns the config');
  if (assignment!.group(1) == 'null') return null;
  return {
    for (final m in RegExp(
      r'(\w+)\s*:\s*"([^"]*)"',
    ).allMatches(assignment.group(1)!))
      m.group(1)!: m.group(2),
  };
}

void main() {
  test('google-services.json has what the Gradle build reads', () {
    final json = _android();
    final info = json['project_info'] as Map<String, dynamic>;
    expect(info['project_id'], 'mafia-master-e0cf5');
    expect('${info['project_number']}', matches(RegExp(r'^\d+$')));
    // android/app/build.gradle.kts picks the client for this package.
    final client = (json['client'] as List).cast<Map<String, dynamic>>().where(
      (c) =>
          (c['client_info'] as Map)['android_client_info']['package_name'] ==
          _package,
    );
    expect(client, hasLength(1));
    final appId = (client.single['client_info'] as Map)['mobilesdk_app_id'];
    expect(appId, matches(RegExp(r'^1:\d+:android:[0-9a-f]+$')));
    final keys = (client.single['api_key'] as List).cast<Map>();
    expect(keys.first['current_key'], isA<String>());
    expect((keys.first['current_key'] as String).isNotEmpty, isTrue);
  });

  test('the Gradle build turns the file into Firebase resources', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    for (final name in [
      'google_app_id',
      'google_api_key',
      'gcm_defaultSenderId',
      'project_id',
    ]) {
      expect(gradle, contains('resValue("string", "$name"'), reason: name);
    }
    expect(gradle, contains('file("google-services.json")'));
    expect(gradle, contains('resValues = true'));
  });

  test('web/firebase-config.js parses into a complete web config', () {
    final map = _web();
    expect(map, isNotNull, reason: 'push is configured for this release');
    final config = WebPushConfig.fromMap(map);
    expect(config, isNotNull);
    expect(config!.projectId, 'mafia-master-e0cf5');
    expect(config.appId, contains(':web:'));
    expect(config.vapidKey, isNotNull, reason: 'no token without it');
    final android = _android()['project_info'] as Map<String, dynamic>;
    expect(config.messagingSenderId, '${android['project_number']}');
    expect(config.authDomain, 'mafia-master-e0cf5.firebaseapp.com');
  });

  test('a missing or blank value turns push off instead of failing', () {
    expect(WebPushConfig.fromMap(null), isNull);
    const full = {
      'apiKey': 'k',
      'appId': '1:2:web:3',
      'messagingSenderId': '2',
      'projectId': 'p',
    };
    expect(WebPushConfig.fromMap(full), isNotNull);
    for (final key in full.keys) {
      expect(WebPushConfig.fromMap({...full, key: ' '}), isNull, reason: key);
      expect(
        WebPushConfig.fromMap(Map.of(full)..remove(key)),
        isNull,
        reason: key,
      );
    }
    expect(WebPushConfig.fromMap(full)!.vapidKey, isNull);
  });

  test('the page and the service worker load the same config, no secret', () {
    final index = File('web/index.html').readAsStringSync();
    final config = index.indexOf('src="firebase-config.js"');
    expect(config, greaterThan(0));
    expect(config, lessThan(index.indexOf('flutter_bootstrap.js')),
        reason: 'the config is on the page before the app starts');
    final worker = File('web/firebase-messaging-sw.js').readAsStringSync();
    expect(worker, contains("importScripts('firebase-config.js')"));
    for (final file in [
      'web/firebase-config.js',
      'web/firebase-messaging-sw.js',
      'android/app/google-services.json',
    ]) {
      final text = File(file).readAsStringSync();
      expect(text, isNot(contains('private_key')), reason: file);
      expect(text, isNot(contains('BEGIN PRIVATE KEY')), reason: file);
    }
  });
}
