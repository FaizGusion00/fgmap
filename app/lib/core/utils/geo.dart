import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Titik geografi bebas pustaka peta, supaya domain dan data tidak terikat kepada MapLibre.
@immutable
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'GeoPoint($lat, $lng)';
}

/// Menyahkod polyline berkod (algoritma Google). Valhalla menggunakan ketepatan 6 digit.
///
/// Melempar [FormatException] jika input rosak (terpotong di tengah satu nilai).
List<GeoPoint> decodePolyline(String encoded, {int precision = 6}) {
  final factor = math.pow(10, precision).toDouble();
  final points = <GeoPoint>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextDelta() {
    var shift = 0;
    var result = 0;
    int byte;
    do {
      if (index >= encoded.length) {
        throw const FormatException('Polyline terpotong');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0 || byte > 63) {
        throw FormatException(
          'Aksara polyline tidak sah pada kedudukan ${index - 1}',
        );
      }
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    lat += nextDelta();
    lng += nextDelta();
    points.add(GeoPoint(lat / factor, lng / factor));
  }
  return points;
}

const _earthRadiusM = 6371008.8;
const _degToRad = math.pi / 180;
const _radToDeg = 180 / math.pi;

/// Jarak permukaan (meter) antara dua titik, formula haversine.
double distanceMeters(GeoPoint a, GeoPoint b) {
  final dLat = (b.lat - a.lat) * _degToRad;
  final dLng = (b.lng - a.lng) * _degToRad;
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(a.lat * _degToRad) *
          math.cos(b.lat * _degToRad) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Arah awal (0-360, 0 = utara, ikut jam) dari [a] ke [b].
double bearingDegrees(GeoPoint a, GeoPoint b) {
  final lat1 = a.lat * _degToRad;
  final lat2 = b.lat * _degToRad;
  final dLng = (b.lng - a.lng) * _degToRad;
  final y = math.sin(dLng) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return normalizeBearing(math.atan2(y, x) * _radToDeg);
}

/// Titik [distanceM] meter dari [from] mengikut arah [bearing] darjah.
GeoPoint destinationPoint(GeoPoint from, double bearing, double distanceM) {
  final delta = distanceM / _earthRadiusM;
  final theta = bearing * _degToRad;
  final lat1 = from.lat * _degToRad;
  final lng1 = from.lng * _degToRad;
  final lat2 = math.asin(
    math.sin(lat1) * math.cos(delta) +
        math.cos(lat1) * math.sin(delta) * math.cos(theta),
  );
  final lng2 =
      lng1 +
      math.atan2(
        math.sin(theta) * math.sin(delta) * math.cos(lat1),
        math.cos(delta) - math.sin(lat1) * math.sin(lat2),
      );
  return GeoPoint(lat2 * _radToDeg, ((lng2 * _radToDeg + 540) % 360) - 180);
}

/// Sudut dalam [0, 360).
double normalizeBearing(double degrees) => ((degrees % 360) + 360) % 360;

/// Beza bertanda terpendek `to - from` dalam (-180, 180]. Positif = putar ikut jam.
double angleDelta(double from, double to) {
  final d = normalizeBearing(to - from);
  return d > 180 ? d - 360 : d;
}

/// Hasil unjuran satu titik ke satu segmen garis.
class SegmentProjection {
  const SegmentProjection({
    required this.point,
    required this.t,
    required this.distanceM,
  });

  /// Titik terdekat pada segmen.
  final GeoPoint point;

  /// Kedudukan pada segmen, 0 (permulaan) hingga 1 (penghujung).
  final double t;

  /// Jarak mendatar dari titik asal ke [point].
  final double distanceM;
}

/// Unjur [p] ke segmen [a]-[b] pada satah tempatan (equirectangular di sekitar [a]); jitu untuk
/// segmen jalan yang pendek. Segmen sifar panjang memulangkan [a].
SegmentProjection projectToSegment(GeoPoint p, GeoPoint a, GeoPoint b) {
  final cosLat = math.cos(a.lat * _degToRad);
  const mPerDeg = _earthRadiusM * _degToRad;
  final bx = (b.lng - a.lng) * cosLat * mPerDeg;
  final by = (b.lat - a.lat) * mPerDeg;
  final px = (p.lng - a.lng) * cosLat * mPerDeg;
  final py = (p.lat - a.lat) * mPerDeg;
  final len2 = bx * bx + by * by;
  final t = len2 == 0 ? 0.0 : ((px * bx + py * by) / len2).clamp(0.0, 1.0);
  final dx = px - bx * t;
  final dy = py - by * t;
  return SegmentProjection(
    point: GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t),
    t: t,
    distanceM: math.sqrt(dx * dx + dy * dy),
  );
}

/// Meter per piksel logikal pada [zoom] MapLibre (jubin 512 px) di latitud [lat].
double metersPerPixel(double zoom, double lat) =>
    78271.51696 * math.cos(lat * _degToRad) / math.pow(2, zoom);
