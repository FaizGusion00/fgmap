import 'dart:math' as math;

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/navigation/domain/nav_route.dart';
import 'package:fgmap/features/navigation/domain/navigation_session.dart';
import 'package:fgmap/features/navigation/domain/vehicle_model.dart';
import 'package:fgmap/features/navigation/presentation/navigation_frame_driver.dart';
import 'package:fgmap/features/navigation/domain/camera_planner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';
import 'nav_test_support.dart';

/// Simulator pemanduan REALISTIK untuk mengukur kedudukan dan arah kereta di selekoh berbanding
/// kebenaran: laluan ialah polyline bucu tajam (seperti Valhalla), tetapi kenderaan sebenar mengikut
/// lengkung berjejari, membrek sebelum selekoh dan memecut selepasnya. GPS 1 Hz dengan hingar, heading
/// yang lewat 0.8 s dan latensi ketibaan fix. Ukuran: ralat kedudukan (m) dan ralat arah (deg) antara
/// pose yang dipaparkan dan kebenaran pada masa yang sama.
class _Truth {
  _Truth({required this.legM, required this.radiusM}) {
    final arcLen = math.pi * radiusM / 2;
    straight1 = legM - radiusM;
    total = straight1 + arcLen + (legM - radiusM);
    cornerS = straight1 + arcLen / 2;
    _simulate();
  }

  final double legM;
  final double radiusM;
  static const cruise = 14.0;
  static const cornerSpeed = 6.0;
  static const decel = 2.5;
  static const accel = 1.5;
  static const startBeforeM = 260.0;
  static const afterM = 140.0;
  late final double straight1;
  late final double total;
  late final double cornerS;

  static const _origin = GeoPoint(3.0, 101.0);
  static const _dt = 0.01;
  final _s = <double>[];
  final _v = <double>[];

  double _targetSpeed(double s) {
    if (s < cornerS) {
      return math.min(
        cruise,
        math.sqrt(cornerSpeed * cornerSpeed + 2 * decel * (cornerS - s)),
      );
    }
    return math.min(
      cruise,
      math.sqrt(cornerSpeed * cornerSpeed + 2 * accel * (s - cornerS)),
    );
  }

  void _simulate() {
    var s = cornerS - startBeforeM;
    var v = cruise;
    final end = cornerS + afterM;
    while (s < end) {
      _s.add(s);
      _v.add(v);
      final target = _targetSpeed(s);
      v = v < target
          ? math.min(target, v + accel * _dt)
          : math.max(target, v - decel * _dt);
      s += v * _dt;
    }
  }

  double get duration => _s.length * _dt;

  double sAt(double t) {
    final i = (t / _dt).floor().clamp(0, _s.length - 2);
    final f = (t / _dt - i).clamp(0.0, 1.0);
    return _s[i] + (_s[i + 1] - _s[i]) * f;
  }

  double vAt(double t) => _v[(t / _dt).floor().clamp(0, _v.length - 1)];

  /// Kedudukan (x timur, y utara; meter) pada jarak [s] sepanjang laluan benar.
  (double, double) _xy(double s) {
    final arcLen = math.pi * radiusM / 2;
    if (s <= straight1) return (s, 0);
    if (s <= straight1 + arcLen) {
      final a = (s - straight1) / radiusM; // 0..pi/2
      return (
        straight1 + radiusM * math.sin(a),
        -radiusM + radiusM * math.cos(a),
      );
    }
    final d = s - straight1 - arcLen;
    return (legM, -radiusM - d);
  }

  GeoPoint pointAtS(double s) {
    final (x, y) = _xy(s);
    return destinationPoint(destinationPoint(_origin, 90, x), 0, y);
  }

  double bearingAtS(double s) {
    final arcLen = math.pi * radiusM / 2;
    if (s <= straight1) return 90;
    if (s <= straight1 + arcLen) {
      return 90 + (s - straight1) / radiusM * 180 / math.pi;
    }
    return 180;
  }
}

class _Result {
  _Result(
    this.posErr,
    this.headErr,
    this.cornerPos,
    this.cornerHead,
    this.straightPos,
  );
  final List<double> straightPos;
  final List<VehiclePose> poses = [];
  final List<double> posErr;
  final List<double> headErr;
  final List<double> cornerPos;
  final List<double> cornerHead;

  static double p(List<double> xs, double q) {
    final s = [...xs]..sort();
    return s.isEmpty ? 0 : s[((s.length - 1) * q).round()];
  }

  @override
  String toString() =>
      'pos p95=${p(posErr, .95).toStringAsFixed(1)} max=${p(posErr, 1).toStringAsFixed(1)} m | '
      'head p95=${p(headErr, .95).toStringAsFixed(0)} max=${p(headErr, 1).toStringAsFixed(0)} deg | '
      'LURUS pos p95=${p(straightPos, .95).toStringAsFixed(1)} max=${p(straightPos, 1).toStringAsFixed(1)} | SELEKOH pos p95=${p(cornerPos, .95).toStringAsFixed(1)} max=${p(cornerPos, 1).toStringAsFixed(1)} m '
      'head p95=${p(cornerHead, .95).toStringAsFixed(0)} max=${p(cornerHead, 1).toStringAsFixed(0)} deg';
}

// ignore: library_private_types_in_public_api
_Result runDrive({
  double radiusM = 12,
  double noiseM = 3,
  double headingLagS = 0.8,
  double latencyS = 0.3,
  int seed = 11,
}) {
  final truth = _Truth(legM: 600, radiusM: radiusM);
  final route = NavRoute(lShapedRoute(legM: 600));
  final clock = FakeClock();
  final t0 = DateTime.utc(2026, 1, 1, 12);
  clock.now = t0;
  final session = NavigationSession(
    route: route,
    language: VoiceLanguage.ms,
    clock: clock.call,
  );
  final rnd = math.Random(seed);
  double gauss() {
    final u1 = 1 - rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) *
        math.cos(2 * math.pi * rnd.nextDouble());
  }

  // Fix 1 Hz dengan hingar; tiba selepas latensi.
  final arrivals = <(double, LocationFix)>[];
  for (var k = 0; k * 1.0 < truth.duration; k++) {
    final t = k.toDouble();
    final s = truth.sAt(t);
    final bearing = truth.bearingAtS(truth.sAt(math.max(0, t - headingLagS)));
    var point = truth.pointAtS(s);
    point = destinationPoint(point, 0, gauss() * noiseM);
    point = destinationPoint(point, 90, gauss() * noiseM);
    final v = truth.vAt(t);
    arrivals.add((
      t + latencyS,
      LocationFix(
        point: point,
        headingDegrees: v > 1 ? bearing.round() % 360 : null,
        accuracyMeters: 5,
        speedMps: v + gauss() * 0.2,
        timestamp: t0.add(Duration(milliseconds: (t * 1000).round())),
      ),
    ));
  }

  final posErr = <double>[];
  final headErr = <double>[];
  final cornerPos = <double>[];
  final cornerHead = <double>[];
  final straightPos = <double>[];
  final poses = <VehiclePose>[];
  var next = 0;
  const dt = 1 / 60;
  // Mula selepas 4 s (penapis dan model telah mantap).
  for (var t = 0.0; t < truth.duration - 1; t += dt) {
    clock.now = t0.add(Duration(microseconds: (t * 1e6).round()));
    while (next < arrivals.length && arrivals[next].$1 <= t) {
      session.onFix(arrivals[next++].$2);
    }
    final pose = session.poseAt(clock.now);
    poses.add(pose);
    if (t < 4) continue;
    final s = truth.sAt(t);
    final err = distanceMeters(pose.point, truth.pointAtS(s));
    final herr = angleDelta(pose.bearing, truth.bearingAtS(s)).abs();
    posErr.add(err);
    headErr.add(herr);
    if ((s - truth.cornerS).abs() > 80) straightPos.add(err);
    if ((s - truth.cornerS).abs() < 40) {
      cornerPos.add(err);
      cornerHead.add(herr);
    }
  }
  final result = _Result(posErr, headErr, cornerPos, cornerHead, straightPos);
  result.poses.addAll(poses);
  return result;
}

/// Memainkan semula pose yang dirakam melalui pemacu bingkai dengan [latency] kamera native; memulangkan
/// pusat kamera yang dihantar pada setiap bingkai.
List<GeoPoint> _replay(List<VehiclePose> poses, Duration latency) {
  final clock = FakeClock();
  final t0 = DateTime.utc(2026, 1, 1, 12);
  clock.now = t0;
  final camera = FakeCamera()..cameraLatency = latency;
  final driver = NavigationFrameDriver(
    camera: camera,
    poseAt: (now) {
      final i = (now.difference(t0).inMicroseconds / (1e6 / 60)).round().clamp(
        0,
        poses.length - 1,
      );
      return poses[i];
    },
    progress: () => null,
    viewportHeight: () => 844,
    cameraMode: () => NavCameraMode.auto,
    clock: clock.call,
  );
  final centers = <GeoPoint>[];
  var elapsed = Duration.zero;
  const frame = Duration(microseconds: 16667);
  for (var i = 0; i < poses.length; i++) {
    clock.now = t0.add(Duration(microseconds: (i * 1e6 / 60).round()));
    driver.step(elapsed);
    centers.add(camera.pose!.center);
    elapsed += frame;
  }
  driver.dispose();
  return centers;
}

void main() {
  // Nilai SEBELUM pembetulan (kod 0.5.1), jejari 12 m: ralat kedudukan maks 5.5 m, ralat arah maks 55 deg
  // di selekoh; jejari 8 m: 4.9 m / 65 deg; heading GPS lewat 1.5 s: 6.2 m; jejari 25 m: 11.6 m.
  group('simulator pemanduan realistik', () {
    test(
      'persimpangan biasa (jejari 12 m): kedudukan dan arah tepat di selekoh',
      () {
        final r = runDrive(radiusM: 12);
        // ignore: avoid_print
        print('jejari 12 m -> $r');
        expect(_Result.p(r.posErr, .95), lessThan(3.5));
        expect(_Result.p(r.straightPos, .95), lessThan(2.8));
        expect(_Result.p(r.cornerPos, 1), lessThan(4.0));
        expect(_Result.p(r.cornerHead, 1), lessThan(20));
      },
    );

    test('persimpangan ketat (jejari 8 m)', () {
      final r = runDrive(radiusM: 8);
      // ignore: avoid_print
      print('jejari 8 m -> $r');
      expect(_Result.p(r.cornerPos, 1), lessThan(4.0));
      expect(_Result.p(r.cornerHead, 1), lessThan(35));
    });

    test(
      'jejari besar (25 m): ralat dihadkan oleh geometri laluan, jauh lebih baik daripada 11.6 m',
      () {
        final r = runDrive(radiusM: 25);
        // ignore: avoid_print
        print('jejari 25 m -> $r');
        expect(_Result.p(r.cornerPos, 1), lessThan(8.5));
        expect(_Result.p(r.cornerHead, 1), lessThan(30));
      },
    );

    test('heading GPS lewat 1.5 s tidak menahan kereta di kaki lama', () {
      final r = runDrive(headingLagS: 1.5);
      // ignore: avoid_print
      print('lag heading 1.5 s -> $r');
      expect(_Result.p(r.cornerPos, 1), lessThan(4.0));
    });

    test('hingar GPS 6 m ditapis (tidak terus ke skrin)', () {
      final r = runDrive(noiseM: 6);
      // ignore: avoid_print
      print('hingar 6 m -> $r');
      expect(_Result.p(r.straightPos, .95), lessThan(6.0));
      expect(_Result.p(r.cornerHead, 1), lessThan(25));
    });

    test('latensi ketibaan fix 1 s dipampas', () {
      final r = runDrive(latencyS: 1.0);
      // ignore: avoid_print
      print('latensi 1 s -> $r');
      expect(_Result.p(r.posErr, 1), lessThan(7.0));
    });

    test(
      'latensi kamera native 100 ms: pusat kamera dipaparkan sepadan dengan kereta (>= 3x lebih baik)',
      () {
        final poses = runDrive(radiusM: 12).poses;
        final ideal = _replay(poses, Duration.zero);
        final compensated = _replay(poses, const Duration(milliseconds: 100));
        const lag = 6; // 100 ms pada 60 fps
        var with_ = <double>[];
        var without = <double>[];
        for (var i = 240 + lag; i < poses.length; i++) {
          // Kamera yang DIPAPARKAN pada bingkai i ialah yang dihantar 100 ms lalu.
          with_.add(distanceMeters(compensated[i - lag], ideal[i]));
          without.add(distanceMeters(ideal[i - lag], ideal[i]));
        }
        final w = _Result.p(with_, .95);
        final wo = _Result.p(without, .95);
        // ignore: avoid_print
        print(
          'drift kamera p95: tanpa pampasan ${wo.toStringAsFixed(2)} m, dengan ${w.toStringAsFixed(2)} m',
        );
        expect(wo, greaterThan(0.3), reason: 'tanpa pampasan memang ada drift');
        // Unjuran sepanjang lengkung + bearing adaptif: masih jauh lebih baik daripada tanpa
        // pampasan (dahulu 3x; longgar sedikit selepas lead lengkung).
        expect(w, lessThan(wo / 2.5));
      },
    );
  });
}
