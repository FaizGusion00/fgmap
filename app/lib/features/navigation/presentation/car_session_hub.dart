import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/geo.dart';
import '../../map/data/map_style_loader.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../domain/camera_planner.dart';
import '../domain/car_session.dart';
import '../domain/instruction_text.dart';
import 'cruise_controller.dart';
import 'navigation_controller.dart';

/// Saluran tunggal antara Flutter dan hos Android Auto.
const carSessionChannel = MethodChannel('com.fguniversal.fgmap/car');

/// Menerbitkan satu gambar sesi dan menerima carian, pusatkan, dan tamat dari skrin kereta.
class CarSessionHub {
  CarSessionHub(this.ref) {
    carSessionChannel.setMethodCallHandler(_onCall);
  }

  final Ref ref;
  CameraPose? _pose;
  bool _following = true;
  int _sentRouteVersion = -1;
  String? _sentStyleKey;
  bool _pushing = false;
  Timer? _throttle;

  void notePose(CameraPose pose, {required bool following}) {
    final nav = ref.read(navigationControllerProvider);
    final previous = _pose;
    _pose = pose;
    _following = following;
    // Semasa mengira semula atau belokan pantas: push lebih kerap supaya AA ikut telefon.
    final turning =
        previous != null && angleDelta(previous.bearing, pose.bearing).abs() > 2.5;
    final urgent = nav.rerouting || turning;
    _schedule(urgent ? const Duration(milliseconds: 60) : _defaultThrottle);
  }

  void publish() => _schedule(_defaultThrottle);

  /// Push serta-merta (resume / adopt / permukaan AA sedia). Membatalkan throttle tertunda.
  void flush() {
    _throttle?.cancel();
    _throttle = null;
    unawaited(_push());
  }

  static const _defaultThrottle = Duration(milliseconds: 200);

  Duration? _pendingDelay;

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
    if (_pushing) return;
    _pushing = true;
    try {
      final snapshot = _snapshot();
      final includeRoute = snapshot.routeVersion != _sentRouteVersion ||
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
    }
  }

  CarSessionSnapshot _snapshot() {
    final nav = ref.read(navigationControllerProvider);
    final cruise = ref.read(cruiseControllerProvider);
    final progress = nav.progress;
    final dark = _dark();
    final loaded = ref.read(mapStyleProvider(dark));
    final style = loaded is AsyncData<ResolvedMapStyle> ? loaded.value : null;
    final navigating = nav.isActive;
    final maneuver = progress?.next;
    final language = VoiceLanguage.fromCode(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    );
    final text = maneuver == null
        ? null
        : InstructionText(language).action(maneuver);
    final pose = navigating || cruise.active
        ? (_pose ??
              (progress == null
                  ? (cruise.point == null
                        ? null
                        : CameraPose(
                            center: cruise.point!,
                            zoom: 17,
                            tilt: 55,
                            bearing: cruise.bearing,
                          ))
                  : CameraPose(
                      center: progress.position,
                      zoom: 17,
                      tilt: 55,
                      bearing: progress.bearing,
                    )))
        : null;
    final now = ref.read(navClockProvider)();
    return mapCarSession(
      navigating: navigating,
      cruising: cruise.active,
      pose: pose,
      speedMps: navigating
          ? (progress?.speedMps ?? 0)
          : cruise.speedMps,
      limitKmh: navigating ? nav.currentLimitKmh : cruise.limitKmh,
      overspeed: navigating ? nav.overspeed : cruise.overspeed,
      navigationRoute: nav.route?.displayPolyline().points ?? const [],
      routeVersion: nav.routeVersion,
      maneuver: text,
      distanceToManeuverM: progress?.distanceToNextM,
      remainingM: progress?.remainingM,
      remainingS: progress?.remainingS.round(),
      etaEpochMs: progress == null
          ? null
          : now
                .add(Duration(seconds: progress.remainingS.round()))
                .millisecondsSinceEpoch,
      following: _following,
      dark: dark,
      style: style?.style ??
          (dark ? AppConfig.mapStyleDark : AppConfig.mapStyleLight),
      styleKey: style?.key ?? (dark ? 'dark' : 'light'),
    );
  }

  bool _dark() {
    final mode = ref.read(effectiveThemeModeProvider);
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return WidgetsBinding
            .instance
            .platformDispatcher
            .platformBrightness ==
        Brightness.dark;
  }

  Future<Object?> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'search':
        final query = (call.arguments as Map?)?['query']?.toString() ?? '';
        return _search(query);
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
      default:
        throw MissingPluginException(call.method);
    }
  }

  VoidCallback? _recenter;
  VoidCallback? _pan;

  void bindCamera({
    required VoidCallback recenter,
    required VoidCallback pan,
  }) {
    _recenter = recenter;
    _pan = pan;
  }

  Future<List<Map<String, Object?>>> _search(String query) async {
    final near = _near();
    try {
      final places = await ref
          .read(geocoderProvider)
          .search(query, near: near);
      return [
        for (final p in places)
          {
            'name': p.name,
            'subtitle': p.subtitle,
            'lat': p.point.lat,
            'lng': p.point.lng,
          },
      ];
    } on Object {
      return const [];
    }
  }

  GeoPoint? _near() {
    final nav = ref.read(navigationControllerProvider);
    final progress = nav.progress;
    if (progress != null) return progress.position;
    return ref.read(cruiseControllerProvider).point;
  }

  /// Merancang dan memulakan sesi navigasi yang sama dengan telefon.
  Future<String?> _openPlace(Place place) async {
    final origin = _near();
    if (origin == null) return 'no-location';
    final query = RouteQuery(
      origin: origin,
      destination: place.point,
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
      hub.flush();
    } else {
      hub.publish();
    }
  });
  ref.listen(cruiseControllerProvider, (_, _) => hub.publish());
  return hub;
});
