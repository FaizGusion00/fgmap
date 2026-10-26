import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../search/domain/place.dart';
import '../../search/domain/place_json.dart';
import '../domain/saved_place.dart';

const _savedKey = 'saved.v1';
const _schemaVersion = 1;

/// Tempat disimpan (Rumah, Kerja, kegemaran) dalam storan setempat. Rosak/versi tidak dikenali ->
/// senarai kosong (tidak merosakkan app); had 30 kegemaran supaya storan tidak membesar tanpa had.
class SavedPlacesController extends Notifier<List<SavedPlace>> {
  static const maxFavorites = 30;

  @override
  List<SavedPlace> build() =>
      _decode(ref.watch(sharedPreferencesProvider).getString(_savedKey));

  SavedPlace? get home => _byId(SavedPlace.homeId);
  SavedPlace? get work => _byId(SavedPlace.workId);

  SavedPlace? _byId(String id) {
    for (final s in state) {
      if (s.id == id) return s;
    }
    return null;
  }

  Iterable<SavedPlace> get favorites =>
      state.where((s) => s.kind == SavedKind.favorite);

  bool isFavorite(Place place) =>
      state.any((s) => s.id == SavedPlace.favoriteId(place));

  Future<void> setHome(Place place) => _put(
    SavedPlace(id: SavedPlace.homeId, kind: SavedKind.home, place: place),
  );

  Future<void> setWork(Place place) => _put(
    SavedPlace(id: SavedPlace.workId, kind: SavedKind.work, place: place),
  );

  /// Menambah atau membuang kegemaran; pulangkan benar jika kini disimpan.
  Future<bool> toggleFavorite(Place place) async {
    final id = SavedPlace.favoriteId(place);
    if (state.any((s) => s.id == id)) {
      await remove(id);
      return false;
    }
    await _put(SavedPlace(id: id, kind: SavedKind.favorite, place: place));
    return true;
  }

  Future<void> remove(String id) async {
    state = [
      for (final s in state)
        if (s.id != id) s,
    ];
    await _persist();
  }

  Future<void> clear() async {
    state = const [];
    await _persist();
  }

  Future<void> _put(SavedPlace item) async {
    final next = <SavedPlace>[
      item,
      for (final s in state)
        if (s.id != item.id) s,
    ];
    // Kegemaran paling lama dibuang apabila melebihi had (Rumah/Kerja tidak pernah dibuang).
    var favorites = 0;
    state = [
      for (final s in next)
        if (s.kind != SavedKind.favorite || ++favorites <= maxFavorites) s,
    ];
    await _persist();
  }

  Future<void> _persist() => ref
      .read(sharedPreferencesProvider)
      .setString(
        _savedKey,
        jsonEncode({
          'v': _schemaVersion,
          'items': [
            for (final s in state)
              {'id': s.id, 'kind': s.kind.name, 'place': placeToJson(s.place)},
          ],
        }),
      );

  static List<SavedPlace> _decode(String? raw) {
    if (raw == null) return const [];
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != _schemaVersion) {
        return const [];
      }
      final items = json['items'];
      if (items is! List) return const [];
      final out = <SavedPlace>[];
      final seen = <String>{};
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final id = item['id'];
        final kind = SavedKind.values.where((k) => k.name == item['kind']);
        final place = placeFromJson(item['place']);
        if (id is! String || kind.isEmpty || place == null || !seen.add(id)) {
          continue;
        }
        out.add(SavedPlace(id: id, kind: kind.first, place: place));
      }
      return out;
    } on FormatException {
      return const [];
    }
  }
}

final savedPlacesControllerProvider =
    NotifierProvider<SavedPlacesController, List<SavedPlace>>(
      SavedPlacesController.new,
    );
