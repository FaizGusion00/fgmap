import 'package:fgmap/features/cameras/domain/osm_camera_tags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('direction OSM: darjah, negatif, kardinal', () {
    expect(parseOsmDirection('305'), 305);
    expect(parseOsmDirection(' 82 '), 82);
    expect(parseOsmDirection('-90'), 270);
    expect(parseOsmDirection('360'), 0);
    expect(parseOsmDirection(140), 140);
    expect(parseOsmDirection(12.5), 12.5);
    expect(parseOsmDirection('N'), 0);
    expect(parseOsmDirection('ne'), 45);
    expect(parseOsmDirection('WNW'), 292.5);
    expect(parseOsmDirection('S'), 180);
  });

  test('direction OSM: forward/backward/both dan lain = tidak diketahui', () {
    for (final v in [
      null,
      '',
      'forward',
      'backward',
      'both',
      'clockwise',
      'Southbound',
      '90;270',
      'abc',
    ]) {
      expect(parseOsmDirection(v), isNull, reason: '$v');
    }
  });

  test('bound daripada nama', () {
    expect(boundFromText('AES Taiping - Northbound'), 'NB');
    expect(boundFromText('AWAS Pagoh -  Southbound'), 'SB');
    expect(boundFromText('KM 185 Lebuhraya PLUS, Jasin (SB)'), 'SB');
    expect(boundFromText('PLUS Pagoh KM 151.4 (NB)'), 'NB');
    expect(boundFromText('AES Exit Chukai Eastbound'), 'EB');
    expect(boundFromText('Southbound'), 'SB');
    expect(boundFromText('AES SKVE'), isNull);
    expect(boundFromText('Kampung Nibong'), isNull);
    expect(boundFromText(null), isNull);
  });

  test('maxspeed km/j', () {
    expect(parseMaxspeedKmh('110'), 110);
    expect(parseMaxspeedKmh('90 km/h'), 90);
    expect(parseMaxspeedKmh('50 mph'), 80);
    expect(parseMaxspeedKmh(70), 70);
    expect(parseMaxspeedKmh('signals'), isNull);
    expect(parseMaxspeedKmh('0'), isNull);
    expect(parseMaxspeedKmh(null), isNull);
  });

  test('jenis kamera daripada enforcement', () {
    expect(cameraTypeFromEnforcement('maxspeed'), 'speed');
    expect(cameraTypeFromEnforcement(null), 'speed');
    expect(cameraTypeFromEnforcement('traffic_signals'), 'red_light');
    expect(cameraTypeFromEnforcement('red_light_camera'), 'red_light');
  });
}
