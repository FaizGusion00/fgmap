import 'dart:math' as math;

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';

/// Satu titik jejak GPX.
class GpxPoint {
  const GpxPoint(this.point, this.time);

  final GeoPoint point;
  final DateTime? time;
}

final _trkpt = RegExp(
  r'<(?:trkpt|rtept)\b([^>]*?)(?:/>|>(.*?)</(?:trkpt|rtept)>)',
  dotAll: true,
);
final _attrLat = RegExp(r'''lat\s*=\s*["']([^"']+)["']''');
final _attrLon = RegExp(r'''lon\s*=\s*["']([^"']+)["']''');
final _timeTag = RegExp(r'<time>\s*([^<\s]+)\s*</time>');

/// Menghurai titik jejak/laluan daripada teks GPX. Toleran: titik rosak dilangkau.
List<GpxPoint> parseGpx(String xml) {
  final points = <GpxPoint>[];
  for (final match in _trkpt.allMatches(xml)) {
    final attrs = match.group(1) ?? '';
    final lat = double.tryParse(_attrLat.firstMatch(attrs)?.group(1) ?? '');
    final lon = double.tryParse(_attrLon.firstMatch(attrs)?.group(1) ?? '');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      continue;
    }
    final timeText = _timeTag.firstMatch(match.group(2) ?? '')?.group(1);
    points.add(GpxPoint(GeoPoint(lat, lon), DateTime.tryParse(timeText ?? '')));
  }
  return points;
}

/// Menukar titik GPX kepada fix GPS dengan kelajuan dan arah diterbitkan daripada perpindahan.
/// Tanpa cap masa, titik diandaikan dilalui pada [fallbackSpeedMps], satu fix sesaat.
List<LocationFix> gpxToFixes(
  List<GpxPoint> points, {
  double fallbackSpeedMps = 13.9,
  double accuracyM = 5,
}) {
  if (points.isEmpty) return const [];
  final hasTimes = points.every((p) => p.time != null);
  final base = hasTimes ? points.first.time! : DateTime.utc(2026);
  final fixes = <LocationFix>[];
  var syntheticSeconds = 0.0;

  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    double speed = 0;
    int? heading;
    if (i > 0) {
      final prev = points[i - 1];
      final dist = distanceMeters(prev.point, p.point);
      final dt = hasTimes
          ? p.time!.difference(prev.time!).inMilliseconds / 1000
          : dist / fallbackSpeedMps;
      speed = dt > 0 ? dist / dt : 0;
      if (dist > 1) {
        heading = bearingDegrees(prev.point, p.point).round() % 360;
      }
      syntheticSeconds += dt;
    }
    fixes.add(
      LocationFix(
        point: p.point,
        headingDegrees: speed > 1 ? heading : null,
        accuracyMeters: accuracyM,
        speedMps: math.max(0, speed),
        timestamp: hasTimes
            ? p.time
            : base.add(
                Duration(milliseconds: (syntheticSeconds * 1000).round()),
              ),
      ),
    );
  }
  return fixes;
}
