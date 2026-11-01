import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../data/open_meteo_client.dart';
import '../data/weather_forecast_store.dart';
import '../domain/weather_forecast.dart';

/// ID tempat "lokasi semasa" (GPS).
const currentWeatherPlaceId = 'current';

@immutable
class WeatherPageState {
  const WeatherPageState({
    this.places = const [],
    this.index = 0,
    this.forecasts = const {},
    this.loading = const {},
    this.failed = const {},
    this.locating = true,
  });

  /// Lokasi semasa (jika diketahui) dahulu, kemudian tempat yang disimpan.
  final List<WeatherPlace> places;
  final int index;
  final Map<String, WeatherForecast> forecasts;
  final Set<String> loading;

  /// Muat semula terakhir gagal (paparan menggunakan simpanan dan menandakannya).
  final Set<String> failed;
  final bool locating;

  WeatherPlace? get selected =>
      places.isEmpty ? null : places[index.clamp(0, places.length - 1)];

  WeatherPageState copyWith({
    List<WeatherPlace>? places,
    int? index,
    Map<String, WeatherForecast>? forecasts,
    Set<String>? loading,
    Set<String>? failed,
    bool? locating,
  }) => WeatherPageState(
    places: places ?? this.places,
    index: index ?? this.index,
    forecasts: forecasts ?? this.forecasts,
    loading: loading ?? this.loading,
    failed: failed ?? this.failed,
    locating: locating ?? this.locating,
  );
}

/// Halaman Cuaca: lokasi semasa + tempat disimpan, ramalan dari simpanan dahulu (serta-merta, juga
/// tanpa internet) kemudian disegarkan jika lebih 30 minit.
class WeatherPageController extends Notifier<WeatherPageState> {
  @override
  WeatherPageState build() {
    final store = ref.read(weatherForecastStoreProvider);
    final saved = store.places();
    final forecasts = <String, WeatherForecast>{
      for (final p in saved) p.id: ?store.load(p.point),
    };
    Future.microtask(() {
      _locate();
      for (final p in saved) {
        unawaited(load(p));
      }
    });
    return WeatherPageState(places: saved, forecasts: forecasts);
  }

  Future<void> _locate() async {
    final loc = ref.read(locationServiceProvider);
    GeoPoint? point;
    try {
      point = (await loc.lastKnownFix())?.point;
      if (point != null) _setCurrent(point);
      final fix = await loc.currentFix(
        timeout: const Duration(seconds: 6),
        maxAccuracyMeters: 2000,
        fallbackAccuracyMeters: 10000,
      );
      if (fix != null &&
          (point == null || distanceMeters(point, fix.point) > 1000)) {
        point = fix.point;
        _setCurrent(point);
      }
    } on Object catch (e) {
      logDiag('Cuaca: lokasi gagal: $e');
    }
    if (!ref.mounted) return;
    state = state.copyWith(locating: false);
    if (point == null) return;
    try {
      final place = await ref.read(reverseGeocoderProvider).reverse(point);
      if (!ref.mounted || place == null) return;
      final current = state.places
          .where((p) => p.id == currentWeatherPlaceId)
          .firstOrNull;
      if (current == null) return;
      _replace(
        current.copyWith(name: _placeName(place), subtitle: _area(place)),
      );
    } on Object {
      // Tanpa nama: UI memaparkan "Lokasi semasa".
    }
  }

  void _setCurrent(GeoPoint point) {
    if (!ref.mounted) return;
    final existing = state.places
        .where((p) => p.id == currentWeatherPlaceId)
        .firstOrNull;
    final current =
        existing?.copyWith(point: point) ??
        WeatherPlace(
          id: currentWeatherPlaceId,
          name: '',
          point: point,
          isCurrent: true,
        );
    if (existing == null) {
      // Lokasi semasa sentiasa pertama; kekalkan tempat yang sedang dilihat.
      final viewing = state.selected?.id;
      final places = [current, ...state.places];
      state = state.copyWith(
        places: places,
        index: viewing == null
            ? 0
            : places
                  .indexWhere((p) => p.id == viewing)
                  .clamp(0, places.length - 1),
      );
    } else {
      _replace(current);
    }
    final cached = ref.read(weatherForecastStoreProvider).load(point);
    if (cached != null && !state.forecasts.containsKey(currentWeatherPlaceId)) {
      state = state.copyWith(
        forecasts: {...state.forecasts, currentWeatherPlaceId: cached},
      );
    }
    unawaited(load(current));
  }

  void _replace(WeatherPlace place) {
    state = state.copyWith(
      places: [for (final p in state.places) p.id == place.id ? place : p],
    );
  }

  /// Muat ramalan [place]. Tanpa [force], ramalan yang belum 30 minit tidak dimuat semula.
  Future<void> load(WeatherPlace place, {bool force = false}) async {
    final have = state.forecasts[place.id];
    if (!force &&
        have != null &&
        !have.isStale() &&
        distanceMeters(have.point, place.point) < 2000) {
      return;
    }
    if (state.loading.contains(place.id)) return;
    state = state.copyWith(loading: {...state.loading, place.id});
    try {
      final (forecast, raw) = await ref
          .read(openMeteoClientProvider)
          .fetchForecast(place.point);
      if (!ref.mounted) return;
      unawaited(
        ref
            .read(weatherForecastStoreProvider)
            .save(place.point, raw, forecast.fetchedAt),
      );
      state = state.copyWith(
        forecasts: {...state.forecasts, place.id: forecast},
        failed: {...state.failed}..remove(place.id),
      );
    } on Object catch (e) {
      logDiag('Cuaca: ramalan ${place.id} gagal: $e');
      if (!ref.mounted) return;
      state = state.copyWith(failed: {...state.failed, place.id});
    } finally {
      if (ref.mounted) {
        state = state.copyWith(loading: {...state.loading}..remove(place.id));
      }
    }
  }

  void select(int index) {
    if (index < 0 || index >= state.places.length) return;
    state = state.copyWith(index: index);
    unawaited(load(state.places[index]));
  }

  Future<void> refresh() async {
    final place = state.selected;
    if (place == null) {
      await _locate();
      return;
    }
    await load(place, force: true);
  }

  /// Tambah tempat dari carian (atau pergi kepadanya jika sudah ada) dan paparkannya.
  Future<void> addPlace(Place place) async {
    final existing = state.places.indexWhere(
      (p) => distanceMeters(p.point, place.point) < 2000,
    );
    if (existing >= 0) {
      select(existing);
      return;
    }
    final added = WeatherPlace(
      id: '${place.point.lat.toStringAsFixed(3)},${place.point.lng.toStringAsFixed(3)}',
      name: _placeName(place),
      subtitle: _area(place),
      point: place.point,
    );
    final places = [...state.places, added];
    state = state.copyWith(places: places, index: places.length - 1);
    await _persist();
    final cached = ref.read(weatherForecastStoreProvider).load(added.point);
    if (cached != null) {
      state = state.copyWith(forecasts: {...state.forecasts, added.id: cached});
    }
    await load(added);
  }

  Future<void> removePlace(String id) async {
    if (id == currentWeatherPlaceId) return;
    final places = [
      for (final p in state.places)
        if (p.id != id) p,
    ];
    state = state.copyWith(
      places: places,
      index: state.index.clamp(0, places.isEmpty ? 0 : places.length - 1),
    );
    await _persist();
  }

  Future<void> _persist() => ref.read(weatherForecastStoreProvider).savePlaces([
    for (final p in state.places)
      if (!p.isCurrent) p,
  ]);

  static String _placeName(Place p) {
    final name = p.name.trim();
    if (name.isNotEmpty) return name;
    return p.subtitle.split(',').first.trim();
  }

  static String? _area(Place p) {
    final parts = p.subtitle
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s != p.name)
        .toList();
    if (parts.isEmpty) return null;
    return parts.length > 2
        ? parts.sublist(parts.length - 2).join(', ')
        : parts.join(', ');
  }
}

final weatherPageControllerProvider =
    NotifierProvider.autoDispose<WeatherPageController, WeatherPageState>(
      WeatherPageController.new,
    );
