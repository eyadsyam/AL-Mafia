import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mafia_master/ui/screens/online/table/connection_weather.dart';
import 'package:mafia_master/ui/theme/design_tokens.dart';

import '../support/localized.dart';

/// 1.1 F8 reconnect: 0–6 s a neutral strip, then the persistent surface, and
/// a manual retry after 15 s — never an automatic abandon.
void main() {
  test('stages follow the elapsed time, whatever the role or phase', () {
    expect(WeatherStage.after(Duration.zero), WeatherStage.strip);
    expect(
      WeatherStage.after(
        MafiaTiming.reconnectStrip - const Duration(milliseconds: 1),
      ),
      WeatherStage.strip,
    );
    expect(
      WeatherStage.after(MafiaTiming.reconnectStrip),
      WeatherStage.surface,
    );
    expect(WeatherStage.after(MafiaTiming.reconnectRetry), WeatherStage.retry);
  });

  testWidgets('retry appears only after the second threshold', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      localizedApp(
        ConnectionWeather(
          weather: TableWeather.reconnecting,
          onRetry: () => retries++,
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(find.byKey(ConnectionWeather.messageKey), findsOneWidget);
    expect(find.byKey(ConnectionWeather.retryKey), findsNothing);

    await tester.pump(MafiaTiming.reconnectStrip);
    expect(find.byKey(ConnectionWeather.retryKey), findsNothing);

    await tester.pump(MafiaTiming.reconnectRetry - MafiaTiming.reconnectStrip);
    expect(find.byKey(ConnectionWeather.retryKey), findsOneWidget);
    await tester.tap(find.byKey(ConnectionWeather.retryKey));
    expect(retries, 1);
  });

  testWidgets('clear weather resets the clock', (tester) async {
    Widget at(TableWeather weather) => localizedApp(
      ConnectionWeather(
        weather: weather,
        onRetry: () {},
        child: const SizedBox.expand(),
      ),
    );
    await tester.pumpWidget(at(TableWeather.reconnecting));
    await tester.pump(MafiaTiming.reconnectRetry);
    expect(find.byKey(ConnectionWeather.retryKey), findsOneWidget);

    await tester.pumpWidget(at(TableWeather.clear));
    await tester.pumpWidget(at(TableWeather.reconnecting));
    expect(find.byKey(ConnectionWeather.retryKey), findsNothing);
    await tester.pump(MafiaTiming.reconnectRetry);
  });
}
