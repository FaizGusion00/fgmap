import 'fgmap_valhalla_platform_interface.dart';

export 'fgmap_valhalla_platform_interface.dart' show ValhallaEngineException;

/// Enjin laluan Valhalla yang berjalan dalam peranti, terhadap tile yang dimuat turun.
class FgmapValhalla {
  const FgmapValhalla();

  Future<void> open(String tarPath) => FgmapValhallaPlatform.instance.open(tarPath);

  Future<String> route(String requestJson) => FgmapValhallaPlatform.instance.route(requestJson);

  Future<void> close() => FgmapValhallaPlatform.instance.close();
}
