import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

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
import '../../route_preview/presentation/route_preview_controller.dart';
import '../../route_preview/presentation/route_summary_sheet.dart';
import '../../offline_maps/presentation/offline_maps_sheet.dart';
import '../../search/domain/location_link.dart';
import '../../search/presentation/trip_planner_page.dart';
import '../../settings/presentation/appearance_sheet.dart';
import '../../navigation/data/location_sources.dart';
import '../../navigation/data/navigation_settings.dart';
import '../../navigation/domain/camera_planner.dart';
import '../../navigation/domain/instruction_text.dart';
import '../../navigation/domain/nav_route.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../navigation/presentation/navigation_frame_driver.dart';
import '../../navigation/presentation/navigation_hud.dart';
import '../../navigation/presentation/navigation_settings_sheet.dart';
import 'location_prompt.dart';
import 'map_view.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    _ticker?.dispose();
    _driver?.dispose();
    unawaited(_linkSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pengguna mungkin menukar kebenaran di Tetapan sistem lalu kembali.
    if (state == AppLifecycleState.resumed) {
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

  /// Pada pelancaran, hanya gunakan lokasi jika kebenaran sudah diberi. Minta kebenaran apabila
  /// pengguna sendiri memilih tindakan yang memerlukan lokasi.
  Future<void> _handleStartupLocation() async {
    if (_startupLocationHandled || !mounted) return;
    _startupLocationHandled = true;

    final access = await ref.read(locationServiceProvider).access();
    if (access == LocationAccess.granted) await _flyToUser();
  }

  Future<void> _flyToUser({bool showFailure = false}) async {
    final fix = await ref
        .read(locationServiceProvider)
        .currentFix(timeout: const Duration(seconds: 12));
    if (!mounted || (!showFailure && _incomingLocationReceived)) return;
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
    if (ref.read(navigationControllerProvider).isActive) {
      _driver?.userInteracted();
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
  Future<void> _openPlanner() async {
    final near = _cameraCenterOrDefault();
    final selection = await TripPlannerPage.open(context, near: near);
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

    final near = _cameraCenterOrDefault();
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

  // Bentuk laluan baki yang dihantar ke peta. Disimpan supaya identiti senarai stabil antara
  // pembinaan semula (peta hanya dikemas kini bila senarai berubah) dan hanya dikira semula apabila
  // kenderaan telah bergerak cukup jauh.
  List<GeoPoint> _shape = const [];
  double _shapeAlong = -1000;
  int _shapeVersion = -1;

  void _onNavigationChanged(NavigationState? prev, NavigationState next) {
    final wasActive = prev?.isActive ?? false;
    if (next.isActive && !wasActive) unawaited(_beginDriving());
    if (!next.isActive && wasActive) _endDriving();
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
    _shapeVersion = -1;
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
          ready.query,
          uiLanguage: uiLanguage,
          source: simulate ? routeSimulation(NavRoute(route)) : null,
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
        media.padding.top + 220,
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

  List<MapRouteLine> _navigationLines(NavigationState nav) {
    final route = nav.route;
    if (route == null) return const [];
    final along = nav.progress?.alongM ?? 0;
    if (nav.routeVersion != _shapeVersion ||
        (along - _shapeAlong).abs() >= 15) {
      _shape = route.remainingShape(along);
      _shapeAlong = along;
      _shapeVersion = nav.routeVersion;
    }
    return [MapRouteLine(points: _shape, isMain: true)];
  }

  GeoPoint _cameraCenterOrDefault() {
    // Kawalan kamera sudah tersedia pada masa pengguna menekan lama (peta telah dipaparkan).
    return _readyCamera?.center ?? AppConfig.initialCenter;
  }

  MapCameraController? _readyCamera;

  void _onMapReady(MapCameraController controller) {
    _readyCamera = controller;
    if (!_camera.isCompleted) _camera.complete(controller);
  }

  Future<void> _fitRoute(List<GeoPoint> points) async {
    final camera = await _camera.future;
    if (!mounted) return;
    final media = MediaQuery.of(context);
    await camera.fitTo(
      points,
      padding: EdgeInsets.fromLTRB(
        40,
        media.padding.top + 80,
        40,
        300 + media.padding.bottom,
      ),
    );
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
    final mapIsDark = switch (themeSettings.mode) {
      ThemeMode.light => false,
      ThemeMode.dark => true,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };

    ref.listen<NavigationState>(
      navigationControllerProvider,
      _onNavigationChanged,
    );

    ref.listen<RoutePreviewState>(routePreviewControllerProvider, (prev, next) {
      // Muatkan laluan dalam pandangan hanya bila set pilihan baharu tiba, bukan bila pengguna
      // sekadar bertukar antara laluan yang sama.
      if (next is RouteReady &&
          (prev is! RouteReady || !identical(prev.options, next.options))) {
        _fitRoute(next.selected.points);
      }
    });

    final sheetVisible = state is! RouteIdle;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    final config = MapViewConfig(
      styleUrl: mapIsDark ? AppConfig.mapStyleDark : AppConfig.mapStyleLight,
      initialCenter: AppConfig.initialCenter,
      initialZoom: AppConfig.initialZoom,
      routes: navigating ? _navigationLines(nav) : _routeLines(state),
      destination: navigating ? nav.query?.destination : _destination(state),
      showUserLocation: access == LocationAccess.granted && !navigating,
      colors: MapOverlayColors(
        mainRoute: fg.routeMain,
        routeCasing: fg.routeCasing,
        alternativeRoute: fg.routeAlternative,
        destination: fg.destination,
        vehicle: theme.colorScheme.primary,
      ),
      onLongPress: navigating ? (_) {} : _onLongPress,
      onReady: _onMapReady,
      onUserGesture: navigating ? _driver?.userInteracted : null,
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ref.watch(mapViewBuilderProvider)(context, config),
          ),
          if (!navigating)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GlassIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: l10n.appearanceTooltip,
                      onPressed: () => showAppearanceSheet(context),
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
                            _MapZoomControls(
                              onZoomIn: () => unawaited(_zoomMap(1)),
                              onZoomOut: () => unawaited(_zoomMap(-1)),
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
                  if (state is RouteReady)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: NavStartBar(
                        onStart: () => _startNavigation(state, simulate: false),
                        onSimulate: () =>
                            _startNavigation(state, simulate: true),
                      ),
                    ),
                  AnimatedSwitcher(
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
                            onSelect: controller.select,
                            onAvoidTollsChanged: controller.setAvoidTolls,
                            onRetry: controller.retry,
                            onClear: controller.clear,
                            onOpenOfflineMaps: () =>
                                showOfflineMapsSheet(context),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-sheet')),
                  ),
                ],
              ),
            ),
          if (navigating) ..._navigationOverlay(nav, navSettings),
        ],
      ),
    );
  }

  /// Lapisan HUD navigasi: kad manuver di atas, kelajuan dan butang pusatkan, panel perjalanan di bawah.
  List<Widget> _navigationOverlay(
    NavigationState nav,
    NavigationSettings settings,
  ) {
    final progress = nav.progress;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final follow = _driver?.follow.value ?? NavFollow.following;
    final arrived = nav.phase == NavPhase.arrived;
    final stop = ref.read(navigationControllerProvider.notifier).stop;

    return [
      SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (progress != null && !arrived)
                    ManeuverBanner(progress: progress),
                  NavStatusChip(state: nav),
                ],
              ),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (progress != null && !arrived)
                    SpeedBubble(speedMps: progress.speedMps),
                  const SizedBox(width: 12),
                  const Spacer(),
                  const SizedBox(width: 12),
                  if (!arrived)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (follow != NavFollow.following) ...[
                          RecenterButton(onPressed: () => _driver?.recenter()),
                          const SizedBox(height: 12),
                        ],
                        _MapZoomControls(
                          onZoomIn: () => unawaited(_zoomMap(1)),
                          onZoomOut: () => unawaited(_zoomMap(-1)),
                        ),
                        const SizedBox(height: 8),
                        NavSideButtons(
                          voiceEnabled: settings.voiceEnabled,
                          cameraMode: settings.cameraMode,
                          onToggleVoice: () => ref
                              .read(navigationSettingsProvider.notifier)
                              .setVoiceEnabled(!settings.voiceEnabled),
                          onCycleCamera: _cycleCameraMode,
                          onOverview: _showOverview,
                          onSettings: () =>
                              showNavigationSettingsSheet(context),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (arrived)
              ArrivalCard(onDone: stop)
            else if (progress != null)
              NavBottomPanel(
                progress: progress,
                now: ref.read(navClockProvider)(),
                simulated: nav.simulated,
                onEnd: _confirmEnd,
              )
            else
              SizedBox(height: bottomSafe),
          ],
        ),
      ),
    ];
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
      ),
    );
  }
}
