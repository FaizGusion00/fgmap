import 'dart:async';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/map_frame_pump.dart';
import 'package:fgmap/features/map/presentation/map_view.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:flutter_test/flutter_test.dart';

VehicleMarker marker(double lat) =>
    VehicleMarker(point: GeoPoint(lat, 101), bearing: 90);

CameraPose pose(double zoom) =>
    CameraPose(center: const GeoPoint(3, 101), zoom: zoom, tilt: 0, bearing: 0);

/// Hantaran palsu yang selesai hanya apabila ujian mengizinkan, untuk meniru panggilan platform
/// yang masih berjalan.
class _Harness {
  _Harness() {
    pump = MapFramePump(
      sendVehicle: (m) {
        log.add('v:${m?.point.lat}');
        return _gate();
      },
      sendCamera: (p) {
        log.add('c:${p.zoom}');
        return _gate();
      },
    );
  }

  late final MapFramePump pump;
  final log = <String>[];
  final _gates = <Completer<void>>[];
  bool autoComplete = false;

  Future<void> _gate() {
    if (autoComplete) return Future.value();
    final c = Completer<void>();
    _gates.add(c);
    return c.future;
  }

  /// Selesaikan semua hantaran yang sedang berjalan.
  Future<void> finishInFlight() async {
    final pending = List.of(_gates);
    _gates.clear();
    for (final g in pending) {
      g.complete();
    }
    await pumpEventQueue();
  }
}

void main() {
  test('marker dan kamera dalam bingkai yang sama dihantar serentak', () async {
    final h = _Harness();
    h.pump
      ..setVehicle(marker(1))
      ..moveCamera(pose(17));
    await pumpEventQueue();
    // Kedua-duanya sudah dipanggil sebelum mana-mana selesai.
    expect(h.log, ['v:1.0', 'c:17.0']);
  });

  test('bingkai semasa hantaran berjalan tidak digugurkan: yang terkini '
      'dihantar selepas itu', () async {
    final h = _Harness();
    h.pump
      ..setVehicle(marker(1))
      ..moveCamera(pose(17));
    await pumpEventQueue();
    expect(h.log, hasLength(2));

    // 100 bingkai tiba semasa hantaran pertama masih berjalan.
    for (var i = 2; i <= 100; i++) {
      h.pump
        ..setVehicle(marker(i.toDouble()))
        ..moveCamera(pose(17 + i / 100));
    }
    await pumpEventQueue();
    expect(
      h.log,
      hasLength(2),
      reason: 'hanya satu hantaran dalam penerbangan',
    );

    await h.finishInFlight();
    // Tepat satu hantaran susulan, membawa nilai TERAKHIR (bukan yang pertama atau tengah).
    expect(h.log.skip(2), ['v:100.0', 'c:18.0']);

    await h.finishInFlight();
    await pumpEventQueue();
    expect(h.log, hasLength(4), reason: 'tiada hantaran berlebihan');
  });

  test('hanya marker berubah: kamera tidak dihantar semula', () async {
    final h = _Harness()..autoComplete = true;
    h.pump
      ..setVehicle(marker(1))
      ..moveCamera(pose(17));
    await pumpEventQueue();
    h.pump.setVehicle(marker(2));
    await pumpEventQueue();
    expect(h.log, ['v:1.0', 'c:17.0', 'v:2.0']);
  });

  test(
    'cancelCamera membuang gerakan yang menunggu (sebelum animasi)',
    () async {
      final h = _Harness();
      h.pump.moveCamera(pose(17));
      await pumpEventQueue();
      h.pump.moveCamera(pose(18));
      h.pump.cancelCamera();
      await h.finishInFlight();
      expect(h.log, ['c:17.0']);
    },
  );

  test('hantaran gagal tidak menghentikan pam', () async {
    final errors = <String>[];
    final pump = MapFramePump(
      sendVehicle: (m) async {
        errors.add('v');
        throw StateError('platform');
      },
      sendCamera: (p) async => errors.add('c'),
    );
    pump
      ..setVehicle(marker(1))
      ..moveCamera(pose(17));
    await pumpEventQueue();
    pump
      ..setVehicle(marker(2))
      ..moveCamera(pose(18));
    await pumpEventQueue();
    expect(errors, ['v', 'c', 'v', 'c']);
  });

  test('dispose: tiada hantaran selepas dilupuskan', () async {
    final h = _Harness();
    h.pump.moveCamera(pose(17));
    await pumpEventQueue();
    h.pump
      ..setVehicle(marker(5))
      ..moveCamera(pose(18))
      ..dispose();
    await h.finishInFlight();
    expect(h.log, ['c:17.0']);
    h.pump.moveCamera(pose(19));
    await pumpEventQueue();
    expect(h.log, ['c:17.0']);
  });
}
