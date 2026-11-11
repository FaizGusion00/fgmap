import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/settings/device_tier.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../cameras/data/awas_camera_store.dart';
import '../../cameras/domain/camera_alert_logic.dart';
import '../../cameras/domain/speed_camera.dart';
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
    this.cameraAlert,
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

  /// Kamera kelajuan paling hampir di hadapan (memandu tanpa laluan), jika amaran dihidupkan.
  final CameraAlert? cameraAlert;

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
  int _snapGeneration = 0;
  DateTime? _lastPersist;
  DateTime? _lastSnapAt;
  bool _snapInFlight = false;

  /// Snap jalan ialah permintaan rangkaian (atau padanan peta dalam telefon bila luar talian).
  /// Setiap 1 s dulu ialah antara pengguna bateri terbesar; 3 s (5 s dalam Mod Lite) masih licin
  /// kerana pemacu bingkai meramal kedudukan di antara sampel.
  static Duration get _snapEvery => Duration(seconds: LiteMode.enabled ? 5 : 3);
  static const _snapMaxDriftM = 28.0;

  /// Abaikan snap jalan bila GPS lebih kasar daripada ini (meter).
  static const _snapMinAccuracyM = 25.0;

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
    state = CruiseState(
      active: true,
      speedMps: fix.speedMps,
      point: fix.point,
      bearing: fix.bearing,
      fix: fix,
    );
    // Selepas `state` berubah: peta menggantung penjejak idle dahulu (pendengar segerak), jadi
    // aliran navigasi dibuka dengan tetapannya sendiri (servis latar depan), bukan menumpang
    // aliran idle. Hab lokasi juga menjamin ini, tetapi susunan ini mengelak pertukaran dua kali.
    _listenGps();
    if (!_background) unawaited(ref.read(screenAwakeProvider).enable());
    unawaited(_persist(force: true));
    ref.read(reportAlertsProvider.notifier).reset();
    unawaited(_loadCameras());
  }

  List<SpeedCamera> _cameras = const [];
  String? _announcedCameraId;

  /// Kamera dimuat dari aset dalam app (luar talian), sekali sahaja.
  Future<void> _loadCameras() async {
    if (_cameras.isNotEmpty) return;
    try {
      _cameras = await ref.read(awasCameraStoreProvider).load();
    } on Object catch (e) {
      logDiag('Kamera kelajuan tidak dapat dimuat (memandu bebas): $e');
    }
  }

  /// Amaran kamera tanpa laluan: kamera di hadapan mengikut arah gerakan GPS (bukan arah kamera
  /// peta yang dilicinkan), dalam jarak tetapan amaran. Gaya Waze: tidak perlu set destinasi.
  CameraAlert? _cameraAhead(GeoPoint point, double? heading, double speed) {
    final settings = ref.read(navigationSettingsProvider);
    if (!settings.speedCameraAlerts || _cameras.isEmpty) return null;
    // Arah GPS tidak bermakna ketika hampir pegun; kekalkan amaran sedia ada.
    if (heading == null || speed < 2) return state.cameraAlert;
    return nextCameraAheadFreeDrive(
      position: point,
      headingDegrees: heading,
      cameras: _cameras,
      alertWithinM: settings.speedCameraAlertM.toDouble(),
      maxLateralM: 90,
    );
  }

  void _announceCamera(CameraAlert? alert) {
    if (alert == null || alert.camera.id == _announcedCameraId) return;
    _announcedCameraId = alert.camera.id;
    final en = _language == VoiceLanguage.en;
    final text = alert.camera.source == SpeedCameraSource.jpjAwas
        ? (en
              ? 'AwAS camera ahead — observe the speed limit'
              : 'Kamera AwAS di hadapan — patuhi had laju')
        : (en
              ? 'Camera ahead — observe the speed limit'
              : 'Kamera di hadapan — patuhi had laju');
    _speak([
      Announcement(
        kind: AnnouncementKind.now,
        text: text,
        chime: ChimeKind.warning,
      ),
    ]);
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
    final accuracy = fix.accuracyMeters;
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
    final camera = _cameraAhead(fix.point, heading, speed);
    state = CruiseState(
      active: true,
      speedMps: speed,
      limitKmh: limit,
      overspeed: over,
      point: fix.point,
      bearing: bearing,
      fix: sample,
      cameraAlert: camera,
    );
    _announceCamera(camera);
    _speak(
      _voice.update(
        voiceEnabled: ref.read(navigationSettingsProvider).voiceEnabled,
        overspeed: over,
        limitKmh: limit,
        now: ref.read(navClockProvider)(),
        language: _language,
      ),
    );
    _speak(ref.read(reportAlertsProvider.notifier).onFix(fix, _language));
    _trail.add(fix.point);
    if (_trail.due(time, fix.point)) unawaited(_refreshLimit(fix.point, time));
    final accurateEnough = accuracy == null || accuracy <= _snapMinAccuracyM;
    final lastSnap = _lastSnapAt;
    if (accurateEnough &&
        !_snapInFlight &&
        (lastSnap == null || time.difference(lastSnap) >= _snapEvery)) {
      _lastSnapAt = time;
      unawaited(_refreshSnap(fix.point, bearing, speed, time));
    }
    unawaited(_persist());
  }

  bool _overspeed(double speedMps, int? limit) {
    final tolerance = ref
        .read(navigationSettingsProvider)
        .overspeedToleranceKmh;
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
      cameraAlert: state.cameraAlert,
    );
  }

  /// Snap lembut ke jalan untuk paparan sahaja (GPS mentah kekal jika gagal / terlalu jauh).
  Future<void> _refreshSnap(
    GeoPoint here,
    double bearing,
    double speed,
    DateTime time,
  ) async {
    if (!_trail.canQuery) return;
    final generation = ++_snapGeneration;
    final points = List<GeoPoint>.of(_trail.points);
    GeoPoint? snapped;
    // Satu permintaan pada satu masa: isyarat lemah dulu menimbunkan sehingga ~8 permintaan bertindih.
    _snapInFlight = true;
    try {
      snapped = await ref
          .read(speedLimitServiceProvider)
          .snapTraceEnd(points, ref.read(routeVehicleProvider));
    } on Object {
      snapped = null;
    } finally {
      _snapInFlight = false;
    }
    if (!ref.mounted || generation != _snapGeneration || !state.active) return;
    if (snapped == null) return;
    if (distanceMeters(here, snapped) > _snapMaxDriftM) return;
    final sample = CruiseFix(
      point: snapped,
      bearing: bearing,
      speedMps: speed,
      time: time,
    );
    state = CruiseState(
      active: true,
      speedMps: state.speedMps,
      limitKmh: state.limitKmh,
      overspeed: state.overspeed,
      point: snapped,
      bearing: bearing,
      fix: sample,
      cameraAlert: state.cameraAlert,
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
    _snapGeneration++;
    _lastSnapAt = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _gate.reset();
    _voice.reset();
    _trail.clear();
    _announcedCameraId = null;
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
    await ref
        .read(tripStoreProvider)
        .write(
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

final cruiseControllerProvider =
    NotifierProvider<CruiseController, CruiseState>(CruiseController.new);
