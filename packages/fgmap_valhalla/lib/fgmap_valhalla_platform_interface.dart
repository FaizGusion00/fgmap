import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'fgmap_valhalla_method_channel.dart';

/// Kegagalan enjin Valhalla dalam peranti.
class ValhallaEngineException implements Exception {
  const ValhallaEngineException(this.code, this.message);

  /// `tiles_missing`, `open_failed`, `not_open`, `route_failed`, `bad_args`, `internal`,
  /// atau `unsupported` (platform tiada enjin).
  final String code;
  final String message;

  @override
  String toString() => 'ValhallaEngineException($code): $message';
}

abstract class FgmapValhallaPlatform extends PlatformInterface {
  FgmapValhallaPlatform() : super(token: _token);

  static final Object _token = Object();

  static FgmapValhallaPlatform _instance = MethodChannelFgmapValhalla();

  static FgmapValhallaPlatform get instance => _instance;

  static set instance(FgmapValhallaPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Buka enjin pada fail tile extract (.tar). Menggantikan enjin yang sedang dibuka.
  Future<void> open(String tarPath) => throw UnimplementedError();

  /// Kira laluan. [requestJson] ialah permintaan Valhalla `/route`; memulangkan JSON respons Valhalla.
  Future<String> route(String requestJson) => throw UnimplementedError();

  /// Atribut tepi jalan sepanjang jejak (Valhalla `trace_attributes`), cth. had laju. JSON masuk, JSON keluar.
  Future<String> traceAttributes(String requestJson) => throw UnimplementedError();

  /// Lepaskan enjin. Mesti dipanggil sebelum fail tile diganti atau dipadam.
  Future<void> close() => throw UnimplementedError();
}
