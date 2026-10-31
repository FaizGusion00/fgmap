import 'dart:convert';

import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/trip_record.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/route_preview/domain/route_option.dart';
import 'package:flutter_test/flutter_test.dart';

const _origin = GeoPoint(3.1579, 101.7116);
const _dest = GeoPoint(2.7456, 101.7072);

RouteOption _route() => const RouteOption(
  distanceM: 60000,
  durationS: 3000,
  hasTolls: true,
  points: [_origin, GeoPoint(3.0, 101.7), _dest],
);

NavigationTrip _trip(RouteQuery q) => NavigationTrip(
  savedAt: DateTime.utc(2026, 5, 1),
  route: _route(),
  query: q,
  alongM: 100,
  language: VoiceLanguage.ms,
  position: _origin,
  bearing: 0,
  speedMps: 0,
);

void main() {
  test('via pergi balik dengan susunan dikekalkan', () {
    const via = [GeoPoint(3.0912, 101.7), GeoPoint(2.9, 101.65)];
    final back =
        decodeTrip(
              encodeTrip(
                _trip(
                  const RouteQuery(
                    origin: _origin,
                    destination: _dest,
                    via: via,
                  ),
                ),
              ),
            )!
            as NavigationTrip;
    expect(back.query.via, via);
    expect(back.query.destination, _dest);
  });

  test('tanpa via memberi senarai kosong', () {
    final back =
        decodeTrip(
              encodeTrip(
                _trip(const RouteQuery(origin: _origin, destination: _dest)),
              ),
            )!
            as NavigationTrip;
    expect(back.query.via, isEmpty);
  });

  test('rekod lama tanpa kunci via masih dinyahkod', () {
    final json = _trip(
      const RouteQuery(origin: _origin, destination: _dest),
    ).toJson();
    final query = Map<String, Object?>.from(json['query']! as Map)
      ..remove('via');
    json['query'] = query;
    final back = decodeTrip(jsonEncode(json))! as NavigationTrip;
    expect(back.query.via, isEmpty);
  });

  test('entri via rosak dilangkau, yang sah dikekalkan', () {
    final json = _trip(
      const RouteQuery(origin: _origin, destination: _dest),
    ).toJson();
    final query = Map<String, Object?>.from(json['query']! as Map)
      ..['via'] = [
        {'lat': 3.0, 'lng': 101.5},
        'sampah',
        {'lat': 2.9},
        {'lat': 2.8, 'lng': 101.6},
      ];
    json['query'] = query;
    final back = decodeTrip(jsonEncode(json))! as NavigationTrip;
    expect(back.query.via, const [GeoPoint(3.0, 101.5), GeoPoint(2.8, 101.6)]);
  });

  test('via bertaip salah menolak keseluruhan rekod (tidak ranap)', () {
    final json = _trip(
      const RouteQuery(origin: _origin, destination: _dest),
    ).toJson();
    final query = Map<String, Object?>.from(json['query']! as Map)
      ..['via'] = [
        {'lat': 'x', 'lng': 1},
      ];
    json['query'] = query;
    expect(decodeTrip(jsonEncode(json)), isNull);
  });

  test('via ditulis sebagai senarai lat/lng dalam JSON', () {
    final json = _trip(
      const RouteQuery(
        origin: _origin,
        destination: _dest,
        via: [GeoPoint(3.0, 101.5)],
      ),
    ).toJson();
    final via = (json['query']! as Map)['via'] as List;
    expect(via, [
      {'lat': 3.0, 'lng': 101.5},
    ]);
  });
}
