import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';

/// Jenis peta yang dipilih pengguna (butang lapisan di peta).
enum MapLayer {
  /// Peta vektor biasa (cerah atau malam ikut tema).
  standard,

  /// Imej satelit dengan jalan dan label di atasnya (hibrid).
  satellite;

  static MapLayer fromName(String? name) =>
      values.firstWhere((l) => l.name == name, orElse: () => MapLayer.standard);
}

const mapLayerPrefsKey = 'map.layer';

class MapLayerController extends Notifier<MapLayer> {
  @override
  MapLayer build() => MapLayer.fromName(
    ref.watch(sharedPreferencesProvider).getString(mapLayerPrefsKey),
  );

  Future<void> set(MapLayer layer) async {
    if (state == layer) return;
    state = layer;
    await ref
        .read(sharedPreferencesProvider)
        .setString(mapLayerPrefsKey, layer.name);
  }
}

final mapLayerProvider = NotifierProvider<MapLayerController, MapLayer>(
  MapLayerController.new,
);
