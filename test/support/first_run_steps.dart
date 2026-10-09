import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/onboarding/first_run_screen.dart';

/// The intro plays by itself and hands over to the first question.
Future<void> passIntro(WidgetTester tester) => tester.pumpAndSettle();

Future<void> tapKey(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

/// Ticks the one box and picks a card; the card flips and the name step opens.
Future<void> answerKind(WidgetTester tester, {bool boy = true}) async {
  await tapKey(tester, FirstRunScreen.agreeKey);
  await tapKey(tester, boy ? FirstRunScreen.boyKey : FirstRunScreen.girlKey);
}

Future<void> typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byKey(FirstRunScreen.nameKey), name);
  await tester.pumpAndSettle();
}

/// Whole first run on the no-server build: intro, kind, name, finish.
Future<void> completeFirstRun(
  WidgetTester tester, {
  String name = 'Eyad',
  bool boy = true,
}) async {
  await passIntro(tester);
  await answerKind(tester, boy: boy);
  await typeName(tester, name);
  await tapKey(tester, FirstRunScreen.continueKey);
}
