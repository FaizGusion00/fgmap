import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:fgmap_valhalla/fgmap_valhalla.dart'
    show ValhallaEngineException;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/storage/preferences.dart';
import '../../offline_maps/data/offline_engine_host.dart';
import '../domain/route_candidates.dart';
import '../domain/route_option.dart';
import '../domain/route_options_merge.dart';
import '../domain/routing_failure.dart';
import 'valhalla_codec.dart';
import '../../../core/utils/log.dart';

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

/// Satu kumpulan pilihan laluan. [done] benar pada kumpulan terakhir; sebelum itu, laluan lain masih
/// dicari dan senarai boleh bertambah atau disusun semula.
class RouteBatch {
  const RouteBatch(this.options, {required this.done});

  final List<RouteOption> options;
  final bool done;
}

/// Perancang yang menghantar pilihan laluan secara berperingkat: laluan biasa dahulu (pantas), kemudian
/// alternatif apabila setiap permintaan tambahan selesai.
abstract interface class ProgressiveRoutePlanner implements RoutePlanner {
  Stream<RouteBatch> watch(RouteQuery query);
}

/// Aliran kumpulan untuk [planner]: progresif jika disokong, jika tidak satu kumpulan sahaja.
Stream<RouteBatch> watchRoutes(RoutePlanner planner, RouteQuery query) {
  if (planner is ProgressiveRoutePlanner) return planner.watch(query);
  return Stream.fromFuture(
    planner.plan(query).then((options) => RouteBatch(options, done: true)),
  );
}

/// Perancang pilihan laluan untuk pratonton. Selain laluan biasa dan alternatif Valhalla, ia meminta
/// (secara dihad dan berperingkat) laluan tanpa tol, elak lebuh raya, jarak terpendek dan beberapa
/// lencongan paksa, kemudian memilih sehingga 10 pilihan yang berbeza dengan laluan utama yang terbaik
/// (lihat [mergeRouteCandidates]), bukan sekadar yang terpantas.
///
/// Permintaan tambahan sentiasa menggunakan sumber (online/offline) yang sama dengan laluan biasa,
/// supaya pilihan tidak bercampur antara data segar dan pek offline. Kegagalan permintaan tambahan
/// tidak menggagalkan pratonton: laluan biasa tetap dipaparkan. Pelayan awam dilindungi: maksimum
/// [maxExtra] permintaan tambahan, [maxConcurrent] serentak dengan jeda [stagger], dan semua
/// permintaan berhenti pada kegagalan sistem pertama (429, 5xx, tamat masa, tiada rangkaian).
class MultiRoutePlanner implements ProgressiveRoutePlanner {
  MultiRoutePlanner({
    required this.primary,
    required this.forSource,
    this.maxExtra = 10,
    this.maxConcurrent = 2,
    this.stagger = const Duration(milliseconds: 250),
    this.retryDelay = const Duration(milliseconds: 600),
  });

  /// Perancang bagi laluan biasa (dasar online/offline pengguna).
  final RoutePlanner primary;

  /// Perancang yang terhad kepada satu sumber, untuk permintaan tambahan.
  final RoutePlanner Function(RouteSource source) forSource;

  final int maxExtra;
  final int maxConcurrent;
  final Duration stagger;

  /// Jeda sebelum mencuba semula kegagalan sementara.
  final Duration retryDelay;

  /// Kegagalan yang menghentikan semua permintaan tambahan serta-merta: pelayan menyekat kita atau enjin
  /// dalam peranti rosak. Cuba lagi tidak membantu.
  static const _hardStops = {
    RoutingFailureKind.rateLimited,
    RoutingFailureKind.offlineEngine,
  };

  /// Kegagalan sementara: dicuba semula sekali dan dikira dalam [maxTransientFailures].
  static const _transient = {
    RoutingFailureKind.unavailable,
    RoutingFailureKind.timeout,
    RoutingFailureKind.network,
  };

  /// Selepas sekian banyak kegagalan sementara berturutan (selepas cuba semula) pelayan dianggap tidak
  /// sihat dan permintaan tambahan dihentikan.
  static const maxTransientFailures = 3;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async =>
      (await watch(query).last).options;

  @override
  Stream<RouteBatch> watch(RouteQuery query) {
    final controller = StreamController<RouteBatch>();
    var cancelled = false;
    controller.onCancel = () => cancelled = true;
    unawaited(_run(query, controller, () => cancelled));
    return controller.stream;
  }

  Future<void> _run(
    RouteQuery query,
    StreamController<RouteBatch> out,
    bool Function() isCancelled,
  ) async {
    try {
      final standard = await primary.plan(query);
      if (isCancelled()) return;
      if (standard.isEmpty) {
        out.add(const RouteBatch([], done: true));
        return;
      }

      final memo = SameRouteMemo();
      final requests = planCandidateRequests(
        query,
        standard,
        maxExtra: maxExtra,
      );
      final found = <RouteCandidateOrigin, List<RouteOption>>{};
      // Laluan utama kelompok sebelumnya: kad pertama tidak bertukar kecuali calon baharu jelas lebih baik.
      RouteOption? lastPrimary;
      List<RouteOption> merged() => mergeRouteCandidates(
        incumbent: lastPrimary,
        standard: standard,
        noTolls: found[RouteCandidateOrigin.noTolls] ?? const [],
        noHighways: found[RouteCandidateOrigin.noHighways] ?? const [],
        shortest: found[RouteCandidateOrigin.shortest] ?? const [],
        detours: found[RouteCandidateOrigin.detour] ?? const [],
        memo: memo,
      );

      var lastSignature = '';
      void emit({required bool done}) {
        final options = merged();
        if (options.isNotEmpty) lastPrimary = options.first;
        final signature = _signature(options);
        if (!done && signature == lastSignature) return;
        lastSignature = signature;
        out.add(RouteBatch(options, done: done));
      }

      emit(done: requests.isEmpty);
      if (requests.isEmpty) return;

      final planner = forSource(standard.first.source);
      var next = 0;
      var stopped = false;
      var transientFailures = 0;
      Future<void> worker(int index) async {
        // Mulakan pekerja berperingkat supaya pelayan awam tidak menerima letusan serentak.
        if (index > 0 && stagger > Duration.zero) {
          await Future<void>.delayed(stagger * index);
        }
        while (!stopped && !isCancelled() && next < requests.length) {
          final request = requests[next++];
          for (var attempt = 0; attempt < 2; attempt++) {
            try {
              final routes = await planner.plan(request.query);
              (found[request.origin] ??= []).addAll(routes);
              transientFailures = 0;
              break;
            } on RoutingFailure catch (failure) {
              if (_hardStops.contains(failure.kind)) {
                stopped = true;
                break;
              }
              if (!_transient.contains(failure.kind)) {
                break; // noRoute dll.: langkau
              }
              if (attempt == 0 && !isCancelled()) {
                await Future<void>.delayed(retryDelay);
                continue;
              }
              if (++transientFailures >= maxTransientFailures) stopped = true;
            } on Object catch (e) {
              if (kDebugMode) logDiag('Permintaan laluan tambahan gagal: $e');
              if (++transientFailures >= maxTransientFailures) stopped = true;
              break;
            }
          }
          if (isCancelled()) return;
          emit(done: false);
          if (stagger > Duration.zero && !stopped && next < requests.length) {
            await Future<void>.delayed(stagger);
          }
        }
      }

      await Future.wait([
        for (var i = 0; i < math.max(1, maxConcurrent); i++) worker(i),
      ]);
      if (!isCancelled()) emit(done: true);
    } on Object catch (e, st) {
      if (!out.isClosed) out.addError(e, st);
    } finally {
      await out.close();
    }
  }

  static String _signature(List<RouteOption> options) => [
    for (final o in options) '${o.label.name}:${o.durationS}:${o.distanceM}',
  ].join('|');
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

const _vehicleKey = 'route.vehicle';

/// Kenderaan pilihan pengguna, disimpan merentas sesi (pemandu motosikal kekal motosikal).
class RouteVehicleController extends Notifier<RouteVehicle> {
  @override
  RouteVehicle build() {
    final saved = ref.watch(sharedPreferencesProvider).getString(_vehicleKey);
    return RouteVehicle.values.firstWhere(
      (v) => v.name == saved,
      orElse: () => RouteVehicle.car,
    );
  }

  Future<void> set(RouteVehicle vehicle) async {
    state = vehicle;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_vehicleKey, vehicle.name);
  }
}

final routeVehicleProvider =
    NotifierProvider<RouteVehicleController, RouteVehicle>(
      RouteVehicleController.new,
    );

final routingModeProvider =
    NotifierProvider<RoutingModeController, RoutingMode>(
      RoutingModeController.new,
    );

/// Perancang satu laluan (satu permintaan setiap kali). Digunakan untuk mengira semula semasa
/// navigasi: ia mesti pantas dan mengekalkan pilihan laluan pengguna.
final routePlannerProvider = Provider<RoutePlanner>((ref) {
  return HybridRoutePlanner(
    online: ref.watch(_onlinePlannerProvider),
    offline: ref.watch(_offlinePlannerProvider),
    // Dibaca pada setiap permintaan (bukan ditangkap), supaya menukar mod berkuat kuasa serta-merta.
    mode: () => ref.read(routingModeProvider),
  );
});

/// Perancang pratonton: semua pilihan laluan yang bermakna, berlabel (lihat [MultiRoutePlanner]).
final routeOptionsPlannerProvider = Provider<RoutePlanner>((ref) {
  return MultiRoutePlanner(
    primary: ref.watch(routePlannerProvider),
    forSource: (source) => switch (source) {
      RouteSource.online => ref.read(_onlinePlannerProvider),
      RouteSource.offline => ref.read(_offlinePlannerProvider),
    },
  );
});

final _onlinePlannerProvider = Provider<RoutePlanner>(
  (ref) => OnlineRoutePlanner(ref.watch(dioProvider), AppConfig.valhallaUrl),
);

final _offlinePlannerProvider = Provider<RoutePlanner>(
  (ref) => OfflineRoutePlanner(ref.watch(offlineEngineHostProvider)),
);
