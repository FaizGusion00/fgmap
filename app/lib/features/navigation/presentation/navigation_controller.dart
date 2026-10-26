import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/domain/routing_failure.dart';
import '../../speed_limits/data/speed_limit_service.dart';
import '../../speed_limits/domain/speed_limits.dart';
import '../data/location_sources.dart';
import '../data/navigation_settings.dart';
import '../data/screen_awake.dart';
import '../data/voice_guide.dart';
import '../domain/announcement_planner.dart';
import '../domain/instruction_text.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart';
import '../domain/vehicle_model.dart';

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
    tts: FlutterTtsEngine(),
    chimes: AudioplayersChimePlayer(),
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
  bool _refreshingLocation = false;

  /// Fix mentah terkini, untuk disuap ke sesi re-route baharu supaya HUD tidak kosong menunggu fix
  /// seterusnya.
  LocationFix? _lastFix;
  VoiceLanguage _uiLanguage = VoiceLanguage.ms;

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
    return const NavigationState();
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
    state = NavigationState(
      phase: NavPhase.active,
      route: nav,
      query: query,
      simulated: src.isSimulated,
      routeVersion: 1,
    );

    unawaited(ref.read(screenAwakeProvider).enable());
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
    // 4 Hz: banner, jarak dan pengumuman mengikut kedudukan kenderaan yang diunjur, bukan hanya fix 1 Hz.
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final s = _session;
      if (s == null || generation != _generation) return;
      final said = s.tick();
      if (said.isNotEmpty) {
        // Isyarat hilang: kemas kini penanda GPS lemah walaupun tiada fix baharu.
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
    return true;
  }

  Future<void> stop() async {
    _generation++;
    _teardown();
    _session = null;
    _lastFix = null;
    _reroutePending = false;
    if (state.phase != NavPhase.idle) {
      state = const NavigationState();
      try {
        await ref.read(voiceGuideProvider).stop();
      } on Object catch (e) {
        debugPrint('Menghentikan suara gagal: $e');
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
      debugPrint(
        'FGDIAG GPS: latensi fix purata ${avg.round()} ms, maks $max ms',
      );
      _diagLatenciesMs.clear();
    }
  }

  void _teardown() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _ticker?.cancel();
    _ticker = null;
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
    _updateOverspeed(progress);

    if (progress.status == NavStatus.arrived) {
      state = state.copyWith(phase: NavPhase.arrived);
      HapticFeedback.heavyImpact();
      _teardown();
      // Perjalanan selesai: skrin tidak perlu dijaga hidup lagi.
      unawaited(ref.read(screenAwakeProvider).disable());
      return;
    }

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

  Future<void> _reroute(RerouteRequest request) async {
    final query = state.query;
    final session = _session;
    if (query == null || session == null || _reroutePending) return;
    _reroutePending = true;
    final generation = _generation;
    state = state.copyWith(rerouting: true);

    try {
      final options = await ref
          .read(routePlannerProvider)
          .plan(
            query.rerouteFrom(
              request.origin,
              headingDegrees: request.headingDegrees,
            ),
          );
      if (generation != _generation) return;
      if (options.isEmpty) {
        throw const RoutingFailure(RoutingFailureKind.generic);
      }
      final route = NavRoute(options.first);
      if (!route.isUsable) {
        throw const RoutingFailure(RoutingFailureKind.generic);
      }

      final fresh = NavigationSession(
        route: route,
        language: _voiceLanguage(),
        clock: ref.read(navClockProvider),
        isReroute: true,
      );
      _session = fresh;
      state = NavigationState(
        phase: NavPhase.active,
        route: route,
        query: query,
        simulated: state.simulated,
        routeVersion: state.routeVersion + 1,
      );
      _speak(fresh.takeStartAnnouncements());
      unawaited(
        _loadSpeedLimits(options.first, query, generation, state.routeVersion),
      );

      // Sesi baharu belum melihat fix: tanpa ini progress kosong sehingga fix seterusnya (~1 s),
      // banner hilang dan chip "mencari GPS" berkelip. Fix terkini (bukan yang mencetuskan
      // re-route; kedudukan sudah beralih sepanjang pengiraan) disuap terus.
      final fix = _lastFix;
      final clock = ref.read(navClockProvider);
      if (fix != null &&
          clock().difference(fix.timestamp ?? clock()) <= _maxFeedAge) {
        _onFix(fix);
      }
    } on RoutingFailure catch (failure) {
      if (generation != _generation) return;
      // Kekal di sesi semasa; pengesan menyimpang akan mencuba lagi selepas cooldown.
      state = state.copyWith(rerouting: false, rerouteFailure: failure.kind);
    } on Object catch (e) {
      // Apa-apa ralat lain (respons rosak, dsb.) tidak boleh meninggalkan "mengira semula" tersangkut.
      debugPrint('Re-route gagal: $e');
      if (generation != _generation) return;
      state = state.copyWith(
        rerouting: false,
        rerouteFailure: RoutingFailureKind.generic,
      );
    } finally {
      _reroutePending = false;
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
      debugPrint('Had laju tidak dapat dimuat: $e');
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

  void _speak(List<Announcement> announcements) {
    if (announcements.isEmpty) return;
    if (announcements.any((a) => a.kind == AnnouncementKind.now)) {
      HapticFeedback.mediumImpact();
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
