import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../along_route/domain/along_route_projector.dart';
import '../../route_preview/domain/route_option.dart';
import '../data/open_meteo_client.dart';
import '../domain/weather_snapshot.dart';

class WeatherController extends Notifier<WeatherUiState> {
  CancelToken? _cancel;
  int _seq = 0;

  @override
  WeatherUiState build() => const WeatherUiIdle();

  Future<void> loadForRoute(
    RouteOption route,
    GeoPoint destination, {
    String? destinationLabel,
  }) async {
    final seq = ++_seq;
    _cancel?.cancel();
    _cancel = CancelToken();
    state = const WeatherUiLoading();

    // Lokasi sebenar pemandu (GPS), bukan pusat peta — lebih tepat untuk "di sini".
    GeoPoint? origin;
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .currentFix(
            timeout: const Duration(seconds: 4),
            maxAccuracyMeters: 80,
          );
      origin = fix?.point;
      origin ??=
          (await ref.read(locationServiceProvider).lastKnownFix())?.point;
    } catch (_) {}

    if (seq != _seq) return;

    final step = (route.distanceM / 4).clamp(5000.0, 40000.0);
    final samples = samplePolyline(
      route.points,
      everyM: step,
    ).skip(1).take(4).toList();

    final snap = await ref
        .read(openMeteoClientProvider)
        .fetch(
          destination: destination,
          origin: origin,
          alongSamples: samples,
          destinationLabel: destinationLabel,
          cancel: _cancel,
        );

    if (seq != _seq) return;
    state = snap == null ? const WeatherUiUnavailable() : WeatherUiReady(snap);
  }

  void clear() {
    _cancel?.cancel();
    _seq++;
    state = const WeatherUiIdle();
  }
}

final weatherControllerProvider =
    NotifierProvider<WeatherController, WeatherUiState>(WeatherController.new);
