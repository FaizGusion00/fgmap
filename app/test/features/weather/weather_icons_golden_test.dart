@Tags(['golden'])
library;

import 'package:fgmap/features/weather/presentation/weather_animated_icon.dart';
import 'package:fgmap/features/weather/presentation/weather_icon_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Lembaran semua keluarga ikon cuaca, siang (gradien cerah) dan malam (gradien gelap), pada bingkai
/// statik Reduce Motion. Menangkap regresi warna/bentuk; gerakan diuji berasingan.
void main() {
  setUpAll(loadAppFonts);

  const samples = <(int, String)>[
    (0, 'cerah'),
    (1, 'hampir cerah'),
    (2, 'sebahagian berawan'),
    (3, 'mendung'),
    (45, 'kabus'),
    (51, 'gerimis'),
    (63, 'hujan'),
    (65, 'hujan lebat'),
    (95, 'ribut petir'),
    (73, 'salji'),
  ];

  Widget sheet(bool day) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: day
            ? const [Color(0xFF7EC8E8), Color(0xFFE8F4FA)]
            : const [Color(0xFF1A3A5C), Color(0xFF0E1F33)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (code, name) in samples)
            SizedBox(
              width: 96,
              child: Column(
                children: [
                  WeatherAnimatedIcon(weatherCode: code, size: 84, isDay: day),
                  Text(
                    name,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 11,
                      color: day ? Colors.black87 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  for (final day in [true, false]) {
    testWidgets('lembaran ikon cuaca ${day ? 'siang' : 'malam'}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1040, 760);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      reduceMotion(tester);
      await pumpApp(
        tester,
        RepaintBoundary(key: const ValueKey('sheet'), child: sheet(day)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byKey(const ValueKey('sheet')),
        matchesGoldenFile('goldens/weather_icons_${day ? 'day' : 'night'}.png'),
      );
    });
  }

  test('setiap kod WMO dipetakan kepada keluarga ikon', () {
    expect(weatherGlyphFor(0), WeatherGlyph.clear);
    expect(weatherGlyphFor(2), WeatherGlyph.partlyCloudy);
    expect(weatherGlyphFor(3), WeatherGlyph.overcast);
    expect(weatherGlyphFor(48), WeatherGlyph.fog);
    expect(weatherGlyphFor(53), WeatherGlyph.drizzle);
    expect(weatherGlyphFor(61), WeatherGlyph.rain);
    expect(weatherGlyphFor(65), WeatherGlyph.heavyRain);
    expect(weatherGlyphFor(81), WeatherGlyph.rain);
    expect(weatherGlyphFor(82), WeatherGlyph.heavyRain);
    expect(weatherGlyphFor(75), WeatherGlyph.snow);
    expect(weatherGlyphFor(95), WeatherGlyph.thunder);
    expect(weatherGlyphFor(99), WeatherGlyph.thunder);
    for (var code = 0; code <= 99; code++) {
      expect(() => weatherGlyphFor(code), returnsNormally);
    }
  });

  test('siang 07:00–19:00 sahaja', () {
    expect(isDaytime(DateTime(2026, 1, 1, 6, 59)), isFalse);
    expect(isDaytime(DateTime(2026, 1, 1, 7)), isTrue);
    expect(isDaytime(DateTime(2026, 1, 1, 18, 59)), isTrue);
    expect(isDaytime(DateTime(2026, 1, 1, 19)), isFalse);
  });
}
