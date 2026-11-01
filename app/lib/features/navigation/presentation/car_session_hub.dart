import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/geo.dart';
import '../../air_quality/domain/air_quality.dart';
import '../../air_quality/presentation/air_quality_controller.dart';
import '../../azan/data/azan_settings.dart';
import '../../azan/presentation/azan_controller.dart';
import '../../azan/presentation/azan_l10n.dart' show prayerName;
import '../../along_route/domain/along_route_category.dart';
import '../../cameras/domain/speed_camera.dart';
import '../../map/data/map_style_loader.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../../search/domain/place.dart';
import '../data/navigation_settings.dart';
import '../domain/camera_planner.dart';
import '../domain/car_session.dart';
import '../domain/cruise_motion.dart';
import '../domain/instruction_text.dart';
import '../domain/lane_guidance.dart' show laneHintWithinM;
import '../domain/lane_plan.dart';
import '../domain/nav_route.dart';
import '../domain/navigation_session.dart' show NavStatus;
import '../domain/vehicle_model.dart' show VehiclePose;
import 'car_places.dart';
import 'cruise_controller.dart';
import 'navigation_controller.dart';

/// Saluran tunggal antara Flutter dan hos Android Auto.
const carSessionChannel = MethodChannel('com.fguniversalempire.fgmaps/car');

/// Menerbitkan satu gambar sesi dan menerima carian, pusatkan, dan tamat dari skrin kereta.
class CarSessionHub {
  CarSessionHub(this.ref) {
    carSessionChannel.setMethodCallHandler(_onCall);
    unawaited(_pullCarState());
  }

  final Ref ref;

  /// Carian dan "Berdekatan" untuk skrin kereta (penghala arahan FG AI + carian kategori).
  late final CarPlaces _places = CarPlaces(ref, live: _near);

  /// Kamera skrin kereta sendiri (lihat [CarCamera]); pose kamera telefon hanya isyarat kadar.
  final CarCamera _camera = CarCamera();

  /// Pelicin kedudukan free-ride untuk penanda dan kamera kereta (fix GPS ~1 Hz).
  final CruiseMotion _cruiseMotion = CruiseMotion();
  CameraPose? _phonePose;

  /// Lokasi pengguna dalam browse (daripada penjejak peta), supaya peta kereta tidak di 0,0.
  GeoPoint? _browsePoint;

  /// Permukaan peta Android Auto sedang dipaparkan, dan mod malam kereta (lampu/penderia kereta).
  bool _carVisible = false;
  bool? _carDark;
  Timer? _pump;

  NavRoute? _routeOf;
  List<GeoPoint> _routePoints = const [];
  int _sentRouteVersion = -1;
  String? _sentStyleKey;
  bool _pushing = false;
  Timer? _throttle;

  /// Pose kamera telefon setiap bingkai (pemacu navigasi/cruise). Hanya menentukan kadar push:
  /// skrin kereta mengira kameranya sendiri.
  void notePose(CameraPose pose) {
    final nav = ref.read(navigationControllerProvider);
    final previous = _phonePose;
    _phonePose = pose;
    // notePose ~60 Hz: 0.5°/bingkai ≈ 30°/s — cukup untuk selekoh bandar.
    // Ambang 2.5° hampir tidak pernah tercapai dan AA kekal pada 200 ms.
    final turning =
        previous != null &&
        angleDelta(previous.bearing, pose.bearing).abs() > 0.5;
    final nearTurn = (nav.progress?.distanceToNextM ?? double.infinity) < 80;
    final urgent = nav.rerouting || turning || nearTurn;
    _schedule(urgent ? const Duration(milliseconds: 60) : _defaultThrottle);
  }

  /// Lokasi pengguna di luar perjalanan (penjejak peta). Push hanya bila beranjak >= 25 m.
  void noteLocation(GeoPoint point) {
    final shown = _browsePoint;
    if (shown != null && distanceMeters(shown, point) < 25) return;
    _browsePoint = point;
    publish();
  }

  void publish() => _schedule(_defaultThrottle);

  /// Push serta-merta (resume / adopt / permukaan AA sedia). Membatalkan throttle tertunda.
  void flush() {
    _throttle?.cancel();
    _throttle = null;
    _pendingDelay = null;
    unawaited(_push());
  }

  static const _defaultThrottle = Duration(milliseconds: 200);

  /// Kadar kamera kereta semasa memandu bila permukaan AA kelihatan. Bebas daripada ticker telefon,
  /// yang berhenti sebaik telefon dikunci atau app ke latar (kes biasa ketika Android Auto).
  static const _pumpEvery = Duration(milliseconds: 100);

  /// Hidupkan/matikan pam kamera kereta mengikut keadaan semasa.
  void syncPump() {
    final want =
        _carVisible &&
        (ref.read(navigationControllerProvider).isActive ||
            ref.read(cruiseControllerProvider).active);
    if (want == (_pump != null)) return;
    _pump?.cancel();
    _pump = want
        ? Timer.periodic(_pumpEvery, (_) => _schedule(Duration.zero))
        : null;
  }

  Duration? _pendingDelay;
  bool _dirty = false;

  void _schedule([Duration delay = _defaultThrottle]) {
    // Jika sudah dijadualkan lebih lambat, ketatkan ke delay mendesak (selekoh / re-route).
    if (_throttle != null) {
      final pending = _pendingDelay;
      if (pending != null && delay < pending) {
        _throttle!.cancel();
        _throttle = null;
        _pendingDelay = null;
      } else {
        return;
      }
    }
    _pendingDelay = delay;
    _throttle = Timer(delay, () {
      _throttle = null;
      _pendingDelay = null;
      unawaited(_push());
    });
  }

  Future<void> _push() async {
    if (_pushing) {
      // flush/publish semasa push berjalan: cuba lagi selepas selesai.
      _dirty = true;
      return;
    }
    _pushing = true;
    _dirty = false;
    try {
      final snapshot = _snapshot();
      final includeRoute =
          snapshot.routeVersion != _sentRouteVersion ||
          snapshot.mode != CarDriveMode.navigating;
      final includeStyle = snapshot.styleKey != _sentStyleKey;
      await carSessionChannel.invokeMethod<void>(
        'session',
        snapshot.toMap(includeRoute: includeRoute, includeStyle: includeStyle),
      );
      _sentRouteVersion = snapshot.routeVersion;
      _sentStyleKey = snapshot.styleKey;
    } on MissingPluginException {
      // Bukan Android, atau hos kereta belum didaftarkan.
    } on PlatformException {
      // Hos belum sedia. Gambar seterusnya akan mencuba lagi.
    } finally {
      _pushing = false;
      if (_dirty) {
        _dirty = false;
        unawaited(_push());
      }
    }
  }

  CarSessionSnapshot _snapshot() {
    final nav = ref.read(navigationControllerProvider);
    final cruise = ref.read(cruiseControllerProvider);
    final progress = nav.progress;
    final dark = _dark();
    final loaded = ref.read(mapStyleProvider(dark));
    final style = loaded is AsyncData<ResolvedMapStyle> ? loaded.value : null;
    if (style == null) _publishWhenStyleReady(dark);
    final navigating = nav.isActive;
    final arrived = nav.phase == NavPhase.arrived;
    final maneuver = arrived ? null : progress?.next;
    final language = VoiceLanguage.fromCode(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    final text = maneuver == null
        ? null
        : InstructionText(language).action(maneuver);
    final now = ref.read(navClockProvider)();
    final settings = ref.read(navigationSettingsProvider);
    final moving = _vehicleAt(nav, cruise, now);
    final CameraPose? pose;
    final CarVehicle? vehicle;
    if (moving != null) {
      pose = _camera.step(
        now: now,
        vehicle: moving,
        navigating: navigating,
        next: progress?.next,
        following: progress?.following,
        mode: settings.cameraMode,
      );
      vehicle = CarVehicle(moving.point, moving.bearing);
    } else {
      _camera.reset();
      final browse = navigating || cruise.active ? null : _browsePoint;
      pose = browse == null ? null : carBrowsePose(browse);
      vehicle = browse == null ? null : CarVehicle(browse);
    }
    final en = language == VoiceLanguage.en;
    // Lorong: gambar lorong asli kereta hanya daripada data sebenar dan dalam jarak yang sama dengan
    // kotak lorong di telefon; ayat sisi ("Guna lorong paling kanan") dalam 700 m.
    final toManeuverM = progress?.distanceToNextM;
    final motorcycle = nav.query?.vehicle == RouteVehicle.motorcycle;
    final laneNear =
        maneuver != null &&
        toManeuverM != null &&
        toManeuverM <=
            laneViewWithinM(
              speedMps: progress?.speedMps ?? 0,
              motorcycle: motorcycle,
            );
    final laneHintNear =
        maneuver != null &&
        toManeuverM != null &&
        toManeuverM <= laneHintWithinM;
    return mapCarSession(
      navigating: navigating,
      cruising: cruise.active,
      pose: pose,
      vehicle: vehicle,
      speedMps: navigating ? (progress?.speedMps ?? 0) : cruise.speedMps,
      limitKmh: navigating ? nav.currentLimitKmh : cruise.limitKmh,
      overspeed: navigating ? nav.overspeed : cruise.overspeed,
      navigationRoute: _routeFor(nav.route),
      routeVersion: nav.routeVersion,
      maneuver: text,
      maneuverKind: maneuver?.kind.name,
      roundaboutExit: maneuver?.roundaboutExit,
      distanceToManeuverM: progress?.distanceToNextM,
      remainingM: progress?.remainingM,
      remainingS: progress?.remainingS.round(),
      etaEpochMs: progress == null
          ? null
          : now
                .add(Duration(seconds: progress.remainingS.round()))
                .millisecondsSinceEpoch,
      // Kamera kereta sentiasa mengikut kenderaan; pan di skrin kereta diurus oleh hos sendiri,
      // dan menggerakkan peta telefon tidak lagi membekukan skrin kereta.
      dark: dark,
      style:
          style?.style ??
          (dark ? AppConfig.mapStyleDark : AppConfig.mapStyleLight),
      styleKey: style?.key ?? (dark ? 'dark' : 'light'),
      cameraAlert: _cameraLine(nav, en),
      weatherAlert: _weatherLine(nav, settings, en),
      alongCue: _alongLine(nav, progress?.alongM ?? 0, en),
      airAqi: _airLine(en),
      prayerLine: _prayerLine(),
      lanes: laneNear ? carLanesFor(lanePlanFor(maneuver)) : const [],
      laneHint: laneHintNear
          ? InstructionText(language).laneHint(maneuver)
          : null,
      rerouting: nav.rerouting,
      arrived: arrived,
      destination: nav.query?.destinationLabel,
    );
  }

  /// Kenderaan pada [now]: pose model kenderaan navigasi (null sehingga fix GPS pertama; dahulu
  /// (0,0)), jika tiada, kedudukan kemajuan yang dipulihkan; free-ride daripada [CruiseMotion].
  VehiclePose? _vehicleAt(
    NavigationState nav,
    CruiseState cruise,
    DateTime now,
  ) {
    if (nav.isActive) {
      _cruiseMotion.reset();
      final pose = ref.read(navigationControllerProvider.notifier).poseAt(now);
      if (pose != null) return pose;
      final progress = nav.progress;
      if (progress == null) return null;
      return VehiclePose(
        point: progress.position,
        bearing: progress.bearing,
        speedMps: progress.speedMps,
        onRoute: progress.status == NavStatus.onRoute,
        alongM: progress.alongM,
      );
    }
    final fix = cruise.fix;
    if (!cruise.active || fix == null) {
      _cruiseMotion.reset();
      return null;
    }
    _cruiseMotion.onFix(
      point: fix.point,
      bearing: fix.bearing,
      speedMps: fix.speedMps,
      time: fix.time,
    );
    final shown = _cruiseMotion.at(now);
    if (shown == null) return null;
    return VehiclePose(
      point: shown.point,
      bearing: shown.bearing,
      speedMps: shown.speedMps,
      onRoute: false,
      alongM: 0,
    );
  }

  /// Garisan laluan untuk kereta, dikira sekali bagi setiap laluan (bukan setiap push 10 Hz).
  /// Langkah kasar di lurus, halus di selekoh — muatan AA jauh lebih kecil daripada telefon.
  List<GeoPoint> _routeFor(NavRoute? route) {
    if (route == null) return const [];
    if (!identical(route, _routeOf)) {
      _routeOf = route;
      _routePoints = route
          .displayPolyline(stepM: 25, cornerStepM: 8, cornerPadM: 50)
          .points;
    }
    return _routePoints;
  }

  final Set<bool> _awaitingStyle = {};

  /// Gaya peta belum dimuat (cth. mod malam kereta baru bertukar): push semula sebaik siap, supaya
  /// skrin kereta tidak kekal pada gaya sandaran walaupun tiada perubahan lain.
  void _publishWhenStyleReady(bool dark) {
    if (!_awaitingStyle.add(dark)) return;
    ref
        .read(mapStyleProvider(dark).future)
        .then<void>((_) => publish(), onError: (Object _) {})
        .whenComplete(() => _awaitingStyle.remove(dark));
  }

  /// Waktu solat seterusnya untuk skrin kereta ("Asar 16:28"), hanya jika Waktu Azan dihidupkan.
  /// Tanpa baki masa: baris ini tidak berubah setiap minit, jadi skrin kereta tidak dikemas kini
  /// tanpa perlu dan pemandu tidak terganggu.
  String? _prayerLine() {
    if (!ref.read(azanSettingsProvider).enabled) return null;
    final azan = ref.read(azanControllerProvider);
    final next = azan.upNext;
    final at = azan.upNextAt;
    if (next == null || at == null) return null;
    final l10n = CarPlaces.l10nFor(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    final hh = at.hour.toString().padLeft(2, '0');
    final mm = at.minute.toString().padLeft(2, '0');
    return '${prayerName(l10n, next)} $hh:$mm';
  }

  String? _cameraLine(NavigationState nav, bool en) {
    final alert = nav.cameraAlert;
    if (alert == null) return null;
    final dist = carFormatDistance(alert.distanceAheadM);
    final awas = alert.camera.source == SpeedCameraSource.jpjAwas;
    if (en) {
      return awas ? 'AwAS camera · $dist' : 'Camera · $dist';
    }
    return awas ? 'Kamera AwAS · $dist' : 'Kamera · $dist';
  }

  String? _weatherLine(
    NavigationState nav,
    NavigationSettings settings,
    bool en,
  ) {
    final haze = nav.hazeAlert;
    if (haze != null) {
      return en ? 'Elevated IPU · ${haze.ipu}' : 'IPU tinggi · ${haze.ipu}';
    }
    if (!nav.weatherSevere || !settings.weatherAlerts) return null;
    return en ? 'Severe weather' : 'Cuaca buruk';
  }

  String? _alongLine(NavigationState nav, double alongNow, bool en) {
    final poi = nav.upcomingAlongPoi;
    if (poi == null) return null;
    final ahead = poi.remainingFrom(alongNow);
    // Skrin kereta: hanya isyarat dekat (≤5 km), sama seperti TTS.
    if (ahead > 5200) return null;
    final dist = carFormatDistance(ahead);
    final isRr = poi.category == AlongRouteCategory.restArea;
    if (en) return isRr ? 'R&R · $dist' : 'Fuel · $dist';
    return isRr ? 'R&R · $dist' : 'Minyak · $dist';
  }

  String? _airLine(bool en) {
    final air = ref.read(airQualityControllerProvider);
    if (air is! AirUiReady) return null;
    final ipu = air.reading.ipu;
    final band = switch (air.reading.band) {
      AirBand.good => en ? 'Good' : 'Baik',
      AirBand.moderate => en ? 'Moderate' : 'Sederhana',
      AirBand.unhealthy => en ? 'Unhealthy' : 'Tidak sihat',
      AirBand.veryUnhealthy => en ? 'Very unhealthy' : 'Sangat tidak sihat',
      AirBand.hazardous => en ? 'Hazardous' : 'Berbahaya',
    };
    return 'IPU $ipu · $band';
  }

  /// Mod malam: ikut kereta bila skrin Android Auto kelihatan (lampu/penderia kereta, sama seperti
  /// templat hos), supaya peta kereta tidak terang menyilaukan pada waktu malam walaupun telefon
  /// dalam tema cerah. Tanpa kereta, tema telefon.
  bool _dark() {
    final car = _carDark;
    if (_carVisible && car != null) return car;
    final mode = ref.read(effectiveThemeModeProvider);
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'search':
        final query = (call.arguments as Map?)?['query']?.toString() ?? '';
        return _places.search(query);
      case 'nearbyCategories':
        return _places.categories();
      case 'nearby':
        final id = (call.arguments as Map?)?['category']?.toString() ?? '';
        return _places.nearby(id);
      case 'openPlace':
        final args = (call.arguments as Map).cast<String, Object?>();
        final lat = (args['lat'] as num?)?.toDouble();
        final lng = (args['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return 'no-point';
        return _openPlace(
          Place(
            name: args['name']?.toString() ?? '',
            subtitle: args['subtitle']?.toString() ?? '',
            point: GeoPoint(lat, lng),
          ),
        );
      case 'endNavigation':
        await ref.read(navigationControllerProvider.notifier).stop();
        return null;
      case 'recenter':
        _recenter?.call();
        return null;
      case 'pan':
        _pan?.call();
        return null;
      case 'carState':
        // Android Auto sahaja: permukaan peta kelihatan/hilang, atau mod malam kereta bertukar.
        _applyCarState(call.arguments);
        return null;
      default:
        throw MissingPluginException(call.method);
    }
  }

  void _applyCarState(Object? raw) {
    if (raw is! Map) return;
    final visible = raw['visible'] == true;
    final dark = raw['dark'] is bool ? raw['dark'] as bool : null;
    if (visible == _carVisible && (dark == null || dark == _carDark)) return;
    _carVisible = visible;
    if (dark != null) _carDark = dark;
    syncPump();
    flush();
  }

  /// Keadaan kereta semasa (enjin Flutter mungkin bermula selepas Android Auto bersambung).
  Future<void> _pullCarState() async {
    try {
      _applyCarState(await carSessionChannel.invokeMethod<Object?>('carState'));
    } on MissingPluginException {
      // Bukan Android, atau hos kereta belum didaftarkan.
    } on PlatformException {
      // Hos belum sedia; Android Auto akan menghantar 'carState' sendiri.
    }
  }

  VoidCallback? _recenter;
  VoidCallback? _pan;

  void bindCamera({required VoidCallback recenter, required VoidCallback pan}) {
    _recenter = recenter;
    _pan = pan;
  }

  GeoPoint? _near() {
    final nav = ref.read(navigationControllerProvider);
    final progress = nav.progress;
    if (progress != null) return progress.position;
    return ref.read(cruiseControllerProvider).point;
  }

  /// Arah pergerakan semasa (darjah) untuk asal laluan, seperti perancang telefon (`fix.headingDegrees`):
  /// tanpanya laluan yang dimulakan dari kereta yang sedang bergerak boleh bermula ke belakang.
  int? _heading() {
    final progress = ref.read(navigationControllerProvider).progress;
    if (progress != null) {
      return progress.speedMps > 2 ? progress.bearing.round() % 360 : null;
    }
    final cruise = ref.read(cruiseControllerProvider);
    return cruise.active && cruise.speedMps > 2
        ? cruise.bearing.round() % 360
        : null;
  }

  /// Merancang dan memulakan sesi navigasi yang sama dengan telefon.
  Future<String?> _openPlace(Place place) async {
    // Kereta berhenti = tiada cruise: guna GPS peranti, bukan hanya kedudukan navigasi.
    final origin = await _places.origin();
    if (origin == null) return 'no-location';
    final query = RouteQuery(
      origin: origin,
      destination: place.point,
      headingDegrees: _heading(),
      vehicle: ref.read(routeVehicleProvider),
      destinationLabel: place.name,
      alternates: 0,
      destinationRadiusM: place.routingRadiusM,
    );
    try {
      final options = await ref.read(routePlannerProvider).plan(query);
      if (options.isEmpty) return 'no-route';
      final language = VoiceLanguage.fromCode(
        WidgetsBinding.instance.platformDispatcher.locale.languageCode,
      );
      final ok = await ref
          .read(navigationControllerProvider.notifier)
          .start(options.first, query, uiLanguage: language);
      return ok ? null : 'no-route';
    } on Object {
      return 'no-route';
    }
  }

  void dispose() {
    _throttle?.cancel();
    _throttle = null;
    _pump?.cancel();
    _pump = null;
    _pendingDelay = null;
    _dirty = false;
  }
}

final carSessionHubProvider = Provider<CarSessionHub>((ref) {
  final hub = CarSessionHub(ref);
  ref.onDispose(hub.dispose);
  ref.listen(navigationControllerProvider, (prev, next) {
    // Adopt / mula / tamat: push serta-merta supaya AA dapat laluan dan pose baharu.
    if (prev == null ||
        prev.routeVersion != next.routeVersion ||
        prev.phase != next.phase ||
        prev.rerouting != next.rerouting) {
      hub.syncPump();
      hub.flush();
    } else {
      hub.publish();
    }
  });
  ref.listen(cruiseControllerProvider, (prev, next) {
    if (prev?.active != next.active) hub.syncPump();
    hub.publish();
  });
  ref.listen(effectiveThemeModeProvider, (_, _) => hub.publish());
  ref.listen(airQualityControllerProvider, (_, _) => hub.publish());
  // Waktu solat seterusnya di skrin kereta: hanya bila waktu seterusnya atau suisnya berubah.
  ref.listen(azanControllerProvider.select((s) => s.upNext), (_, _) {
    hub.publish();
  });
  ref.listen(azanSettingsProvider.select((s) => s.enabled), (_, _) {
    hub.publish();
  });
  ref.listen(navigationSettingsProvider, (_, _) => hub.publish());
  return hub;
});
