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
}

@immutable
class RerouteRequest {
  const RerouteRequest({required this.origin, required this.headingDegrees});

  final GeoPoint origin;
  final int? headingDegrees;
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
  final OffRouteDetector _offRoute = OffRouteDetector();
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
  bool _arrived = false;
  bool _gpsLostAnnounced = false;
  bool _startPending = true;

  set language(VoiceLanguage l) => _planner.language = l;

  /// Pengumuman pembukaan (sekali). Dipanggil sebaik sesi bermula.
  List<Announcement> takeStartAnnouncements() {
    if (!_startPending) return const [];
    _startPending = false;
    return _planner.start(isReroute: isReroute);
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

    final threshold = OffRouteDetector.thresholdFor(fix.accuracyM);
    final onRoute = match.crossTrackM <= threshold;

    var announcements = <Announcement>[];
    RerouteRequest? reroute;

    if (onRoute) {
      _along = math.max(_along, match.alongM);
      _offRouteRequested = false;
      _offRoute.reset();
      vehicle.onRouteFix(
        alongM: _along,
        speedMps: fix.speedMps,
        time: clockNow,
      );
      _lastBearing = match.routeBearing;
    } else {
      final request = _offRoute.update(match, fix);
      vehicle.onFreeFix(
        point: fix.point,
        bearing: fix.headingDegrees ?? _lastBearing,
        speedMps: fix.speedMps,
        time: clockNow,
      );
      if (fix.headingDegrees != null) _lastBearing = fix.headingDegrees!;
      if (request) {
        _offRoute.markRequested(fix.time);
        _offRouteRequested = true;
        announcements = [_planner.reroutingNotice];
        reroute = RerouteRequest(
          origin: fix.point,
          headingDegrees: fix.headingDegrees?.round(),
        );
      }
    }

    if (_gpsLostAnnounced) {
      _gpsLostAnnounced = false;
      announcements = [...announcements, _planner.gpsBackNotice];
    }

    final remaining = math.max(0.0, route.totalM - _along);
    final arrivalThreshold = (fix.accuracyM * 1.2).clamp(25.0, 50.0);
    if (onRoute && remaining <= arrivalThreshold) {
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
    final next = route.nextActionable(_along);
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
}
