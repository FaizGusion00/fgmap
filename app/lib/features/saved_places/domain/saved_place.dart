import 'package:flutter/foundation.dart';

import '../../search/domain/place.dart';

enum SavedKind { home, work, favorite }

/// Tempat yang disimpan pengguna. Rumah dan Kerja hanya satu setiap satu (id tetap); kegemaran
/// dikenal pasti mengikut koordinat dibundar supaya tempat sama tidak berganda.
@immutable
class SavedPlace {
  const SavedPlace({required this.id, required this.kind, required this.place});

  final String id;
  final SavedKind kind;
  final Place place;

  static const homeId = 'home';
  static const workId = 'work';

  static String favoriteId(Place place) =>
      'fav-${place.point.lat.toStringAsFixed(5)},${place.point.lng.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is SavedPlace &&
      other.id == id &&
      other.kind == kind &&
      other.place == place;

  @override
  int get hashCode => Object.hash(id, kind, place);
}
