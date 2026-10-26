import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'nav_route.dart';

/// Mod kamera navigasi.
enum NavCameraMode {
  /// Pandangan 3D atau 2D mengikut keadaan: condong di jalan lurus, menegak di selekoh dan bulatan.
  auto,

  /// Sentiasa 2D (pandangan atas, arah ke hadapan).
  flat,

  /// Sentiasa 3D condong.
  tilted;

  static NavCameraMode fromName(String? name) => values.firstWhere(
    (m) => m.name == name,
    orElse: () => NavCameraMode.auto,
  );
}

@immutable
class CameraPose {
  const CameraPose({
    required this.center,
    required this.zoom,
    required this.tilt,
    required this.bearing,
  });

  final GeoPoint center;
  final double zoom;

  /// Sudut condong dari menegak ke bawah (0 = 2D).
  final double tilt;
  final double bearing;
}

/// Keadaan memandu yang menentukan rupa kamera.
@immutable
class CameraSituation {
  const CameraSituation({
    required this.speedMps,
    required this.distanceToNextM,
    required this.nextKind,
    this.mode = NavCameraMode.auto,
  });

  final double speedMps;

  /// Jarak ke manuver bertindakan seterusnya; null jika tiada.
  final double? distanceToNextM;
  final ManeuverKind? nextKind;
  final NavCameraMode mode;
}

/// Sasaran zum dan condongan untuk satu situasi (sebelum pelicinan).
@immutable
class CameraTarget {
  const CameraTarget({required this.zoom, required this.tilt});

  final double zoom;
  final double tilt;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// Zum asas mengikut kelajuan: perlahan = dekat dan terperinci, laju = jauh untuk melihat ke hadapan.
double zoomForSpeed(double speedMps) {
  const table = [
    (0.0, 18.5),
    (8.0, 18.15),
    (17.0, 17.5),
    (25.0, 16.9),
    (33.0, 16.5),
    (42.0, 16.2),
  ];
  final v = speedMps.clamp(0.0, table.last.$1);
  for (var i = 1; i < table.length; i++) {
    if (v <= table[i].$1) {
      final (v0, z0) = table[i - 1];
      final (v1, z1) = table[i];
      return _lerp(z0, z1, (v - v0) / (v1 - v0));
    }
  }
  return table.last.$2;
}

/// Seberapa hampir (0..1) manuver seterusnya, dalam MASA ke manuver (bukan jarak) supaya lebuh
/// raya dan bandar mendapat peralihan yang sama terasa: 1 dalam <= 4 s, 0 dalam >= 12 s.
double maneuverProximity(double distanceM, double speedMps) {
  final t = distanceM / math.max(speedMps, 4.0);
  return 1 - _smoothstep(4, 12, t);
}

/// Memilih zum dan condongan. Fungsi tulen dan deterministik.
///
/// Rasional (Bahagian 14.3 pelan): di jalan lurus, 3D condong memberi pandangan jauh ke hadapan;
/// menghampiri selekoh, bulatan atau pusingan-U, kamera naik menegak dan zum masuk supaya bentuk
/// persimpangan jelas dan pemandu tahu tepat di mana hendak belok; selepas itu ia kembali ke 3D.
CameraTarget planCamera(CameraSituation s) {
  final speed = s.speedMps;
  var zoom = zoomForSpeed(speed);
  final cruiseTilt = _lerp(52, 60, (speed / 25).clamp(0.0, 1.0));

  if (s.mode == NavCameraMode.flat) {
    return CameraTarget(zoom: zoom - 0.2, tilt: 0);
  }

  final distance = s.distanceToNextM;
  final kind = s.nextKind;
  if (s.mode == NavCameraMode.tilted || distance == null || kind == null) {
    return CameraTarget(zoom: zoom, tilt: cruiseTilt);
  }

  final p = maneuverProximity(distance, speed);
  final (boost, turnTilt) = _maneuverCamera(kind);
  zoom = math.min(19.2, zoom + p * boost);
  return CameraTarget(zoom: zoom, tilt: _lerp(cruiseTilt, turnTilt, p));
}

/// (tambahan zum, condongan) apabila menghampiri jenis manuver ini.
(double, double) _maneuverCamera(ManeuverKind kind) {
  switch (kind) {
    case ManeuverKind.roundabout:
    case ManeuverKind.uTurn:
    case ManeuverKind.sharpLeft:
    case ManeuverKind.sharpRight:
      return (1.0, 12);
    case ManeuverKind.left:
    case ManeuverKind.right:
    case ManeuverKind.rampLeft:
    case ManeuverKind.rampRight:
    case ManeuverKind.exitLeft:
    case ManeuverKind.exitRight:
    case ManeuverKind.rampStraight:
      return (0.8, 30);
    case ManeuverKind.arrive:
    case ManeuverKind.arriveLeft:
    case ManeuverKind.arriveRight:
      return (0.7, 35);
    case ManeuverKind.slightLeft:
    case ManeuverKind.slightRight:
    case ManeuverKind.keepLeft:
    case ManeuverKind.keepRight:
    case ManeuverKind.keepStraight:
    case ManeuverKind.merge:
    case ManeuverKind.mergeLeft:
    case ManeuverKind.mergeRight:
      return (0.35, 46);
    case ManeuverKind.depart:
    case ManeuverKind.straight:
    case ManeuverKind.ferry:
    case ManeuverKind.none:
      return (0.0, 56);
  }
}

/// Peredam kritikal tanpa terlajak (SmoothDamp): bebas kadar bingkai dan stabil pada dt besar.
class _Damped {
  _Damped(this.value);

  double value;
  double _velocity = 0;

  /// [maxSpeed] (unit/saat) menghad kelajuan perubahan, supaya sasaran yang melompat (cth. selepas
  /// bulatan: condongan dari 12 kembali ke 56) tetap menghasilkan gerakan yang lembut.
  void update(
    double target,
    double smoothTime,
    double dt, {
    double maxSpeed = double.infinity,
  }) {
    if (dt <= 0) return;
    final omega = 2 / math.max(0.0001, smoothTime);
    final x = omega * dt;
    final exp = 1 / (1 + x + 0.48 * x * x + 0.235 * x * x * x);
    final maxChange = maxSpeed * smoothTime;
    final change = (value - target).clamp(-maxChange, maxChange);
    final limitedTarget = value - change;
    final temp = (_velocity + omega * change) * dt;
    _velocity = (_velocity - omega * temp) * exp;
    var next = limitedTarget + (change + temp) * exp;
    // Elak terlajak melepasi sasaran asal.
    if ((target - value > 0) == (next > target)) {
      next = target;
      _velocity = (next - target) / dt;
    }
    value = next;
  }

  void snap(double v) {
    value = v;
    _velocity = 0;
  }
}

/// Memacu kamera: kenderaan di bawah tengah skrin, kamera menghadap arah gerakan, semua nilai
/// (zum, condongan, arah, ofset) dilicinkan dengan peredam kritikal supaya perubahan terasa lembut
/// dan tidak pernah tersentak, termasuk pada selekoh tajam dan peralihan 3D <-> 2D.
class CameraRig {
  CameraRig({
    required CameraPose entry,
    this.responsiveness = 1,
    this.entryDuration = const Duration(milliseconds: 1400),
  }) : _zoom = _Damped(entry.zoom),
       _tilt = _Damped(entry.tilt),
       _bearing = _Damped(entry.bearing),
       _entry = entry;

  /// Pengali kelajuan tindak balas; > 1 lebih pantas (cth. Reduce Motion: peralihan lebih ringkas).
  final double responsiveness;
  final Duration entryDuration;

  final CameraPose _entry;
  final _Damped _zoom;
  final _Damped _tilt;
  final _Damped _bearing;

  double _smoothedSpeed = 0;
  bool _speedPrimed = false;
  double _entryElapsed = 0;

  /// Kelajuan dilicinkan (pemalar masa ~3 s) sebelum menentukan zum, supaya zum tidak bergoyang
  /// mengikut turun naik kelajuan kecil.
  double get smoothedSpeed => _smoothedSpeed;

  /// Majukan kamera sebanyak [dt] saat. Memulangkan pose baharu.
  ///
  /// [viewportHeightPx] ialah tinggi peta (piksel logikal), digunakan untuk mengira berapa jauh
  /// kamera patut berada di hadapan kenderaan supaya kenderaan duduk di bahagian bawah skrin.
  CameraPose step({
    required double dt,
    required GeoPoint vehicle,
    required double vehicleBearing,
    required double speedMps,
    required double? distanceToNextM,
    required ManeuverKind? nextKind,
    required double viewportHeightPx,
    NavCameraMode mode = NavCameraMode.auto,
  }) {
    final safeDt = dt.clamp(0.0, 0.25);

    if (!_speedPrimed) {
      _smoothedSpeed = speedMps;
      _speedPrimed = true;
    } else {
      _smoothedSpeed +=
          (speedMps - _smoothedSpeed) * (1 - math.exp(-safeDt / 3.0));
    }

    final target = planCamera(
      CameraSituation(
        speedMps: _smoothedSpeed,
        distanceToNextM: distanceToNextM,
        nextKind: nextKind,
        mode: mode,
      ),
    );

    final k = responsiveness;
    // Had kelajuan perubahan: zum 1.0 tahap/saat, condongan 24 darjah/saat. Peredam sahaja tidak
    // cukup apabila sasaran melompat (selepas bulatan, tilt sasaran melonjak dari 12 ke 56).
    // Perubahan besar (masuk navigasi, pusatkan semula) dibenarkan lebih pantas.
    final zoomSpeed = (_zoom.value - target.zoom).abs() > 1.5 ? 4.0 : 1.0;
    _zoom.update(target.zoom, 0.9 / k, safeDt, maxSpeed: zoomSpeed * k);
    _tilt.update(target.tilt, 0.9 / k, safeDt, maxSpeed: 24.0 * k);
    // Arah mengikut jalan lebih pantas supaya peta berputar bersama selekoh, tetapi tetap lembut.
    final bearingGoal =
        _bearing.value + angleDelta(_bearing.value, vehicleBearing);
    _bearing.update(bearingGoal, 0.45 / k, safeDt);

    // Kenderaan sekitar 22% tinggi skrin di bawah tengah (kurang apabila condong: perspektif
    // memampatkan jarak jauh).
    final fraction = 0.21 - 0.07 * (_tilt.value / 60).clamp(0.0, 1.0);
    // Ofset ialah fungsi zum dan condongan yang SUDAH dilicinkan, jadi kenderaan kekal pada kedudukan
    // skrin yang sama walaupun zum berubah; tidak perlu dilicinkan lagi (itu menyebabkan lonjakan).
    final offsetM =
        metersPerPixel(_zoom.value, vehicle.lat) * viewportHeightPx * fraction;

    final bearing = normalizeBearing(_bearing.value);
    final navCenter = destinationPoint(vehicle, bearing, offsetM);

    // Peralihan masuk: dari pandangan peta sebelumnya terbang ke kenderaan.
    _entryElapsed += safeDt;
    final entryT = entryDuration == Duration.zero
        ? 1.0
        : (_entryElapsed / (entryDuration.inMilliseconds / 1000)).clamp(
            0.0,
            1.0,
          );
    final eased = 1 - math.pow(1 - entryT, 3).toDouble();
    final center = entryT >= 1
        ? navCenter
        : GeoPoint(
            _lerp(_entry.center.lat, navCenter.lat, eased),
            _lerp(_entry.center.lng, navCenter.lng, eased),
          );

    return CameraPose(
      center: center,
      zoom: _zoom.value,
      tilt: _tilt.value.clamp(0.0, 60.0),
      bearing: bearing,
    );
  }
}
