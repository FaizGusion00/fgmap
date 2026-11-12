import 'dart:io';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/car_session.dart';
import 'package:fgmap/features/navigation/presentation/car_session_hub.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kontrak saluran kereta: Dart <-> Android Auto (Kotlin) <-> CarPlay (Swift).
/// Swift tidak boleh dikompil di sini, jadi ujian menyemak teks sumber Swift/Kotlin supaya nama
/// saluran dan kaedah tidak menyimpang secara senyap.
void main() {
  const channel = 'com.fguniversalempire.fgmaps/car';

  /// Flutter -> native.
  const toNative = ['session'];

  /// Native -> Flutter (dikendalikan oleh CarSessionHub._onCall).
  const fromNative = [
    'search',
    'nearbyCategories',
    'nearby',
    'openPlace',
    'endNavigation',
    'recenter',
    'pan',
  ];

  test('nama saluran Dart sama dengan kontrak', () {
    expect(carSessionChannel.name, channel);
  });

  test('muatan session membawa kunci yang dibaca CarPlay/Android Auto', () {
    final snap = mapCarSession(
      navigating: true,
      cruising: false,
      navigationRoute: const [GeoPoint(3.1, 101.7), GeoPoint(3.2, 101.8)],
      routeVersion: 3,
      maneuver: 'Belok kanan',
      maneuverKind: 'right',
      distanceToManeuverM: 120,
      remainingM: 4000,
      remainingS: 600,
      etaEpochMs: 1700000000000,
    );
    final map = snap.toMap();
    for (final key in [
      'mode',
      'lat',
      'lng',
      'routeVersion',
      'route',
      'maneuver',
      'maneuverKind',
      'distanceToManeuverM',
      'remainingM',
      'remainingS',
      'etaEpochMs',
      'cameraAlert',
      'weatherAlert',
      'alongCue',
      'driveAlert',
      'airAqi',
      'prayerLine',
      'lanes',
      'laneHint',
    ]) {
      expect(map.containsKey(key), isTrue, reason: key);
    }
    expect(map['mode'], 'navigating');
    expect(map['route'], [
      [3.1, 101.7],
      [3.2, 101.8],
    ]);
    // Laluan tidak diulang bila tidak berubah; CarPlay mengekalkan salinan terakhir.
    expect(snap.toMap(includeRoute: false).containsKey('route'), isFalse);
  });

  group('sumber native', () {
    final swift = File('ios/Runner/CarPlay/CarBridge.swift');
    final kotlin = File(
      'android/app/src/main/kotlin/com/fguniversalempire/fgmaps/car/CarBridge.kt',
    );

    test('CarBridge.swift guna saluran dan kaedah yang sama', () {
      final src = swift.readAsStringSync();
      expect(src, contains('"$channel"'));
      for (final m in [...toNative, ...fromNative]) {
        expect(src, contains('"$m"'), reason: m);
      }
    });

    test(
      'CarSessionHub (Dart) mengendalikan setiap kaedah daripada native',
      () {
        final src = File(
          'lib/features/navigation/presentation/car_session_hub.dart',
        ).readAsStringSync();
        for (final m in fromNative) {
          expect(src, contains("case '$m'"), reason: m);
        }
      },
    );

    test('CarBridge.kt guna saluran dan kaedah yang sama', () {
      final src = kotlin.readAsStringSync();
      expect(src, contains('"$channel"'));
      // Android Auto tidak terus memulakan laluan (openPlace, kekal untuk CarPlay): ia membuka
      // pilihan laluan dahulu (preview -> startPreview).
      for (final m in [...toNative, ...fromNative]) {
        if (m == 'openPlace') continue;
        expect(src, contains('"$m"'), reason: m);
      }
    });

    test(
      'Android Auto sahaja: Tempat, pilihan laluan, Lapor, Tetapan, muzik',
      () {
        const androidOnly = [
          'places',
          'preview',
          'startPreview',
          'reportTypes',
          'report',
          'settings',
          'setSetting',
          'mediaBrowser',
        ];
        final src = kotlin.readAsStringSync();
        final hub = File(
          'lib/features/navigation/presentation/car_session_hub.dart',
        ).readAsStringSync();
        for (final m in androidOnly) {
          expect(src, contains('"$m"'), reason: m);
          expect(hub, contains("case '$m'"), reason: m);
        }
      },
    );

    test('Android Auto sahaja: carState (keterlihatan + mod malam kereta)', () {
      // Dua hala: Kotlin melapor perubahan, Dart bertanya keadaan semasa semasa dicipta.
      expect(kotlin.readAsStringSync(), contains('"carState"'));
      final hub = File(
        'lib/features/navigation/presentation/car_session_hub.dart',
      ).readAsStringSync();
      expect(hub, contains("case 'carState'"));
      expect(hub, contains("invokeMethod<Object?>('carState')"));
    });

    test('kunci kenderaan/ketibaan dihantar Dart dan dibaca Kotlin', () {
      const keys = [
        'vehicleLat',
        'vehicleLng',
        'vehicleBearing',
        'rerouting',
        'arrived',
        'destination',
      ];
      final map = mapCarSession(navigating: true, cruising: false).toMap();
      final kotlinSrc = [
        File(
          'android/app/src/main/kotlin/com/fguniversalempire/fgmaps/car/CarMapSurface.kt',
        ).readAsStringSync(),
        File(
          'android/app/src/main/kotlin/com/fguniversalempire/fgmaps/car/FgMapCarScreens.kt',
        ).readAsStringSync(),
      ].join('\n');
      for (final key in keys) {
        expect(map.containsKey(key), isTrue, reason: key);
        expect(kotlinSrc, contains('"$key"'), reason: key);
      }
    });
  });
}
