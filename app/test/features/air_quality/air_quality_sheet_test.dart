import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/air_quality/domain/air_quality.dart';
import 'package:fgmap/features/air_quality/presentation/air_quality_controller.dart';
import 'package:fgmap/features/air_quality/presentation/air_quality_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('lembaran IPU tunjuk pencemar, masa, dan skala rasmi', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(390, 1200));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: AirQualitySheet()),
      overrides: [
        airQualityControllerProvider.overrideWith(
            () => _ReadyAir(
            AirReading(
              ipu: 90,
              point: const GeoPoint(3.15, 101.7),
              fetchedAt: _at,
              stationName: 'Cheras, Kuala Lumpur',
              stationDistanceM: 4200,
              here: true,
              observedAt: _at,
              pollutant: DominantPollutant.pm25,
            ),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('90'), findsOneWidget);
    expect(find.textContaining('PM2.5'), findsOneWidget);
    expect(find.textContaining('20:00'), findsOneWidget);
    expect(find.text('Skala rasmi JAS'), findsOneWidget);
    expect(find.text('0–50'), findsOneWidget);
    expect(find.text('51–100'), findsOneWidget);
    expect(find.text('101–200'), findsOneWidget);
    expect(find.text('201–300'), findsOneWidget);
    expect(find.text('301+'), findsOneWidget);
    expect(find.text('Sesuai untuk aktiviti luar.'), findsOneWidget);
    expect(find.textContaining('Cheras'), findsOneWidget);
  });
}

final _at = DateTime(2026, 10, 31, 20);

class _ReadyAir extends AirQualityController {
  _ReadyAir(this.reading);
  final AirReading reading;

  @override
  AirUiState build() => AirUiReady(reading);
}
