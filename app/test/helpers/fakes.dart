import 'package:fgmap/features/splash/data/splash_controller.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:dio/dio.dart';
import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/platform/external_actions.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:fgmap/features/route_preview/domain/routing_failure.dart';

class FakeLocationService implements LocationService {
  FakeLocationService({
    this.accessValue = LocationAccess.granted,
    this.fix,
    this.requestResult = LocationAccess.granted,
  });

  LocationAccess accessValue;
  LocationFix? fix;
  LocationAccess requestResult;

  int requestCalls = 0;
  int openAppSettingsCalls = 0;
  int openLocationSettingsCalls = 0;

  @override
  Future<LocationAccess> access() async => accessValue;

  @override
  Future<LocationAccess> request() async {
    requestCalls++;
    accessValue = requestResult;
    return requestResult;
  }

  @override
  Future<LocationFix?> currentFix({
    Duration timeout = const Duration(seconds: 8),
    double maxAccuracyMeters =
        GeolocatorLocationService.defaultMaxAccuracyMeters,
    double? fallbackAccuracyMeters,
  }) async {
    // GPS lambat: hanya panggilan PERTAMA selepas [currentFixGate] ditetapkan ditahan (cth. fix
    // permulaan app), supaya panggilan lain (merancang laluan) tidak ikut tersekat.
    final gate = currentFixGate;
    currentFixGate = null;
    await gate?.future;
    return accessValue == LocationAccess.granted ? fix : null;
  }

  /// Jika ditetapkan, panggilan [currentFix] seterusnya menunggu sehingga ia selesai.
  Completer<void>? currentFixGate;

  /// Fix terakhir diketahui (boleh lapuk); null = peranti belum pernah ada fix.
  LocationFix? lastKnown;

  @override
  Future<LocationFix?> lastKnownFix() async =>
      accessValue == LocationAccess.granted ? lastKnown : null;

  /// Strim "ikut saya" di peta; ujian menolak fix melalui [trackingController]. [trackingListens]
  /// mengira berapa kali strim dilanggan (untuk membuktikan ia dihentikan apabila tidak diperlukan).
  int trackingListens = 0;
  late final StreamController<LocationFix> trackingController =
      StreamController<LocationFix>.broadcast(
        onListen: () => trackingListens++,
      );

  @override
  Stream<LocationFix> trackingFixes() => trackingController.stream;

  final StreamController<LocationFix> navigationController =
      StreamController<LocationFix>.broadcast();

  @override
  Stream<LocationFix> navigationFixes() => navigationController.stream;

  @override
  Future<bool> openAppSettings() async {
    openAppSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openLocationSettingsCalls++;
    return true;
  }
}

class FakeRoutePlanner implements RoutePlanner {
  FakeRoutePlanner(this.handler);

  Future<List<RouteOption>> Function(RouteQuery query) handler;
  final List<RouteQuery> queries = [];

  @override
  Future<List<RouteOption>> plan(RouteQuery query) {
    queries.add(query);
    return handler(query);
  }
}

const klcc = GeoPoint(3.1579, 101.7116);
const klia = GeoPoint(2.7456, 101.7072);
const batuCaves = GeoPoint(3.2379, 101.6840);

RouteOption sampleOption({
  int distanceM = 67049,
  int durationS = 3477,
  bool hasTolls = true,
  bool hasHighway = false,
  List<GeoPoint> points = const [klcc, klia],
  RouteSource source = RouteSource.online,
  RouteLabel label = RouteLabel.fastest,
  String? via,
}) {
  return RouteOption(
    distanceM: distanceM,
    durationS: durationS,
    hasTolls: hasTolls,
    hasHighway: hasHighway,
    points: points,
    source: source,
    label: label,
    maneuvers: [
      if (via != null)
        Maneuver(
          type: 8,
          streetNames: [via],
          lengthM: distanceM,
          timeS: durationS,
          beginShapeIndex: 0,
        ),
    ],
  );
}

/// Adapter Dio yang memulangkan respons tetap dan merekod permintaan terakhir.
class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  RequestOptions? lastRequest;

  /// Badan permintaan terakhir seperti yang SEBENARNYA dihantar ke wayar (bait dinyahkod JSON),
  /// bukan `options.data` yang hanya objek Dart sebelum serialisasi.
  Object? lastBody;

  /// Badan mentah (cth. borang `data=...` untuk Overpass POST), tidak dinyahkod.
  String? lastBodyText;

  static Object? _tryJson(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return text;
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      final text = utf8.decode(bytes);
      lastBodyText = bytes.isEmpty ? null : text;
      lastBody = bytes.isEmpty ? null : _tryJson(text);
    }
    return respond(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(Object body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  /// Badan teks dengan jenis kandungan tertentu. Hos sebenar berbeza: server Valhalla dan R2 menghantar
  /// `application/json` (Dio menyahkodnya kepada Map), GitHub Releases `application/octet-stream`.
  static ResponseBody text(
    String body, {
    required int status,
    String contentType = 'text/html',
  }) {
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }
}

/// Adapter yang melempar [DioException] jenis tertentu (kegagalan pengangkutan).
class FailingAdapter implements HttpClientAdapter {
  FailingAdapter(this.type);

  final DioExceptionType type;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls++;
    throw DioException(
      requestOptions: options,
      type: type,
      message: 'simulated $type',
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [RoutePlanner] yang merekod panggilan dan memulangkan hasil tetap atau melempar kegagalan.
class RecordingPlanner implements RoutePlanner {
  RecordingPlanner.returns(this._result) : _failure = null;
  RecordingPlanner.fails(RoutingFailure this._failure) : _result = null;

  final List<RouteOption>? _result;
  final RoutingFailure? _failure;
  int calls = 0;

  @override
  Future<List<RouteOption>> plan(RouteQuery query) async {
    calls++;
    final failure = _failure;
    if (failure != null) throw failure;
    return _result!;
  }
}

/// Splash animasi dianggap sudah selesai (ujian yang bukan tentang splash tidak perlu menunggunya).
class SplashAlreadyDone extends SplashController {
  @override
  bool build() => true;
}

/// Perkongsian palsu: merekod teks yang akan dikongsi tanpa membuka UI sistem.
class FakeShareService implements ShareService {
  final List<String> shared = [];
  bool fail = false;

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    if (fail) throw StateError('tiada lembaran kongsi');
    shared.add(text);
  }
}

/// Papan nombor palsu: merekod nombor yang dibuka.
class FakePhoneDialer implements PhoneDialer {
  final List<String> dialed = [];
  bool succeed = true;

  @override
  Future<bool> dial(String number) async {
    if (!succeed) return false;
    dialed.add(number);
    return true;
  }
}
