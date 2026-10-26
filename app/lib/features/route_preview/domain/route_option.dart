import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jenis kenderaan untuk costing Valhalla. Motosikal penting di Malaysia (laluan dan lebuh raya berbeza).
enum RouteVehicle {
  car('auto'),
  motorcycle('motorcycle');

  const RouteVehicle(this.costing);

  /// Nama costing Valhalla.
  final String costing;
}

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

/// Sifat yang membezakan satu pilihan laluan daripada yang lain (dipaparkan sebagai label kad).
enum RouteLabel {
  /// Pilihan utama: skor terbaik (masa, belokan, jalan selamat) dalam lingkungan masa terpantas.
  recommended,

  /// Masa perjalanan paling singkat (hanya apabila bukan pilihan utama).
  fastest,

  /// Bilangan belokan paling sedikit (mudah diikuti, kurang risiko tersilap lorong).
  simplest,

  /// Jarak paling pendek (dan jelas lebih pendek daripada yang terpantas).
  shortest,

  /// Laluan tanpa tol, ditawarkan bila yang terpantas ada tol.
  noTolls,

  /// Laluan yang mengutamakan jalan biasa berbanding lebuh raya.
  noHighways,

  /// Laluan lain yang berbeza daripada yang di atas.
  alternative,
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
    this.label = RouteLabel.fastest,
    this.hasHighway = false,
    this.hasFerry = false,
    this.hasTimeRestrictions = false,
  });

  final int distanceM;
  final int durationS;
  final bool hasTolls;
  final List<GeoPoint> points;
  final List<Maneuver> maneuvers;
  final RouteSource source;
  final RouteLabel label;

  /// Melalui lebuh raya / ekspres (daripada ringkasan Valhalla).
  final bool hasHighway;

  /// Menaiki feri.
  final bool hasFerry;

  /// Melalui jalan bersekatan masa (cth. dibuka waktu tertentu sahaja).
  final bool hasTimeRestrictions;

  RouteOption copyWith({RouteLabel? label}) => RouteOption(
    distanceM: distanceM,
    durationS: durationS,
    hasTolls: hasTolls,
    points: points,
    maneuvers: maneuvers,
    source: source,
    label: label ?? this.label,
    hasHighway: hasHighway,
    hasFerry: hasFerry,
    hasTimeRestrictions: hasTimeRestrictions,
  );

  RouteOption withLabel(RouteLabel label) => copyWith(label: label);

  /// Nama jalan utama laluan ("melalui ..."): jalan bernama dengan jarak terkumpul terpanjang.
  /// Null jika tiada manuver bernama (cth. laluan dibina tanpa arahan).
  String? get via {
    final byRoad = <String, int>{};
    for (final m in maneuvers) {
      if (m.streetNames.isEmpty) continue;
      final name = m.streetNames.first;
      byRoad[name] = (byRoad[name] ?? 0) + m.lengthM;
    }
    String? best;
    var bestM = -1;
    byRoad.forEach((name, meters) {
      if (meters > bestM) {
        best = name;
        bestM = meters;
      }
    });
    return best;
  }
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
    this.avoidHighways = false,
    this.vehicle = RouteVehicle.car,
    this.destinationLabel,
    this.alternates = 2,
    this.destinationRadiusM,
    this.shortest = false,
    this.exclusions = const [],
  });

  final GeoPoint origin;
  final GeoPoint destination;
  final int? headingDegrees;
  final bool avoidTolls;
  final bool avoidHighways;
  final RouteVehicle vehicle;

  /// Nama destinasi untuk dipaparkan. Null = titik yang dipilih pada peta.
  final String? destinationLabel;

  /// Bilangan laluan alternatif tambahan yang diminta daripada Valhalla (0 = hanya satu laluan).
  final int alternates;

  /// Jarak carian calon jalan di sekitar destinasi (meter), untuk bangunan/kawasan yang titik
  /// tengahnya bukan pintu masuk. Null = Valhalla memilih tepi jalan terdekat.
  final double? destinationRadiusM;

  /// Utamakan jarak terpendek (costing `shortest` Valhalla).
  final bool shortest;

  /// Kawasan bulat yang mesti dielakkan (memaksa lencongan untuk laluan alternatif yang benar-benar
  /// berbeza). Kosong untuk permintaan biasa.
  final List<RouteExclusion> exclusions;

  RouteQuery copyWith({
    bool? avoidTolls,
    bool? avoidHighways,
    RouteVehicle? vehicle,
    int? alternates,
    bool? shortest,
    List<RouteExclusion>? exclusions,
  }) {
    return RouteQuery(
      origin: origin,
      destination: destination,
      headingDegrees: headingDegrees,
      avoidTolls: avoidTolls ?? this.avoidTolls,
      avoidHighways: avoidHighways ?? this.avoidHighways,
      vehicle: vehicle ?? this.vehicle,
      destinationLabel: destinationLabel,
      alternates: alternates ?? this.alternates,
      destinationRadiusM: destinationRadiusM,
      shortest: shortest ?? this.shortest,
      exclusions: exclusions ?? this.exclusions,
    );
  }

  /// Permintaan baharu ke destinasi yang sama dari [origin] (cth. mengira semula bila menyimpang).
  /// Kenderaan, pilihan elak dan nama destinasi dikekalkan; hanya satu laluan diminta.
  RouteQuery rerouteFrom(GeoPoint origin, {int? headingDegrees}) {
    return RouteQuery(
      origin: origin,
      destination: destination,
      headingDegrees: headingDegrees,
      avoidTolls: avoidTolls,
      avoidHighways: avoidHighways,
      vehicle: vehicle,
      destinationLabel: destinationLabel,
      alternates: 0,
      destinationRadiusM: destinationRadiusM,
      shortest: shortest,
    );
  }
}

/// Kawasan bulat [radiusM] di sekitar [center] yang tidak boleh dilalui laluan (lencongan paksa).
@immutable
class RouteExclusion {
  const RouteExclusion(this.center, this.radiusM);

  final GeoPoint center;
  final double radiusM;
}
