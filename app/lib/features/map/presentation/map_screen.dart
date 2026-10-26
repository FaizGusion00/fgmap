import 'dart:async';
import 'dart:math' as math;

import 'package:app_links/app_links.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/location/location_service.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/theme/motion.dart';
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
import '../../settings/presentation/settings_sheet.dart';
import '../../navigation/data/location_sources.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/domain/camera_planner.dart';
import '../../navigation/domain/instruction_text.dart';
import '../../navigation/domain/nav_route.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../navigation/presentation/navigation_frame_driver.dart';
import '../../navigation/presentation/navigation_hud.dart';
import '../../navigation/presentation/car/car_mesh.dart' show VehicleKind;
import '../../navigation/presentation/car/car_renderer.dart';
import '../../navigation/presentation/car/vehicle_overlay.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import 'idle_follow.dart';
import 'location_prompt.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../search/domain/place.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../../reports/domain/report.dart';
import '../../reports/presentation/report_alerts_controller.dart';
import '../../reports/presentation/report_sheet.dart';
import '../../reports/presentation/reports_controller.dart';
import '../data/map_style_loader.dart';
import 'map_view.dart';
import 'nav_route_line.dart';
import 'user_location.dart';

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
    WidgetsBinding.instance.addObserver(this);
    _tracker.location.addListener(_feedSunLocation);
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_openSharedLocation(uri)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Incoming location link failed: $error');
      },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _handleStartupLocation(),
    );
  }

  /// Menyimpan lokasi terakhir untuk mod tema matahari (hanya berubah jika berpindah jauh).
  void _feedSunLocation() {
    final location = _tracker.location.value;
    if (location == null || location.stale || !mounted) return;
    ref.read(sunLocationProvider.notifier).update(location.point);
  }

  @override
  void dispose() {
    _tracker.location.removeListener(_feedSunLocation);
    _idle.dispose();
    _tracker.dispose();
    _ticker?.dispose();
    _driver?.dispose();
    unawaited(_linkSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Di latar belakang tanpa navigasi, peta tidak kelihatan: lepaskan GPS.
      _backgroundedAt = DateTime.now();
      _tracker.suspend(_Suspend.background);
    }
    // Pengguna mungkin menukar kebenaran di Tetapan sistem lalu kembali.
    if (state == AppLifecycleState.resumed) {
      // Kedudukan lama ditandakan lapuk dan penapis dimulakan semula: pengguna mungkin sudah berpindah.
      _tracker.resume(_Suspend.background);
      unawaited(_recenterAfterBackground());
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

    _tracker.start();
    await _centerOnUser();
    // Selepas itu kamera terus mengikut pengguna sehingga mereka menggerakkan peta sendiri.
    if (mounted && !_incomingLocationReceived) _idle.engage();
  }

  /// Navigasi memiliki kamera sepenuhnya. Semua operasi tak segerak yang menggerakkan kamera
  /// (menunggu GPS sehingga 12 s, menunggu peta siap) mesti menyemak ini SELEPAS setiap `await`;
  /// jika tidak, ia boleh menerbangkan kamera ke lokasi sebenar di tengah navigasi dan melawan
  /// pemacu bingkai.
  bool get _navigationOwnsCamera =>
      ref.read(navigationControllerProvider).isActive;

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
    if (ref.read(navigationControllerProvider).isActive) {
      driver?.userInteracted();
    }
    await camera.zoomBy(amount);
  }

  Future<void> _onMyLocationPressed() async {
    if (_locating) return;
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

  void _onLongPress(GeoPoint point) {
    HapticFeedback.mediumImpact();
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
              options: Options(followRedirects: true, maxRedirects: 5),
            );
        final resolved = response.realUri;
        if (_isSupportedMapLink(resolved)) {
          shared = sharedLocationFromUri(resolved);
        }
      } on DioException catch (error) {
        debugPrint('Shared map link could not be resolved: ${error.type.name}');
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

  // Laluan navigasi aktif untuk peta: dibina sekali setiap laluan (re-route menggantinya) dan dipangkas
  // di permulaan oleh peta mengikut kedudukan kenderaan.
  NavRouteLine? _navLine;

  NavRouteLine? _navLineFor(NavigationState nav) {
    final route = nav.route;
    if (route == null) return null;
    final current = _navLine;
    if (current != null && current.version == nav.routeVersion) return current;
    return _navLine = NavRouteLine(
      points: route.points,
      cumulativeM: route.cum,
      version: nav.routeVersion,
    );
  }

  void _onNavigationChanged(NavigationState? prev, NavigationState next) {
    final wasActive = prev?.isActive ?? false;
    if (next.isActive && !wasActive) {
      _tracker.suspend(_Suspend.navigation);
      _idle.suspend(_Suspend.navigation);
      unawaited(_beginDriving());
    }
    if (!next.isActive && wasActive) {
      _endDriving();
      _idle.resume(_Suspend.navigation);
      _tracker.resume(_Suspend.navigation);
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
      viewportHeight: () => MediaQuery.sizeOf(context).height,
      screenOffset: () => carScreenOffsetFor(MediaQuery.sizeOf(context)),
      viewportWidth: () => MediaQuery.sizeOf(context).width,
      cameraMode: () => ref.read(navigationSettingsProvider).cameraMode,
      clock: ref.read(navClockProvider),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
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
    }
    final route = ready.selected;
    await ref
        .read(navigationControllerProvider.notifier)
        .start(
          route,
          ready.selectedQuery,
          uiLanguage: uiLanguage,
          source: simulate
              ? routeSimulation(
                  NavRoute(route),
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
        (ready.options.length > 1 ? 420.0 : 360.0) *
        media.textScaler.scale(1).clamp(1.0, 1.4);
    await camera.fitTo(
      [for (final option in ready.options) ...option.points],
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
    if (state is! RouteReady || state.options.length < 2) return;
    final index = nearestRouteIndex(
      [for (final o in state.options) o.points],
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
    unawaited(HapticFeedback.selectionClick());
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

  void _selectRoute(int index) {
    HapticFeedback.selectionClick();
    ref.read(routePreviewControllerProvider.notifier).select(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = context.fg;
    final l10n = AppLocalizations.of(context);
    final themeSettings = ref.watch(themeControllerProvider);
    final state = ref.watch(routePreviewControllerProvider);
    final access = ref.watch(locationAccessProvider);
    final controller = ref.read(routePreviewControllerProvider.notifier);
    final nav = ref.watch(navigationControllerProvider);
    final navSettings = ref.watch(navigationSettingsProvider);
    final navigating = nav.isActive;
    // Kenderaan yang dipilih (kereta/motosikal): sama dengan yang digunakan untuk mengira laluan.
    final vehicle = navigating
        ? (nav.query?.vehicle ?? ref.watch(routeVehicleProvider))
        : ref.watch(routeVehicleProvider);
    final vehicleKind = vehicle == RouteVehicle.motorcycle
        ? VehicleKind.motorcycle
        : VehicleKind.car;
    final mapIsDark = switch (themeSettings.mode) {
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.sun => ref.watch(sunDarkProvider),
      AppThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    ref.listen<NavigationState>(
      navigationControllerProvider,
      _onNavigationChanged,
    );

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
        if (prev is! RouteIdle && _idle.following) unawaited(_flyToUser());
      } else {
        _idle.suspend(_Suspend.route);
      }
      // Muatkan laluan dalam pandangan hanya bila set pilihan baharu tiba, bukan bila pengguna
      // sekadar bertukar antara laluan yang sama.
      if (next is RouteReady &&
          (prev is! RouteReady || !identical(prev.options, next.options))) {
        unawaited(_fitRoutes(next));
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
      initialCenter: AppConfig.initialCenter,
      initialZoom: AppConfig.initialZoom,
      routes: navigating ? const [] : _routeLines(state),
      navRoute: navigating ? _navLineFor(nav) : null,
      navAlong: navigating ? _driver?.routeAlong : null,
      finalLeg: _finalLeg(
        end: navigating
            ? nav.route?.points.last
            : (state is RouteReady ? state.selected.points.last : null),
        destination: navigating ? nav.query?.destination : _destination(state),
      ),
      destination: navigating ? nav.query?.destination : _destination(state),
      showUserLocation: access == LocationAccess.granted && !navigating,
      userLocation: _tracker.location,
      showCompass: !navigating,
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
      onUserGesture: navigating ? _driver?.userInteracted : _idle.release,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: style == null
                ? ColoredBox(color: theme.scaffoldBackgroundColor)
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
                        onAssign: (kind) =>
                            unawaited(_openPlanner(assign: kind)),
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
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: Motion.of(context, Motion.normal),
                      switchInCurve: Motion.enter,
                      switchOutCurve: Motion.exit,
                      transitionBuilder: (child, animation) => SlideTransition(
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
                                  ? () =>
                                        _startNavigation(state, simulate: false)
                                  : null,
                              onSimulate: state is RouteReady
                                  ? () =>
                                        _startNavigation(state, simulate: true)
                                  : null,
                            )
                          : const SizedBox.shrink(key: ValueKey('no-sheet')),
                    ),
                  ),
                ],
              ),
            ),
          if (navigating) ..._navigationOverlay(nav, navSettings),
        ],
      ),
    );
  }

  /// Lapisan HUD navigasi. Potret: kad manuver di atas, kelajuan dan butang di atas panel perjalanan.
  /// Mendatar: kad manuver dan panel di sebelah kiri, butang di sebelah kanan, dan bahagian tengah
  /// dibiarkan kosong supaya kereta dan jalan di hadapan tidak terlindung.
  List<Widget> _navigationOverlay(
    NavigationState nav,
    NavigationSettings settings,
  ) {
    final progress = nav.progress;
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final metrics = NavHudMetrics.forSize(media.size);
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
      ],
    );

    final speed = progress != null && !arrived
        ? SpeedBubble(
            speedMps: progress.speedMps,
            limitKmh: nav.currentLimitKmh,
            overspeed: nav.overspeed,
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
          RecenterButton(onPressed: () => _driver?.recenter()),
          const SizedBox(height: 10),
        ],
        _MapZoomControls(
          onZoomIn: () => unawaited(_zoomMap(1)),
          onZoomOut: () => unawaited(_zoomMap(-1)),
        ),
      ],
    );
    final sideButtons = NavSideButtons(
      voiceEnabled: settings.voiceEnabled,
      cameraMode: settings.cameraMode,
      onToggleVoice: () => ref
          .read(navigationSettingsProvider.notifier)
          .setVoiceEnabled(!settings.voiceEnabled),
      onCycleCamera: _cycleCameraMode,
      onOverview: _showOverview,
      onSettings: () => showNavigationSettingsSheet(context),
      onReport: _openReport,
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ?speed,
                      if (speed != null) const SizedBox(width: 8),
                      if (panel != null) Expanded(child: panel),
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
      for (var i = 0; i < state.options.length; i++)
        if (i != state.selectedIndex)
          MapRouteLine(points: state.options[i].points, isMain: false),
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
    return Material(
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
                constraints: const BoxConstraints(minHeight: 48),
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
    );
  }
}

/// Sebab penjejak lokasi atau [IdleFollow] digantung sementara.
abstract final class _Suspend {
  static const background = 'background';
  static const navigation = 'navigation';
  static const route = 'route';
}
