import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/audio/audio_coordinator.dart';
import '../../../core/utils/geo.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/domain/routing_failure.dart';
import '../../reports/presentation/report_alerts_controller.dart';
import '../../speed_limits/data/speed_limit_service.dart';
import '../../speed_limits/domain/speed_limits.dart';
import '../data/location_sources.dart';
import '../data/navigation_settings.dart';
import '../data/screen_awake.dart';
import '../data/trip_record.dart';
import '../data/trip_store.dart';
import '../data/voice_guide.dart';
import '../domain/announcement_planner.dart';
import '../domain/instruction_text.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart';
import '../domain/restored_progress.dart';
import '../domain/route_tracker.dart';
import '../domain/vehicle_model.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/log.dart';

enum NavPhase { idle, active, arrived }

@immutable
class NavigationState {
  const NavigationState({
    this.phase = NavPhase.idle,
    this.route,
    this.query,
    this.progress,
    this.simulated = false,
    this.rerouting = false,
    this.rerouteFailure,
    this.routeVersion = 0,
    this.locationError = false,
    this.speedLimits = SpeedLimits.empty,
    this.overspeed = false,
  });

  final NavPhase phase;
  final NavRoute? route;
  final RouteQuery? query;
  final NavProgress? progress;
  final bool simulated;

  /// Re-route sedang dikira.
  final bool rerouting;

  /// Sebab re-route terakhir gagal (cth. tiada rangkaian); null jika tiada kegagalan.
  final RoutingFailureKind? rerouteFailure;

  /// Bertambah setiap kali laluan diganti (re-route), supaya UI tahu melukis semula.
  final int routeVersion;

  /// Aliran lokasi terputus dengan ralat (cth. kebenaran ditarik balik).
  final bool locationError;

  /// Had laju sepanjang laluan semasa (kosong jika belum dimuat atau tiada data).
  final SpeedLimits speedLimits;

  /// Kelajuan semasa melebihi had laju (+ toleransi pengguna).
  final bool overspeed;

  /// Had laju di kedudukan semasa, atau null jika tidak diketahui.
  int? get currentLimitKmh {
    final along = progress?.alongM;
    return along == null ? null : speedLimits.atDistance(along);
  }

  bool get isActive => phase != NavPhase.idle;

  NavigationState copyWith({
    NavPhase? phase,
    NavRoute? route,
    NavProgress? progress,
    bool? rerouting,
    RoutingFailureKind? rerouteFailure,
    bool clearRerouteFailure = false,
    int? routeVersion,
    bool? locationError,
    SpeedLimits? speedLimits,
    bool? overspeed,
  }) {
    return NavigationState(
      phase: phase ?? this.phase,
      route: route ?? this.route,
      query: query,
      progress: progress ?? this.progress,
      simulated: simulated,
      rerouting: rerouting ?? this.rerouting,
      rerouteFailure: clearRerouteFailure
          ? null
          : (rerouteFailure ?? this.rerouteFailure),
      routeVersion: routeVersion ?? this.routeVersion,
      locationError: locationError ?? this.locationError,
      speedLimits: speedLimits ?? this.speedLimits,
      overspeed: overspeed ?? this.overspeed,
    );
  }
}

/// Jam navigasi; ujian menggantikannya dengan jam palsu.
final navClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final voiceGuideProvider = Provider<VoiceGuide>((ref) {
  final guide = QueuedVoiceGuide(
    tts: FlutterTtsEngine(
      volume: () => ref.read(navigationSettingsProvider).voiceVolume,
      speechRate: () => ref.read(navigationSettingsProvider).speechRate,
    ),
    chimes: AudioplayersChimePlayer(),
    coordinator: ref.read(audioCoordinatorProvider),
  );
  ref.onDispose(guide.dispose);
  return guide;
});

/// Memacu satu perjalanan: menerima fix, menjalankan [NavigationSession], menyebut arahan dan
/// meminta re-route. Logik navigasi sebenar berada dalam sesi (domain); kelas ini hanya I/O.
class NavigationController extends Notifier<NavigationState> {
  NavigationSession? _session;
  StreamSubscription<LocationFix>? _subscription;
  Timer? _ticker;
  int _generation = 0;
  bool _reroutePending = false;

  /// Tiada permintaan re-route baharu sebelum ini (cooldown bertahan merentas sesi: sesi dicipta semula
  /// setiap kali laluan baharu dipasang).
  DateTime? _rerouteBlockedUntil;

  /// Anggaran masa pergi-balik re-route (EMA), untuk mengunjur asal ke hadapan.
  Duration _rerouteRtt = const Duration(milliseconds: 1500);
  bool _refreshingLocation = false;

  /// Fix mentah terkini, untuk disuap ke sesi re-route baharu supaya HUD tidak kosong menunggu fix
  /// seterusnya.
  LocationFix? _lastFix;
  VoiceLanguage _uiLanguage = VoiceLanguage.ms;

  bool _background = false;
  double? _persistedAlong;
  ReplayLocationSource? _simReplay;

  /// Pengganda kelajuan simulasi semasa (null jika bukan simulasi).
  ValueListenable<double>? get simSpeedMultiplier => _simReplay?.speedMultiplier;

  /// Tukar kelajuan masa simulasi semasa main (1 = biasa, 4 = 4× lebih pantas).
  void setSimSpeedMultiplier(double value) {
    final notifier = _simReplay?.speedMultiplier;
    if (notifier == null) return;
    notifier.value = value.clamp(0.25, 8.0);
  }

  @override
  NavigationState build() {
    ref.onDispose(_teardown);
    // Tukar bahasa/mute berkuat kuasa pada sesi yang sedang berjalan.
    ref.listen<NavigationSettings>(navigationSettingsProvider, (prev, next) {
      _session?.language = _voiceLanguage(next);
      if (!next.voiceEnabled && prev?.voiceEnabled == true) {
        unawaited(ref.read(voiceGuideProvider).stop());
      }
    });
    final saved = ref.read(tripStoreProvider).read();
    if (saved is NavigationTrip) return _resumeSaved(saved);
    return const NavigationState();
  }

  /// Pulihkan perjalanan sebelum bingkai peta pertama. Laluan yang disimpan dikekalkan; jika GPS
  /// sudah di luar laluan, [_onFix] menggunakan laluan semula yang sedia ada.
  NavigationState _resumeSaved(NavigationTrip saved) {
    final nav = NavRoute(saved.route);
    if (!nav.isUsable) {
      unawaited(ref.read(tripStoreProvider).clear());
      return const NavigationState();
    }
    _uiLanguage = saved.language;
    final generation = ++_generation;
    final clock = ref.read(navClockProvider);
    final session = NavigationSession(
      route: nav,
      language: _voiceLanguage(),
      clock: clock,
    );
    _session = session;
    session.primeRestored(
      alongM: saved.alongM,
      speedMps: saved.speedMps,
      time: clock(),
    );
    final progress = restoredProgress(
      route: nav,
      alongM: saved.alongM,
      position: saved.position,
      bearing: saved.bearing,
      speedMps: saved.speedMps,
      arrived: saved.arrived,
    );
    final resumed = NavigationState(
      phase: saved.arrived ? NavPhase.arrived : NavPhase.active,
      route: nav,
      query: saved.query,
      progress: progress,
      routeVersion: 1,
    );
    if (saved.arrived) return resumed;

    final src = DeviceLocationSource(ref.read(locationServiceProvider));
    _subscription = src.fixes().listen(
      (fix) {
        if (generation == _generation) _onFix(fix);
      },
      onError: (Object e) {
        if (generation != _generation) return;
        state = state.copyWith(locationError: true);
      },
    );
    _ensureTicker(generation);
    if (!_background) unawaited(ref.read(screenAwakeProvider).enable());
    unawaited(_loadSpeedLimits(saved.route, saved.query, generation, 1));
    return resumed;
  }

  /// App di latar: hentikan pemasa UI, lepaskan wakelock skrin, kekalkan satu langganan GPS.
  void noteBackground(bool background) {
    _background = background;
    if (!state.isActive || state.simulated) return;
    if (background) {
      _ticker?.cancel();
      _ticker = null;
      unawaited(ref.read(screenAwakeProvider).disable());
      unawaited(_persistTrip(force: true));
    } else if (state.phase == NavPhase.active) {
      _ensureTicker(_generation);
      unawaited(ref.read(screenAwakeProvider).enable());
    }
  }

  VoiceLanguage _voiceLanguage([NavigationSettings? override]) {
    final NavigationSettings settings =
        override ?? ref.read(navigationSettingsProvider);
    return settings.voiceLanguage ?? _uiLanguage;
  }

  /// Pose kenderaan untuk bingkai kamera pada [now]; null jika tiada navigasi.
  VehiclePose? poseAt(DateTime now) => _session?.poseAt(now);

  /// Mula navigasi pada [route]. [uiLanguage] ialah bahasa app (digunakan jika pengguna tidak
  /// memilih bahasa suara). [source] lalai kepada GPS peranti.
  Future<bool> start(
    RouteOption route,
    RouteQuery query, {
    required VoiceLanguage uiLanguage,
    NavLocationSource? source,
  }) async {
    releaseActiveCruise?.call();
    await stop();
    // Dua start() serentak (cth. ketik dua kali) kedua-duanya melepasi stop() di atas; tanpa ini
    // langganan dan pemasa sesi pertama bocor kerana rujukannya ditimpa.
    _teardown();
    final nav = NavRoute(route);
    if (!nav.isUsable) return false;

    _uiLanguage = uiLanguage;
    final generation = ++_generation;
    final clock = ref.read(navClockProvider);
    final session = NavigationSession(
      route: nav,
      language: _voiceLanguage(),
      clock: clock,
    );
    _session = session;
    final src =
        source ?? DeviceLocationSource(ref.read(locationServiceProvider));
    _simReplay = src is ReplayLocationSource ? src : null;
    state = NavigationState(
      phase: NavPhase.active,
      route: nav,
      query: query,
      simulated: src.isSimulated,
      routeVersion: 1,
    );

    unawaited(ref.read(screenAwakeProvider).enable());
    ref.read(reportAlertsProvider.notifier).reset();
    _speak(session.takeStartAnnouncements());
    unawaited(_loadSpeedLimits(route, query, generation, 1));

    _subscription = src.fixes().listen(
      (fix) {
        if (generation == _generation) _onFix(fix);
      },
      onError: (Object e) {
        if (generation != _generation) return;
        state = state.copyWith(locationError: true);
      },
    );
    _ensureTicker(generation);
    if (!src.isSimulated) unawaited(_persistTrip(force: true));
    return true;
  }

  /// 4 Hz semasa app di depan: banner dan pengumuman antara fix. Dibatalkan di latar belakang
  /// supaya peta tidak dikira pada kadar bingkai; langganan GPS kekal.
  void _ensureTicker(int generation) {
    if (_background || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final s = _session;
      if (s == null || generation != _generation) return;
      final said = s.tick();
      if (said.isNotEmpty) {
        final p = s.progress;
        if (p != null) state = state.copyWith(progress: p);
        _speak(said);
      }
      if (state.phase != NavPhase.active) return;
      final live = s.refreshLive();
      if (live == null) return;
      state = state.copyWith(progress: live.progress);
      _speak(live.announcements);
      _updateOverspeed(live.progress);
    });
  }

  Future<void> stop() async {
    _generation++;
    _teardown();
    _session = null;
    _lastFix = null;
    _reroutePending = false;
    _persistedAlong = null;
    await ref.read(tripStoreProvider).clear();
    ref.read(reportAlertsProvider.notifier).reset();
    if (state.phase != NavPhase.idle) {
      state = const NavigationState();
      try {
        await ref.read(voiceGuideProvider).stop();
      } on Object catch (e) {
        logDiag('Menghentikan suara gagal: $e');
      } finally {
        // Skrin mesti dilepaskan walaupun enjin suara bermasalah.
        await ref.read(screenAwakeProvider).disable();
      }
    }
  }

  /// Diagnostik (`--dart-define=FG_DIAG=true`): berapa lewat fix GPS tiba berbanding cap masanya.
  static const _diagnostics = bool.fromEnvironment('FG_DIAG');
  final List<int> _diagLatenciesMs = [];

  void _logFixLatency(LocationFix fix) {
    final stamp = fix.timestamp;
    if (stamp == null) return;
    _diagLatenciesMs.add(
      ref.read(navClockProvider)().difference(stamp).inMilliseconds,
    );
    if (_diagLatenciesMs.length >= 10) {
      final avg =
          _diagLatenciesMs.reduce((a, b) => a + b) / _diagLatenciesMs.length;
      final max = _diagLatenciesMs.reduce((a, b) => a > b ? a : b);
      logDiag('FGDIAG GPS: latensi fix purata ${avg.round()} ms, maks $max ms');
      _diagLatenciesMs.clear();
    }
  }

  void _teardown() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _ticker?.cancel();
    _ticker = null;
    // Jangan dispose ValueNotifier di sini: strim replay mungkin masih bangun dari sleep.
    _simReplay = null;
  }

  void _onFix(LocationFix fix) {
    final session = _session;
    if (session == null || state.phase != NavPhase.active) return;
    _lastFix = fix;
    if (_diagnostics) _logFixLatency(fix);
    final update = session.onFix(fix);
    if (update == null) return;

    final progress = update.progress;
    state = state.copyWith(
      progress: progress,
      locationError: false,
      // Kembali ke laluan sendiri: kegagalan re-route lama tidak relevan lagi.
      clearRerouteFailure: progress.status == NavStatus.onRoute,
    );
    _speak(update.announcements);
    _speak(
      ref.read(reportAlertsProvider.notifier).onFix(fix, _voiceLanguage()),
    );
    _updateOverspeed(progress);

    if (progress.status == NavStatus.arrived) {
      state = state.copyWith(phase: NavPhase.arrived);
      Haptics.heavy();
      _teardown();
      unawaited(_persistTrip(force: true));
      // Perjalanan selesai: skrin tidak perlu dijaga hidup lagi.
      unawaited(ref.read(screenAwakeProvider).disable());
      return;
    }
    unawaited(_persistTrip());

    final request = update.reroute;
    if (request != null) unawaited(_reroute(request));
  }

  /// Resume the current route from a fresh fix when the app returns to foreground.
  /// The live location stream remains authoritative; duplicate fixes are filtered by the session.
  Future<void> refreshCurrentLocation() async {
    if (_refreshingLocation ||
        state.phase != NavPhase.active ||
        state.simulated) {
      return;
    }
    _refreshingLocation = true;
    final generation = _generation;
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .currentFix(
            timeout: const Duration(seconds: 5),
            maxAccuracyMeters: 35,
          );
      if (fix != null && generation == _generation && ref.mounted) {
        _onFix(fix);
      }
    } finally {
      _refreshingLocation = false;
    }
  }

  /// Fix lebih lama daripada ini tidak disuap ke sesi re-route baharu (kenderaan sudah jauh).
  static const _maxFeedAge = Duration(seconds: 5);

  /// Selang selepas re-route berjaya / gagal sebelum permintaan baharu dibenarkan.
  static const _cooldownAfterSuccess = Duration(seconds: 8);
  static const _cooldownAfterFailure = Duration(seconds: 3);

  /// Jarak maksimum asal re-route diunjur ke hadapan (meter).
  static const _maxOriginLeadM = 80.0;

  Future<void> _reroute(RerouteRequest request) async {
    final query = state.query;
    final session = _session;
    if (query == null || session == null || _reroutePending) return;
    final clock = ref.read(navClockProvider);
    final blocked = _rerouteBlockedUntil;
    if (blocked != null && clock().isBefore(blocked)) return;
    _reroutePending = true;
    final generation = _generation;
    final startedAt = clock();
    // "Mengira semula" disebut sekali bagi satu episod menyimpang (bukan setiap percubaan).
    final firstAttempt = !session.awaitingReroute;
    session.noteRerouteRequested();
    if (firstAttempt) _speak([session.reroutingNotice]);
    state = state.copyWith(rerouting: true);

    // Kenderaan terus bergerak sepanjang pengiraan: asal diunjur ke hadapan sepanjang heading supaya
    // laluan baharu tidak bermula di belakang kereta.
    var origin = request.origin;
    final heading = request.headingDegrees;
    if (heading != null && request.speedMps > 3) {
      final lead = math.min(
        _maxOriginLeadM,
        request.speedMps * _rerouteRtt.inMilliseconds / 1000,
      );
      origin = destinationPoint(origin, heading.toDouble(), lead);
    }

    try {
      final options = await ref
          .read(routePlannerProvider)
          .plan(query.rerouteFrom(origin, headingDegrees: heading));
      if (generation != _generation) return;
      final took = clock().difference(startedAt);
      _rerouteRtt = Duration(
        milliseconds: ((_rerouteRtt.inMilliseconds + took.inMilliseconds) / 2)
            .round()
            .clamp(300, 6000),
      );
      // Pemandu sudah kembali ke laluan lama semasa menunggu: jawapan ini tidak diperlukan lagi.
      if (identical(_session, session) &&
          state.progress?.status == NavStatus.onRoute) {
        state = state.copyWith(rerouting: false);
        return;
      }
      if (options.isEmpty) {
        throw const RoutingFailure(RoutingFailureKind.generic);
      }
      _rerouteBlockedUntil = clock().add(_cooldownAfterSuccess);
      _adopt(options.first, query, generation);
    } on RoutingFailure catch (failure) {
      if (generation != _generation) return;
      // Kekal di sesi semasa; pengesan menyimpang akan mencuba lagi selepas cooldown pendek.
      _rerouteBlockedUntil = clock().add(_cooldownAfterFailure);
      state = state.copyWith(rerouting: false, rerouteFailure: failure.kind);
    } on Object catch (e) {
      // Apa-apa ralat lain (respons rosak, dsb.) tidak boleh meninggalkan "mengira semula" tersangkut.
      logDiag('Re-route gagal: $e');
      if (generation != _generation) return;
      _rerouteBlockedUntil = clock().add(_cooldownAfterFailure);
      state = state.copyWith(
        rerouting: false,
        rerouteFailure: RoutingFailureKind.generic,
      );
    } finally {
      _reroutePending = false;
    }
  }

  /// Menggantikan laluan semasa dengan [option] (re-route atau pilihan pengguna): sesi baharu dan had laju
  /// dimuat semula untuk laluan baharu.
  void _adopt(RouteOption option, RouteQuery query, int generation) {
    final route = NavRoute(option);
    if (!route.isUsable) {
      throw const RoutingFailure(RoutingFailureKind.generic);
    }
    final clock = ref.read(navClockProvider);
    final now = clock();
    final previous = state.progress;
    final fresh = NavigationSession(
      route: route,
      language: _voiceLanguage(),
      clock: clock,
      isReroute: true,
    );
    // Benihkan model daripada GPS terkini (bukan paparan laluan lama) supaya seed
    // dekat pemandu sebenar; jatuh balik ke progress jika fix lapuk.
    final seedPoint = () {
      final fix = _lastFix;
      final clockFn = clock;
      if (fix != null &&
          clockFn().difference(fix.timestamp ?? clockFn()) <= _maxFeedAge) {
        return fix.point;
      }
      return previous?.position;
    }();
    final seedAlong = seedPoint == null
        ? 0.0
        : RouteTracker(route).match(seedPoint).alongM.clamp(0.0, route.totalM);
    // Pengumuman laluan baharu sebelum primeRestored (yang menutup bendera start).
    final startAnnouncements = fresh.takeStartAnnouncements();
    fresh.primeRestored(
      alongM: seedAlong,
      speedMps: previous?.speedMps ?? 0,
      time: now,
    );
    _session = fresh;
    state = NavigationState(
      phase: NavPhase.active,
      route: route,
      query: query,
      simulated: state.simulated,
      routeVersion: state.routeVersion + 1,
      progress: previous == null
          ? null
          : restoredProgress(
              route: route,
              alongM: seedAlong,
              position: route.displayPointAt(seedAlong),
              bearing: route.displayBearingAt(seedAlong),
              speedMps: previous.speedMps,
            ),
    );
    _speak(startAnnouncements);
    unawaited(_persistTrip(force: true));
    unawaited(_loadSpeedLimits(option, query, generation, state.routeVersion));

    // Fix terkini (kedudukan sudah beralih sepanjang pengiraan) disuap terus.
    final fix = _lastFix;
    if (fix != null &&
        clock().difference(fix.timestamp ?? clock()) <= _maxFeedAge) {
      _onFix(fix);
    }
  }

  /// Pilihan laluan dari kedudukan semasa ke destinasi yang sama (untuk pengguna menukar laluan semasa
  /// dalam perjalanan). Tidak mengubah navigasi. Mencampakkan [RoutingFailure] jika gagal.
  Future<List<RouteOption>> planAlternatives() async {
    final query = state.query;
    final fix = _lastFix;
    if (state.phase != NavPhase.active || query == null) {
      throw const RoutingFailure(RoutingFailureKind.generic);
    }
    if (fix == null) throw const RoutingFailure(RoutingFailureKind.generic);
    final generation = _generation;
    final options = await ref
        .read(routeOptionsPlannerProvider)
        .plan(
          query.alternativesFrom(fix.point, headingDegrees: fix.headingDegrees),
        );
    if (generation != _generation) {
      throw const RoutingFailure(RoutingFailureKind.generic);
    }
    return options;
  }

  /// Tukar kepada [option] (daripada [planAlternatives]) tanpa menamatkan perjalanan. Label menentukan
  /// pilihan elak yang dikekalkan untuk re-route seterusnya. Mengembalikan false jika tidak dapat ditukar.
  bool switchRoute(RouteOption option) {
    final query = state.query;
    if (state.phase != NavPhase.active || query == null || _reroutePending) {
      return false;
    }
    final next = query.copyWith(
      avoidTolls: option.label == RouteLabel.noTolls,
      avoidHighways: option.label == RouteLabel.noHighways,
    );
    try {
      _adopt(option, next, _generation);
      return true;
    } on RoutingFailure {
      return false;
    }
  }

  /// Had laju ialah maklumat sokongan: kegagalan atau data kosong tidak menjejas navigasi.
  Future<void> _loadSpeedLimits(
    RouteOption route,
    RouteQuery query,
    int generation,
    int routeVersion,
  ) async {
    try {
      final limits = await ref
          .read(speedLimitServiceProvider)
          .forRoute(route, query.vehicle);
      if (generation != _generation || state.routeVersion != routeVersion) {
        return;
      }
      state = state.copyWith(speedLimits: limits);
    } on Object catch (e) {
      logDiag('Had laju tidak dapat dimuat: $e');
    }
  }

  DateTime? _lastOverspeedChime;

  /// Menilai kelajuan terhadap had; bunyi amaran sekali apabila mula melebihi (dengan cooldown) supaya
  /// tidak membebel ketika kelajuan berayun di sekitar had.
  void _updateOverspeed(NavProgress progress) {
    final tolerance = ref
        .read(navigationSettingsProvider)
        .overspeedToleranceKmh;
    final limit = state.speedLimits.atDistance(progress.alongM);
    final over =
        tolerance >= 0 &&
        overspeedLevel(
              speedKmh: progress.speedMps * 3.6,
              limitKmh: limit,
              toleranceKmh: tolerance,
            ) ==
            OverspeedLevel.warning;
    if (over == state.overspeed) return;
    state = state.copyWith(overspeed: over);
    if (!over) return;
    final now = ref.read(navClockProvider)();
    final last = _lastOverspeedChime;
    if (last != null && now.difference(last) < const Duration(seconds: 20)) {
      return;
    }
    _lastOverspeedChime = now;
    _speak(const [
      Announcement(
        kind: AnnouncementKind.speeding,
        text: '',
        chime: ChimeKind.warning,
      ),
    ]);
  }

  Future<void> _persistTrip({bool force = false}) async {
    if (state.simulated || !state.isActive) return;
    final route = state.route;
    final query = state.query;
    final progress = state.progress;
    if (route == null || query == null) return;
    final along = progress?.alongM ?? 0;
    if (!force &&
        _persistedAlong != null &&
        (along - _persistedAlong!).abs() < 25) {
      return;
    }
    _persistedAlong = along;
    await ref.read(tripStoreProvider).write(
      NavigationTrip(
        savedAt: ref.read(navClockProvider)().toUtc(),
        route: route.option,
        query: query,
        alongM: along,
        language: _voiceLanguage(),
        position: progress?.position ?? route.points.first,
        bearing: progress?.bearing ?? 0,
        speedMps: progress?.speedMps ?? 0,
        arrived: state.phase == NavPhase.arrived,
      ),
    );
  }

  void _speak(List<Announcement> announcements) {
    if (announcements.isEmpty) return;
    if (announcements.any((a) => a.kind == AnnouncementKind.now)) {
      Haptics.medium();
    }
    if (!ref.read(navigationSettingsProvider).voiceEnabled) return;
    final voice = ref.read(voiceGuideProvider);
    final language = _voiceLanguage();
    for (final a in announcements) {
      unawaited(voice.announce(a, language));
    }
  }
}

final navigationControllerProvider =
    NotifierProvider<NavigationController, NavigationState>(
      NavigationController.new,
    );
