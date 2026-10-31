@Tags(['golden'])
library;

import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/compass_heading.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/qibla/domain/qibla.dart';
import 'package:fgmap/features/qibla/presentation/qibla_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _kl = GeoPoint(3.139, 101.6869);

class _Compass implements CompassHeadingSource {
  final c = StreamController<CompassReading>.broadcast();
  @override
  Stream<CompassReading> readings() => c.stream;
  @override
  Future<void> setLocation(GeoPoint point, {double altitudeM = 0}) async {}
}

/// Rupa skrin Kiblat pada telefon: belok ke kanan, tepat (cincin hijau) dan perlu kalibrasi, terang dan
/// gelap. Bacaan ditolak melalui sumber palsu supaya bingkai deterministik.
void main() {
  setUpAll(loadAppFonts);

  final cases = <(String, double, CompassAccuracy, bool)>[
    ('turn', -38, CompassAccuracy.high, false),
    ('aligned', 0.5, CompassAccuracy.high, false),
    ('calibrate', -90, CompassAccuracy.low, false),
  ];

  for (final dark in [false, true]) {
    for (final (name, offset, acc, _) in cases) {
      testWidgets('kiblat $name ${dark ? 'gelap' : 'terang'}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final compass = _Compass();
        usePhoneSurface(tester);
        await pumpApp(
          tester,
          const RepaintBoundary(key: ValueKey('shot'), child: QiblaPage()),
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            locationServiceProvider.overrideWithValue(
              FakeLocationService(fix: const LocationFix(point: _kl)),
            ),
            compassHeadingSourceProvider.overrideWithValue(compass),
          ],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final qibla = qiblaBearingDegrees(_kl);
        compass.c.add(
          CompassReading(
            headingDegrees: (qibla + offset + 360) % 360,
            accuracy: acc,
            trueNorth: true,
          ),
        );
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 400));
        await expectLater(
          find.byKey(const ValueKey('shot')),
          matchesGoldenFile(
            'goldens/qibla_${name}_${dark ? 'dark' : 'light'}.png',
          ),
        );
      });
    }
  }
}
