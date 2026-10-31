import '../../../core/utils/geo.dart';

/// Unjuran titik ke polyline laluan.
class PolylineProjection {
  const PolylineProjection({
    required this.alongM,
    required this.crossTrackM,
    required this.snapped,
  });

  final double alongM;
  final double crossTrackM;
  final GeoPoint snapped;
}

/// Jarak kumulatif sepanjang [points] (meter); panjang sama dengan points.
List<double> cumulativeMeters(List<GeoPoint> points) {
  if (points.isEmpty) return const [];
  final out = <double>[0];
  for (var i = 1; i < points.length; i++) {
    out.add(out.last + distanceMeters(points[i - 1], points[i]));
  }
  return out;
}

/// Titik pada jarak [meters] sepanjang polyline.
GeoPoint pointAtMeters(
  List<GeoPoint> points,
  List<double> along,
  double meters,
) {
  if (points.isEmpty) return const GeoPoint(0, 0);
  if (points.length == 1 || along.isEmpty) return points.first;
  var lo = 0;
  var hi = along.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (along[mid] < meters) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  if (lo == 0) return points.first;
  final span = along[lo] - along[lo - 1];
  final t = span <= 0 ? 0.0 : ((meters - along[lo - 1]) / span).clamp(0.0, 1.0);
  final a = points[lo - 1];
  final b = points[lo];
  return GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
}

/// Sampel titik setiap [everyM] meter sepanjang laluan (asal + akhir sentiasa).
List<GeoPoint> samplePolyline(List<GeoPoint> points, {double everyM = 1500}) {
  if (points.isEmpty) return const [];
  if (points.length == 1) return [points.first];
  final along = cumulativeMeters(points);
  final total = along.last;
  if (total <= 0) return [points.first];
  final out = <GeoPoint>[points.first];
  for (var m = everyM; m < total; m += everyM) {
    out.add(pointAtMeters(points, along, m));
  }
  if (distanceMeters(out.last, points.last) > 50) out.add(points.last);
  return out;
}

/// Unjur [p] ke polyline; null jika polyline terlalu pendek.
PolylineProjection? projectOntoPolyline(List<GeoPoint> points, GeoPoint p) {
  if (points.length < 2) return null;
  final along = cumulativeMeters(points);
  var bestDist = double.infinity;
  var bestAlong = 0.0;
  GeoPoint bestSnap = points.first;

  for (var i = 0; i < points.length - 1; i++) {
    final proj = projectToSegment(p, points[i], points[i + 1]);
    if (proj.distanceM >= bestDist) continue;
    final segLen = along[i + 1] - along[i];
    bestDist = proj.distanceM;
    bestAlong = along[i] + proj.t * segLen;
    bestSnap = proj.point;
  }
  return PolylineProjection(
    alongM: bestAlong,
    crossTrackM: bestDist,
    snapped: bestSnap,
  );
}

/// Buang pendua dalam [maxM] meter (kekalkan yang lebih hampir ke laluan).
List<T> dedupeByProximity<T>({
  required List<T> items,
  required GeoPoint Function(T) pointOf,
  required double Function(T) crossTrackOf,
  double maxM = 80,
}) {
  final kept = <T>[];
  for (final item in items) {
    final p = pointOf(item);
    final dup = kept.any((k) => distanceMeters(pointOf(k), p) < maxM);
    if (dup) {
      final i = kept.indexWhere((k) => distanceMeters(pointOf(k), p) < maxM);
      if (i >= 0 && crossTrackOf(item) < crossTrackOf(kept[i])) {
        kept[i] = item;
      }
      continue;
    }
    kept.add(item);
  }
  return kept;
}
