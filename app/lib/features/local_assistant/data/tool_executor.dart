import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../air_quality/domain/air_quality.dart';
import '../../air_quality/presentation/air_quality_controller.dart';
import '../../along_route/domain/along_route_category.dart';
import '../../along_route/domain/along_route_projector.dart';
import '../../along_route/presentation/along_route_controller.dart';
import '../../azan/domain/prayer.dart';
import '../../azan/presentation/azan_controller.dart';
import '../../cameras/data/awas_camera_store.dart';
import '../../cameras/domain/speed_camera.dart';
import '../../music/data/audius_repository.dart';
import '../../music/data/radio_browser_repository.dart';
import '../../music/domain/music_repository.dart';
import '../../music/presentation/player_controller.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../qibla/domain/qibla.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../../search/data/photon_geocoder.dart';
import '../../weather/data/open_meteo_client.dart';
import '../../weather/domain/weather_codes.dart';
import '../domain/assistant_tools.dart';
import 'wikipedia_client.dart';

/// Menjalankan alat pembantu terhadap ciri FGMaps sedia ada.
class AssistantToolExecutor {
  AssistantToolExecutor(this._ref);

  final Ref _ref;

  Future<Map<String, Object?>> run(
    String name,
    Map<String, Object?> args,
  ) async {
    if (!isKnownAssistantTool(name)) {
      return {'ok': false, 'error': 'unknown_tool'};
    }
    try {
      return switch (name) {
        'search_place' => await _searchPlace(_str(args, 'query')),
        'plan_route' => await _planRoute(
          _str(args, 'query'),
          avoidTolls: _bool(args, 'avoid_tolls'),
          avoidHighways: _bool(args, 'avoid_highways'),
        ),
        'get_air_quality' => await _airQuality(_str(args, 'query')),
        'get_weather' => await _weather(_str(args, 'query')),
        'get_qibla' => await _qibla(),
        'get_prayer_times' => _prayerTimes(),
        'play_radio' => await _playRadio(
          _str(args, 'query'),
          region: _str(args, 'region'),
        ),
        'play_music' => await _playMusic(_str(args, 'query')),
        'list_cameras_along_route' => await _cameras(),
        'list_along_route' => await _alongRoute(_str(args, 'category')),
        'wikipedia_summary' => await _wiki(
          _str(args, 'query'),
          lang: _str(args, 'lang'),
        ),
        _ => {'ok': false, 'error': 'unknown_tool'},
      };
    } on Object catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<Map<String, Object?>> _searchPlace(String? query) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final near = await _gps();
    final places = await _ref
        .read(geocoderProvider)
        .search(query.trim(), near: near);
    if (places.isEmpty) return {'ok': false, 'error': 'not_found'};
    final top = places.take(5).toList();
    return {
      'ok': true,
      'places': [
        for (final p in top)
          {
            'name': p.name,
            'subtitle': p.subtitle,
            'lat': p.point.lat,
            'lng': p.point.lng,
          },
      ],
    };
  }

  Future<Map<String, Object?>> _planRoute(
    String? query, {
    required bool avoidTolls,
    required bool avoidHighways,
  }) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final near = await _gps();
    final places = await _ref
        .read(geocoderProvider)
        .search(query.trim(), near: near);
    if (places.isEmpty) return {'ok': false, 'error': 'not_found'};
    final place = places.first;
    await _ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(place.point, destinationLabel: place.name);

    // Tunggu pratonton siap (atau gagal) sehingga ~20 s.
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final state = _ref.read(routePreviewControllerProvider);
      if (state is RouteReady) {
        var selected = state.selectedIndex;
        if (avoidTolls) {
          final i = state.options.indexWhere(
            (o) => o.label == RouteLabel.noTolls || !o.hasTolls,
          );
          if (i >= 0) {
            _ref.read(routePreviewControllerProvider.notifier).select(i);
            selected = i;
          }
        } else if (avoidHighways) {
          final i = state.options.indexWhere(
            (o) => o.label == RouteLabel.noHighways || !o.hasHighway,
          );
          if (i >= 0) {
            _ref.read(routePreviewControllerProvider.notifier).select(i);
            selected = i;
          }
        }
        final ready = _ref.read(routePreviewControllerProvider);
        final opt = ready is RouteReady
            ? ready.selected
            : state.options[selected.clamp(0, state.options.length - 1)];
        return {
          'ok': true,
          'destination': place.name,
          'lat': place.point.lat,
          'lng': place.point.lng,
          'distance_km': (opt.distanceM / 1000).toStringAsFixed(1),
          'duration_min': (opt.durationS / 60).round(),
          'has_tolls': opt.hasTolls,
          'label': opt.label.name,
          'note': 'Route preview opened. User taps Start to navigate.',
        };
      }
      if (state is RouteLocationUnavailable || state is RouteFailed) {
        return {'ok': false, 'error': 'route_failed'};
      }
    }
    return {'ok': false, 'error': 'route_timeout'};
  }

  Future<Map<String, Object?>> _airQuality(String? query) async {
    final ctrl = _ref.read(airQualityControllerProvider.notifier);
    if (query != null && query.trim().isNotEmpty) {
      final near = await _gps();
      final places = await _ref
          .read(geocoderProvider)
          .search(query.trim(), near: near);
      if (places.isEmpty) return {'ok': false, 'error': 'not_found'};
      await ctrl.loadAt(places.first.point, label: places.first.name);
    } else {
      await ctrl.loadHere();
    }
    final state = _ref.read(airQualityControllerProvider);
    if (state is! AirUiReady) {
      return {'ok': false, 'error': 'unavailable'};
    }
    final r = state.reading;
    return {
      'ok': true,
      'ipu': r.ipu,
      'band': r.band.name,
      'station': r.stationName,
      'distance_m': r.stationDistanceM.round(),
      'observed_at': r.observedAt?.toIso8601String(),
      'pollutant': r.pollutant?.name,
      'source': 'JAS APIMS',
    };
  }

  Future<Map<String, Object?>> _weather(String? query) async {
    GeoPoint? point = await _gps();
    String? label;
    if (query != null && query.trim().isNotEmpty) {
      final places = await _ref
          .read(geocoderProvider)
          .search(query.trim(), near: point);
      if (places.isEmpty) return {'ok': false, 'error': 'not_found'};
      point = places.first.point;
      label = places.first.name;
    }
    if (point == null) return {'ok': false, 'error': 'no_location'};
    final snap = await _ref
        .read(openMeteoClientProvider)
        .fetch(destination: point, destinationLabel: label);
    if (snap == null) return {'ok': false, 'error': 'unavailable'};
    final d = snap.destination;
    return {
      'ok': true,
      'place': label ?? 'here',
      'temp_c': d.tempC.round(),
      'feels_like_c': d.feelsLikeC?.round(),
      'weather': WeatherCodes.label(d.weatherCode, malay: false),
      'precip_prob': d.precipProb,
      'humidity_pct': d.humidityPct,
      'wind_kmh': d.windKmh?.round(),
      'source': 'Open-Meteo',
    };
  }

  Future<Map<String, Object?>> _qibla() async {
    final point = await _gps();
    if (point == null) return {'ok': false, 'error': 'no_location'};
    final bearing = qiblaBearingDegrees(point);
    final distKm = (geodesicInverse(point, kaaba).distanceM / 1000).round();
    return {'ok': true, 'bearing_deg': bearing.round(), 'distance_km': distKm};
  }

  Map<String, Object?> _prayerTimes() {
    final azan = _ref.read(azanControllerProvider);
    final today = azan.today;
    if (today == null) return {'ok': false, 'error': 'unavailable'};
    final times = <String, String>{};
    for (final p in Prayer.fardu) {
      final t = today.timeOf(p);
      if (t != null) {
        times[p.name] =
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
    }
    return {
      'ok': true,
      'official': today.isOfficial,
      'zone': today.zone,
      'times': times,
      'next': azan.next?.name,
      'next_at': azan.nextAt?.toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _playRadio(
    String? query, {
    String? region,
  }) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final reg = switch (region?.toLowerCase()) {
      'indonesia' => RadioRegion.indonesia,
      'japan' => RadioRegion.japan,
      'korea' => RadioRegion.korea,
      _ => RadioRegion.malaysia,
    };
    final stations = await _ref
        .read(radioRepositoryProvider)
        .stations(query: query.trim(), region: reg);
    if (stations.isEmpty) return {'ok': false, 'error': 'not_found'};
    final track = stations.first;
    await _ref.read(playerControllerProvider.notifier).playTrack(track);
    return {'ok': true, 'title': track.title, 'artist': track.artist};
  }

  Future<Map<String, Object?>> _playMusic(String? query) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final tracks = await _ref
        .read(audiusRepositoryProvider)
        .search(query.trim());
    if (tracks.isEmpty) return {'ok': false, 'error': 'not_found'};
    final track = tracks.first;
    await _ref
        .read(playerControllerProvider.notifier)
        .playTrack(track, queue: tracks.take(20).toList());
    return {'ok': true, 'title': track.title, 'artist': track.artist};
  }

  Future<Map<String, Object?>> _cameras() async {
    final points = _routePoints();
    if (points == null || points.length < 2) {
      return {'ok': false, 'error': 'no_route'};
    }
    final cams = await _ref.read(awasCameraStoreProvider).load();
    final hits = <Map<String, Object?>>[];
    for (final cam in cams) {
      final proj = projectOntoPolyline(points, cam.point);
      if (proj == null) continue;
      final corridor = cam.confidence == SpeedCameraConfidence.approx
          ? 700.0
          : 450.0;
      if (proj.crossTrackM.abs() > corridor) continue;
      hits.add({
        'name': cam.name,
        'along_km': (proj.alongM / 1000).toStringAsFixed(1),
        'type': cam.type,
      });
      if (hits.length >= 8) break;
    }
    hits.sort((a, b) {
      final aa = double.tryParse(a['along_km']?.toString() ?? '') ?? 0;
      final bb = double.tryParse(b['along_km']?.toString() ?? '') ?? 0;
      return aa.compareTo(bb);
    });
    return {'ok': true, 'count': hits.length, 'cameras': hits};
  }

  Future<Map<String, Object?>> _alongRoute(String? category) async {
    final points = _routePoints();
    if (points == null || points.length < 2) {
      return {'ok': false, 'error': 'no_route'};
    }
    final cat = switch (category?.toLowerCase()) {
      'fuel' => AlongRouteCategory.fuel,
      'ev' || 'ev_charging' => AlongRouteCategory.evCharging,
      'mosque' => AlongRouteCategory.mosque,
      'toilets' || 'toilet' => AlongRouteCategory.toilets,
      _ => AlongRouteCategory.restArea,
    };
    // Guna RouteOption sementara dari titik laluan aktif/pratonton.
    final preview = _ref.read(routePreviewControllerProvider);
    final nav = _ref.read(navigationControllerProvider);
    final RouteOption? route = switch (preview) {
      RouteReady(:final selected) => selected,
      _ => nav.route?.option,
    };
    if (route == null) return {'ok': false, 'error': 'no_route'};
    await _ref
        .read(alongRouteControllerProvider.notifier)
        .loadForRoute(route, category: cat);
    final state = _ref.read(alongRouteControllerProvider);
    final pois = state.pois
        .take(8)
        .map(
          (p) => {
            'name': p.name,
            'along_km': (p.alongM / 1000).toStringAsFixed(1),
          },
        )
        .toList();
    return {
      'ok': true,
      'category': cat.name,
      'count': pois.length,
      'places': pois,
    };
  }

  Future<Map<String, Object?>> _wiki(String? query, {String? lang}) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final code = lang == 'en' ? 'en' : 'ms';
    final text = await _ref
        .read(wikipediaClientProvider)
        .summary(query.trim(), lang: code);
    if (text == null) return {'ok': false, 'error': 'not_found'};
    return {'ok': true, 'summary': text};
  }

  List<GeoPoint>? _routePoints() {
    final nav = _ref.read(navigationControllerProvider);
    if (nav.isActive && nav.route != null) return nav.route!.points;
    final preview = _ref.read(routePreviewControllerProvider);
    if (preview is RouteReady) return preview.selected.points;
    return null;
  }

  Future<GeoPoint?> _gps() async {
    try {
      final fix = await _ref
          .read(locationServiceProvider)
          .currentFix(
            timeout: const Duration(seconds: 4),
            maxAccuracyMeters: 500,
            fallbackAccuracyMeters: 5000,
          );
      if (fix != null) return fix.point;
      return (await _ref.read(locationServiceProvider).lastKnownFix())?.point;
    } on Object {
      return null;
    }
  }

  static String? _str(Map<String, Object?> args, String key) {
    final v = args[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static bool _bool(Map<String, Object?> args, String key) {
    final v = args[key];
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return false;
  }
}

final assistantToolExecutorProvider = Provider(
  (ref) => AssistantToolExecutor(ref),
);
