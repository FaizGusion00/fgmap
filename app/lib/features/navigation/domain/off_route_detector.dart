import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'fix_filter.dart';
import 'route_tracker.dart';

/// Mengesan pemandu menyimpang daripada laluan (Bahagian 8.5C pelan).
///
/// Menyimpang = jarak ke laluan melebihi ambang ADAPTIF (mengikut ketepatan GPS semasa) DAN arah
/// gerakan tidak sepadan dengan laluan, berterusan beberapa fix. Sengaja konservatif supaya
/// persimpangan rapat, flyover selari dan hingar GPS tidak mencetuskan re-route palsu.
class OffRouteDetector {
  OffRouteDetector({
    this.confirmFixes = 3,
    this.confirmTime = const Duration(milliseconds: 1800),
    this.cooldown = const Duration(seconds: 8),
  });

  /// Bilangan fix berturut-turut "di luar laluan" sebelum disahkan.
  final int confirmFixes;
  final Duration confirmTime;

  /// Selang minimum antara dua permintaan re-route.
  final Duration cooldown;

  int _count = 0;
  DateTime? _firstOffTime;
  DateTime? _lastRequest;

  /// Ambang jarak (meter) untuk ketepatan [accuracyM]: sekurang-kurangnya lebar jalan raya biasa,
  /// membesar apabila GPS kurang tepat.
  static double thresholdFor(double accuracyM) =>
      (25 + 1.5 * accuracyM).clamp(35.0, 120.0);

  /// Benar apabila re-route patut diminta untuk fix ini.
  bool update(RouteMatch match, FilteredFix fix) {
    final threshold = thresholdFor(fix.accuracyM);
    final offending = _isOff(match, fix, threshold);

    if (!offending) {
      reset();
      return false;
    }

    _firstOffTime ??= fix.time;
    _count++;

    // Jauh di luar laluan: lebih yakin, sahkan lebih cepat.
    final far = match.crossTrackM > threshold * 3;
    final needed = far ? math.max(2, confirmFixes - 1) : confirmFixes;
    final elapsed = fix.time.difference(_firstOffTime!);
    if (_count < needed || elapsed < (far ? Duration.zero : confirmTime)) {
      return false;
    }

    final last = _lastRequest;
    if (last != null && fix.time.difference(last) < cooldown) return false;
    return true;
  }

  /// Rekod bahawa re-route telah diminta (mulakan cooldown).
  void markRequested(DateTime at) => _lastRequest = at;

  /// Kosongkan kiraan (kembali ke laluan, atau laluan baharu dipasang).
  void reset() {
    _count = 0;
    _firstOffTime = null;
  }

  bool _isOff(RouteMatch match, FilteredFix fix, double threshold) {
    if (match.crossTrackM <= threshold) return false;
    // Hampir pegun jauh dari laluan: bukan menyimpang (cth. berhenti di stesen minyak) kecuali
    // sangat jauh. Re-route bermakna apabila bergerak.
    if (fix.speedMps < 2) return match.crossTrackM > threshold * 3;
    final heading = fix.headingDegrees;
    if (heading == null) return match.crossTrackM > threshold * 1.5;
    final diff = angleDelta(match.routeBearing, heading).abs();
    return diff > 40 || match.crossTrackM > threshold * 2;
  }
}
