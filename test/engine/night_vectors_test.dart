import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../tool/night_vectors.dart' as generator;

void main() {
  test('the Dart engine reproduces every stored night outcome', () {
    final file = File(generator.outputPath);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'run `dart run tool/night_vectors.dart`',
    );
    final stored = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(stored['version'], 1);
    final actual = generator.generateNightVectors();
    expect(actual.length, greaterThanOrEqualTo(40));
    expect(actual, stored['scenarios']);
  });
}
