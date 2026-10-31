import '../../along_route/domain/along_route_projector.dart';
import '../../../core/utils/geo.dart';
import 'speed_camera.dart';

/// Cari kamera AwAS/OSM yang paling hampir di hadapan sepanjang laluan.
///
/// [corridorM] lalai lebih luas (~450 m) kerana pin AwAS dikurasi mungkin anggaran
/// (KM lebuh raya), bukan GPS tepat. [travelBearingDegrees] menapis `bound` NB/SB
/// bila diketahui.
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
    if (!_boundMatches(cam.bound, travelBearingDegrees)) continue;
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

/// NB ≈ utara (bearing 315–45), SB ≈ selatan (135–225), EB/WB serupa.
bool _boundMatches(String? bound, double? bearing) {
  if (bound == null || bound.isEmpty || bearing == null) return true;
  final b = ((bearing % 360) + 360) % 360;
  final key = bound.toUpperCase();
  return switch (key) {
    'NB' || 'N' => b < 45 || b >= 315,
    'SB' || 'S' => b >= 135 && b < 225,
    'EB' || 'E' => b >= 45 && b < 135,
    'WB' || 'W' => b >= 225 && b < 315,
    _ => true,
  };
}
