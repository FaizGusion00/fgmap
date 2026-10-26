import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'fgmap_valhalla_platform_interface.dart';

class MethodChannelFgmapValhalla extends FgmapValhallaPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('fgmap_valhalla');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await methodChannel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw ValhallaEngineException(e.code, e.message ?? '');
    } on MissingPluginException {
      throw const ValhallaEngineException('unsupported', 'No offline engine on this platform');
    }
  }

  @override
  Future<void> open(String tarPath) => _invoke<void>('open', {'tarPath': tarPath});

  @override
  Future<String> route(String requestJson) async {
    final response = await _invoke<String>('route', {'request': requestJson});
    if (response == null) {
      throw const ValhallaEngineException('internal', 'Engine returned no response');
    }
    return response;
  }

  @override
  Future<void> close() => _invoke<void>('close');
}
