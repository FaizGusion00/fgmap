import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../domain/place.dart';
import '../domain/place_json.dart';

const _historyKey = 'search.history.v1';
const _historyLimit = 10;

class SearchHistoryController extends Notifier<List<Place>> {
  @override
  List<Place> build() {
    final saved = ref
        .watch(sharedPreferencesProvider)
        .getStringList(_historyKey);
    if (saved == null) return const [];
    return [for (final item in saved) ?_decode(item)];
  }

  Future<void> record(Place place) async {
    final key = _placeKey(place);
    final next = [
      place,
      ...state.where((item) => _placeKey(item) != key),
    ].take(_historyLimit).toList();
    state = next;
    await _persist(next);
  }

  Future<void> clear() async {
    state = const [];
    await _persist(state);
  }

  Future<void> _persist(List<Place> places) async {
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(_historyKey, places.map(_encode).toList());
  }

  static String _placeKey(Place place) =>
      '${place.point.lat.toStringAsFixed(5)},${place.point.lng.toStringAsFixed(5)}';

  static String _encode(Place place) => jsonEncode(placeToJson(place));

  static Place? _decode(String value) {
    try {
      return placeFromJson(jsonDecode(value));
    } on FormatException {
      return null;
    }
  }
}

final searchHistoryControllerProvider =
    NotifierProvider<SearchHistoryController, List<Place>>(
      SearchHistoryController.new,
    );
