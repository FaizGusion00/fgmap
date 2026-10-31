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

    test('CarBridge.kt guna saluran dan kaedah yang sama', () {
      final src = kotlin.readAsStringSync();
      expect(src, contains('"$channel"'));
      for (final m in [...toNative, ...fromNative]) {
        expect(src, contains('"$m"'), reason: m);
      }
    });
  });
}
