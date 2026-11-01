import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/network/connectivity_probe.dart';
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
import '../../route_preview/domain/route_preference.dart';
import '../../route_preview/domain/route_scoring.dart';
import '../../route_preview/domain/routing_failure.dart';
import '../../route_preview/domain/toll.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../../search/data/nearby_search.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/nearby_category.dart';
import '../../search/domain/place.dart';
import '../../search/domain/place_query_expand.dart';
import '../../search/domain/place_ranker.dart';
import '../../weather/data/open_meteo_client.dart';
import '../../weather/domain/weather_codes.dart';
import '../domain/assistant_tools.dart';
import '../presentation/ai_map_bridge.dart';
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
        'search_place' => await searchPlace(_str(args, 'query')),
        'plan_route' => await planRoute(
          _str(args, 'query'),
          preference: _preference(args),
          start: _bool(args, 'start'),
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
      return {'ok': false, 'error': networkErrorCode(e) ?? e.toString()};
    }
  }

  /// Kedudukan GPS semasa (+ nama tempat jika geokod songsang berjaya).
  /// Berfungsi luar talian untuk koordinat; nama tempat mungkin tiada tanpa internet.
  Future<Map<String, Object?>> currentLocation() async {
    final here = await _gps();
    if (here == null) return {'ok': false, 'error': 'no_location'};
    String? place;
    try {
      final reverse = _ref.read(reverseGeocoderProvider);
      final hit = await reverse.reverse(here);
      place = hit == null
          ? null
          : [
              hit.name,
              if (hit.subtitle.isNotEmpty) hit.subtitle.split(',').first.trim(),
            ].where((s) => s.isNotEmpty).join(', ');
    } on Object {
      // GPS kekal berguna walaupun songsang gagal (luar talian / flaky).
    }
    return {
      'ok': true,
      'lat': here.lat,
      'lng': here.lng,
      if (place != null && place.isNotEmpty) 'place': place,
      'source': 'gps',
    };
  }

  Future<bool> _online() => _ref.read(onlineProbeProvider)();

  /// Cari [query] dengan varian ejaan ("attaufiqiah" -> "at taufiqiah") dan SATU ulangan untuk ralat sementara.
  /// Hasil disusun [PlaceRanker] (nama + jarak) dan bukan sekadar yang pertama daripada pelayan.
  /// Ralat tidak ditelan: dipulangkan supaya pemanggil memberi mesej yang betul (luar talian / sibuk / perlahan).
  Future<({List<Place> places, Object? error})> _findPlaces(
    String query,
    GeoPoint? near, {
    required bool online,
  }) async {
    final geocoder = _ref.read(geocoderProvider);
    for (final variant in placeQueryVariants(query)) {
      for (var attempt = 0; ; attempt++) {
        try {
          final found = await geocoder.search(variant, near: near);
          if (found.isEmpty) break; // cuba varian seterusnya
          return (
            places: const PlaceRanker().rank(
              found,
              variant,
              near: near,
              maxResults: 8,
            ),
            error: null,
          );
        } on Object catch (e) {
          if (online && attempt == 0 && isTransientNetworkError(e)) {
            await Future<void>.delayed(const Duration(milliseconds: 700));
            continue;
          }
          return (places: const <Place>[], error: e);
        }
      }
    }
    return (places: const <Place>[], error: null);
  }

  Future<Map<String, Object?>> searchPlace(String? query) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final q = query.trim();
    final near = await _gps();
    final online = await _online();
    final found = await _findPlaces(q, near, online: online);
    final error = found.error;
    if (error != null) {
      return {
        'ok': false,
        'error': networkErrorCode(error, online: online) ?? 'search_failed',
        'query': q,
      };
    }
    if (found.places.isEmpty) {
      return {
        'ok': false,
        'error': online ? 'not_found' : 'offline_not_found',
        'query': q,
      };
    }
    return {
      'ok': true,
      'places': [
        for (final p in found.places.take(5))
          {
            'name': p.name,
            'subtitle': p.subtitle,
            'lat': p.point.lat,
            'lng': p.point.lng,
            if (near != null)
              'distance_km': double.parse(
                (distanceMeters(near, p.point) / 1000).toStringAsFixed(1),
              ),
          },
      ],
    };
  }

  /// Rancang laluan ke [query] dan pilih pilihan yang sepadan dengan [preference]. Dengan [start],
  /// minta peta memulakan navigasi terus (tanpa bertanya lagi).
  Future<Map<String, Object?>> planRoute(
    String? query, {
    RoutePreference preference = RoutePreference.recommended,
    bool start = false,
  }) async {
    if (query == null || query.trim().isEmpty) {
      return {'ok': false, 'error': 'missing_query'};
    }
    final q = query.trim();
    final near = await _gps();
    final online = await _online();
    final found = await _findPlaces(q, near, online: online);
    final error = found.error;
    if (error != null) {
      return {
        'ok': false,
        'error': networkErrorCode(error, online: online) ?? 'search_failed',
        'query': q,
      };
    }
    if (found.places.isEmpty) {
      return {
        'ok': false,
        'error': online ? 'not_found' : 'offline_not_found',
        'query': q,
      };
    }
    final place = found.places.first;
    await _ref
        .read(routePreviewControllerProvider.notifier)
        .planTo(place.point, destinationLabel: place.name);

    final ready = await _awaitRoute(
      // Pilihan selain "Disyorkan" perlu calon tambahan (cth. tanpa tol) yang tiba kemudian.
      waitForAll: preference != RoutePreference.recommended,
      waitForTolls: preference == RoutePreference.cheapest,
    );
    if (ready == null) {
      return {
        'ok': false,
        'error': routeFailureCode(
          _ref.read(routePreviewControllerProvider),
          online: await _online(),
        ),
        'destination': place.name,
        'query': q,
      };
    }
    var choice = chooseRoute(ready.options, preference, tolls: ready.tolls);
    var base = ready;
    final strict = await _replanIfUnmet(preference, choice);
    if (strict != null) {
      base = strict;
      choice = chooseRoute(base.options, preference, tolls: base.tolls);
    }
    final ctrl = _ref.read(routePreviewControllerProvider.notifier);
    if (choice.index != base.selectedIndex) ctrl.select(choice.index);
    final current = _ref.read(routePreviewControllerProvider);
    final chosen = current is RouteReady ? current : base;
    if (start) _ref.read(aiMapRequestProvider.notifier).startNavigation();
    return {
      'ok': true,
      'destination': place.name,
      'destination_area': place.subtitle,
      'lat': place.point.lat,
      'lng': place.point.lng,
      ..._optionSummary(chosen.selected, chosen.tollOf(chosen.selected)),
      'reason': choice.reason.name,
      'options_count': chosen.options.length,
      'alternatives': [
        for (final o in chosen.options.take(3))
          if (!identical(o, chosen.selected))
            _optionSummary(o, chosen.tollOf(o)),
      ],
      'navigation_started': start,
    };
  }

  /// Tukar pilihan pada laluan yang sedang dipratonton ("tanpa tol", "paling selamat").
  Future<Map<String, Object?>> chooseCurrentRoute(
    RoutePreference preference, {
    bool start = false,
  }) async {
    final state = _ref.read(routePreviewControllerProvider);
    if (state is! RouteReady) return {'ok': false, 'error': 'no_route'};
    final ready = state.loadingMore
        ? await _awaitRoute(
                waitForAll: true,
                waitForTolls: preference == RoutePreference.cheapest,
              ) ??
              state
        : state;
    var choice = chooseRoute(ready.options, preference, tolls: ready.tolls);
    var base = ready;
    final strict = await _replanIfUnmet(preference, choice);
    if (strict != null) {
      base = strict;
      choice = chooseRoute(base.options, preference, tolls: base.tolls);
    }
    _ref.read(routePreviewControllerProvider.notifier).select(choice.index);
    final now = _ref.read(routePreviewControllerProvider);
    final chosen = now is RouteReady ? now : base;
    if (start) _ref.read(aiMapRequestProvider.notifier).startNavigation();
    return {
      'ok': true,
      'destination': chosen.query.destinationLabel,
      ..._optionSummary(chosen.selected, chosen.tollOf(chosen.selected)),
      'reason': choice.reason.name,
      'navigation_started': start,
    };
  }

  /// Pilihan sedia ada tidak memenuhi kehendak tegas ("tanpa tol" tetapi semua bertol; "elak lebuh
  /// raya" tetapi semua melaluinya): minta laluan dengan kehendak itu terus daripada enjin laluan,
  /// bukan bergantung pada calon tambahan yang mungkin gagal di pelayan awam. Jika enjin tetap
  /// memberi laluan bertol (tiada jalan lain), jawapan melaporkannya dengan jujur.
  Future<RouteReady?> _replanIfUnmet(
    RoutePreference preference,
    RouteChoice choice,
  ) async {
    final unmet = switch (preference) {
      RoutePreference.noTolls => choice.reason == RouteChoiceReason.fewestTolls,
      RoutePreference.noHighways =>
        choice.reason != RouteChoiceReason.noHighways,
      _ => false,
    };
    if (!unmet) return null;
    final ctrl = _ref.read(routePreviewControllerProvider.notifier);
    if (preference == RoutePreference.noTolls) {
      // Larangan mutlak dahulu (laluan tanpa tol sebenar, mungkin jauh lebih panjang); jika tiada
      // jalan tanpa tol langsung (cth. ke pulau), jatuh kepada keutamaan lembut.
      await ctrl.replanWith(avoidTolls: true, excludeTolls: true);
      final strict = await _awaitRoute();
      if (strict != null) return strict;
      await ctrl.replanWith(avoidTolls: true, excludeTolls: false);
      return _awaitRoute();
    }
    await ctrl.replanWith(avoidHighways: true);
    return _awaitRoute();
  }

  static Map<String, Object?> _optionSummary(RouteOption o, TollEstimate? t) =>
      {
        'distance_km': double.parse((o.distanceM / 1000).toStringAsFixed(1)),
        'duration_min': (o.durationS / 60).round(),
        'has_tolls': o.hasTolls,
        if (t != null && t.knownRm > 0) 'toll_rm': t.knownRm,
        if (t != null && t.isPartial) 'toll_partial': true,
        'turns': turnCountOf(o),
        'via': o.via,
        'label': o.label.name,
      };

  /// Tunggu pratonton siap melalui pendengar (bukan tinjauan). [waitForAll]: tunggu calon tambahan
  /// juga (paling lama ~8 s selepas laluan pertama); [waitForTolls]: tunggu anggaran tol.
  Future<RouteReady?> _awaitRoute({
    bool waitForAll = false,
    bool waitForTolls = false,
  }) async {
    bool done(RoutePreviewState s) {
      if (s is! RouteReady) return false;
      if (waitForAll && s.loadingMore) return false;
      if (waitForTolls &&
          s.options.any((o) => o.hasTolls && s.tollOf(o) == null)) {
        return false;
      }
      return true;
    }

    bool failed(RoutePreviewState s) =>
        s is RouteFailed || s is RouteLocationUnavailable || s is RouteIdle;

    final first = Completer<void>();
    final complete = Completer<RouteReady?>();
    final sub = _ref.listen<RoutePreviewState>(routePreviewControllerProvider, (
      _,
      next,
    ) {
      if (next is RouteReady && !first.isCompleted) first.complete();
      if (complete.isCompleted) return;
      if (next is RouteReady && done(next)) complete.complete(next);
      if (failed(next)) complete.complete(null);
    }, fireImmediately: true);
    // Pemasa boleh dibatalkan (bukan Future.delayed): tidak tertinggal 15 s selepas laluan siap.
    final firstDeadline = Completer<void>();
    final deadlineTimer = Timer(const Duration(seconds: 15), () {
      if (!firstDeadline.isCompleted) firstDeadline.complete();
    });
    try {
      // Laluan pertama: sehingga 15 s (pelayan awam, atau enjin offline).
      await Future.any([first.future, complete.future, firstDeadline.future]);
      if (_ref.read(routePreviewControllerProvider) is! RouteReady) return null;
      return await complete.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          final s = _ref.read(routePreviewControllerProvider);
          return s is RouteReady ? s : null;
        },
      );
    } finally {
      deadlineTimer.cancel();
      sub.close();
    }
  }

  /// Tempat terdekat mengikut kategori (stesen minyak, surau, tandas...), tersusun mengikut jarak.
  Future<Map<String, Object?>> nearby(
    NearbyCategory category, {
    required String fallbackName,
  }) async {
    final here = await _gps();
    if (here == null) return {'ok': false, 'error': 'no_location'};
    try {
      final result = await _ref
          .read(nearbySearchProvider)
          .search(category, here, fallbackName: fallbackName);
      if (result.places.isEmpty) return {'ok': false, 'error': 'not_found'};
      return {
        'ok': true,
        'places': [
          for (final p in result.places.take(5))
            {
              'name': p.name,
              'subtitle': p.subtitle,
              'lat': p.point.lat,
              'lng': p.point.lng,
              'distance_m': distanceMeters(here, p.point).round(),
            },
        ],
      };
    } on Object catch (e) {
      return {'ok': false, 'error': networkErrorCode(e) ?? e.toString()};
    }
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
      'code': d.weatherCode,
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

  static RoutePreference _preference(Map<String, Object?> args) {
    if (_bool(args, 'avoid_tolls')) return RoutePreference.noTolls;
    if (_bool(args, 'avoid_highways')) return RoutePreference.noHighways;
    return switch (_str(
      args,
      'preference',
    )?.toLowerCase().replaceAll('-', '_')) {
      'fastest' => RoutePreference.fastest,
      'shortest' => RoutePreference.shortest,
      'no_tolls' || 'toll_free' || 'notolls' => RoutePreference.noTolls,
      'no_highways' => RoutePreference.noHighways,
      'cheapest' => RoutePreference.cheapest,
      'safest' || 'safe' => RoutePreference.safest,
      _ => RoutePreference.recommended,
    };
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

/// Kegagalan sementara yang wajar diulang sekali (rangkaian terputus-putus, pelayan sibuk, tamat masa).
bool isTransientNetworkError(Object e) {
  if (e is GeocodeFailure) return e.kind != GeocodeFailureKind.generic;
  if (e is TimeoutException || e is SocketException) return true;
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 429 || (code != null && code >= 500)) return true;
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.unknown => e.error is SocketException,
      _ => false,
    };
  }
  return false;
}

/// Kod ralat stabil untuk kegagalan rangkaian/pelayan. [online] ialah keadaan pautan sebenar peranti
/// (`onlineProbeProvider`): tanpa pautan -> 'offline'; ada pautan tetapi sambungan gagal/tamat masa -> 'slow';
/// HTTP 429 -> 'busy'; 5xx -> 'service_down'. Null = bukan ralat rangkaian (ralat lain).
/// [online] null (tidak diketahui) menganggap sambungan terputus sebagai 'offline'.
String? networkErrorCode(Object e, {bool? online}) {
  String linkDown() => online == true ? 'slow' : 'offline';
  if (e is GeocodeFailure) {
    return switch (e.kind) {
      GeocodeFailureKind.network => linkDown(),
      GeocodeFailureKind.rateLimited => 'busy',
      GeocodeFailureKind.unavailable => 'service_down',
      GeocodeFailureKind.generic => null,
    };
  }
  if (e is RoutingFailure) return _routingKindCode(e.kind, online: online);
  if (e is TimeoutException) return linkDown();
  if (e is DioException) {
    final code = e.response?.statusCode;
    if (code == 429) return 'busy';
    if (code != null && code >= 500) return 'service_down';
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.connectionError ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => linkDown(),
      DioExceptionType.unknown when e.error is SocketException => linkDown(),
      _ => null,
    };
  }
  if (e is SocketException) return linkDown();
  final text = e.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset')) {
    return linkDown();
  }
  return null;
}

String _routingKindCode(RoutingFailureKind kind, {bool? online}) =>
    switch (kind) {
      RoutingFailureKind.noRoute => 'no_drivable_route',
      RoutingFailureKind.rateLimited => 'busy',
      RoutingFailureKind.unavailable => 'service_down',
      RoutingFailureKind.timeout ||
      RoutingFailureKind.network => online == true ? 'slow' : 'offline',
      RoutingFailureKind.offlineRequired => 'offline_pack_needed',
      RoutingFailureKind.offlineEngine => 'offline_engine',
      RoutingFailureKind.invalidRequest ||
      RoutingFailureKind.generic => 'route_failed',
    };

/// Kod ralat sebenar untuk pratonton laluan yang tidak siap: setiap jenis kegagalan ada mesej tersendiri
/// (bukan semua "semak sambungan"). [RouteIdle]/lain-lain = tiada keputusan dalam masa yang diberi.
String routeFailureCode(RoutePreviewState state, {bool? online}) {
  if (state is RouteLocationUnavailable) return 'no_location';
  if (state is RouteFailed) return _routingKindCode(state.kind, online: online);
  return 'route_timeout';
}
