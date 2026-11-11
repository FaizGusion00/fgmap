import 'dart:math' as math;

import '../../along_route/domain/along_route_projector.dart';
import '../../../core/utils/geo.dart';
import 'speed_camera.dart';

/// Cari kamera AwAS/OSM yang paling hampir di hadapan sepanjang laluan.
///
/// [corridorM] lalai lebih luas (~450 m) kerana pin AwAS dikurasi mungkin anggaran
/// (KM lebuh raya), bukan GPS tepat. [travelBearingDegrees] menapis `bound`/`direction`
/// bila diketahui (lihat [cameraAppliesToHeading]).
CameraAlert? nextCameraAlert({
  required List<GeoPoint> routePoints,
  required List<SpeedCamera> cameras,
  required double alongNow,
  required double alertWithinM,
  double corridorM = 450,
  double? travelBearingDegrees,
}) {
  if (routePoints.length < 2 || cameras.isEmpty) return null;
  CameraAlert? best;
  for (final cam in cameras) {
    if (!cameraAppliesToHeading(cam, travelBearingDegrees)) continue;
    final proj = projectOntoPolyline(routePoints, cam.point);
    if (proj == null) continue;
    // Pin anggaran (KM) perlu koridor ≥700 m supaya amaran masih berguna.
    final maxCross = cam.confidence == SpeedCameraConfidence.approx
        ? (corridorM < 700 ? 700.0 : corridorM)
        : corridorM;
    if (proj.crossTrackM > maxCross) continue;
    final ahead = proj.alongM - alongNow;
    if (ahead <= 30 || ahead > alertWithinM) continue;
    if (best == null || ahead < best.distanceAheadM) {
      best = CameraAlert(
        camera: cam,
        alongM: proj.alongM,
        distanceAheadM: ahead,
      );
    }
  }
  return best;
}

/// Kamera di hadapan semasa memandu bebas (tiada laluan): hanya kedudukan + arah GPS.
///
/// Kamera mesti berada dalam kon ±[coneHalfAngleDeg] di hadapan, dalam [alertWithinM]
/// (jarak lurus), dan ofset sisi ≤ [maxLateralM] dari garis arah (pin `approx` diberi
/// sekurang-kurangnya 150 m). Penapis `bound`/`direction` turut digunakan. Tanpa
/// [headingDegrees] "hadapan" tidak diketahui, jadi null. Memulangkan yang terdekat;
/// [CameraAlert.alongM] dan [CameraAlert.distanceAheadM] = jarak lurus.
CameraAlert? nextCameraAheadFreeDrive({
  required GeoPoint position,
  required double? headingDegrees,
  required List<SpeedCamera> cameras,
  required double alertWithinM,
  double coneHalfAngleDeg = 30,
  double maxLateralM = 60,
}) {
  if (headingDegrees == null || !headingDegrees.isFinite || cameras.isEmpty) {
    return null;
  }
  // Tapisan kasar kotak sempadan (~1 darjah lat ≈ 111 km) sebelum haversine.
  final dLatMax = alertWithinM / 110000 + 0.001;
  final dLngMax =
      dLatMax / math.max(0.01, math.cos(position.lat * math.pi / 180));
  CameraAlert? best;
  for (final cam in cameras) {
    if ((cam.point.lat - position.lat).abs() > dLatMax ||
        (cam.point.lng - position.lng).abs() > dLngMax) {
      continue;
    }
    final d = distanceMeters(position, cam.point);
    if (d <= 30 || d > alertWithinM) continue;
    final rel = angleDelta(headingDegrees, bearingDegrees(position, cam.point));
    if (rel.abs() > coneHalfAngleDeg) continue;
    final lateral = d * math.sin(rel.abs() * math.pi / 180);
    final maxLat = cam.confidence == SpeedCameraConfidence.approx
        ? math.max(maxLateralM, 150.0)
        : maxLateralM;
    if (lateral > maxLat) continue;
    if (!cameraAppliesToHeading(cam, headingDegrees)) continue;
    if (best == null || d < best.distanceAheadM) {
      best = CameraAlert(camera: cam, alongM: d, distanceAheadM: d);
    }
  }
  return best;
}

/// Sama ada kamera menguatkuasa kenderaan yang bergerak pada [headingDegrees].
///
/// `bound` diuji sebagai separuh satah (lebuh raya jarang lurus ke utara): NB lulus jika
/// arah ada komponen ke utara (270–90, eksklusif), SB (90–270), EB (0–180), WB (180–360).
/// `directionDegrees` lulus jika beza sudut ≤ 60°. Arah/bound tiada = lulus.
bool cameraAppliesToHeading(SpeedCamera cam, double? headingDegrees) {
  if (headingDegrees == null || !headingDegrees.isFinite) return true;
  final b = normalizeBearing(headingDegrees);
  if (!_boundMatches(cam.bound, b)) return false;
  final dir = cam.directionDegrees;
  if (dir != null && angleDelta(dir, b).abs() > 60) return false;
  return true;
}

bool _boundMatches(String? bound, double b) {
  if (bound == null || bound.isEmpty) return true;
  return switch (bound.toUpperCase()) {
    'NB' || 'N' => b > 270 || b < 90,
    'SB' || 'S' => b > 90 && b < 270,
    'EB' || 'E' => b > 0 && b < 180,
    'WB' || 'W' => b > 180,
    _ => true,
  };
}

/// Gabung kamera dibundel dengan hasil carian OSM langsung tanpa pendua: kamera langsung
/// dibuang jika id sama atau dalam [dedupeWithinM] daripada kamera dibundel.
List<SpeedCamera> mergeLiveCameras(
  List<SpeedCamera> bundled,
  List<SpeedCamera> live, {
  double dedupeWithinM = 150,
}) {
  if (live.isEmpty) return bundled;
  final ids = {for (final c in bundled) c.id};
  final out = List<SpeedCamera>.of(bundled);
  for (final cam in live) {
    if (ids.contains(cam.id)) continue;
    final near = bundled.any(
      (b) => distanceMeters(b.point, cam.point) <= dedupeWithinM,
    );
    if (near) continue;
    ids.add(cam.id);
    out.add(cam);
  }
  return out;
}
