import 'dart:async';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/map/presentation/user_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<LocationFix> stream;
  late int listens;
  late int cancels;
  late DateTime now;
  late UserLocationTracker tracker;
  late List<UserLocation> updates;

  /// Fix dengan cap masa [ageS] saat sebelum "sekarang".
  LocationFix fix(
    double lat, {
    double lng = 101.7,
    double? accuracy = 8,
    double? speed = 8,
    int ageS = 0,
  }) => LocationFix(
    point: GeoPoint(lat, lng),
    accuracyMeters: accuracy,
    speedMps: speed,
    timestamp: now.subtract(Duration(seconds: ageS)),
  );

  Future<void> push(LocationFix f) async {
    stream.add(f);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 26, 10);
    listens = 0;
    cancels = 0;
    updates = [];
    stream = StreamController<LocationFix>.broadcast(
      onListen: () => listens++,
      onCancel: () => cancels++,
    );
    tracker = UserLocationTracker(fixes: () => stream.stream, clock: () => now);
    tracker.updates.listen(updates.add);
    addTearDown(() {
      tracker.dispose();
      stream.close();
    });
  });

  test('belum start: tiada GPS dipakai', () {
    expect(tracker.listening, isFalse);
    expect(listens, 0);
    expect(tracker.location.value, isNull);
  });

  test('start: melanggan dan menerbitkan kedudukan', () async {
    tracker.start();
    await push(fix(3.1));

    expect(tracker.listening, isTrue);
    expect(tracker.location.value!.point.lat, 3.1);
    expect(updates, hasLength(1));
  });

  test('fix lapuk (cache platform sebaik langganan) ditolak', () async {
    tracker.start();
    await push(fix(3.5, ageS: 120)); // lokasi lama di tempat lain
    expect(tracker.location.value, isNull);
    expect(updates, isEmpty);

    await push(fix(3.1));
    expect(tracker.location.value!.point.lat, 3.1);
  });

  test(
    'fix terlalu kasar ditolak; ketepatan tidak diketahui diterima',
    () async {
      tracker.start();
      await push(fix(3.1, accuracy: 400));
      expect(tracker.location.value, isNull);

      now = now.add(const Duration(seconds: 1));
      await push(
        fix(3.1, accuracy: 0),
      ); // platform memulangkan 0 = tidak diketahui
      expect(tracker.location.value, isNotNull);
      expect(tracker.location.value!.accuracyM, greaterThan(10));
    },
  );

  test('pegun: hingar GPS beberapa meter tidak menggerakkan titik', () async {
    tracker.start();
    await push(fix(3.1, speed: 0));
    final first = tracker.location.value!.point;

    for (var i = 1; i <= 5; i++) {
      now = now.add(const Duration(seconds: 1));
      // ~1-3 m ke utara/selatan secara bergilir.
      await push(fix(3.1 + (i.isEven ? 1 : -1) * i * 0.000008, speed: 0));
    }
    expect(tracker.location.value!.point, first);
  });

  test('bergerak: titik mengikut pengguna', () async {
    tracker.start();
    await push(fix(3.1, speed: 14));
    for (var i = 1; i <= 6; i++) {
      now = now.add(const Duration(seconds: 1));
      await push(fix(3.1 + i * 0.00013, speed: 14)); // ~14 m / saat
    }
    expect(tracker.location.value!.point.lat, greaterThan(3.1005));
  });

  test(
    'suspend melepaskan GPS; resume menyambung dan menandakan lapuk',
    () async {
      tracker.start();
      await push(fix(3.1));
      expect(tracker.location.value!.stale, isFalse);

      tracker.suspend('background');
      expect(tracker.listening, isFalse);
      expect(cancels, 1);

      tracker.resume('background');
      expect(tracker.listening, isTrue);
      // Kedudukan lama dikekalkan tetapi ditandakan lapuk sehingga fix segar tiba.
      expect(tracker.location.value!.stale, isTrue);
      expect(tracker.location.value!.point.lat, 3.1);

      now = now.add(const Duration(minutes: 5));
      await push(fix(3.4)); // pengguna sudah berpindah jauh
      expect(tracker.location.value!.stale, isFalse);
      expect(
        tracker.location.value!.point.lat,
        3.4,
        reason: 'penapis dimulakan semula: tiada lompatan "mustahil" ditolak',
      );
    },
  );

  test('beberapa sebab gantungan: hidup semula apabila semuanya batal', () {
    tracker.start();
    tracker.suspend('navigation');
    tracker.suspend('background');
    tracker.resume('navigation');
    expect(tracker.listening, isFalse);
    tracker.resume('background');
    expect(tracker.listening, isTrue);
  });

  test('suspend tanpa start: resume tidak melanggan', () {
    tracker.suspend('background');
    tracker.resume('background');
    expect(tracker.listening, isFalse);
    expect(listens, 0);
  });

  test('stop: melepaskan GPS dan melupakan kedudukan', () async {
    tracker.start();
    await push(fix(3.1));
    tracker.stop();

    expect(tracker.listening, isFalse);
    expect(tracker.location.value, isNull);
  });

  test('start berulang tidak menggandakan langganan', () {
    tracker.start();
    tracker.start();
    expect(listens, 1);
  });

  test('ralat strim (kebenaran ditarik balik): berhenti tanpa ranap', () async {
    tracker.start();
    stream.addError(StateError('permission revoked'));
    await Future<void>.delayed(Duration.zero);

    expect(tracker.listening, isFalse);
  });
}
