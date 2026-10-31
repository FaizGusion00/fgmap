import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/easy_mode_scope.dart';
import '../../azan/domain/prayer.dart';
import '../../azan/presentation/azan_controller.dart';
import '../../azan/presentation/azan_l10n.dart';
import '../../azan/presentation/azan_now_banner.dart';
import '../../azan/presentation/azan_sheet.dart';
import '../../azan/presentation/azan_today_pill.dart';
import '../../music/presentation/mini_player.dart';
import '../../music/presentation/music_sheet.dart';
import '../../music/presentation/player_controller.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/retry_interceptor.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/platform/external_actions.dart';
import '../../../core/utils/map_links.dart';
import '../../fuel/data/fuel_settings.dart';
import '../../fuel/domain/fuel.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../safety/presentation/emergency_sheet.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/data/route_planner.dart' show routeVehicleProvider;
import '../../route_preview/domain/route_option.dart' show RouteVehicle;
import '../../route_preview/domain/route_options_merge.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../../route_preview/presentation/route_summary_sheet.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';
import '../../search/domain/location_link.dart';
import '../../search/presentation/recent_places_bar.dart';
import '../../search/presentation/trip_planner_page.dart';
import '../../settings/presentation/settings_page.dart';
import '../../navigation/data/location_sources.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/domain/camera_planner.dart';
import '../../navigation/domain/instruction_text.dart';
import '../../navigation/domain/nav_route.dart';
import '../../navigation/presentation/car_session_hub.dart';
import '../../navigation/presentation/cruise_controller.dart';
import '../../navigation/presentation/cruise_frame_driver.dart';
import '../../navigation/presentation/nav_alternatives.dart';
import '../../navigation/presentation/nav_routes_sheet.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../navigation/presentation/navigation_frame_driver.dart';
import '../../navigation/presentation/navigation_hud.dart';
import '../../navigation/presentation/simulate_speed_sheet.dart';
import '../../navigation/presentation/car/car_mesh.dart' show VehicleKind;
import '../../navigation/presentation/car/car_renderer.dart';
import '../../navigation/presentation/car/vehicle_overlay.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import 'auto_start_banner.dart';
import 'idle_follow.dart';
import 'location_prompt.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../search/domain/place.dart';
import '../../saved_places/presentation/assign_place_flow.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_alerts_controller.dart';
import '../../reports/presentation/report_sheet.dart';
import '../../reports/presentation/reports_controller.dart';
import '../data/map_style_loader.dart';
import 'map_view.dart';
import 'nav_route_line.dart';
import 'user_location.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/log.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Selesai apabila pandangan peta memberi kawalan kamera.
  final Completer<MapCameraController> _camera = Completer();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _hintDismissed = false;

  /// Nama destinasi yang sedang dikira mundur untuk navigasi automatik (Rumah/Kerja); null = tiada.
  String? _autoStart;

  /// Bilangan pilihan laluan semasa kamera terakhir dimuatkan (untuk memuat semula selepas alternatif tiba).
  int _fittedRouteCount = 0;
  bool _startupLocationHandled = false;
  bool _incomingLocationReceived = false;
  bool _locating = false;

  /// Satu-satunya langganan GPS peta semasa tidak bernavigasi: menyuap titik lokasi DAN kamera, supaya
  /// kedua-duanya sentiasa bersetuju. Fix lapuk dan melompat ditapis; lihat [UserLocationTracker].
  late final UserLocationTracker _tracker = UserLocationTracker(
    fixes: () => ref.read(locationServiceProvider).trackingFixes(),
  );

  /// Kamera mengikut pengguna semasa tidak bernavigasi (gaya Waze); lihat [IdleFollow].
  late final IdleFollow _idle = IdleFollow(
    updates: _tracker.updates,
    onLocation: _followLocation,
  );
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    _azanTapSub = ref
        .read(azanControllerProvider.notifier)
        .tapped
        .stream
        .listen((_) {
          if (mounted) unawaited(showAzanSheet(context));
        });
    WidgetsBinding.instance.addObserver(this);
    _tracker.location.addListener(_feedSunLocation);
    _tracker.location.addListener(_feedCruise);
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_openSharedLocation(uri)),
      onError: (Object error, StackTrace stackTrace) {
        logDiag('Incoming location link failed: $error');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreTripCamera();
      unawaited(_handleStartupLocation());
    });
  }

  /// Sampel idle untuk ambang memandu bebas. Strim navigasi mengambil alih sebaik mod itu hidup.
  void _feedCruise() {
    final location = _tracker.location.value;
    if (location == null || location.stale || !mounted) return;
    ref
        .read(cruiseControllerProvider.notifier)
        .noteIdle(
          point: location.point,
          speedMps: location.speedMps,
          heading: location.headingDegrees,
          time: location.time,
          blocked:
              ref.read(navigationControllerProvider).isActive ||
              ref.read(routePreviewControllerProvider) is! RouteIdle,
        );
  }

  /// Menyimpan lokasi terakhir untuk mod tema matahari (hanya berubah jika berpindah jauh).
  void _feedSunLocation() {
    final location = _tracker.location.value;
    if (location == null || location.stale || !mounted) return;
    ref.read(sunLocationProvider.notifier).update(location.point);
    ref.read(azanControllerProvider.notifier).onLocation(location.point);
  }

  StreamSubscription<String>? _azanTapSub;

  @override
  void dispose() {
    unawaited(_azanTapSub?.cancel());
    _tracker.location.removeListener(_feedSunLocation);
    _tracker.location.removeListener(_feedCruise);
    _idle.dispose();
    _tracker.dispose();
    _ticker?.dispose();
    _driver?.dispose();
    _cruiseTicker?.dispose();
    _cruiseDriver?.dispose();
    unawaited(_linkSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final trip = _tripOwnsCamera;
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
      ref.read(navigationControllerProvider.notifier).noteBackground(true);
      ref.read(cruiseControllerProvider.notifier).noteBackground(true);
      // Peta tidak dilukis pada kadar bingkai di latar. Perjalanan kekal pada satu strim GPS.
      if (_ticker?.isActive ?? false) _ticker!.stop();
      if (_cruiseTicker?.isActive ?? false) _cruiseTicker!.stop();
      if (!trip) _tracker.suspend(_Suspend.background);
    }
    // Pengguna mungkin menukar kebenaran di Tetapan sistem lalu kembali.
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(azanControllerProvider.notifier).onAppResumed());
      ref.read(navigationControllerProvider.notifier).noteBackground(false);
      ref.read(cruiseControllerProvider.notifier).noteBackground(false);
      if (_ticker != null && !_ticker!.isActive) unawaited(_ticker!.start());
      if (_cruiseTicker != null && !_cruiseTicker!.isActive) {
        unawaited(_cruiseTicker!.start());
      }
      // Perjalanan memiliki kamera: jangan recenter penuh, tetapi hidupkan semula overlay
      // dan paksa push pose ke Android Auto (lapisan GPU / throttle mungkin lapuk).
      _driver?.reviveAfterForeground();
      _cruiseDriver?.reviveAfterForeground();
      ref.read(carSessionHubProvider).flush();
      if (!trip) {
        _tracker.resume(_Suspend.background);
        unawaited(_recenterAfterBackground());
      }
      ref.read(locationAccessProvider.notifier).refresh();
      final navigation = ref.read(navigationControllerProvider);
      if (navigation.phase == NavPhase.active && !navigation.simulated) {
        unawaited(
          ref
              .read(navigationControllerProvider.notifier)
              .refreshCurrentLocation(),
        );
      }
    }
  }

  /// Pada pelancaran app terus membuka peta di lokasi pengguna (gaya Waze), tanpa perlu menekan
  /// "Lokasi saya".
  ///
  /// Kebenaran yang belum diminta dimohon di sini (penjelasan dahulu, kemudian dialog sistem); ditolak
  /// kekal atau GPS dimatikan tidak mengganggu pelancaran. Kamera pergi dahulu ke lokasi terakhir yang
  /// diketahui (serta-merta, walaupun lapuk) supaya peta tidak tersangkut di Kuala Lumpur sementara
  /// menunggu GPS, kemudian diperhalusi dengan fix segar.
  Future<void> _handleStartupLocation() async {
    if (_startupLocationHandled || !mounted) return;
    _startupLocationHandled = true;

    final service = ref.read(locationServiceProvider);
    var access = await service.access();
    if (access == LocationAccess.askable && mounted) {
      access = await ensureLocationAccess(context, ref);
    } else {
      await ref.read(locationAccessProvider.notifier).refresh();
    }
    if (access != LocationAccess.granted || !mounted) return;

    if (_tripOwnsCamera) return;
    _tracker.start();
    await _centerOnUser();
    // Selepas itu kamera terus mengikut pengguna sehingga mereka menggerakkan peta sendiri.
    if (mounted && !_incomingLocationReceived) _idle.engage();
  }

  /// Navigasi memiliki kamera sepenuhnya. Semua operasi tak segerak yang menggerakkan kamera
  /// (menunggu GPS sehingga 12 s, menunggu peta siap) mesti menyemak ini SELEPAS setiap `await`;
  /// jika tidak, ia boleh menerbangkan kamera ke lokasi sebenar di tengah navigasi dan melawan
  /// pemacu bingkai.
  bool get _tripOwnsCamera =>
      ref.read(navigationControllerProvider).isActive ||
      ref.read(cruiseControllerProvider).active;

  bool get _navigationOwnsCamera => _tripOwnsCamera;

  /// Letakkan kamera pada pengguna: lokasi terakhir diketahui dahulu (serta-merta), kemudian fix segar.
  ///
  /// [useLastKnown] hanya untuk pelancaran sejuk, supaya peta tidak tersangkut di Kuala Lumpur sementara
  /// menunggu GPS. Selepas app dibuka semula dari latar belakang ia mesti `false`: lokasi terakhir
  /// ialah tempat pengguna PERNAH berada, dan terbang ke sana ialah punca peta "lari ke tempat lain".
  Future<void> _centerOnUser({bool useLastKnown = true}) async {
    final last = useLastKnown
        ? await ref.read(locationServiceProvider).lastKnownFix()
        : null;
    if (!mounted || _navigationOwnsCamera) return;
    if (last != null && !_incomingLocationReceived) {
      final camera = await _camera.future;
      if (!mounted || _navigationOwnsCamera) return;
      await camera.flyTo(last.point, zoom: 15);
    }
    await _flyToUser(alreadyAt: last?.point);
  }

  /// Kamera mengikut pengguna: anjakkan pusat sahaja, zum/condongan/arah pilihan pengguna dikekalkan.
  void _followLocation(UserLocation location) {
    final camera = _readyCamera;
    if (camera == null || !mounted) return;
    // Navigasi memiliki kamera sepenuhnya; fix lewat (sebelum langganan dibatalkan) tidak boleh menyentuhnya.
    if (ref.read(navigationControllerProvider).isActive) return;
    final pose = camera.pose;
    if (pose == null) {
      unawaited(camera.flyTo(location.point, zoom: 15));
      return;
    }
    // Hingar GPS ketika pegun tidak patut menggoyang kamera.
    if (distanceMeters(pose.center, location.point) < 4) return;
    unawaited(
      camera.animateTo(
        CameraPose(
          center: location.point,
          zoom: pose.zoom,
          tilt: pose.tilt,
          bearing: pose.bearing,
        ),
      ),
    );
  }

  /// App dibuka semula selepas lama di latar belakang: pengguna mungkin sudah berpindah jauh, jadi
  /// pusatkan peta dan mula mengikut semula (kecuali navigasi/laluan sedang berjalan atau lokasi dikongsi).
  Future<void> _recenterAfterBackground() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || !mounted || _incomingLocationReceived) return;
    if (DateTime.now().difference(since) <
        ref.read(idleRecenterAfterProvider)) {
      return;
    }
    if (ref.read(navigationControllerProvider).isActive ||
        ref.read(routePreviewControllerProvider) is! RouteIdle) {
      return;
    }
    if (await ref.read(locationServiceProvider).access() !=
            LocationAccess.granted ||
        !mounted) {
      return;
    }
    _tracker.start();
    _idle.engage();
    await _centerOnUser(useLastKnown: false);
  }

  /// Kedudukan segar terbaik untuk meletakkan kamera. Jika penjejak sedang berjalan, kedudukannya
  /// (yang sama dengan titik lokasi di peta) digunakan serta-merta; jika tidak, tunggu GPS. Fix yang
  /// lebih kasar (sehingga 150 m) lebih baik daripada kamera yang tersangkut di tempat lapuk.
  Future<LocationFix?> _freshFix() async {
    final tracked = _tracker.location.value;
    if (tracked != null &&
        !tracked.stale &&
        DateTime.now().difference(tracked.time) < const Duration(seconds: 10)) {
      return LocationFix(
        point: tracked.point,
        accuracyMeters: tracked.accuracyM,
        headingDegrees: tracked.headingDegrees?.round(),
        speedMps: tracked.speedMps,
        timestamp: tracked.time,
      );
    }
    return ref
        .read(locationServiceProvider)
        .currentFix(
          timeout: const Duration(seconds: 12),
          fallbackAccuracyMeters: 150,
        );
  }

  /// [alreadyAt]: kamera sudah di titik ini; fix segar yang sangat hampir tidak perlu animasi kedua.
  Future<void> _flyToUser({
    bool showFailure = false,
    GeoPoint? alreadyAt,
  }) async {
    final fix = await _freshFix();
    if (!mounted || _navigationOwnsCamera) return;
    if (!showFailure && _incomingLocationReceived) return;
    if (fix != null &&
        alreadyAt != null &&
        distanceMeters(alreadyAt, fix.point) < 30) {
      return;
    }
    if (fix == null) {
      if (showFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).locationFixUnavailable),
          ),
        );
      }
      return;
    }
    final camera = await _camera.future;
    if (!mounted || _navigationOwnsCamera) return;
    await camera.flyTo(fix.point, zoom: 15);
    final accuracy = fix.accuracyMeters;
    if (showFailure && mounted && accuracy != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).locationAccuracy(accuracy.round()),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _zoomMap(double amount) async {
    final camera = await _camera.future;
    if (!mounted) return;
    final driver = _driver;
    if (driver != null && driver.follow.value == NavFollow.following) {
      // Sedang mengikut kenderaan: laras zum dalam pemacu (kamera terus mengikut).
      driver.nudgeZoom(amount);
      return;
    }
    final cruise = _cruiseDriver;
    if (cruise != null && cruise.follow.value == NavFollow.following) {
      cruise.nudgeZoom(amount);
      return;
    }
    if (ref.read(navigationControllerProvider).isActive) {
      driver?.userInteracted();
    }
    await camera.zoomBy(amount);
  }

  Future<void> _onMyLocationPressed() async {
    if (_locating) return;
    // Cruise / nav memiliki kamera: pusatkan semula pemacu (bukan fly-to idle).
    if (ref.read(cruiseControllerProvider).active) {
      _cruiseDriver?.recenter();
      if (mounted) setState(() {});
      return;
    }
    if (ref.read(navigationControllerProvider).isActive) {
      _driver?.recenter();
      if (mounted) setState(() {});
      return;
    }
    final access = await ensureLocationAccess(context, ref);
    if (!mounted || access != LocationAccess.granted) return;
    setState(() => _locating = true);
    try {
      await _flyToUser(showFailure: true);
      if (mounted) _idle.engage();
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _recenterTripCamera() {
    _driver?.recenter();
    _cruiseDriver?.recenter();
    if (mounted) setState(() {});
  }

  void _onLongPress(GeoPoint point) {
    Haptics.medium();
    setState(() => _hintDismissed = true);
    unawaited(_planToDestination(point));
  }

  /// Membuka perancang destinasi, kemudian mengira laluan dari lokasi pengguna.
  Future<void> _openPlanner({SavedKind? assign}) async {
    final user = _userPoint();
    final selection = await TripPlannerPage.open(
      context,
      near: user ?? _cameraCenterOrDefault(),
      userLocation: user,
      assign: assign,
    );
    if (selection == null || !mounted) return;
    await _planSelection(selection);
  }

  Future<void> _planSelection(TripSelection selection) async {
    if (!mounted) return;
    setState(() => _hintDismissed = true);
    final access = await ensureLocationAccess(context, ref);
    if (!mounted || access != LocationAccess.granted) return;
    await ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(
          selection.destination.point,
          destinationLabel: selection.destination.name,
          radiusM: selection.destination.routingRadiusM,
        );
  }

  /// Rumah/Kerja diketik: kira laluan, kemudian mula navigasi selepas kiraan 3 saat yang boleh
  /// dibatalkan. Jika laluan gagal atau kebenaran lokasi tiada, kekal pada pratonton biasa.
  Future<void> _goNow(Place place) async {
    await _planSelection(TripSelection(destination: place));
    if (!mounted) return;
    final state = ref.read(routePreviewControllerProvider);
    if (state is RouteReady &&
        !ref.read(navigationControllerProvider).isActive) {
      unawaited(Haptics.selection());
      setState(() => _autoStart = place.name);
    }
  }

  void _cancelAutoStart() {
    if (_autoStart != null) setState(() => _autoStart = null);
  }

  Future<void> _finishAutoStart() async {
    if (!mounted || _autoStart == null) return;
    setState(() => _autoStart = null);
    // Keadaan terkini (pengguna mungkin menukar kenderaan atau laluan dalam 3 saat itu).
    final state = ref.read(routePreviewControllerProvider);
    if (state is! RouteReady ||
        ref.read(navigationControllerProvider).isActive) {
      return;
    }
    await _startNavigation(state, simulate: false);
  }

  Future<void> _planToDestination(
    GeoPoint point, {
    String? destinationLabel,
  }) async {
    final access = await ensureLocationAccess(context, ref);
    if (!mounted || access != LocationAccess.granted) return;
    await ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(point, destinationLabel: destinationLabel);
  }

  Future<void> _openSharedLocation(Uri uri) async {
    var shared = sharedLocationFromUri(uri);
    if (shared != null || _isShortMapLink(uri)) {
      _incomingLocationReceived = true;
      _idle.release();
    }
    if (shared == null && _isShortMapLink(uri)) {
      try {
        final response = await ref
            .read(dioProvider)
            .headUri<Object?>(
              uri,
              options: RetryInterceptor.options(
                Options(followRedirects: true, maxRedirects: 5),
              ),
            );
        final resolved = response.realUri;
        if (_isSupportedMapLink(resolved)) {
          shared = sharedLocationFromUri(resolved);
        }
      } on DioException catch (error) {
        logDiag('Shared map link could not be resolved: ${error.type.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).routeErrorNetwork),
            ),
          );
        }
        return;
      }
    }
    if (shared == null || !mounted) return;
    if (ref.read(navigationControllerProvider).isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).sharedLocationStopNavigation,
          ),
        ),
      );
      return;
    }

    final user = _userPoint();
    final near = user ?? _cameraCenterOrDefault();
    final point = shared.point;
    if (point != null) {
      setState(() => _hintDismissed = true);
      await _planToDestination(
        point,
        destinationLabel:
            shared.label ??
            '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
      );
      return;
    }

    final query = shared.label;
    if (query == null || query.isEmpty) return;
    final selection = await TripPlannerPage.open(
      context,
      near: near,
      userLocation: user,
      initialDestinationQuery: query,
    );
    if (selection != null) await _planSelection(selection);
  }

  static bool _isShortMapLink(Uri uri) =>
      uri.scheme == 'https' &&
      const {'maps.app.goo.gl', 'goo.gl'}.contains(uri.host.toLowerCase());

  static bool _isSupportedMapLink(Uri uri) =>
      const {'http', 'https'}.contains(uri.scheme) &&
      const {
        'google.com',
        'www.google.com',
        'maps.google.com',
        'maps.app.goo.gl',
        'goo.gl',
        'waze.com',
        'www.waze.com',
        'maps.apple.com',
      }.contains(uri.host.toLowerCase());

  // ---- Navigasi ----

  NavigationFrameDriver? _driver;
  Ticker? _ticker;
  CruiseFrameDriver? _cruiseDriver;
  Ticker? _cruiseTicker;

  // Laluan navigasi aktif untuk peta: dibina sekali setiap laluan (re-route menggantinya) dan dipangkas
  // di permulaan oleh peta mengikut kedudukan kenderaan.
  NavRouteLine? _navLine;

  NavRouteLine? _navLineFor(NavigationState nav) {
    final route = nav.route;
    if (route == null) return null;
    final current = _navLine;
    if (current != null && current.version == nav.routeVersion) return current;
    final display = route.displayPolyline(stepM: 5, cornerStepM: 3);
    return _navLine = NavRouteLine(
      points: display.points,
      cumulativeM: display.cumulativeM,
      version: nav.routeVersion,
    );
  }

  void _restoreTripCamera() {
    if (!mounted) return;
    final nav = ref.read(navigationControllerProvider);
    if (nav.isActive) {
      _tracker.suspend(_Suspend.navigation);
      _idle.suspend(_Suspend.navigation);
      unawaited(_beginDriving());
    }
    if (ref.read(cruiseControllerProvider).active) {
      _tracker.suspend(_Suspend.cruise);
      _idle.suspend(_Suspend.cruise);
      unawaited(_beginCruise());
    }
  }

  void _onNavigationChanged(NavigationState? prev, NavigationState next) {
    final wasActive = prev?.isActive ?? false;
    if (next.isActive && !wasActive) {
      _endCruise(settle: false);
      _tracker.suspend(_Suspend.navigation);
      _idle.suspend(_Suspend.navigation);
      unawaited(_beginDriving());
    }
    if (!next.isActive && wasActive) {
      _endDriving();
      _idle.resume(_Suspend.navigation);
      _tracker.resume(_Suspend.navigation);
      ref.read(cruiseControllerProvider.notifier).setBlocked(false);
      if (ref.read(locationAccessProvider) == LocationAccess.granted) {
        _tracker.start();
      }
    }
  }

  void _onCruiseChanged(CruiseState? prev, CruiseState next) {
    final was = prev?.active ?? false;
    if (next.active && !was) {
      _tracker.suspend(_Suspend.cruise);
      _idle.suspend(_Suspend.cruise);
      unawaited(_beginCruise());
    }
    if (!next.active && was) {
      final handoff =
          next.handoff || ref.read(navigationControllerProvider).isActive;
      _endCruise(
        settle:
            !handoff && ref.read(routePreviewControllerProvider) is RouteIdle,
      );
      if (!handoff) {
        _tracker.resume(_Suspend.cruise);
        _idle.resume(_Suspend.cruise);
        if (ref.read(locationAccessProvider) == LocationAccess.granted) {
          _tracker.start();
        }
      }
    }
  }

  Future<void> _beginDriving() async {
    final camera = await _camera.future;
    if (!mounted || _driver != null) return;
    if (!ref.read(navigationControllerProvider).isActive) return;
    final nav = ref.read(navigationControllerProvider.notifier);
    final driver = NavigationFrameDriver(
      camera: camera,
      poseAt: nav.poseAt,
      progress: () => ref.read(navigationControllerProvider).progress,
      route: () => ref.read(navigationControllerProvider).route,
      viewportHeight: () => MediaQuery.sizeOf(context).height,
      screenOffset: () => carScreenOffsetFor(MediaQuery.sizeOf(context)),
      viewportWidth: () => MediaQuery.sizeOf(context).width,
      cameraMode: () => ref.read(navigationSettingsProvider).cameraMode,
      clock: ref.read(navClockProvider),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onPose: (pose, {required bool following}) =>
          ref.read(carSessionHubProvider).notePose(pose, following: following),
    );
    driver.follow.addListener(() {
      if (mounted) setState(() {});
    });
    _driver = driver;
    final ticker = createTicker(driver.step);
    _ticker = ticker;
    unawaited(ticker.start());
    setState(() {});
  }

  void _endDriving() {
    _ticker?.dispose();
    _ticker = null;
    _driver?.dispose();
    _driver = null;
    _navLine = null;
    final camera = _readyCamera;
    if (camera != null) {
      camera.showVehicle(null);
      // Kembali ke peta 2D menghadap utara.
      final pose = camera.pose;
      if (pose != null) {
        unawaited(
          camera.animateTo(
            CameraPose(
              center: pose.center,
              zoom: math.min(pose.zoom, 16),
              tilt: 0,
              bearing: 0,
            ),
          ),
        );
      }
    }
    ref.read(routePreviewControllerProvider.notifier).clear();
    if (mounted) setState(() {});
  }

  Future<void> _beginCruise() async {
    final camera = await _camera.future;
    if (!mounted || _cruiseDriver != null) return;
    if (!ref.read(cruiseControllerProvider).active) return;
    if (ref.read(navigationControllerProvider).isActive) return;
    final driver = CruiseFrameDriver(
      camera: camera,
      sample: () => ref.read(cruiseControllerProvider).fix,
      viewportHeight: () => MediaQuery.sizeOf(context).height,
      viewportWidth: () => MediaQuery.sizeOf(context).width,
      screenOffset: () => cruiseScreenOffsetFor(MediaQuery.sizeOf(context)),
      cameraMode: () => ref.read(navigationSettingsProvider).cameraMode,
      clock: ref.read(navClockProvider),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      onPose: (pose, {required bool following}) =>
          ref.read(carSessionHubProvider).notePose(pose, following: following),
    );
    driver.follow.addListener(() {
      if (mounted) setState(() {});
    });
    _cruiseDriver = driver;
    final ticker = createTicker(driver.step);
    _cruiseTicker = ticker;
    unawaited(ticker.start());
    setState(() {});
  }

  void _endCruise({required bool settle}) {
    _cruiseTicker?.dispose();
    _cruiseTicker = null;
    _cruiseDriver?.dispose();
    _cruiseDriver = null;
    if (!settle) {
      if (mounted) setState(() {});
      return;
    }
    _settleNorthUp();
    if (mounted) setState(() {});
  }

  void _settleNorthUp() {
    final camera = _readyCamera;
    if (camera == null) return;
    camera.showVehicle(null);
    final pose = camera.pose;
    if (pose == null) return;
    unawaited(
      camera.animateTo(
        CameraPose(
          center: pose.center,
          zoom: math.min(pose.zoom, 16),
          tilt: 0,
          bearing: 0,
        ),
      ),
    );
  }

  Future<void> _startNavigation(
    RouteReady ready, {
    required bool simulate,
  }) async {
    final uiLanguage = VoiceLanguage.fromCode(
      AppLocalizations.of(context).localeName,
    );
    if (!simulate) {
      final access = await ensureLocationAccess(context, ref);
      if (access != LocationAccess.granted || !mounted) return;
    } else {
      final kmh = await showSimulateSpeedSheet(context, ref);
      if (kmh == null || !mounted) return;
    }
    final route = ready.selected;
    final simKmh = ref.read(navigationSettingsProvider).simSpeedKmh;
    await ref
        .read(navigationControllerProvider.notifier)
        .start(
          route,
          ready.selectedQuery,
          uiLanguage: uiLanguage,
          source: simulate
              ? routeSimulation(
                  NavRoute(route),
                  cruiseSpeedMps: simKmh > 0 ? simKmh / 3.6 : null,
                  clock: ref.read(navClockProvider),
                )
              : null,
        );
  }

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context);
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.navEndTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.navEndKeep),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.navEnd),
          ),
        ],
      ),
    );
    if (end == true) {
      await ref.read(navigationControllerProvider.notifier).stop();
    }
  }

  void _showOverview() {
    final nav = ref.read(navigationControllerProvider);
    final route = nav.route;
    if (route == null) return;
    final media = MediaQuery.of(context);
    final shape = route.remainingShape(
      nav.progress?.alongM ?? 0,
      aheadM: route.totalM,
    );
    _driver?.showOverview(
      shape,
      padding: EdgeInsets.fromLTRB(
        40,
        media.padding.top + 260,
        40,
        140 + media.padding.bottom,
      ),
    );
  }

  /// Pilih laluan lain dari kedudukan semasa tanpa menamatkan perjalanan. Pilihan dilukis pada peta
  /// dan kamera menunjukkan seluruh kawasan; selepas ditutup kamera kembali mengikut kenderaan.
  Future<void> _changeRoute() async {
    final alternatives = ref.read(navAlternativesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final media = MediaQuery.of(context);
    unawaited(
      alternatives.load().then((_) {
        if (!mounted) return;
        final state = ref.read(navAlternativesProvider);
        if (state.status != NavAlternativesStatus.ready) return;
        final nav = ref.read(navigationControllerProvider);
        final route = nav.route;
        _driver?.showOverview(
          [
            for (final option in state.options) ...option.points,
            ?(route?.points.last),
          ],
          padding: EdgeInsets.fromLTRB(
            40,
            media.padding.top + 260,
            40,
            media.size.height * 0.45,
          ),
        );
      }),
    );
    final switched = await showNavRoutesSheet(context);
    alternatives.clear();
    if (!mounted) return;
    _driver?.recenter();
    if (switched == true) {
      messenger?.showSnackBar(SnackBar(content: Text(l10n.navRoutesSwitched)));
    }
  }

  Future<void> _cycleCameraMode() {
    final controller = ref.read(navigationSettingsProvider.notifier);
    final current = ref.read(navigationSettingsProvider).cameraMode;
    final next = switch (current) {
      NavCameraMode.auto => NavCameraMode.tilted,
      NavCameraMode.tilted => NavCameraMode.flat,
      NavCameraMode.flat => NavCameraMode.auto,
    };
    return controller.setCameraMode(next);
  }

  /// Destinasi laluan semasa sebagai [Place] untuk disimpan; nama daripada label carian jika ada.
  Place _destinationPlace(RouteReady ready) {
    final point = ready.query.destination;
    return Place(
      name:
          ready.query.destinationLabel ??
          '${point.lat.toStringAsFixed(5)}, ${point.lng.toStringAsFixed(5)}',
      subtitle: '',
      point: point,
    );
  }

  /// Lokasi GPS yang sah (tidak lapuk), untuk mengutamakan hasil carian berhampiran dan memaparkan jarak.
  GeoPoint? _userPoint() {
    final tracked = _tracker.location.value;
    return tracked == null || tracked.stale ? null : tracked.point;
  }

  GeoPoint _cameraCenterOrDefault() {
    // Kawalan kamera sudah tersedia pada masa pengguna menekan lama (peta telah dipaparkan).
    return _readyCamera?.center ?? AppConfig.initialCenter;
  }

  MapCameraController? _readyCamera;
  ResolvedMapStyle? _lastStyle;

  void _onMapReady(MapCameraController controller) {
    _readyCamera = controller;
    if (!_camera.isCompleted) _camera.complete(controller);
  }

  /// Memuatkan semua pilihan laluan dalam pandangan di atas lembaran ringkasan. Lembaran dengan
  /// kad pilihan lebih tinggi daripada lembaran satu laluan, dan membesar mengikut saiz teks sistem.
  Future<void> _fitRoutes(RouteReady ready) async {
    final camera = await _camera.future;
    if (!mounted || _navigationOwnsCamera) return;
    final media = MediaQuery.of(context);
    final sheetHeight =
        (ready.visibleOptions.length > 1 ? 440.0 : 360.0) *
        media.textScaler.scale(1).clamp(1.0, 1.4);
    await camera.fitTo(
      [for (final option in ready.visibleOptions) ...option.points],
      padding: EdgeInsets.fromLTRB(
        40,
        media.padding.top + 80,
        // Ruang untuk butang zum dan lokasi di kanan supaya destinasi tidak tertutup.
        88,
        sheetHeight + media.padding.bottom,
      ),
    );
  }

  /// Mengetuk laluan alternatif pada peta memilihnya (seperti aplikasi peta lain).
  void _onMapTap(GeoPoint point) {
    final zoom = _readyCamera?.pose?.zoom ?? 12;
    final tapped = _reportNear(point, metersPerPixel(zoom, point.lat) * 30);
    if (tapped != null) {
      unawaited(_reviewReport(tapped));
      return;
    }
    final state = ref.read(routePreviewControllerProvider);
    if (state is! RouteReady || state.visibleOptions.length < 2) return;
    final index = nearestRouteIndex(
      [for (final o in state.visibleOptions) o.points],
      point,
      toleranceM: metersPerPixel(zoom, point.lat) * 28,
    );
    if (index == null || index == state.selectedIndex) return;
    _selectRoute(index);
  }

  /// Laporan aktif paling hampir dengan [point] dalam [toleranceM] (kira-kira 30 piksel), atau null.
  Report? _reportNear(GeoPoint point, double toleranceM) {
    Report? best;
    var bestD = toleranceM;
    for (final r in ref.read(reportsControllerProvider)) {
      final d = distanceMeters(point, r.point);
      if (d <= bestD) {
        best = r;
        bestD = d;
      }
    }
    return best;
  }

  /// Ketuk penanda: tanya "Masih ada?" dan undi.
  Future<void> _reviewReport(Report report) async {
    unawaited(Haptics.selection());
    final stillThere = await showStillThereDialog(context, report);
    if (stillThere == null || !mounted) return;
    await ref
        .read(reportsControllerProvider.notifier)
        .vote(report.id, confirm: stillThere);
  }

  Future<void> _openReport() async {
    final result = await showReportSheet(context);
    if (result == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (result) {
      CreateReportResult.created => l10n.reportCreated,
      CreateReportResult.confirmedExisting => l10n.reportConfirmedExisting,
      CreateReportResult.noLocation => l10n.reportNoLocation,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _askOpen = false;

  /// Soalan "Masih ada?" semasa memandu; ditutup sendiri apabila pengawal melepaskannya (tamat masa).
  Future<void> _onAskChanged(Report? previous, Report? next) async {
    if (next == null) {
      if (_askOpen) {
        Navigator.of(context, rootNavigator: true).pop();
        _askOpen = false;
      }
      return;
    }
    if (_askOpen || !mounted) return;
    _askOpen = true;
    final answer = await showStillThereDialog(context, next);
    _askOpen = false;
    if (!mounted) return;
    await ref.read(reportAlertsProvider.notifier).answer(confirm: answer);
  }

  /// Kedudukan semasa untuk kecemasan: penjejak jika ada, jika tidak GPS (lebih lambat).
  Future<GeoPoint?> _emergencyLocate() async {
    final known = _userPoint();
    if (known != null) return known;
    return (await _freshFix())?.point;
  }

  void _openEmergency() {
    Haptics.medium();
    unawaited(showEmergencySheet(context, locate: _emergencyLocate));
  }

  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _share(String text) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = AppLocalizations.of(context).shareFailed;
    try {
      await ref
          .read(shareServiceProvider)
          .shareText(text, origin: _shareOrigin());
    } on Object {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  String _etaText(Duration remaining) =>
      MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(ref.read(navClockProvider)().add(remaining)),
      );

  /// Kongsi destinasi dan masa tiba laluan terpilih (teks + pautan OpenStreetMap; tiada pengesanan langsung).
  Future<void> _shareDestination(RouteReady ready) {
    final l10n = AppLocalizations.of(context);
    final route = ready.selected;
    final name =
        ready.query.destinationLabel ?? coordinateText(ready.query.destination);
    return _share(
      l10n.shareDestinationText(
        name,
        _etaText(Duration(seconds: route.durationS)),
        formatDuration(l10n, route.durationS),
        formatDistance(l10n, route.distanceM),
        osmPointLink(ready.query.destination),
      ),
    );
  }

  /// Semasa navigasi: kongsi masa tiba yang dikemas kini dan baki jarak.
  Future<void> _shareEta() {
    final l10n = AppLocalizations.of(context);
    final nav = ref.read(navigationControllerProvider);
    final query = nav.query;
    final progress = nav.progress;
    if (query == null || progress == null) return Future.value();
    final name = query.destinationLabel ?? coordinateText(query.destination);
    return _share(
      l10n.shareEtaText(
        name,
        _etaText(Duration(seconds: progress.remainingS.round())),
        formatDistance(l10n, progress.remainingM.round()),
        osmPointLink(query.destination),
      ),
    );
  }

  void _selectRoute(int index) {
    Haptics.selection();
    ref.read(routePreviewControllerProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = context.fg;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(routePreviewControllerProvider);
    final access = ref.watch(locationAccessProvider);
    final controller = ref.read(routePreviewControllerProvider.notifier);
    final nav = ref.watch(navigationControllerProvider);
    final navSettings = ref.watch(navigationSettingsProvider);
    // Harga minyak hanya diambil (rangkaian) apabila laluan sedia, bukan semasa app dibuka.
    final fuelSettings = ref.watch(fuelSettingsProvider);
    final fuelPrice = state is RouteReady
        ? ref.watch(effectiveFuelPriceProvider)
        : null;
    final navigating = nav.isActive;
    final cruising = ref.watch(cruiseControllerProvider).active && !navigating;
    // Kenderaan yang dipilih (kereta/motosikal): sama dengan yang digunakan untuk mengira laluan.
    final vehicle = navigating
        ? (nav.query?.vehicle ?? ref.watch(routeVehicleProvider))
        : ref.watch(routeVehicleProvider);
    final vehicleKind = vehicle == RouteVehicle.motorcycle
        ? VehicleKind.motorcycle
        : VehicleKind.car;
    // Waktu Azan: teks notifikasi ikut bahasa UI; sepanduk/cip apabila azan dimainkan dalam app.
    ref
        .read(azanControllerProvider.notifier)
        .setTexts(azanNotificationTexts(l10n, Localizations.localeOf(context)));
    final azanNow = ref.watch(
      azanControllerProvider.select((s) => s.nowPlaying),
    );
    // Sumber tunggal dengan app.dart: mod matahari sudah dipetakan kepada cerah/gelap di sana.
    final mapIsDark = isDarkTheme(
      ref.watch(effectiveThemeModeProvider),
      MediaQuery.platformBrightnessOf(context),
    );

    ref.listen<NavigationState>(
      navigationControllerProvider,
      _onNavigationChanged,
    );
    ref.listen<CruiseState>(cruiseControllerProvider, _onCruiseChanged);
    final hub = ref.watch(carSessionHubProvider);
    hub.bindCamera(
      recenter: _recenterTripCamera,
      pan: () {
        _driver?.userInteracted();
        _cruiseDriver?.userInteracted();
      },
    );
    // Sebarang tindakan pengguna pada laluan (tukar kenderaan, pilih laluan lain, padam) membatalkan
    // kiraan mundur; navigasi tidak boleh bermula di luar kehendaknya.
    ref.listen<RoutePreviewState>(routePreviewControllerProvider, (prev, next) {
      if (_autoStart == null) return;
      final changed =
          next is! RouteReady ||
          (prev is RouteReady && prev.selectedIndex != next.selectedIndex);
      if (changed) _cancelAutoStart();
    });

    // Penjejak lokasi hidup selagi kebenaran ada (ia juga digantung sendiri di latar belakang dan
    // semasa navigasi); berhenti sepenuhnya jika kebenaran ditarik balik.
    ref.listen<Report?>(
      reportAlertsProvider.select((s) => s.ask),
      (prev, next) => unawaited(_onAskChanged(prev, next)),
    );

    ref.listen<LocationAccess>(locationAccessProvider, (prev, next) {
      if (next == LocationAccess.granted) {
        _tracker.start();
      } else {
        _tracker.stop();
      }
    });

    ref.listen<RoutePreviewState>(routePreviewControllerProvider, (prev, next) {
      // Semasa laluan dipratonton, kamera dipegang oleh paparan laluan, bukan pengguna.
      if (next is RouteIdle) {
        _idle.resume(_Suspend.route);
        ref
            .read(cruiseControllerProvider.notifier)
            .setBlocked(ref.read(navigationControllerProvider).isActive);
        if (prev is! RouteIdle && _idle.following) unawaited(_flyToUser());
      } else {
        _idle.suspend(_Suspend.route);
        ref.read(cruiseControllerProvider.notifier).setBlocked(true);
      }
      // Muatkan laluan dalam pandangan apabila set pilihan pertama tiba, dan sekali lagi apabila
      // pencarian alternatif selesai dengan lebih banyak laluan (bukan pada setiap laluan yang tiba
      // atau bila pengguna sekadar bertukar antara laluan).
      if (next is RouteReady) {
        final first = prev is! RouteReady;
        final finished =
            prev is RouteReady &&
            prev.loadingMore &&
            !next.loadingMore &&
            next.options.length > _fittedRouteCount;
        if (first || finished) {
          _fittedRouteCount = next.options.length;
          unawaited(_fitRoutes(next));
        }
      }
    });

    final sheetVisible = state is! RouteIdle;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    // Gaya peta (gaya malam diwarnakan semula; lihat NightStyle). Gaya sebelumnya dikekalkan semasa
    // gaya baharu dimuat supaya peta tidak berkelip; peta pertama menunggu paling lama beberapa saat.
    final resolved = ref.watch(mapStyleProvider(mapIsDark)).value;
    if (resolved != null) _lastStyle = resolved;
    final style = resolved ?? _lastStyle;

    final config = MapViewConfig(
      styleUrl:
          style?.style ??
          (mapIsDark ? AppConfig.mapStyleDark : AppConfig.mapStyleLight),
      styleKey: style?.key,
      reports: [
        for (final r in ref.watch(reportsControllerProvider))
          MapReport(id: r.id, type: r.type, point: r.point),
      ],
      initialCenter:
          nav.progress?.position ??
          (cruising
              ? (ref.read(cruiseControllerProvider).point ??
                    AppConfig.initialCenter)
              : AppConfig.initialCenter),
      initialZoom: navigating || cruising ? 17 : AppConfig.initialZoom,
      initialBearing: navigating
          ? (nav.progress?.bearing ?? 0)
          : (cruising ? ref.read(cruiseControllerProvider).bearing : 0),
      // Free-ride Waze 2D: tilt 0. Navigasi kekal 3D default.
      initialTilt: navigating ? 55 : 0,
      routes: navigating
          ? [
              // Pilihan laluan lain semasa lembaran "Tukar laluan" dibuka (kelabu di bawah laluan semasa).
              for (final points
                  in ref.watch(navAlternativesProvider).otherRoutes)
                MapRouteLine(points: points, isMain: false),
            ]
          : _routeLines(state),
      navRoute: navigating ? _navLineFor(nav) : null,
      navAlong: navigating ? _driver?.routeAlong : null,
      finalLeg: _finalLeg(
        end: navigating
            ? nav.route?.points.last
            : (state is RouteReady ? state.selected.points.last : null),
        destination: navigating ? nav.query?.destination : _destination(state),
      ),
      destination: navigating ? nav.query?.destination : _destination(state),
      showUserLocation:
          access == LocationAccess.granted && !navigating && !cruising,
      userLocation: _tracker.location,
      showCompass: !navigating && !cruising,
      vehicleKind: vehicleKind,
      colors: MapOverlayColors(
        mainRoute: fg.routeMain,
        routeCasing: fg.routeCasing,
        alternativeRoute: fg.routeAlternative,
        destination: fg.destination,
        vehicle: theme.colorScheme.primary,
        dark: mapIsDark,
      ),
      onLongPress: navigating ? (_) {} : _onLongPress,
      onTap: navigating ? null : _onMapTap,
      onReady: _onMapReady,
      onUserGesture: navigating
          ? _driver?.userInteracted
          : cruising
          ? _cruiseDriver?.userInteracted
          : _idle.release,
    );

    // Skop Mod mudah untuk semua anak (HUD, pil carian, cip Rumah/Kerja, lembaran laluan); app.dart
    // juga menyediakannya, tetapi ujian memasang MapScreen terus.
    return EasyModeScope(
      enabled: ref.watch(appPreferencesProvider.select((p) => p.easyMode)),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: style == null
                  ? const _MapLoading()
                  : ref.watch(mapViewBuilderProvider)(context, config),
            ),
            if (navigating && _driver != null)
              Positioned.fill(
                child: VehicleOverlay(
                  placement: _driver!.car,
                  palette: CarPalette.forBrightness(
                    theme.colorScheme.primary,
                    mapIsDark ? Brightness.dark : Brightness.light,
                  ),
                  kind: vehicleKind,
                ),
              ),
            // Free-ride: penanda peta 2D sahaja (tiada VehicleOverlay 3D).
            if (!navigating)
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _GlassIconButton(
                            icon: Icons.tune_rounded,
                            tooltip: l10n.appearanceTooltip,
                            onPressed: () => showSettingsSheet(context),
                          ),
                          Expanded(
                            // topCenter, bukan Center: Row mengisi seluruh tinggi skrin, jadi Center
                            // meletakkan pil di tengah peta.
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: _SearchPill(
                                label: l10n.searchPillHint,
                                hint: !_hintDismissed && state is RouteIdle
                                    ? l10n.mapHintLongPress
                                    : null,
                                onTap: _openPlanner,
                              ),
                            ),
                          ),
                          _GlassIconButton(
                            icon: Icons.music_note_rounded,
                            tooltip: l10n.musicOpen,
                            onPressed: () => unawaited(showMusicSheet(context)),
                          ),
                          _GlassIconButton(
                            icon: Icons.cloud_download_outlined,
                            tooltip: l10n.offlineMapsOpen,
                            onPressed: () => showOfflineMapsSheet(context),
                          ),
                        ],
                      ),
                      if (state is RouteIdle) ...[
                        const SizedBox(height: 10),
                        RecentPlacesBar(
                          onPick: (place) => unawaited(
                            _planSelection(TripSelection(destination: place)),
                          ),
                          onGo: (place) => unawaited(_goNow(place)),
                          onAssign: (kind) => unawaited(
                            assignSavedPlace(
                              context,
                              ref,
                              kind,
                              near: _userPoint() ?? _cameraCenterOrDefault(),
                              userLocation: _userPoint(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: AzanTodayPill(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (!navigating)
              Align(
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        0,
                        12,
                        sheetVisible ? 8 : 8 + bottomSafe,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Spacer(),
                          const SizedBox(width: 12),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Skrin pendek (telefon mendatar): butang zum disembunyikan supaya lajur
                              // kawalan tidak menutup lembaran laluan; mencubit tetap berfungsi.
                              if (MediaQuery.sizeOf(context).height >= 500) ...[
                                _MapZoomControls(
                                  onZoomIn: () => unawaited(_zoomMap(1)),
                                  onZoomOut: () => unawaited(_zoomMap(-1)),
                                ),
                                const SizedBox(height: 8),
                              ],
                              _GlassIconButton(
                                icon: Icons.emergency_rounded,
                                tooltip: l10n.emergencyTooltip,
                                onPressed: _openEmergency,
                              ),
                              const SizedBox(height: 8),
                              _GlassIconButton(
                                icon: Icons.add_alert_rounded,
                                tooltip: l10n.reportButtonTooltip,
                                onPressed: _openReport,
                              ),
                              const SizedBox(height: 8),
                              _GlassIconButton(
                                icon: Icons.my_location_rounded,
                                tooltip: l10n.myLocation,
                                onPressed: _onMyLocationPressed,
                                loading: _locating,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_autoStart != null && state is RouteReady)
                      AutoStartBanner(
                        name: _autoStart!,
                        onDone: () => unawaited(_finishAutoStart()),
                        onCancel: _cancelAutoStart,
                      ),
                    // Pemain muzik kecil di atas lembaran laluan (bukan semasa navigasi).
                    if (ref.watch(
                      playerControllerProvider.select((p) => p.current != null),
                    ))
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: MiniPlayer(),
                      ),
                    Flexible(
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.normal),
                        // Pegas redaman kritikal: mendarat lembut tanpa lajak (lembaran melekat di bawah).
                        switchInCurve: Motion.sheet,
                        switchOutCurve: Motion.exit,
                        transitionBuilder: (child, animation) =>
                            SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                        child: sheetVisible
                            ? RouteSummarySheet(
                                key: const ValueKey('route-sheet'),
                                state: state,
                                onSelect: _selectRoute,
                                onShowMore: controller.showMore,
                                onShare: state is RouteReady
                                    ? () => unawaited(_shareDestination(state))
                                    : null,
                                fuelCostRm: state is RouteReady
                                    ? estimateFuelCostRm(
                                        distanceM: state.selected.distanceM,
                                        litersPer100Km: fuelSettings
                                            .litersPer100Km(
                                              state.query.vehicle,
                                            ),
                                        pricePerLiter: fuelPrice,
                                      )
                                    : null,
                                onVehicleChanged: (v) =>
                                    unawaited(controller.setVehicle(v)),
                                onRetry: controller.retry,
                                onClear: controller.clear,
                                onSave: state is RouteReady
                                    ? () => unawaited(
                                        showSavePlaceSheet(
                                          context,
                                          _destinationPlace(state),
                                        ),
                                      )
                                    : null,
                                onOpenOfflineMaps: () =>
                                    showOfflineMapsSheet(context),
                                onStart: state is RouteReady
                                    ? () => _startNavigation(
                                        state,
                                        simulate: false,
                                      )
                                    : null,
                                onSimulate: state is RouteReady
                                    ? () => _startNavigation(
                                        state,
                                        simulate: true,
                                      )
                                    : null,
                              )
                            : const SizedBox.shrink(key: ValueKey('no-sheet')),
                      ),
                    ),
                  ],
                ),
              ),
            if (cruising) ..._cruiseOverlay(),
            if (navigating) ..._navigationOverlay(nav, navSettings, azanNow),
            if (!navigating && azanNow != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 76, 12, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: AzanNowBanner(prayer: azanNow),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// HUD memandu bebas: kelajuan + butang pusatkan apabila pengguna menggerakkan peta.
  List<Widget> _cruiseOverlay() {
    final follow = _cruiseDriver?.follow.value ?? NavFollow.following;
    return [
      SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SpeedBubble(
              speedMps: ref.watch(cruiseControllerProvider).speedMps,
              limitKmh: ref.watch(cruiseControllerProvider).limitKmh,
              overspeed: ref.watch(cruiseControllerProvider).overspeed,
            ),
          ),
        ),
      ),
      if (follow != NavFollow.following)
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 12, 120),
              child: RecenterButton(onPressed: _recenterTripCamera),
            ),
          ),
        ),
    ];
  }

  /// Lapisan HUD navigasi. Potret: kad manuver di atas, kelajuan dan butang di atas panel perjalanan.
  /// Mendatar: kad manuver dan panel di sebelah kiri, butang di sebelah kanan, dan bahagian tengah
  /// dibiarkan kosong supaya kereta dan jalan di hadapan tidak terlindung.
  List<Widget> _navigationOverlay(
    NavigationState nav,
    NavigationSettings settings,
    Prayer? azanNow,
  ) {
    final progress = nav.progress;
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    // Terus daripada tetapan (bukan EasyModeScope): konteks ini berada di atas skop yang dibina
    // oleh skrin ini sendiri.
    final easy = ref.watch(appPreferencesProvider.select((p) => p.easyMode));
    final metrics = NavHudMetrics.forSize(media.size, easy: easy);
    final follow = _driver?.follow.value ?? NavFollow.following;
    final arrived = nav.phase == NavPhase.arrived;
    final stop = ref.read(navigationControllerProvider.notifier).stop;

    final banner = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (progress != null && !arrived)
          ManeuverBanner(progress: progress, liveAlongM: _driver?.alongM),
        NavStatusChip(state: nav),
        // Azan semasa navigasi: cip kecil + bunyi pendek sahaja (lihat AzanController).
        if (azanNow != null) AzanNavChip(prayer: azanNow),
      ],
    );

    final simMult = ref
        .read(navigationControllerProvider.notifier)
        .simSpeedMultiplier;
    final speed = progress != null && !arrived
        ? SpeedBubble(
            speedMps: progress.speedMps,
            limitKmh: nav.currentLimitKmh,
            overspeed: nav.overspeed,
          )
        : null;
    final simBar = nav.simulated && simMult != null && !arrived
        ? SimSpeedMultiplierBar(
            multiplier: simMult,
            onChanged: ref
                .read(navigationControllerProvider.notifier)
                .setSimSpeedMultiplier,
          )
        : null;

    final panel = progress == null
        ? null
        : NavBottomPanel(
            progress: progress,
            now: ref.read(navClockProvider)(),
            simulated: nav.simulated,
            floating: landscape,
            vehicleIcon: nav.query?.vehicle == RouteVehicle.motorcycle
                ? Icons.two_wheeler_rounded
                : Icons.directions_car_rounded,
            onEnd: _confirmEnd,
          );

    final zoomAndRecenter = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (follow != NavFollow.following) ...[
          RecenterButton(onPressed: _recenterTripCamera),
          const SizedBox(height: 10),
        ],
        // Mod mudah: tiada butang zum (cubit masih berfungsi); skrin lebih lapang.
        if (!easy)
          _MapZoomControls(
            onZoomIn: () => unawaited(_zoomMap(1)),
            onZoomOut: () => unawaited(_zoomMap(-1)),
          ),
      ],
    );
    final sideButtons = NavSideButtons(
      compact: easy,
      voiceEnabled: settings.voiceEnabled,
      cameraMode: settings.cameraMode,
      onToggleVoice: () => ref
          .read(navigationSettingsProvider.notifier)
          .setVoiceEnabled(!settings.voiceEnabled),
      onCycleCamera: _cycleCameraMode,
      onOverview: _showOverview,
      onSettings: () => showNavigationSettingsSheet(
        context,
        onShareEta: () => unawaited(_shareEta()),
        onEmergency: _openEmergency,
        onMusic: () => unawaited(showMusicSheet(context)),
      ),
      onReport: _openReport,
      onChangeRoute: _changeRoute,
    );

    if (landscape) {
      return [
        SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: metrics.bannerMaxWidth),
                child: banner,
              ),
            ),
          ),
        ),
        if (!arrived) ...[
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (simBar != null) ...[
                        simBar,
                        const SizedBox(height: 6),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ?speed,
                          if (speed != null) const SizedBox(width: 8),
                          if (panel != null) Expanded(child: panel),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    zoomAndRecenter,
                    const SizedBox(width: 8),
                    sideButtons,
                  ],
                ),
              ),
            ),
          ),
        ] else
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: ArrivalCard(onDone: stop, floating: true),
                ),
              ),
            ),
          ),
      ];
    }

    return [
      SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: metrics.bannerMaxWidth),
              child: banner,
            ),
          ),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (simBar != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                child: Align(alignment: Alignment.centerLeft, child: simBar),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ?speed,
                  const SizedBox(width: 12),
                  const Spacer(),
                  const SizedBox(width: 12),
                  if (!arrived)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        zoomAndRecenter,
                        const SizedBox(height: 8),
                        sideButtons,
                      ],
                    ),
                ],
              ),
            ),
            if (arrived)
              ArrivalCard(onDone: stop)
            else if (panel != null)
              panel
            else
              SizedBox(height: media.padding.bottom),
          ],
        ),
      ),
    ];
  }

  /// Sambungan bertitik dari hujung laluan (titik jalan yang disnap) ke destinasi sebenar bila ia
  /// berjauhan, supaya penanda destinasi tidak terapung di luar jalan tanpa kaitan dengan laluan.
  static List<GeoPoint> _finalLeg({GeoPoint? end, GeoPoint? destination}) {
    if (end == null || destination == null) return const [];
    return distanceMeters(end, destination) > 10
        ? [end, destination]
        : const [];
  }

  static List<MapRouteLine> _routeLines(RoutePreviewState state) {
    if (state is! RouteReady) return const [];
    return [
      // Alternatif dahulu, laluan terpilih terakhir (dilukis paling atas).
      for (var i = 0; i < state.visibleOptions.length; i++)
        if (i != state.selectedIndex)
          MapRouteLine(points: state.visibleOptions[i].points, isMain: false),
      MapRouteLine(points: state.selected.points, isMain: true),
    ];
  }

  static GeoPoint? _destination(RoutePreviewState state) => switch (state) {
    RouteReady() => state.query.destination,
    RouteFailed() => state.query.destination,
    RouteLocationUnavailable() => state.destination,
    RouteLoading() => state.destination,
    RouteIdle() => null,
  };
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    return PressScale(
      child: Material(
        color: fg.glassSurface,
        shape: CircleBorder(side: BorderSide(color: fg.glassBorder)),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        child: IconButton(
          tooltip: tooltip,
          onPressed: loading ? null : onPressed,
          icon: loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _MapZoomControls extends StatelessWidget {
  const _MapZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fg = context.fg;
    final theme = Theme.of(context);
    return Material(
      color: fg.glassSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: fg.glassBorder),
      ),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      child: SizedBox(
        width: 48,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l10n.mapZoomIn,
              onPressed: onZoomIn,
              icon: const Icon(Icons.add_rounded),
              color: theme.colorScheme.onSurface,
              visualDensity: VisualDensity.compact,
            ),
            Divider(
              height: 1,
              indent: 10,
              endIndent: 10,
              color: fg.glassBorder,
            ),
            IconButton(
              tooltip: l10n.mapZoomOut,
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove_rounded),
              color: theme.colorScheme.onSurface,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pil carian terapung. Mengetuknya membuka perancang perjalanan; [hint] (cara tekan-lama) dipaparkan
/// sebagai teks sekunder sehingga pengguna mencuba, kerana tekan-lama kekal cara pantas memilih titik.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.label, required this.onTap, this.hint});

  final String label;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: PressScale(
        scale: 0.985,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            // Tanpa BackdropFilter: kabur di atas pandangan peta asli dirender semula setiap kali peta
            // bergerak dan menjejaskan telefon lemah; permukaan kaca sudah separa lutsinar.
            child: Material(
              color: fg.glassSurface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: fg.glassBorder),
              ),
              child: InkWell(
                key: const ValueKey('search-pill'),
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: EasyModeScope.of(context) ? 60 : 48,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.search_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pemegang tempat semasa gaya peta dimuat (biasanya sudah siap oleh splash): latar tema dengan logo
/// yang berdenyut perlahan, bukan skrin kosong.
class _MapLoading extends StatefulWidget {
  const _MapLoading();

  @override
  State<_MapLoading> createState() => _MapLoadingState();
}

class _MapLoadingState extends State<_MapLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      key: const ValueKey('map-loading'),
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Opacity(
            opacity: 0.55 + 0.45 * Curves.easeInOut.transform(_pulse.value),
            child: child,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/branding/fgmap-app-icon.png',
              width: 72,
              height: 72,
              cacheWidth: 144,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sebab penjejak lokasi atau [IdleFollow] digantung sementara.
abstract final class _Suspend {
  static const background = 'background';
  static const navigation = 'navigation';
  static const route = 'route';
  static const cruise = 'cruise';
}
