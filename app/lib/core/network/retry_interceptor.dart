import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Cuba semula SEKALI untuk permintaan idempoten yang gagal kerana sebab sementara (rangkaian terputus,
/// tamat masa, 502/503/504), selepas jeda berjitter supaya ramai klien tidak mencuba serentak.
///
/// Opt-in setiap permintaan (`Options(extra: retryOnce)`): carian tempat dan laluan TIDAK dicuba semula
/// kerana ia mempunyai sandaran sendiri (Nominatim, enjin offline) yang lebih pantas daripada menunggu.
/// Hanya GET/HEAD; pembatalan oleh pemanggil tidak pernah dicuba semula.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this._dio, {Duration Function()? delay, Random? random})
    : _delay = delay ?? (() => _jitter(random ?? Random()));

  /// Kunci `extra` yang mengaktifkan cuba semula untuk satu permintaan.
  static const retryKey = 'fgmap.retryOnce';
  static const _attemptKey = 'fgmap.retryAttempt';

  /// Pilihan permintaan yang boleh dicuba semula sekali.
  static Options options(Options base) =>
      base.copyWith(extra: {...?base.extra, retryKey: true});

  final Dio _dio;
  final Duration Function() _delay;

  static Duration _jitter(Random random) =>
      Duration(milliseconds: 300 + random.nextInt(400));

  static const _transient = {
    DioExceptionType.connectionError,
    DioExceptionType.connectionTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.sendTimeout,
  };

  bool _retryable(DioException e) {
    final o = e.requestOptions;
    if (o.extra[retryKey] != true || o.extra[_attemptKey] == true) return false;
    if (o.method != 'GET' && o.method != 'HEAD') return false;
    if (o.cancelToken?.isCancelled ?? false) return false;
    if (_transient.contains(e.type)) return true;
    if (e.type == DioExceptionType.badResponse) {
      final s = e.response?.statusCode;
      return s == 502 || s == 503 || s == 504;
    }
    return false;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_retryable(err)) return handler.next(err);
    await Future<void>.delayed(_delay());
    final options = err.requestOptions;
    if (options.cancelToken?.isCancelled ?? false) return handler.next(err);
    options.extra[_attemptKey] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
