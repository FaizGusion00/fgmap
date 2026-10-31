import 'along_route_poi.dart';

/// POI R&R/minyak paling hampir di hadapan dalam [withinM] (lalai 8 km).
AlongRoutePoi? nextAlongPoiAhead({
  required List<AlongRoutePoi> pois,
  required double alongNow,
  double withinM = 8000,
  double minAheadM = 80,
}) {
  AlongRoutePoi? best;
  var bestDist = double.infinity;
  for (final p in pois) {
    final d = p.alongM - alongNow;
    if (d < minAheadM || d > withinM) continue;
    if (d < bestDist) {
      bestDist = d;
      best = p;
    }
  }
  return best;
}
