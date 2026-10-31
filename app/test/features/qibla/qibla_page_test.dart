import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/compass_heading.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/qibla/domain/qibla.dart';
import 'package:fgmap/features/qibla/presentation/qibla_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

const _kl = GeoPoint(3.139, 101.6869);

class _FakeCompass implements CompassHeadingSource {
  _FakeCompass({this.hasSensor = true});

  final bool hasSensor;
  final _c = StreamController<CompassReading>.broadcast();
  GeoPoint? location;
  int listens = 0;

  @override
  Stream<CompassReading> readings() {
    listens++;
    return hasSensor ? _c.stream : const Stream.empty();
  }

  @override
  Future<void> setLocation(GeoPoint point, {double altitudeM = 0}) async {
    location = point;
  }

  void emit(
    double heading, {
    CompassAccuracy accuracy = CompassAccuracy.high,
    bool trueNorth = true,
  }) => _c.add(
    CompassReading(
      headingDegrees: heading,
      accuracy: accuracy,
      trueNorth: trueNorth,
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late _FakeCompass compass;
  late FakeLocationService location;
  final haptics = <String>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    compass = _FakeCompass();
    location = FakeLocationService(fix: const LocationFix(point: _kl));
    haptics.clear();
  });

  Future<void> pump(WidgetTester tester) async {
    usePhoneSurface(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await pumpApp(
      tester,
      const QiblaPage(),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
        compassHeadingSourceProvider.overrideWithValue(compass),
      ],
    );
    // Lokasi diselesaikan secara asinkron.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Hantar bacaan dan biarkan penapis licin menumpu beberapa bingkai.
  Future<void> reading(
    WidgetTester tester,
    double heading, {
    CompassAccuracy accuracy = CompassAccuracy.high,
    int frames = 90,
  }) async {
    compass.emit(heading, accuracy: accuracy);
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final qibla = qiblaBearingDegrees(_kl);

  testWidgets('menunggu kompas sebelum bacaan pertama', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('qibla-state-waiting')), findsOneWidget);
    expect(find.text('Menyediakan kompas…'), findsOneWidget);
    // Lokasi dihantar kepada sumber supaya deklinasi magnet (utara benar) boleh dikira.
    expect(compass.location, _kl);
  });

  testWidgets('kiblat di sebelah kanan: "Pusing ke kanan N°"', (tester) async {
    await pump(tester);
    await reading(tester, qibla - 40);
    expect(find.text('Pusing ke kanan 40°'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('qibla-state-turn-right')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsNothing);
  });

  testWidgets('kiblat di sebelah kiri: "Pusing ke kiri N°"', (tester) async {
    await pump(tester);
    await reading(tester, qibla + 25);
    expect(find.text('Pusing ke kiri 25°'), findsOneWidget);
  });

  testWidgets('melintasi utara: laluan terpendek, bukan 340°', (tester) async {
    // Kiblat ~292°; heading 280° => kanan 12°, bukan kiri 348°.
    await pump(tester);
    await reading(tester, qibla - 12);
    expect(find.text('Pusing ke kanan 12°'), findsOneWidget);
  });

  testWidgets('tepat: kad hijau, haptik sekali, kekal dalam histeresis', (
    tester,
  ) async {
    await pump(tester);
    await reading(tester, qibla - 30);
    expect(haptics, isEmpty);

    await reading(tester, qibla + 1);
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsOneWidget);
    expect(find.text('Tepat ke arah kiblat'), findsOneWidget);
    expect(haptics, ['HapticFeedbackType.heavyImpact']);

    // Bergetar 4° (di dalam zon keluar 6°): kekal tepat, tiada haptik baharu.
    await reading(tester, qibla + 4);
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsOneWidget);
    expect(haptics, hasLength(1));

    // Menyimpang jauh: tidak lagi tepat.
    await reading(tester, qibla + 20);
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsNothing);
    expect(find.text('Pusing ke kiri 20°'), findsOneWidget);
  });

  testWidgets('sensor tidak boleh dipercayai: tidak mendakwa tepat, minta '
      'kalibrasi', (tester) async {
    await pump(tester);
    await reading(tester, qibla, accuracy: CompassAccuracy.unreliable);
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsNothing);
    expect(find.byKey(const ValueKey('qibla-calibrate')), findsOneWidget);
    expect(find.text('Perlu kalibrasi'), findsOneWidget);
    expect(haptics, isEmpty);

    // Selepas dikalibrasi, tepat dan kad kalibrasi hilang.
    await reading(tester, qibla, accuracy: CompassAccuracy.high);
    expect(find.byKey(const ValueKey('qibla-state-aligned')), findsOneWidget);
    expect(find.byKey(const ValueKey('qibla-calibrate')), findsNothing);
    expect(find.text('Tinggi'), findsOneWidget);
  });

  testWidgets('maklumat: bearing 1 perpuluhan dan jarak geodesik', (
    tester,
  ) async {
    await pump(tester);
    await reading(tester, 10, frames: 2);
    expect(find.text('${qibla.toStringAsFixed(1)}°'), findsOneWidget);
    expect(find.text('6,979 km'), findsOneWidget);
    expect(find.text('Utara benar (deklinasi magnet dikira)'), findsOneWidget);
  });

  testWidgets('utara magnet dilabel jujur apabila lokasi belum diketahui', (
    tester,
  ) async {
    await pump(tester);
    compass.emit(100, trueNorth: false);
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('Utara magnet (menunggu lokasi)'), findsOneWidget);
  });

  testWidgets('tiada sensor: mesej jelas, bukan skrin beku', (tester) async {
    compass = _FakeCompass(hasSensor: false);
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const ValueKey('qibla-state-nosensor')), findsOneWidget);
    expect(find.textContaining('Tiada sensor kompas'), findsOneWidget);
    // Bearing kiblat tetap ditunjukkan.
    expect(find.text('${qibla.toStringAsFixed(1)}°'), findsOneWidget);
  });

  testWidgets('tiada lokasi: mesej GPS diperlukan', (tester) async {
    location = FakeLocationService(accessValue: LocationAccess.deniedForever);
    await pump(tester);
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.byKey(const ValueKey('qibla-state-nolocation')),
      findsOneWidget,
    );
  });

  testWidgets('label semantik menerangkan arah dan panduan', (tester) async {
    await pump(tester);
    await reading(tester, qibla - 40);
    final label = tester
        .getSemantics(find.byKey(const ValueKey('qibla-dial')))
        .label;
    expect(label, contains('Kompas kiblat'));
    expect(label, contains('Pusing ke kanan 40°'));
  });

  testWidgets('bahasa Inggeris', (tester) async {
    usePhoneSurface(tester);
    await pumpApp(
      tester,
      const QiblaPage(),
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        locationServiceProvider.overrideWithValue(location),
        compassHeadingSourceProvider.overrideWithValue(compass),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));
    await reading(tester, qibla - 40);
    expect(find.text('Turn right 40°'), findsOneWidget);
    await reading(tester, qibla);
    expect(find.text('Facing the Qibla'), findsOneWidget);
  });

  test('peristiwa natif: sah, tidak sah dan penormalan', () {
    final r = parseCompassEvent({
      'heading': -10.0,
      'accuracy': 2,
      'trueNorth': true,
    })!;
    expect(r.headingDegrees, closeTo(350, 1e-9));
    expect(r.accuracy, CompassAccuracy.medium);
    expect(r.trueNorth, isTrue);
    expect(parseCompassEvent({'unavailable': true}), isNull);
    expect(parseCompassEvent(null), isNull);
    expect(parseCompassEvent({'heading': double.nan}), isNull);
    expect(
      parseCompassEvent({'heading': 1.0, 'accuracy': 9})!.accuracy,
      CompassAccuracy.high,
    );
    expect(
      parseCompassEvent({'heading': 1.0, 'accuracy': -1})!.accuracy,
      CompassAccuracy.unreliable,
    );
  });
}
