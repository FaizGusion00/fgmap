import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'report.dart';

@immutable
class ReportAhead {
  const ReportAhead(this.report, this.distanceM);

  final Report report;
  final double distanceM;
}

/// Laporan aktif di hadapan [position]: dalam [radiusM] dan (jika [headingDegrees] diketahui) dalam
/// ±[halfAngleDegrees] daripada arah perjalanan. Tanpa arah, semua laporan dalam jejari dipulangkan
/// (lebih baik amaran berlebihan daripada terlepas bahaya). Disusun dari yang terdekat.
List<ReportAhead> reportsAhead(
  Iterable<Report> reports,
  GeoPoint position, {
  double? headingDegrees,
  double radiusM = 600,
  double halfAngleDegrees = 60,
  required DateTime now,
}) {
  final out = <ReportAhead>[];
  for (final r in reports) {
    if (!r.isActive(now)) continue;
    final d = distanceMeters(position, r.point);
    if (d > radiusM) continue;
    // Sangat dekat: bearing tidak stabil dan laporan di sebelah pemandu masih relevan.
    if (headingDegrees != null && d > 30) {
      final bearing = bearingDegrees(position, r.point);
      if (angleDelta(headingDegrees, bearing).abs() > halfAngleDegrees) {
        continue;
      }
    }
    out.add(ReportAhead(r, d));
  }
  out.sort((a, b) => a.distanceM.compareTo(b.distanceM));
  return out;
}

@immutable
class ReportEvents {
  const ReportEvents({this.announce = const [], this.ask = const []});

  /// Laporan yang baharu masuk jarak amaran (umumkan sekali).
  final List<ReportAhead> announce;

  /// Laporan yang sedang dilepasi dan layak ditanya "Masih ada?" (tanya sekali).
  final List<ReportAhead> ask;

  bool get isEmpty => announce.isEmpty && ask.isEmpty;
}

/// Menjejak laporan mana yang sudah diumumkan/ditanya supaya setiap laporan hanya sekali bagi satu perjalanan.
class ReportAlertTracker {
  ReportAlertTracker({
    this.alertRadiusM = 500,
    this.askRadiusM = ReportRules.askRadiusM,
  });

  final double alertRadiusM;
  final double askRadiusM;

  final Set<String> _announced = {};
  final Set<String> _asked = {};

  ReportEvents update(
    Iterable<Report> reports,
    GeoPoint position, {
    required double? headingDegrees,
    required DateTime now,
  }) {
    final ahead = reportsAhead(
      reports,
      position,
      headingDegrees: headingDegrees,
      radiusM: alertRadiusM,
      now: now,
    );

    final announce = <ReportAhead>[];
    for (final a in ahead) {
      if (_announced.add(a.report.id)) announce.add(a);
    }

    // "Masih ada?": hanya bila hampir, laporan cukup tua, dan belum ditanya. Laporan baharu (dicipta pemandu
    // ini sendiri sebentar tadi) tidak ditanya.
    final ask = <ReportAhead>[];
    for (final r in reports) {
      if (!r.isActive(now) || _asked.contains(r.id)) continue;
      if (now.difference(r.createdAt) < ReportRules.minAgeToAsk) continue;
      final d = distanceMeters(position, r.point);
      if (d <= askRadiusM) {
        _asked.add(r.id);
        ask.add(ReportAhead(r, d));
      }
    }
    return ReportEvents(announce: announce, ask: ask);
  }

  /// Mulakan semula (perjalanan baharu).
  void reset() {
    _announced.clear();
    _asked.clear();
  }
}
