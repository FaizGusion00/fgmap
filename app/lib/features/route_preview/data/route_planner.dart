import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart'
    show ValhallaEngineException;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/storage/preferences.dart';
import '../../offline_maps/data/offline_engine_host.dart';
import '../domain/route_option.dart';
import '../domain/routing_failure.dart';
import 'valhalla_codec.dart';

/// Mengira laluan. Melempar [RoutingFailure] untuk semua kegagalan yang boleh dijangka.
abstract interface class RoutePlanner {
  Future<List<RouteOption>> plan(RouteQuery query);
}

/// Laluan online melalui API Valhalla awam: data paling segar.
class OnlineRoutePlanner implements RoutePlanner {
  OnlineRoutePlanner(
    this._dio,
    this._url, {
    this.timeout = const Duration(seconds: 8),
  });

  final Dio _dio;
  final String _url;

  /// Tempoh menunggu respons sebelum jatuh balik ke offline. Lebih pendek daripada lalai Dio supaya
  /// pengguna dengan isyarat lemah tidak menunggu lama sebelum enjin dalam peranti mengambil alih.
  final Duration timeout;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async {
    try {
      final response = await _dio.post<Object>(
        _url,
        data: jsonEncode(buildRouteRequest(query)),
        options: Options(
          contentType: Headers.jsonContentType,
          responseType: ResponseType.bytes,
          receiveTimeout: timeout,
        ),
      );
      return parseRouteResponse(
        responseText(response.data),
        source: RouteSource.online,
      );
    } on DioException catch (e) {
      throw _failureFromDio(e);
    }
  }
}

RoutingFailure _failureFromDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.connectionError:
      return RoutingFailure(RoutingFailureKind.network, e.message);
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return RoutingFailure(RoutingFailureKind.timeout, e.message);
    case DioExceptionType.badResponse:
      return _failureFromResponse(e.response);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return RoutingFailure(RoutingFailureKind.generic, e.message);
  }
}

RoutingFailure _failureFromResponse(Response<dynamic>? response) {
  final status = response?.statusCode;
  if (status == 429) {
    return const RoutingFailure(RoutingFailureKind.rateLimited, 'HTTP 429');
  }

  // Ralat Valhalla membawa error_code dalam badan JSON (cth. 442 destinasi di laut).
  final data = responseText(response?.data);
  if (data != null && data.isNotEmpty) {
    final code = valhallaErrorCodeFromText(data);
    if (code != null) return failureForValhallaError(code);
  }
  return switch (status) {
    504 || 408 => RoutingFailure(RoutingFailureKind.timeout, 'HTTP $status'),
    final s? when s >= 500 => RoutingFailure(
      RoutingFailureKind.unavailable,
      'HTTP $s',
    ),
    // 403/401: disekat oleh hos awam (cth. UA ditolak). Ia bukan salah pengguna; boleh jatuh ke offline.
    401 ||
    403 => RoutingFailure(RoutingFailureKind.unavailable, 'HTTP $status'),
    _ => RoutingFailure(RoutingFailureKind.generic, 'HTTP $status'),
  };
}

/// Laluan offline melalui enjin Valhalla dalam peranti terhadap pek yang dipasang.
class OfflineRoutePlanner implements RoutePlanner {
  OfflineRoutePlanner(this._host);

  final OfflineEngineHost _host;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async {
    try {
      final body = await _host.route(jsonEncode(buildRouteRequest(query)));
      return parseRouteResponse(body, source: RouteSource.offline);
    } on OfflineEngineUnavailable {
      throw const RoutingFailure(RoutingFailureKind.offlineRequired);
    } on ValhallaEngineException catch (e) {
      // Mesej pengecualian enjin membawa JSON ralat Valhalla jika ralat itu dari Valhalla sendiri
      // (cth. 171 tiada jalan berhampiran); jika tidak, enjin sendiri bermasalah.
      final code = valhallaErrorCodeFromText(e.message);
      if (code != null) throw failureForValhallaError(code, e.message);
      throw RoutingFailure(
        RoutingFailureKind.offlineEngine,
        '${e.code}: ${e.message}',
      );
    }
  }
}

/// Pilihan sumber laluan oleh pengguna.
enum RoutingMode {
  /// Online dahulu; jatuh balik ke offline bila online gagal (lalai).
  auto,
  onlineOnly,
  offlineOnly,
}

/// Dasar sumber laluan:
///  - **auto**: cuba online (paling segar). Jika online gagal kerana sebab SISTEM (rangkaian, masa,
///    5xx, sekatan kadar) dan pek offline dipasang, guna offline. Jawapan ONLINE "tiada laluan" atau
///    "permintaan tidak sah" adalah muktamad dan TIDAK dicuba semula offline: ia bukan kegagalan
///    sumber, dan data online lebih terkini.
///  - **onlineOnly / offlineOnly**: pilihan eksplisit; tiada jatuh balik.
class HybridRoutePlanner implements RoutePlanner {
  HybridRoutePlanner({
    required this.online,
    required this.offline,
    required this.mode,
  });

  final RoutePlanner online;
  final RoutePlanner offline;
  final RoutingMode Function() mode;

  static const _authoritative = {
    RoutingFailureKind.noRoute,
    RoutingFailureKind.invalidRequest,
  };

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async {
    switch (mode()) {
      case RoutingMode.offlineOnly:
        return offline.plan(query);
      case RoutingMode.onlineOnly:
        return online.plan(query);
      case RoutingMode.auto:
        try {
          return await online.plan(query);
        } on RoutingFailure catch (onlineFailure) {
          if (_authoritative.contains(onlineFailure.kind)) rethrow;
          try {
            return await offline.plan(query);
          } on RoutingFailure catch (offlineFailure) {
            // Tiada pek offline: jelaskan kegagalan online yang sebenar (rangkaian dsb.), bukan
            // "pek diperlukan", supaya mesej sepadan dengan apa yang pengguna alami.
            if (offlineFailure.kind == RoutingFailureKind.offlineRequired) {
              throw RoutingFailure(
                _withOfflineHint(onlineFailure.kind),
                onlineFailure.detail,
              );
            }
            rethrow;
          }
        }
    }
  }

  /// Kegagalan online yang boleh diatasi dengan memuat turun peta offline dilaporkan sebagai
  /// [RoutingFailureKind.offlineRequired] supaya UI boleh menawarkan muat turun.
  static RoutingFailureKind _withOfflineHint(RoutingFailureKind online) {
    return switch (online) {
      RoutingFailureKind.network ||
      RoutingFailureKind.timeout ||
      RoutingFailureKind.unavailable ||
      RoutingFailureKind.rateLimited => RoutingFailureKind.offlineRequired,
      _ => online,
    };
  }
}

const _modeKey = 'routing.mode';

class RoutingModeController extends Notifier<RoutingMode> {
  @override
  RoutingMode build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_modeKey);
    return RoutingMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => RoutingMode.auto,
    );
  }

  Future<void> set(RoutingMode mode) async {
    state = mode;
    await ref.read(sharedPreferencesProvider).setString(_modeKey, mode.name);
  }
}

final routingModeProvider =
    NotifierProvider<RoutingModeController, RoutingMode>(
      RoutingModeController.new,
    );

final routePlannerProvider = Provider<RoutePlanner>((ref) {
  return HybridRoutePlanner(
    online: OnlineRoutePlanner(ref.watch(dioProvider), AppConfig.valhallaUrl),
    offline: OfflineRoutePlanner(ref.watch(offlineEngineHostProvider)),
    // Dibaca pada setiap permintaan (bukan ditangkap), supaya menukar mod berkuat kuasa serta-merta.
    mode: () => ref.read(routingModeProvider),
  );
});
