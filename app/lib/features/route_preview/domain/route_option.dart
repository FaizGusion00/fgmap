import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Dari mana laluan dikira.
enum RouteSource {
  /// API Valhalla awam: data paling segar.
  online,

  /// Enjin Valhalla dalam peranti terhadap pek peta yang dimuat turun.
  offline,
}

/// Satu langkah arahan. `type` ialah jenis manuver mentah Valhalla; ayat BM/EN dijana dalam app
/// kemudian (Bahagian 8.2 pelan), jadi teks Valhalla sengaja diabaikan.
@immutable
class Maneuver {
  const Maneuver({
    required this.type,
    required this.streetNames,
    required this.lengthM,
    required this.timeS,
    required this.beginShapeIndex,
    this.roundaboutExitCount,
  });

  final int type;
  final List<String> streetNames;
  final int lengthM;
  final int timeS;

  /// Indeks titik dalam [RouteOption.points] tempat manuver bermula.
  final int beginShapeIndex;

  /// Keluar ke berapa pada bulatan (hanya untuk manuver masuk bulatan).
  final int? roundaboutExitCount;
}

/// Satu pilihan laluan, sedia dipaparkan (geometri telah dinyahkod).
@immutable
class RouteOption {
  const RouteOption({
    required this.distanceM,
    required this.durationS,
    required this.hasTolls,
    required this.points,
    this.maneuvers = const [],
    this.source = RouteSource.online,
  });

  final int distanceM;
  final int durationS;
  final bool hasTolls;
  final List<GeoPoint> points;
  final List<Maneuver> maneuvers;
  final RouteSource source;
}

/// Parameter satu permintaan laluan; disimpan supaya "cuba lagi" dan tukar pilihan boleh
/// mengulang permintaan yang sama.
@immutable
class RouteQuery {
  const RouteQuery({
    required this.origin,
    required this.destination,
    this.headingDegrees,
    this.avoidTolls = false,
    this.destinationLabel,
  });

  final GeoPoint origin;
  final GeoPoint destination;
  final int? headingDegrees;
  final bool avoidTolls;

  /// Nama destinasi untuk dipaparkan. Null = titik yang dipilih pada peta.
  final String? destinationLabel;

  RouteQuery copyWith({bool? avoidTolls}) {
    return RouteQuery(
      origin: origin,
      destination: destination,
      headingDegrees: headingDegrees,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      destinationLabel: destinationLabel,
    );
  }
}
