import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';
import 'along_route_category.dart';

@immutable
class AlongRoutePoi {
  const AlongRoutePoi({
    required this.id,
    required this.category,
    required this.name,
    required this.point,
    required this.alongM,
    required this.crossTrackM,
    this.subtitle = '',
  });

  final String id;
  final AlongRouteCategory category;
  final String name;
  final GeoPoint point;
  final double alongM;
  final double crossTrackM;
  final String subtitle;

  Map<String, Object?> toJson() => {
    'id': id,
    'c': category.name,
    'n': name,
    'lat': point.lat,
    'lng': point.lng,
    'a': alongM,
    'x': crossTrackM,
    if (subtitle.isNotEmpty) 's': subtitle,
  };

  static AlongRoutePoi? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final category = AlongRouteCategory.values
        .where((c) => c.name == raw['c'])
        .firstOrNull;
    final lat = raw['lat'];
    final lng = raw['lng'];
    final along = raw['a'];
    final cross = raw['x'];
    if (category == null ||
        lat is! num ||
        lng is! num ||
        along is! num ||
        cross is! num) {
      return null;
    }
    return AlongRoutePoi(
      id: raw['id']?.toString() ?? '',
      category: category,
      name: raw['n']?.toString() ?? '',
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      alongM: along.toDouble(),
      crossTrackM: cross.toDouble(),
      subtitle: raw['s']?.toString() ?? '',
    );
  }

  /// Jarak sepanjang laluan dari kemajuan semasa (atau 0) ke POI.
  double remainingFrom(double alongNow) =>
      (alongM - alongNow).clamp(0.0, double.infinity);
}
