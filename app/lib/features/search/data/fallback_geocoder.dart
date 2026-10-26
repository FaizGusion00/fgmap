import 'package:dio/dio.dart';

import '../../../core/utils/geo.dart';
import '../domain/place.dart';
import 'photon_geocoder.dart';

/// Photon dahulu; jika ia gagal atau tiada hasil, jatuh ke [secondary] (Nominatim).
///
/// Dasar Nominatim awam: maksimum 1 permintaan sesaat dan tiada autocomplete. Justeru laluan fallback
/// menunggu pengguna berhenti menaip ([settle]), menjarakkan permintaan sekurang-kurangnya [minGap]
/// dan membatalkan jika pertanyaan sudah usang.
class FallbackGeocoder implements Geocoder {
  FallbackGeocoder(
    this.primary,
    this.secondary, {
    this.settle = const Duration(milliseconds: 700),
    this.minGap = const Duration(milliseconds: 1100),
    DateTime Function()? clock,
    Future<void> Function(Duration)? delay,
  }) : _clock = clock ?? DateTime.now,
       _delay = delay ?? Future<void>.delayed;

  final Geocoder primary;
  final Geocoder secondary;
  final Duration settle;
  final Duration minGap;
  final DateTime Function() _clock;
  final Future<void> Function(Duration) _delay;

  DateTime? _lastSecondary;

  /// Pertanyaan lebih pendek ini tidak layak jatuh ke fallback (terlalu samar, membazir kuota).
  static const _minFallbackChars = 3;

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    List<Place> primaryResults;
    GeocodeFailure? primaryFailure;
    try {
      primaryResults = await primary.search(query, near: near, cancel: cancel);
    } on GeocodeFailure catch (f) {
      primaryResults = const [];
      primaryFailure = f;
    }
    if (primaryResults.isNotEmpty) return primaryResults;
    if (query.trim().length < _minFallbackChars) {
      if (primaryFailure != null) throw primaryFailure;
      return primaryResults;
    }

    try {
      await _waitTurn(cancel);
      return await secondary.search(query, near: near, cancel: cancel);
    } on GeocodeFailure {
      // Photon gagal DAN fallback gagal: laporkan kegagalan Photon (sebab asal). Photon berjaya tetapi
      // kosong: kosong ialah jawapan yang jujur.
      if (primaryFailure != null) throw primaryFailure;
      return primaryResults;
    }
  }

  Future<void> _waitTurn(CancelToken? cancel) async {
    await _delay(settle);
    _throwIfCancelled(cancel);
    final last = _lastSecondary;
    if (last != null) {
      final wait = minGap - _clock().difference(last);
      if (wait > Duration.zero) {
        await _delay(wait);
        _throwIfCancelled(cancel);
      }
    }
    _lastSecondary = _clock();
  }

  void _throwIfCancelled(CancelToken? cancel) {
    if (cancel?.isCancelled ?? false) {
      throw DioException.requestCancelled(
        requestOptions: RequestOptions(),
        reason: 'carian dibatalkan',
      );
    }
  }
}
