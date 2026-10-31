import 'dart:convert';

import '../../../core/utils/geo.dart';
import '../../route_preview/domain/route_option.dart';
import '../../speed_limits/data/speed_limit_service.dart';
import '../domain/instruction_text.dart';

/// Perjalanan aktif yang boleh dipulihkan selepas proses mati.
///
/// Navigasi menyimpan destinasi, laluan, kemajuan dan bahasa arahan. Memandu bebas menyimpan
/// kedudukan terakhir. Tiada perjalanan: rekod ini tidak wujud.
sealed class TripRecord {
  const TripRecord({required this.savedAt});

  final DateTime savedAt;

  bool restorable(DateTime now);

  Map<String, Object?> toJson();
}

class NavigationTrip extends TripRecord {
  const NavigationTrip({
    required super.savedAt,
    required this.route,
    required this.query,
    required this.alongM,
    required this.language,
    required this.position,
    required this.bearing,
    required this.speedMps,
    this.arrived = false,
  });

  final RouteOption route;
  final RouteQuery query;
  final double alongM;
  final VoiceLanguage language;
  final GeoPoint position;
  final double bearing;
  final double speedMps;
  final bool arrived;

  @override
  bool restorable(DateTime now) => route.points.length >= 2;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'navigation',
    'savedAt': savedAt.millisecondsSinceEpoch,
    'alongM': alongM,
    'language': language.code,
    'lat': position.lat,
    'lng': position.lng,
    'bearing': bearing,
    'speedMps': speedMps,
    'arrived': arrived,
    'route': _encodeRoute(route),
    'query': _encodeQuery(query),
  };
}

class CruiseTrip extends TripRecord {
  const CruiseTrip({
    required super.savedAt,
    required this.position,
    required this.bearing,
    required this.speedMps,
    this.limitKmh,
    this.languageCode = 'ms',
  });

  final GeoPoint position;
  final double bearing;
  final double speedMps;
  final int? limitKmh;
  final String languageCode;

  /// Kereta yang sudah lama berhenti tidak dipulihkan sebagai memandu bebas.
  @override
  bool restorable(DateTime now) =>
      speedMps >= 1 || now.difference(savedAt) < CruiseTrip.parkedLimit;

  static const parkedLimit = Duration(seconds: 45);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'cruise',
    'savedAt': savedAt.millisecondsSinceEpoch,
    'lat': position.lat,
    'lng': position.lng,
    'bearing': bearing,
    'speedMps': speedMps,
    'limitKmh': limitKmh,
    'language': languageCode,
  };
}

/// Dipanggil oleh pengawal navigasi sebelum langganan GPS baharu, supaya memandu bebas melepaskan
/// strim yang sama dahulu. Null sehingga pengawal cruise dibina.
void Function()? releaseActiveCruise;

String? encodeTrip(TripRecord record) => jsonEncode(record.toJson());

TripRecord? decodeTrip(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final json = decoded.cast<String, Object?>();
    final savedAt = DateTime.fromMillisecondsSinceEpoch(
      (json['savedAt'] as num?)?.toInt() ?? 0,
      isUtc: true,
    );
    switch (json['kind']) {
      case 'navigation':
        final route = _decodeRoute(json['route']);
        final query = _decodeQuery(json['query']);
        if (route == null || query == null) return null;
        return NavigationTrip(
          savedAt: savedAt,
          route: route,
          query: query,
          alongM: (json['alongM'] as num?)?.toDouble() ?? 0,
          language: VoiceLanguage.fromCode(json['language'] as String?),
          position: GeoPoint(
            (json['lat'] as num?)?.toDouble() ?? route.points.first.lat,
            (json['lng'] as num?)?.toDouble() ?? route.points.first.lng,
          ),
          bearing: (json['bearing'] as num?)?.toDouble() ?? 0,
          speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0,
          arrived: json['arrived'] == true,
        );
      case 'cruise':
        final lat = (json['lat'] as num?)?.toDouble();
        final lng = (json['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return CruiseTrip(
          savedAt: savedAt,
          position: GeoPoint(lat, lng),
          bearing: (json['bearing'] as num?)?.toDouble() ?? 0,
          speedMps: (json['speedMps'] as num?)?.toDouble() ?? 0,
          limitKmh: (json['limitKmh'] as num?)?.toInt(),
          languageCode: json['language'] as String? ?? 'ms',
        );
      default:
        return null;
    }
  } on Object {
    return null;
  }
}

Map<String, Object?> _encodeRoute(RouteOption route) => {
  'distanceM': route.distanceM,
  'durationS': route.durationS,
  'hasTolls': route.hasTolls,
  'hasHighway': route.hasHighway,
  'hasFerry': route.hasFerry,
  'hasTimeRestrictions': route.hasTimeRestrictions,
  'source': route.source.name,
  'label': route.label.name,
  'shape': encodePolyline6(route.points),
  'maneuvers': [
    for (final m in route.maneuvers)
      {
        'type': m.type,
        'streets': m.streetNames,
        'lengthM': m.lengthM,
        'timeS': m.timeS,
        'begin': m.beginShapeIndex,
        'exit': m.roundaboutExitCount,
        'toll': m.toll,
        if (m.lanes.isNotEmpty) 'lanes': [for (final l in m.lanes) l.toJson()],
      },
  ],
};

RouteOption? _decodeRoute(Object? raw) {
  if (raw is! Map) return null;
  final json = raw.cast<String, Object?>();
  final shape = json['shape'];
  if (shape is! String || shape.isEmpty) return null;
  List<GeoPoint> points;
  try {
    points = decodePolyline(shape);
  } on FormatException {
    return null;
  }
  if (points.length < 2) return null;
  final maneuvers = <Maneuver>[];
  final list = json['maneuvers'];
  if (list is List) {
    for (final item in list) {
      if (item is! Map) continue;
      final m = item.cast<String, Object?>();
      final streets = m['streets'];
      maneuvers.add(
        Maneuver(
          type: (m['type'] as num?)?.toInt() ?? 0,
          streetNames: streets is List
              ? [for (final s in streets) s.toString()]
              : const [],
          lengthM: (m['lengthM'] as num?)?.toInt() ?? 0,
          timeS: (m['timeS'] as num?)?.toInt() ?? 0,
          beginShapeIndex: (m['begin'] as num?)?.toInt() ?? 0,
          roundaboutExitCount: (m['exit'] as num?)?.toInt(),
          toll: m['toll'] == true,
          lanes: m['lanes'] is List
              ? [for (final l in m['lanes'] as List) ?Lane.fromJson(l)]
              : const [],
        ),
      );
    }
  }
  return RouteOption(
    distanceM: (json['distanceM'] as num?)?.toInt() ?? 0,
    durationS: (json['durationS'] as num?)?.toInt() ?? 0,
    hasTolls: json['hasTolls'] == true,
    points: points,
    maneuvers: maneuvers,
    source: RouteSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => RouteSource.online,
    ),
    label: RouteLabel.values.firstWhere(
      (s) => s.name == json['label'],
      orElse: () => RouteLabel.fastest,
    ),
    hasHighway: json['hasHighway'] == true,
    hasFerry: json['hasFerry'] == true,
    hasTimeRestrictions: json['hasTimeRestrictions'] == true,
  );
}

Map<String, Object?> _encodeQuery(RouteQuery query) => {
  'originLat': query.origin.lat,
  'originLng': query.origin.lng,
  'destLat': query.destination.lat,
  'destLng': query.destination.lng,
  'heading': query.headingDegrees,
  'avoidTolls': query.avoidTolls,
  'avoidHighways': query.avoidHighways,
  'vehicle': query.vehicle.name,
  'label': query.destinationLabel,
  'radiusM': query.destinationRadiusM,
  'shortest': query.shortest,
  'headingTolerance': query.headingToleranceDegrees,
};

RouteQuery? _decodeQuery(Object? raw) {
  if (raw is! Map) return null;
  final json = raw.cast<String, Object?>();
  final oLat = (json['originLat'] as num?)?.toDouble();
  final oLng = (json['originLng'] as num?)?.toDouble();
  final dLat = (json['destLat'] as num?)?.toDouble();
  final dLng = (json['destLng'] as num?)?.toDouble();
  if (oLat == null || oLng == null || dLat == null || dLng == null) return null;
  return RouteQuery(
    origin: GeoPoint(oLat, oLng),
    destination: GeoPoint(dLat, dLng),
    headingDegrees: (json['heading'] as num?)?.toInt(),
    avoidTolls: json['avoidTolls'] == true,
    avoidHighways: json['avoidHighways'] == true,
    vehicle: json['vehicle'] == 'motorcycle'
        ? RouteVehicle.motorcycle
        : RouteVehicle.car,
    destinationLabel: json['label'] as String?,
    destinationRadiusM: (json['radiusM'] as num?)?.toDouble(),
    shortest: json['shortest'] == true,
    headingToleranceDegrees: (json['headingTolerance'] as num?)?.toInt(),
    alternates: 0,
  );
}
