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

  /// Jarak sepanjang laluan dari kemajuan semasa (atau 0) ke POI.
  double remainingFrom(double alongNow) =>
      (alongM - alongNow).clamp(0.0, double.infinity);
}
