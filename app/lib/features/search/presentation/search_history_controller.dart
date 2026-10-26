import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../domain/place.dart';

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

  static String _encode(Place place) => jsonEncode({
    'name': place.name,
    'subtitle': place.subtitle,
    'lat': place.point.lat,
    'lng': place.point.lng,
    'category': place.category,
  });

  static Place? _decode(String value) {
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic>) return null;
      final name = json['name'];
      final subtitle = json['subtitle'];
      final lat = json['lat'];
      final lng = json['lng'];
      final category = json['category'];
      if (name is! String ||
          subtitle is! String ||
          lat is! num ||
          lng is! num ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180 ||
          (category != null && category is! String)) {
        return null;
      }
      return Place(
        name: name,
        subtitle: subtitle,
        point: GeoPoint(lat.toDouble(), lng.toDouble()),
        category: category is String ? category : null,
      );
    } on FormatException {
      return null;
    }
  }
}

final searchHistoryControllerProvider =
    NotifierProvider<SearchHistoryController, List<Place>>(
      SearchHistoryController.new,
    );
