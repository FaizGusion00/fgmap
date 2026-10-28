import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import 'announcement_planner.dart';
import 'fix_filter.dart';
import 'instruction_text.dart';
import 'nav_route.dart';
import 'off_route_detector.dart';
import 'route_tracker.dart';
import 'vehicle_model.dart';

enum NavStatus {
  /// Di atas laluan.
  onRoute,

  /// Menyimpang; re-route diminta atau sedang dinanti.
  offRoute,
  arrived,
}

/// Keadaan navigasi pada satu masa, sedia dipaparkan.
@immutable
class NavProgress {
  const NavProgress({
    required this.status,
    required this.alongM,
    required this.remainingM,
    required this.remainingS,
    required this.next,
    required this.distanceToNextM,
    required this.following,
    required this.position,
    required this.bearing,
    required this.speedMps,
    required this.accuracyM,
    required this.crossTrackM,
    required this.street,
    required this.gpsWeak,
    this.signalLost = false,
  });

  final NavStatus status;
  final double alongM;
  final double remainingM;

  /// Anggaran masa baki, dilaras mengikut kelajuan sebenar pemandu berbanding anggaran laluan.
  final double remainingS;

  /// Manuver bertindakan seterusnya dan yang selepasnya (untuk "kemudian ...").
  final NavManeuver? next;
  final double? distanceToNextM;
  final NavManeuver? following;

  /// Kedudukan yang dipaparkan: terpadan dengan laluan jika di atas laluan.
  final GeoPoint position;
  final double bearing;
  final double speedMps;
  final double accuracyM;
  final double crossTrackM;
  final String? street;

  /// Isyarat GPS lemah atau hilang.
  final bool gpsWeak;

  /// Tiada fix langsung > 6 s (cth. terowong): kedudukan dianggar daripada kelajuan terakhir sepanjang laluan.
  final bool signalLost;

  /// Salinan dengan kemajuan dikemas kini (digunakan oleh kemas kini langsung antara dua fix).
  NavProgress withLive({
    required double alongM,
    required double remainingM,
    required double remainingS,
    required NavManeuver? next,
    required NavManeuver? following,
    required double? distanceToNextM,
  }) => NavProgress(
    status: status,
    alongM: alongM,
    remainingM: remainingM,
    remainingS: remainingS,
    next: next,
    distanceToNextM: distanceToNextM,
    following: following,
    position: position,
    bearing: bearing,
    speedMps: speedMps,
    accuracyM: accuracyM,
    crossTrackM: crossTrackM,
    street: street,
    gpsWeak: gpsWeak,
    signalLost: signalLost,
  );
}

@immutable
class RerouteRequest {
  const RerouteRequest({
    required this.origin,
    required this.headingDegrees,
    this.speedMps = 0,
  });

  final GeoPoint origin;
  final int? headingDegrees;

  /// Kelajuan semasa (m/s); digunakan oleh pengawal untuk mengunjur asal ke hadapan sepanjang latensi.
  final double speedMps;
}

@immutable
class SessionUpdate {
  const SessionUpdate({
    required this.progress,
    this.announcements = const [],
    this.reroute,
  });

  final NavProgress progress;
  final List<Announcement> announcements;

  /// Tidak null apabila pemandu disahkan menyimpang dan laluan baharu patut diminta.
  final RerouteRequest? reroute;
}

/// Seluruh logik navigasi untuk SATU laluan, tanpa I/O: terima fix GPS, hasilkan kemajuan,
/// pengumuman suara dan permintaan re-route. Sesi baharu dibuat untuk setiap laluan (termasuk
/// selepas re-route), jadi tiada keadaan lapuk antara laluan.
///
/// Masa disuntik ([clock]) supaya ujian deterministik.
class NavigationSession {
  NavigationSession({
    required this.route,
    required VoiceLanguage language,
    DateTime Function()? clock,
    this.isReroute = false,
  }) : _clock = clock ?? DateTime.now,
       _tracker = RouteTracker(route),
       _offRoute = OffRouteDetector(
         grace: isReroute ? const Duration(seconds: 6) : Duration.zero,
       ),
       vehicle = VehicleModel(route),
       _planner = AnnouncementPlanner(
         route: route,
         text: InstructionText(language),
       );

  final NavRoute route;
  final bool isReroute;
  final DateTime Function() _clock;
  final RouteTracker _tracker;
  final FixFilter _filter = FixFilter();
  final OffRouteDetector _offRoute;
  final AnnouncementPlanner _planner;

  /// Model gerakan kenderaan untuk bingkai kamera.
  final VehicleModel vehicle;

  NavProgress? _progress;
  NavProgress? get progress => _progress;

  double _along = 0;
  double? _startAlong;
  DateTime? _firstFixTime;
  DateTime? _lastFixTime;
  DateTime? _lastFixClock;
  double _lastBearing = 0;
  bool _offRouteRequested = false;

  /// Status "luar laluan" semasa; digunakan untuk hysteresis (kembali ke laluan perlu jarak < 60% ambang).
  bool _offState = false;

  /// Heading GPS terakhir yang sah dan masanya: digunakan jika fix semasa pegun (tiada heading).
  double? _lastGpsHeading;
  DateTime? _lastGpsHeadingTime;
  bool _arrived = false;
  bool _gpsLostAnnounced = false;
  bool _startPending = true;
  double _etaFactor = 1;
  double _liveAlong = 0;

  // Keadaan untuk menentukan ketibaan.
  double _minEndDistanceM = double.infinity;
  DateTime? _stoppedSince;

  set language(VoiceLanguage l) => _planner.language = l;

  /// Pengumuman pembukaan (sekali). Dipanggil sebaik sesi bermula.
  List<Announcement> takeStartAnnouncements() {
    if (!_startPending) return const [];
    _startPending = false;
    return _planner.start(isReroute: isReroute);
  }

  /// Sambung perjalanan yang disimpan. Tiada ayat pembukaan. Fix GPS seterusnya sama ada mengikut
  /// laluan ini atau, jika pemandu sudah menyimpang, mencetus laluan semula yang sedia ada.
  void primeRestored({
    required double alongM,
    required double speedMps,
    required DateTime time,
  }) {
    _startPending = false;
    _along = alongM.clamp(0.0, route.totalM);
    _liveAlong = _along;
    _startAlong = _along;
    _firstFixTime = time;
    _lastFixTime = time;
    _lastFixClock = _clock();
    vehicle.onRouteFix(alongM: _along, speedMps: speedMps, time: time);
  }

  Announcement get reroutingNotice => _planner.reroutingNotice;

  /// Memproses satu fix mentah. Memulangkan null jika fix ditolak oleh penapis.
  SessionUpdate? onFix(LocationFix raw) {
    final clockNow = _clock();
    final fix = _filter.accept(raw, now: clockNow);
    if (fix == null) return null;
    if (_arrived) return SessionUpdate(progress: _progress!);

    final gap = _lastFixTime == null
        ? Duration.zero
        : fix.time.difference(_lastFixTime!);
    _lastFixTime = fix.time;
    _lastFixClock = clockNow;
    _firstFixTime ??= fix.time;

    final match = _tracker.match(
      fix.point,
      headingDegrees: fix.headingDegrees,
      speedMps: fix.speedMps,
      gap: gap,
    );
    _startAlong ??= match.alongM;

    final threshold = _offRoute.threshold(fix);
    final onRoute = _offState
        ? match.crossTrackM <= threshold * OffRouteDetector.returnRatio
        : match.crossTrackM <= threshold;
    _offState = !onRoute;
    if (fix.headingDegrees != null && fix.speedMps >= 1) {
      _lastGpsHeading = fix.headingDegrees;
      _lastGpsHeadingTime = fix.time;
    }

    var announcements = <Announcement>[];
    RerouteRequest? reroute;

    if (onRoute) {
      _along = math.max(_along, match.alongM);
      _liveAlong = math.max(_liveAlong, _along);
      _offRouteRequested = false;
      _offRoute.reset();
      vehicle.onRouteFix(
        alongM: _along,
        speedMps: fix.speedMps,
        time: _measuredAt(fix, clockNow),
      );
      _lastBearing = match.routeBearing;
    } else {
      final request = _offRoute.update(match, fix);
      vehicle.onFreeFix(
        point: fix.point,
        bearing: fix.headingDegrees ?? _lastBearing,
        speedMps: fix.speedMps,
        time: _measuredAt(fix, clockNow),
      );
      if (fix.headingDegrees != null) _lastBearing = fix.headingDegrees!;
      if (request) {
        // Pengawal memutuskan sama ada permintaan dihantar (cooldown, permintaan tertunda) dan, jika
        // ya, memanggil [noteRerouteRequested] serta menyebut "mengira semula" sekali.
        reroute = RerouteRequest(
          origin: fix.point,
          headingDegrees: _headingForReroute(fix)?.round(),
          speedMps: fix.speedMps,
        );
      }
    }

    if (_gpsLostAnnounced) {
      _gpsLostAnnounced = false;
      announcements = [...announcements, _planner.gpsBackNotice];
    }

    final remaining = math.max(0.0, route.totalM - _along);
    if (onRoute && _hasArrived(fix, remaining)) {
      _arrived = true;
      final arrival = _planner.arrival();
      if (arrival != null) announcements = [...announcements, arrival];
    } else if (onRoute) {
      announcements = [
        ...announcements,
        ..._planner.update(alongM: _along, speedMps: fix.speedMps),
      ];
    }

    final progress = _buildProgress(
      fix: fix,
      match: match,
      onRoute: onRoute,
      remaining: remaining,
    );
    _progress = progress;
    return SessionUpdate(
      progress: progress,
      announcements: announcements,
      reroute: reroute,
    );
  }

  /// Berapa awal (meter) manuver dianggap "dilalui" dan arahan seterusnya dipaparkan. Pemandu sudah
  /// bertindak sebelum titik manuver, dan paparan + suara sentiasa ketinggalan sedikit; tanpa ini banner
  /// bertukar 1-2 s selepas simpang, dan dua simpang berturutan terasa terlewat.
  static double leadFor(double speedMps) => (speedMps * 0.7).clamp(3.0, 14.0);

  /// Masa fix DIUKUR, dinyatakan pada jam sesi. Fix tiba lewat (latensi GPS, hantaran platform); model
  /// kenderaan mengunjur dari masa ukuran supaya kereta tidak ketinggalan sebanyak latensi x kelajuan.
  static DateTime _measuredAtClock(DateTime fixTime, DateTime now) {
    final latency = now.difference(fixTime);
    const maxLatency = Duration(milliseconds: 2500);
    final clamped = latency.isNegative
        ? Duration.zero
        : (latency > maxLatency ? maxLatency : latency);
    return now.subtract(clamped);
  }

  DateTime _measuredAt(FilteredFix fix, DateTime now) =>
      _measuredAtClock(fix.time, now);

  /// Ketibaan. Ukuran ialah hujung laluan (titik jalan yang disnap), tetapi tiba terlalu awal di simpang
  /// besar lebih teruk daripada tiba beberapa meter lewat, jadi syaratnya ketat:
  ///  - dalam radius kecil (mengikut ketepatan GPS, 12-25 m) dari hujung laluan; ATAU
  ///  - sudah melepasi titik terdekat dengan hujung laluan (mula menjauh) dan masih dekat; ATAU
  ///  - berhenti dekat hujung laluan selama beberapa saat.
  bool _hasArrived(FilteredFix fix, double remaining) {
    final end = route.points.last;
    final distanceToEnd = distanceMeters(fix.point, end);
    _minEndDistanceM = math.min(_minEndDistanceM, distanceToEnd);

    final radius = (fix.accuracyM * 0.8).clamp(12.0, 25.0);
    if (remaining <= radius) return true;

    if (remaining <= 60 &&
        distanceToEnd <= 45 &&
        distanceToEnd > _minEndDistanceM + 8 &&
        fix.speedMps > 1.5) {
      return true;
    }

    if (remaining <= 40 && fix.speedMps < 1) {
      _stoppedSince ??= fix.time;
      if (fix.time.difference(_stoppedSince!) >= const Duration(seconds: 3)) {
        return true;
      }
    } else {
      _stoppedSince = null;
    }
    return false;
  }

  /// Kemas kini kemajuan ANTARA dua fix GPS (dipanggil beberapa kali sesaat). Kedudukan diambil daripada
  /// model kenderaan yang diunjur (sama seperti kereta yang dilukis), bukan fix 1 Hz, supaya banner,
  /// jarak dan pengumuman suara bertukar tepat apabila pemandu sampai ke simpang.
  ///
  /// Memulangkan null jika tiada apa yang perlu dikemas kini (manuver sama dan jarak berubah < 10 m).
  SessionUpdate? refreshLive() {
    final p = _progress;
    if (p == null || _arrived || p.status != NavStatus.onRoute) return null;
    final pose = vehicle.poseAt(_clock());
    if (!pose.onRoute) return null;

    _liveAlong = math.max(_liveAlong, math.max(_along, pose.alongM));
    final live = math.min(_liveAlong, route.totalM);
    final lead = leadFor(pose.speedMps);

    final announcements = _planner.update(
      alongM: live + lead,
      speedMps: pose.speedMps,
    );

    var next = route.nextActionable(live + lead);
    // Selepas manuver terakhir (ketibaan) dilepasi, kekalkan paparan sebelumnya.
    next ??= p.next;
    final following = next == null ? null : route.actionableAfter(next);
    final remaining = math.max(0.0, route.totalM - live);

    final indexChanged = next?.index != p.next?.index;
    final movedEnough = (p.remainingM - remaining).abs() >= 10;
    if (!indexChanged && !movedEnough && announcements.isEmpty) return null;

    final progress = p.withLive(
      alongM: live,
      remainingM: remaining,
      remainingS: route.plannedRemainingTime(live) * _etaFactor,
      next: next,
      following: following,
      distanceToNextM: next == null ? null : math.max(0.0, next.startM - live),
    );
    _progress = progress;
    return SessionUpdate(progress: progress, announcements: announcements);
  }

  /// Dipanggil secara berkala (cth. 1 Hz) untuk perkara yang berlaku TANPA fix baharu, iaitu isyarat
  /// GPS hilang. Memulangkan pengumuman jika ada.
  List<Announcement> tick() {
    final lastClock = _lastFixClock;
    if (lastClock == null || _arrived) return const [];
    final silent = _clock().difference(lastClock);
    if (silent >= const Duration(seconds: 6) && !_gpsLostAnnounced) {
      _gpsLostAnnounced = true;
      final p = _progress;
      if (p != null) {
        _progress = NavProgress(
          status: p.status,
          alongM: p.alongM,
          remainingM: p.remainingM,
          remainingS: p.remainingS,
          next: p.next,
          distanceToNextM: p.distanceToNextM,
          following: p.following,
          position: p.position,
          bearing: p.bearing,
          speedMps: p.speedMps,
          accuracyM: p.accuracyM,
          crossTrackM: p.crossTrackM,
          street: p.street,
          gpsWeak: true,
          signalLost: true,
        );
      }
      return [_planner.gpsLostNotice];
    }
    return const [];
  }

  /// Pose kenderaan pada [now] untuk bingkai kamera.
  VehiclePose poseAt(DateTime now) => vehicle.poseAt(now);

  NavProgress _buildProgress({
    required FilteredFix fix,
    required RouteMatch match,
    required bool onRoute,
    required double remaining,
  }) {
    final next = route.nextActionable(_along + leadFor(fix.speedMps));
    final following = next == null ? null : route.actionableAfter(next);

    // Faktor ETA: bandingkan masa sebenar dengan masa anggaran laluan untuk jarak yang sudah dilalui.
    // Pemberat meningkat dengan data (penuh selepas ~10 minit) supaya anggaran awal tidak melompat.
    final plannedElapsed =
        route.plannedTimeAt(_along) - route.plannedTimeAt(_startAlong ?? 0);
    final actualElapsed = fix.time.difference(_firstFixTime!).inSeconds;
    var etaFactor = 1.0;
    if (plannedElapsed >= 60 && actualElapsed >= 30) {
      final ratio = (actualElapsed / plannedElapsed).clamp(0.6, 2.0);
      final weight = (plannedElapsed / 600).clamp(0.0, 1.0);
      etaFactor = 1 + (ratio - 1) * weight;
    }
    _etaFactor = etaFactor;

    String? street;
    for (var i = (route.maneuverAt(_along)?.index ?? 0); i >= 0; i--) {
      if (route.maneuvers[i].street != null) {
        street = route.maneuvers[i].street;
        break;
      }
    }

    return NavProgress(
      status: _arrived
          ? NavStatus.arrived
          : (onRoute ? NavStatus.onRoute : NavStatus.offRoute),
      alongM: _along,
      remainingM: remaining,
      remainingS: route.plannedRemainingTime(_along) * etaFactor,
      next: next,
      distanceToNextM: next == null ? null : math.max(0, next.startM - _along),
      following: following,
      position: onRoute ? match.snapped : fix.point,
      bearing: onRoute ? match.routeBearing : _lastBearing,
      speedMps: fix.speedMps,
      accuracyM: fix.accuracyM,
      crossTrackM: match.crossTrackM,
      street: street,
      gpsWeak: fix.degraded || fix.accuracyM > 40,
    );
  }

  /// Benar jika re-route telah diminta dan belum pulih ke laluan.
  bool get awaitingReroute => _offRouteRequested;

  /// Pengawal memanggil ini apabila permintaan re-route benar-benar dihantar.
  void noteRerouteRequested() => _offRouteRequested = true;

  /// Heading untuk permintaan re-route: heading fix semasa, atau heading GPS terakhir (<= 10 s) jika
  /// kenderaan sedang perlahan/berhenti.
  double? _headingForReroute(FilteredFix fix) {
    if (fix.headingDegrees != null) return fix.headingDegrees;
    final at = _lastGpsHeadingTime;
    if (at != null && fix.time.difference(at) <= const Duration(seconds: 10)) {
      return _lastGpsHeading;
    }
    return null;
  }
}
