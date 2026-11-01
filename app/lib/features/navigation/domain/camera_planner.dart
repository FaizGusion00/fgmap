import 'dart:math' as math;
import 'dart:ui' show Size;

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
    this.followingGapM,
    this.sinceTurnM,
    this.lastKind,
  });

  final double speedMps;

  /// Jarak ke manuver bertindakan seterusnya; null jika tiada.
  final double? distanceToNextM;
  final ManeuverKind? nextKind;
  final NavCameraMode mode;

  /// Jarak dari manuver seterusnya ke manuver selepasnya (belokan berangkai); null jika tiada.
  final double? followingGapM;

  /// Jarak dilalui sejak manuver terakhir yang baru dilepasi, dan jenisnya: kamera kekal dekat
  /// sebentar selepas belok (tidak terus zum keluar di tengah simpang).
  final double? sinceTurnM;
  final ManeuverKind? lastKind;
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
/// raya dan bandar mendapat peralihan yang sama terasa: 1 dalam <= 5 s, 0 dalam >= 16 s
/// (tetingkap lebih awal daripada sebelumnya supaya bulatan/simpang jelas sebelum sampai).
double maneuverProximity(
  double distanceM,
  double speedMps, {
  double farS = 16,
}) {
  final t = distanceM / math.max(speedMps, 4.0);
  return 1 - _smoothstep(5, farS, t);
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
  final distance = s.distanceToNextM;
  final kind = s.nextKind;

  // Lebuh raya tanpa simpang dekat: zum keluar sedikit lagi untuk melihat jauh ke hadapan.
  final motorway = speed > 22 && (distance == null || distance > 2000);
  if (motorway) zoom -= 0.3;

  if (s.mode == NavCameraMode.flat) {
    return CameraTarget(zoom: zoom - 0.2, tilt: 0);
  }
  if (s.mode == NavCameraMode.tilted) {
    return CameraTarget(zoom: zoom, tilt: cruiseTilt);
  }

  // Manuver di hadapan.
  var p = 0.0;
  var boost = 0.0;
  var turnTilt = cruiseTilt;
  if (distance != null && kind != null) {
    // Keluar lebuh raya pada kelajuan tinggi: bersedia lebih awal (~24 s, bukan 16 s).
    final early = _exitKind(kind) && speed > 18;
    p = maneuverProximity(distance, speed, farS: early ? 24 : 16);
    // Belokan bandar: juga mengikut jarak mutlak, supaya simpang jelas walau perlahan.
    if (_turnKind(kind)) {
      p = math.max(p, 0.85 * (1 - _smoothstep(60, 200, distance)));
    }
    // Persimpangan kompleks: zum masuk juga mengikut jarak mutlak (~80 m) supaya
    // pendekatan perlahan masih mendapat pandangan jelas.
    if (_complexJunction(kind) && distance <= 80) {
      p = math.max(p, 1 - _smoothstep(20, 80, distance));
    }
    // Belokan berangkai (belok kiri, 120 m kemudian belok kanan): kekal dekat sepanjang rangkaian.
    final gap = s.followingGapM;
    if (gap != null && gap < 250 && distance < 200) p = math.max(p, 0.9);
    (boost, turnTilt) = _maneuverCamera(kind);
  }

  // Baru selepas belok: pegang pandangan belokan ~25 m, kemudian lepaskan perlahan hingga ~70 m.
  final since = s.sinceTurnM;
  final last = s.lastKind;
  if (since != null && last != null && since >= 0) {
    final hold = 1 - _smoothstep(25, 70, since);
    final (lastBoost, lastTilt) = _maneuverCamera(last);
    if (hold * lastBoost > p * boost) {
      p = hold;
      boost = lastBoost;
      turnTilt = lastTilt;
    }
  }

  if (p <= 0) return CameraTarget(zoom: zoom, tilt: cruiseTilt);
  zoom = math.min(19.2, zoom + p * boost);
  return CameraTarget(zoom: zoom, tilt: _lerp(cruiseTilt, turnTilt, p));
}

bool _exitKind(ManeuverKind kind) => switch (kind) {
  ManeuverKind.exitLeft ||
  ManeuverKind.exitRight ||
  ManeuverKind.rampLeft ||
  ManeuverKind.rampRight ||
  ManeuverKind.rampStraight ||
  ManeuverKind.keepLeft ||
  ManeuverKind.keepRight => true,
  _ => false,
};

bool _turnKind(ManeuverKind kind) => switch (kind) {
  ManeuverKind.left ||
  ManeuverKind.right ||
  ManeuverKind.sharpLeft ||
  ManeuverKind.sharpRight ||
  ManeuverKind.uTurn ||
  ManeuverKind.roundabout => true,
  _ => false,
};

bool _complexJunction(ManeuverKind kind) => switch (kind) {
  ManeuverKind.roundabout ||
  ManeuverKind.uTurn ||
  ManeuverKind.sharpLeft ||
  ManeuverKind.sharpRight ||
  ManeuverKind.keepLeft ||
  ManeuverKind.keepRight => true,
  _ => false,
};

/// (tambahan zum, condongan) apabila menghampiri jenis manuver ini.
(double, double) _maneuverCamera(ManeuverKind kind) {
  switch (kind) {
    case ManeuverKind.roundabout:
    case ManeuverKind.uTurn:
    case ManeuverKind.sharpLeft:
    case ManeuverKind.sharpRight:
      return (1.25, 10);
    case ManeuverKind.left:
    case ManeuverKind.right:
    case ManeuverKind.rampLeft:
    case ManeuverKind.rampRight:
    case ManeuverKind.exitLeft:
    case ManeuverKind.exitRight:
    case ManeuverKind.rampStraight:
      return (0.9, 28);
    case ManeuverKind.arrive:
    case ManeuverKind.arriveLeft:
    case ManeuverKind.arriveRight:
      return (0.7, 35);
    case ManeuverKind.slightLeft:
    case ManeuverKind.slightRight:
    case ManeuverKind.keepLeft:
    case ManeuverKind.keepRight:
      return (0.7, 36);
    case ManeuverKind.keepStraight:
    case ManeuverKind.merge:
    case ManeuverKind.mergeLeft:
    case ManeuverKind.mergeRight:
      return (0.4, 46);
    case ManeuverKind.depart:
    case ManeuverKind.straight:
    case ManeuverKind.ferry:
    case ManeuverKind.none:
      return (0.0, 56);
  }
}

/// Kedudukan menegak kenderaan di bawah tengah skrin, sebagai pecahan tinggi skrin (0.19 = kenderaan
/// di 69% dari atas). Cukup rendah untuk melihat jalan di hadapan, cukup tinggi untuk tidak tertutup
/// panel bawah.
const carScreenOffset = 0.19;

/// Mendatar (telefon landscape): tinggi skrin pendek, jadi kenderaan dinaikkan sedikit supaya tidak
/// terlindung panel maklumat di bawah dan masih ada jalan kelihatan di hadapan.
const carScreenOffsetLandscape = 0.12;

/// Free-ride (Waze 2D): puck lebih hampir ke tengah daripada kereta 3D navigasi.
const cruiseScreenOffset = 0.08;

/// Ofset kenderaan yang sesuai untuk saiz paparan [size].
double carScreenOffsetFor(Size size) =>
    size.width > size.height ? carScreenOffsetLandscape : carScreenOffset;

/// Ofset puck free-ride; landscape sedikit lebih kecil supaya jalan di hadapan kelihatan.
double cruiseScreenOffsetFor(Size size) =>
    size.width > size.height ? 0.05 : cruiseScreenOffset;

/// Pelarasan zum untuk paparan yang pendek (landscape): dengan tinggi lebih kecil, jarak jalan di
/// hadapan yang muat pada skrin mengecil, jadi zum dikurangkan sedikit. Paparan tinggi tidak diubah.
double viewportZoomAdjust(double viewportHeightPx) {
  const referenceHeightPx = 640.0;
  if (viewportHeightPx >= referenceHeightPx || viewportHeightPx <= 0) return 0;
  return (-0.5 * math.log(referenceHeightPx / viewportHeightPx) / math.ln2)
      .clamp(-0.6, 0.0);
}

/// Altitud kamera MapLibre sebagai gandaan tinggi viewport (medan pandang ~36.87 darjah).
const _cameraAltitude = 1.5;

/// Jarak di atas tanah (piksel pada skala pusat kamera) dari kenderaan ke pusat kamera supaya
/// kenderaan muncul tepat [carScreenOffset] di bawah tengah skrin pada condongan [tiltDegrees].
///
/// Tanpa condongan ia sekadar `offset x tinggi`. Dengan condongan, perspektif memampatkan jarak di
/// hadapan pusat, jadi jarak di tanah perlu LEBIH besar (bukan lebih kecil) untuk hasil skrin yang
/// sama. Unjuran kamera condong: y = A.d.cos(t) / (A - d.sin(t)) (A = altitud, d = jarak tanah);
/// ini ialah songsangannya.
double groundOffsetPx(
  double tiltDegrees,
  double viewportHeightPx, {
  double screenOffset = carScreenOffset,
}) {
  final t = tiltDegrees.clamp(0.0, 60.0) * math.pi / 180;
  final f = screenOffset;
  return _cameraAltitude *
      f *
      viewportHeightPx /
      (_cameraAltitude * math.cos(t) + f * math.sin(t));
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
       _offset = _Damped(carScreenOffset),
       _entry = entry;

  /// Pengali kelajuan tindak balas; > 1 lebih pantas (cth. Reduce Motion: peralihan lebih ringkas).
  final double responsiveness;
  final Duration entryDuration;

  final CameraPose _entry;
  final _Damped _zoom;
  final _Damped _tilt;
  final _Damped _bearing;

  /// Ofset skrin kenderaan yang dilicinkan: berubah lembut apabila telefon diputar.
  final _Damped _offset;
  bool _offsetPrimed = false;

  double _smoothedSpeed = 0;
  bool _speedPrimed = false;
  double _entryElapsed = 0;
  bool _entryPrimed = false;
  double _entryRemainingPx = 0;

  /// Jarak skrin (piksel) antara pusat kamera peralihan dan pusat navigasi sebenar; 0 selepas tiba.
  /// Kereta 3D (dilukis pada titik skrin tetap) hanya patut muncul bila ini kecil: jika tidak, jalan
  /// masih meluncur di bawahnya.
  double get entryRemainingPx => entryProgress >= 1 ? 0 : _entryRemainingPx;

  /// Tempoh peralihan masuk yang sesuai: lompatan jauh atau perubahan zum besar mendapat masa lebih,
  /// tetapi tidak pernah lebih 2.2 s (pemandu mahu mula). Jarak diukur dalam piksel pada zum akhir.
  static Duration entryDurationFor({
    required CameraPose from,
    required GeoPoint vehicle,
    required double speedMps,
    required double viewportHeightPx,
  }) {
    final goalZoom = zoomForSpeed(speedMps);
    final px =
        distanceMeters(from.center, vehicle) /
        metersPerPixel(goalZoom, vehicle.lat);
    final h = viewportHeightPx > 0 ? viewportHeightPx : 800;
    final s =
        0.9 +
        0.22 * (math.log(1 + px / h) / math.ln2) +
        0.12 * (from.zoom - goalZoom).abs();
    return Duration(milliseconds: (s.clamp(0.9, 2.2) * 1000).round());
  }

  /// Kelajuan dilicinkan (pemalar masa ~3 s) sebelum menentukan zum, supaya zum tidak bergoyang
  /// mengikut turun naik kelajuan kecil.
  double get smoothedSpeed => _smoothedSpeed;

  /// Kedudukan menegak kenderaan di bawah tengah skrin (pecahan tinggi) yang SEDANG digunakan kamera.
  /// Kereta di atas peta dilukis tepat di sini, jadi ia sentiasa di atas laluan.
  double get screenOffset => _offset.value;

  /// Kemajuan peralihan masuk 0..1 (1 = kamera sudah mengikut kenderaan sepenuhnya).
  double get entryProgress {
    if (entryDuration == Duration.zero) return 1;
    return (_entryElapsed / (entryDuration.inMilliseconds / 1000)).clamp(
      0.0,
      1.0,
    );
  }

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
    double zoomBias = 0,
    double screenOffset = carScreenOffset,
    double groundScale = 1,
    double yawRateDeg = 0,
    double? followingGapM,
    double? sinceTurnM,
    ManeuverKind? lastKind,
  }) {
    final safeDt = dt.clamp(0.0, 0.25);

    if (!_offsetPrimed) {
      _offset.snap(screenOffset);
      _offsetPrimed = true;
    } else {
      _offset.update(screenOffset, 0.35, safeDt);
    }

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
        followingGapM: followingGapM,
        sinceTurnM: sinceTurnM,
        lastKind: lastKind,
      ),
    );

    // Pilihan zum pengguna (butang +/-) ditambah pada zum automatik, jadi ia kekal bila kelajuan dan
    // manuver berubah, dan kamera terus mengikut kenderaan.
    final goalZoom =
        (target.zoom + zoomBias + viewportZoomAdjust(viewportHeightPx)).clamp(
          2.0,
          20.0,
        );

    // Peralihan masuk: peredam bermula TEPAT pada sasaran navigasi, dan pose yang dihantar ialah
    // interpolasi dari pandangan sebelumnya ke sasaran itu (pusat, zum, condongan, arah serentak).
    // Dahulu hanya pusat yang dilerp 1.4 s sementara zum (1 tahap/s) dan condongan (24 darjah/s)
    // terus mengejar ~2 s lagi selepas kereta muncul: jalan meluncur dan bergoyang di bawahnya.
    if (!_entryPrimed) {
      _entryPrimed = true;
      if (entryDuration > Duration.zero) {
        _zoom.snap(goalZoom);
        _tilt.snap(target.tilt);
        _bearing.snap(vehicleBearing);
      }
    }

    final k = responsiveness;
    // Had kelajuan perubahan: zum 1.0 tahap/saat, condongan 24 darjah/saat. Peredam sahaja tidak
    // cukup apabila sasaran melompat (selepas bulatan, tilt sasaran melonjak dari 12 ke 56).
    // Perubahan besar (masuk navigasi, pusatkan semula) dibenarkan lebih pantas.
    // Lancar dari 1 tahap/s (perubahan kecil) hingga 4 tahap/s (besar), tanpa "siku" pada 1.5 tahap.
    final zoomSpeed =
        1.0 + ((_zoom.value - goalZoom).abs() - 0.5).clamp(0.0, 3.0);
    _zoom.update(goalZoom, 0.9 / k, safeDt, maxSpeed: zoomSpeed * k);
    _tilt.update(target.tilt, 0.9 / k, safeDt, maxSpeed: 24.0 * k);
    // Di selekoh / dekat manuver: ikut arah kenderaan lebih rapat supaya kereta 3D dan AA
    // tidak "getah" di belakang tangen jalan.
    final nearTurn =
        distanceToNextM != null && distanceToNextM < 80 && nextKind != null;
    final turning = yawRateDeg > 18 || nearTurn;
    final bearingSmooth = (turning ? 0.20 : 0.45) / k;
    final bearingGoal =
        _bearing.value + angleDelta(_bearing.value, vehicleBearing);
    _bearing.update(bearingGoal, bearingSmooth, safeDt);

    // Pusat kamera diletakkan di hadapan kenderaan supaya kenderaan duduk pada [carScreenOffset]
    // di bawah tengah skrin pada SEMUA condongan dan zum (lihat [groundOffsetPx]). Ofset ialah fungsi
    // zum dan condongan yang SUDAH dilicinkan, jadi kenderaan kekal pada kedudukan skrin yang sama
    // walaupun zum berubah; tidak perlu dilicinkan lagi (itu menyebabkan lonjakan).
    // [groundScale] membetulkan ralat sistematik model kamera pada peranti sebenar (diukur oleh
    // pemacu daripada kedudukan skrin kenderaan yang sebenar); 1 = model tepat.
    final offsetM =
        groundScale *
        metersPerPixel(_zoom.value, vehicle.lat) *
        groundOffsetPx(
          _tilt.value,
          viewportHeightPx,
          screenOffset: _offset.value,
        );

    final bearing = normalizeBearing(_bearing.value);
    final navCenter = destinationPoint(vehicle, bearing, offsetM);

    final navPose = CameraPose(
      center: navCenter,
      zoom: _zoom.value,
      tilt: _tilt.value.clamp(0.0, 60.0),
      bearing: bearing,
    );

    // Peralihan masuk: dari pandangan peta sebelumnya terbang ke kenderaan.
    _entryElapsed += safeDt;
    final entryT = entryDuration == Duration.zero
        ? 1.0
        : (_entryElapsed / (entryDuration.inMilliseconds / 1000)).clamp(
            0.0,
            1.0,
          );
    if (entryT >= 1) return navPose;
    return _entryPose(navPose, entryT, viewportHeightPx);
  }

  /// Pose peralihan pada [t] (0..1): mudah-masuk-mudah-keluar (bermula dan tiba tanpa sentakan). Bila
  /// kenderaan jauh dari pandangan sebelumnya, kamera zum keluar sedikit di pertengahan (seperti
  /// "flyTo") supaya pergerakan di skrin tidak terlalu laju.
  CameraPose _entryPose(CameraPose nav, double t, double viewportHeightPx) {
    final e = t < 0.5
        ? 4 * t * t * t
        : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;
    final from = _entry;
    final lowZoom = math.min(from.zoom, nav.zoom);
    final h = viewportHeightPx > 0 ? viewportHeightPx : 800;
    final px =
        distanceMeters(from.center, nav.center) /
        metersPerPixel(lowZoom, nav.center.lat);
    final bump = (math.log(px / (h * 1.2)) / math.ln2).clamp(0.0, 4.0);
    final zoom =
        _lerp(from.zoom, nav.zoom, e) - bump * math.sin(math.pi * e) * 0.8;
    // Pusat bergerak supaya jarak SKRIN yang tinggal susut sekata walaupun zum masuk: bila zum naik,
    // pusat sudah hampir tiba (dalam meter) sebelum zum selesai. Tanpa ini, 10% terakhir peralihan
    // dari ikhtisar laluan (zum 11) ke zum memandu (18) ialah ribuan piksel jalan yang meluru.
    final zoomGain = math.max(0.0, zoom - from.zoom);
    final u = 1 - (1 - e) * math.pow(2, -zoomGain).toDouble();
    final center = GeoPoint(
      _lerp(from.center.lat, nav.center.lat, u),
      _lerp(from.center.lng, nav.center.lng, u),
    );
    _entryRemainingPx =
        distanceMeters(center, nav.center) /
        metersPerPixel(zoom, nav.center.lat);
    return CameraPose(
      center: center,
      zoom: zoom,
      tilt: _lerp(from.tilt, nav.tilt, e).clamp(0.0, 60.0),
      bearing: normalizeBearing(
        from.bearing + angleDelta(from.bearing, nav.bearing) * e,
      ),
    );
  }
}
