import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../data/open_meteo_air_client.dart';
import '../domain/air_quality.dart';

class AirQualityController extends Notifier<AirUiState> {
  CancelToken? _cancel;
  int _seq = 0;

  @override
  AirUiState build() => const AirUiIdle();

  /// GPS semasa (atau fix terakhir).
  Future<void> loadHere() async {
    final seq = ++_seq;
    _cancel?.cancel();
    _cancel = CancelToken();
    state = const AirUiLoading();
    GeoPoint? point;
    try {
      final fix = await ref
          .read(locationServiceProvider)
          .currentFix(
            timeout: const Duration(seconds: 6),
            maxAccuracyMeters: 500,
            fallbackAccuracyMeters: 5000,
          );
      point = fix?.point;
      point ??= (await ref.read(locationServiceProvider).lastKnownFix())?.point;
    } catch (_) {}
    if (seq != _seq) return;
    if (point == null) {
      state = const AirUiUnavailable();
      return;
    }
    await _fetch(point, here: true, seq: seq);
  }

  Future<void> loadAt(GeoPoint point, {String? label}) async {
    final seq = ++_seq;
    _cancel?.cancel();
    _cancel = CancelToken();
    state = const AirUiLoading();
    await _fetch(point, label: label, here: false, seq: seq);
  }

  Future<void> _fetch(
    GeoPoint point, {
    String? label,
    required bool here,
    required int seq,
  }) async {
    final reading = await ref
        .read(openMeteoAirClientProvider)
        .fetch(point: point, placeLabel: label, here: here, cancel: _cancel);
    if (seq != _seq) return;
    state = reading == null ? const AirUiUnavailable() : AirUiReady(reading);
  }
}

final airQualityControllerProvider =
    NotifierProvider<AirQualityController, AirUiState>(
      AirQualityController.new,
    );
