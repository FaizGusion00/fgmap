import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'fix_filter.dart';
import 'route_tracker.dart';

/// Mengesan pemandu menyimpang daripada laluan (Bahagian 8.5C pelan).
///
/// Menyimpang = jarak ke laluan melebihi ambang ADAPTIF (mengikut ketepatan GPS semasa), berterusan
/// beberapa fix. Arah gerakan MEMPERCEPAT pengesahan (bukan syarat): jalan selari 36-70 m yang searah
/// juga dikesan (dahulu ia kekal "luar laluan" tanpa re-route). Hysteresis: kembali ke laluan memerlukan
/// jarak < 60% ambang, supaya status tidak berkelip di sempadan. Cooldown permintaan dipegang oleh
/// pengawal (bertahan merentas sesi), bukan di sini.
class OffRouteDetector {
  OffRouteDetector({
    this.confirmFixes = 3,
    this.confirmTime = const Duration(milliseconds: 2500),
    this.fastConfirmTime = const Duration(milliseconds: 1800),
    this.slowConfirmTime = const Duration(seconds: 4),
    this.grace = Duration.zero,
    this.graceScale = 1.5,
  });

  /// Bilangan fix berturut-turut "di luar laluan" sebelum disahkan (2 jika sangat jauh).
  final int confirmFixes;

  /// Tempoh minimum pengesahan: biasa, yakin (arah berbeza atau agak jauh), dan perlahan (< 2 m/s).
  final Duration confirmTime;
  final Duration fastConfirmTime;
  final Duration slowConfirmTime;

  /// Tempoh awal (diukur dari fix pertama) dengan ambang dibesarkan [graceScale]. Untuk sesi re-route:
  /// asal laluan baharu mungkin disnap ke jalan bersebelahan, dan tanpa ini ia mencetus re-route lagi.
  final Duration grace;
  final double graceScale;

  /// Nisbah ambang untuk dianggap kembali ke laluan (hysteresis).
  static const returnRatio = 0.6;

  int _count = 0;
  DateTime? _firstOffTime;
  DateTime? _firstSeen;

  /// Ambang jarak (meter) untuk ketepatan [accuracyM]: sekurang-kurangnya lebar jalan raya biasa,
  /// membesar apabila GPS kurang tepat.
  static double thresholdFor(double accuracyM) =>
      (25 + 1.5 * accuracyM).clamp(35.0, 120.0);

  /// Ambang semasa untuk [fix], termasuk pembesaran tempoh awal sesi.
  double threshold(FilteredFix fix) {
    _firstSeen ??= fix.time;
    final scale = fix.time.difference(_firstSeen!) < grace ? graceScale : 1.0;
    return thresholdFor(fix.accuracyM) * scale;
  }

  /// Benar apabila re-route patut diminta untuk fix ini. Pengawal memutuskan sama ada permintaan
  /// benar-benar dihantar (cooldown, permintaan tertunda).
  bool update(RouteMatch match, FilteredFix fix) {
    final threshold = this.threshold(fix);
    final cross = match.crossTrackM;

    if (cross <= threshold * returnRatio) {
      reset();
      return false;
    }
    // Di antara 60% dan 100% ambang: tahan kiraan (hysteresis), jangan tambah dan jangan padam.
    if (cross <= threshold) return false;

    final speed = fix.speedMps;
    // Hampir pegun jauh dari laluan: bukan menyimpang (cth. berhenti di stesen minyak) kecuali
    // sangat jauh.
    if (speed < 2 && cross <= threshold * 2) {
      reset();
      return false;
    }

    _firstOffTime ??= fix.time;
    _count++;

    final heading = fix.headingDegrees;
    final headingDiffers =
        heading != null && angleDelta(match.routeBearing, heading).abs() > 35;
    final far = cross > threshold * 3;
    final confident = headingDiffers || cross > threshold * 1.3;
    final slow = speed < 2;

    final needed = far && !slow ? math.max(2, confirmFixes - 1) : confirmFixes;
    final Duration minTime;
    if (far && !slow) {
      minTime = Duration.zero;
    } else if (slow) {
      minTime = slowConfirmTime;
    } else if (confident) {
      minTime = fastConfirmTime;
    } else {
      minTime = confirmTime;
    }
    return _count >= needed && fix.time.difference(_firstOffTime!) >= minTime;
  }

  /// Kosongkan kiraan (kembali ke laluan, atau laluan baharu dipasang).
  void reset() {
    _count = 0;
    _firstOffTime = null;
  }
}
