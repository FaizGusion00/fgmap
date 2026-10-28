import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../reports/presentation/report_alerts_controller.dart';
import '../../route_preview/data/route_planner.dart' show routeVehicleProvider;
import '../../speed_limits/data/speed_limit_service.dart';
import '../../speed_limits/domain/speed_limits.dart';
import '../data/navigation_settings.dart';
import '../data/screen_awake.dart';
import '../data/trip_record.dart';
import '../data/trip_store.dart';
import '../domain/announcement_planner.dart';
import '../domain/cruise_gate.dart';
import '../domain/cruise_voice.dart';
import '../domain/instruction_text.dart';
import '../domain/speed_limit_trail.dart';
import 'cruise_frame_driver.dart';
import 'navigation_controller.dart';

@immutable
class CruiseState {
  const CruiseState({
    this.active = false,
    this.handoff = false,
    this.speedMps = 0,
    this.limitKmh,
    this.overspeed = false,
    this.point,
    this.bearing = 0,
    this.fix,
  });

  final bool active;

  /// Benar semasa cruise dilepaskan kerana navigasi bermula: peta tidak membuka GPS idle.
  final bool handoff;
  final double speedMps;
  final int? limitKmh;
  final bool overspeed;
  final GeoPoint? point;
  final double bearing;

  /// Fix terakhir untuk pemacu kamera. Null apabila tidak aktif.
  final CruiseFix? fix;

  static const idle = CruiseState();
}

/// Memandu bebas: kamera 3D apabila kereta bergerak tanpa laluan. Tidak menulis garisan laluan dan
/// tidak memanggil pemacu bingkai navigasi. Mati serta-merta apabila navigasi aktif.
class CruiseController extends Notifier<CruiseState> {
  final CruiseGate _gate = CruiseGate();
  final CruiseVoice _voice = CruiseVoice();
  final SpeedLimitTrail _trail = SpeedLimitTrail();
  StreamSubscription<LocationFix>? _subscription;
  VoiceLanguage _language = VoiceLanguage.ms;
  bool _blocked = false;
  bool _background = false;
  int _limitGeneration = 0;
  DateTime? _lastPersist;

  @override
  CruiseState build() {
    releaseActiveCruise = releaseForNavigation;
    ref.onDispose(() {
      if (releaseActiveCruise == releaseForNavigation) {
        releaseActiveCruise = null;
      }
      unawaited(_subscription?.cancel());
      _subscription = null;
    });
    final saved = ref.read(tripStoreProvider).read();
    if (saved is CruiseTrip) {
      return _resume(saved);
    }
    return CruiseState.idle;
  }

  void setLanguage(VoiceLanguage language) => _language = language;

  CruiseState _resume(CruiseTrip saved) {
    final clock = ref.read(navClockProvider);
    _gate.seedActive(
      stoppedSince: saved.speedMps < CruiseGate.exitSpeedMps
          ? saved.savedAt
          : null,
    );
    _language = VoiceLanguage.fromCode(saved.languageCode);
    _trail.add(saved.position);
    final fix = CruiseFix(
      point: saved.position,
      bearing: saved.bearing,
      speedMps: saved.speedMps,
      time: clock(),
    );
    _listenGps();
    if (!_background) unawaited(ref.read(screenAwakeProvider).enable());
    return CruiseState(
      active: true,
      speedMps: saved.speedMps,
      limitKmh: saved.limitKmh,
      point: saved.position,
      bearing: saved.bearing,
      fix: fix,
    );
  }

  /// Sampel daripada penjejak peta (satu langganan idle). Apabila ambang masuk dicapai, langganan
  /// itu digantung oleh peta dan cruise mengambil [LocationService.navigationFixes] — masih satu
  /// strim.
  void noteIdle({
    required GeoPoint point,
    required double speedMps,
    required double? heading,
    required DateTime time,
    required bool blocked,
  }) {
    _blocked = blocked || ref.read(navigationControllerProvider).isActive;
    if (state.active) return;
    final on = _gate.update(
      time: time,
      speedMps: speedMps,
      headingKnown: heading != null,
      blocked: _blocked,
    );
    if (!on) return;
    _engage(
      CruiseFix(
        point: point,
        bearing: heading ?? 0,
        speedMps: speedMps,
        time: time,
      ),
    );
  }

  void setBlocked(bool blocked) {
    _blocked = blocked;
    if (blocked && state.active) {
      _disengage(clearTrip: true, handoff: false);
    }
  }

  /// Navigasi bermula: lepaskan GPS cruise dahulu supaya hanya satu langganan kekal.
  void releaseForNavigation() {
    _blocked = true;
    if (!state.active && _subscription == null) {
      _gate.reset();
      return;
    }
    _disengage(clearTrip: true, handoff: true);
  }

  void noteBackground(bool background) {
    _background = background;
    if (!state.active) return;
    if (background) {
      unawaited(ref.read(screenAwakeProvider).disable());
      unawaited(_persist(force: true));
    } else {
      unawaited(ref.read(screenAwakeProvider).enable());
    }
  }

  void _engage(CruiseFix fix) {
    _listenGps();
    state = CruiseState(
      active: true,
      speedMps: fix.speedMps,
      point: fix.point,
      bearing: fix.bearing,
      fix: fix,
    );
    if (!_background) unawaited(ref.read(screenAwakeProvider).enable());
    unawaited(_persist(force: true));
    ref.read(reportAlertsProvider.notifier).reset();
  }

  void _listenGps() {
    if (_subscription != null) return;
    _subscription = ref
        .read(locationServiceProvider)
        .navigationFixes()
        .listen(_onFix);
  }

  void _onFix(LocationFix fix) {
    if (!ref.mounted || !state.active) return;
    if (ref.read(navigationControllerProvider).isActive) {
      releaseForNavigation();
      return;
    }
    final time = fix.timestamp ?? ref.read(navClockProvider)();
    final speed = fix.speedMps ?? 0;
    final heading = fix.headingDegrees?.toDouble();
    final still = _gate.update(
      time: time,
      speedMps: speed,
      headingKnown: heading != null || _gate.active,
      blocked: _blocked,
    );
    if (!still) {
      _disengage(clearTrip: true, handoff: false);
      return;
    }
    final bearing = followHeading(
      state.bearing,
      heading,
      speedMps: speed,
      known: state.fix != null,
    );
    final sample = CruiseFix(
      point: fix.point,
      bearing: bearing,
      speedMps: speed,
      time: time,
    );
    final limit = state.limitKmh;
    final over = _overspeed(speed, limit);
    state = CruiseState(
      active: true,
      speedMps: speed,
      limitKmh: limit,
      overspeed: over,
      point: fix.point,
      bearing: bearing,
      fix: sample,
    );
    _speak(
      _voice.update(
        voiceEnabled: ref.read(navigationSettingsProvider).voiceEnabled,
        overspeed: over,
        limitKmh: limit,
        now: ref.read(navClockProvider)(),
        language: _language,
      ),
    );
    _speak(
      ref.read(reportAlertsProvider.notifier).onFix(fix, _language),
    );
    _trail.add(fix.point);
    if (_trail.due(time, fix.point)) unawaited(_refreshLimit(fix.point, time));
    unawaited(_persist());
  }

  bool _overspeed(double speedMps, int? limit) {
    final tolerance = ref.read(navigationSettingsProvider).overspeedToleranceKmh;
    if (tolerance < 0) return false;
    return overspeedLevel(
          speedKmh: speedMps * 3.6,
          limitKmh: limit,
          toleranceKmh: tolerance,
        ) ==
        OverspeedLevel.warning;
  }

  Future<void> _refreshLimit(GeoPoint here, DateTime time) async {
    final generation = ++_limitGeneration;
    _trail.markQueried(time, here);
    final points = List<GeoPoint>.of(_trail.points);
    int? limit;
    try {
      limit = await ref
          .read(speedLimitServiceProvider)
          .limitForTrace(points, ref.read(routeVehicleProvider));
    } on Object {
      limit = null;
    }
    if (!ref.mounted || generation != _limitGeneration || !state.active) return;
    final over = _overspeed(state.speedMps, limit);
    _speak(
      _voice.update(
        voiceEnabled: ref.read(navigationSettingsProvider).voiceEnabled,
        overspeed: over,
        limitKmh: limit,
        now: ref.read(navClockProvider)(),
        language: _language,
      ),
    );
    state = CruiseState(
      active: true,
      speedMps: state.speedMps,
      limitKmh: limit,
      overspeed: over,
      point: state.point,
      bearing: state.bearing,
      fix: state.fix,
    );
  }

  void _speak(List<Announcement> announcements) {
    if (announcements.isEmpty) return;
    if (!ref.read(navigationSettingsProvider).voiceEnabled) return;
    final voice = ref.read(voiceGuideProvider);
    for (final a in announcements) {
      unawaited(voice.announce(a, _language));
    }
  }

  void _disengage({required bool clearTrip, required bool handoff}) {
    _limitGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _gate.reset();
    _voice.reset();
    _trail.clear();
    state = CruiseState(handoff: handoff);
    if (clearTrip) {
      final saved = ref.read(tripStoreProvider).read();
      if (saved is! NavigationTrip) {
        unawaited(ref.read(tripStoreProvider).clear());
      }
    }
    if (!handoff) unawaited(ref.read(screenAwakeProvider).disable());
  }

  Future<void> _persist({bool force = false}) async {
    if (!state.active) return;
    final point = state.point;
    if (point == null) return;
    final now = ref.read(navClockProvider)();
    final last = _lastPersist;
    if (!force &&
        last != null &&
        now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastPersist = now;
    await ref.read(tripStoreProvider).write(
      CruiseTrip(
        savedAt: now.toUtc(),
        position: point,
        bearing: state.bearing,
        speedMps: state.speedMps,
        limitKmh: state.limitKmh,
        languageCode: _language.code,
      ),
    );
  }
}

final cruiseControllerProvider = NotifierProvider<CruiseController, CruiseState>(
  CruiseController.new,
);
