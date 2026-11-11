import 'dart:async';

import 'package:fgmap/core/location/position_hub.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// Meniru pemalam Android: aliran yang sedang hidup dipulangkan semula dan tetapan baharu
/// diabaikan; aliran dilupakan bila pelanggan terakhir membatalkan.
class _FakePlatform {
  final opened = <LocationSettings>[];
  StreamController<Position>? live;

  Stream<Position> open(LocationSettings settings) {
    final current = live;
    if (current != null) return current.stream;
    opened.add(settings);
    late final StreamController<Position> c;
    c = StreamController<Position>.broadcast(
      onCancel: () {
        if (identical(live, c)) live = null;
      },
    );
    live = c;
    return c.stream;
  }
}

Position _pos(double lat) => Position(
  latitude: lat,
  longitude: 101.7,
  timestamp: DateTime(2026, 11, 11),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const _tracking = LocationSettings(accuracy: LocationAccuracy.high);
const _oneShot = LocationSettings(accuracy: LocationAccuracy.best);
const _navigation = LocationSettings(
  accuracy: LocationAccuracy.bestForNavigation,
);

void main() {
  late _FakePlatform platform;
  late PositionHub hub;

  setUp(() {
    platform = _FakePlatform();
    hub = PositionHub(
      platform.open,
      (mode) => switch (mode) {
        PositionMode.tracking => _tracking,
        PositionMode.oneShot => _oneShot,
        PositionMode.navigation => _navigation,
      },
    );
  });

  test(
    'pelanggan kedua yang lebih berat membuka semula GPS dengan tetapannya',
    () async {
      final idle = hub.stream(PositionMode.tracking).listen((_) {});
      expect(platform.opened, [_tracking]);

      // Dulu: memandu bebas menumpang aliran idle (tanpa servis latar depan).
      final nav = <Position>[];
      final cruise = hub.stream(PositionMode.navigation).listen(nav.add);
      expect(platform.opened, [_tracking, _navigation]);
      expect(hub.activeMode, PositionMode.navigation);

      platform.live!.add(_pos(3.1));
      await Future<void>.delayed(Duration.zero);
      expect(nav, hasLength(1));

      // Peta menggantung penjejaknya: navigasi kekal dengan tetapannya sendiri.
      await idle.cancel();
      expect(platform.opened, [_tracking, _navigation]);
      expect(hub.activeMode, PositionMode.navigation);
      await cruise.cancel();
    },
  );

  test('currentFix selesai: peta terbiar kembali ke tetapan ringan', () async {
    final idle = hub.stream(PositionMode.tracking).listen((_) {});
    final once = hub.stream(PositionMode.oneShot).listen((_) {});
    expect(hub.activeMode, PositionMode.oneShot);

    await once.cancel();
    expect(platform.opened, [_tracking, _oneShot, _tracking]);
    expect(hub.activeMode, PositionMode.tracking);
    await idle.cancel();
  });

  test('pelanggan terakhir berhenti: GPS ditutup', () async {
    final sub = hub.stream(PositionMode.tracking).listen((_) {});
    await sub.cancel();
    expect(hub.activeMode, isNull);
    expect(platform.live, isNull);
  });

  test('semua pelanggan menerima kedudukan dan ralat yang sama', () async {
    final a = <Position>[];
    final b = <Position>[];
    final errors = <Object>[];
    final sa = hub
        .stream(PositionMode.navigation)
        .listen(a.add, onError: (Object _) {});
    final sb = hub
        .stream(PositionMode.navigation)
        .listen(b.add, onError: errors.add);
    platform.live!
      ..add(_pos(3.1))
      ..addError(StateError('gps'));
    await Future<void>.delayed(Duration.zero);
    expect(a, hasLength(1));
    expect(b, hasLength(1));
    expect(errors, hasLength(1));
    await sa.cancel();
    await sb.cancel();
  });
}
