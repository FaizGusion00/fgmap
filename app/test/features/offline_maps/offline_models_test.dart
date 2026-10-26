import 'dart:convert';
import 'dart:io';

import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _valid() => {
  'schema': 1,
  'region': 'malaysia',
  'version': '20261026',
  'valhalla': '3.9.1',
  'file': 'malaysia-20261026.tar.gz',
  'sizeBytes': 253855993,
  'sha256': 'a' * 64,
  'extractedSizeBytes': 682844160,
  'extractedSha256': 'b' * 64,
};

ManifestException _reject(Map<String, Object?> json) {
  try {
    OfflineManifest.fromJson(json);
  } on ManifestException catch (e) {
    return e;
  }
  fail('dijangka ManifestException untuk $json');
}

void main() {
  test('manifest sebenar daripada tools/tiles/build.sh diterima', () {
    final json = jsonDecode(
      File('test/fixtures/manifest_real.json').readAsStringSync(),
    );
    final m = OfflineManifest.fromJson(json);
    expect(m.version, '20261026');
    expect(m.valhalla, expectedValhallaVersion);
    expect(m.sizeBytes, 253855993);
    expect(m.file, 'malaysia-20261026.tar.gz');
  });

  test(
    'versi enjin yang dijangka sepadan dengan tools/tiles/VERSIONS (satu sumber kebenaran)',
    () {
      final versions = File('../tools/tiles/VERSIONS').readAsStringSync();
      expect(versions, contains('VALHALLA_VERSION=$expectedValhallaVersion'));
    },
  );

  group('menolak manifest yang tidak sah', () {
    final cases = <String, void Function(Map<String, Object?>)>{
      'skema lain': (j) => j['schema'] = 2,
      'medan hilang': (j) => j.remove('sha256'),
      'jenis salah': (j) => j['sizeBytes'] = '253855993',
      'saiz sifar': (j) => j['sizeBytes'] = 0,
      'saiz negatif': (j) => j['extractedSizeBytes'] = -1,
      'sha256 pendek': (j) => j['sha256'] = 'abc',
      'sha256 huruf besar': (j) => j['sha256'] = 'A' * 64,
      'sha256 bukan hex': (j) => j['extractedSha256'] = 'z' * 64,
      'versi bukan tarikh': (j) => j['version'] = 'latest',
      'versi pendek': (j) => j['version'] = '2026',
      'nama fail laluan': (j) => j['file'] = 'sub/dir/pack.tar.gz',
      'nama fail naik direktori': (j) => j['file'] = '../pack.tar.gz',
      'nama fail naik tersembunyi': (j) => j['file'] = 'a..b/../c',
      'nama fail URL mutlak': (j) =>
          j['file'] = 'https://evil.example/pack.tar.gz',
      'nama fail laluan mutlak': (j) => j['file'] = '/etc/passwd',
      'nama fail bermula titik': (j) => j['file'] = '.hidden',
      'nama fail kosong': (j) => j['file'] = '',
      'nama fail dengan ruang': (j) => j['file'] = 'pack file.tar.gz',
    };
    cases.forEach((name, mutate) {
      test(name, () {
        final json = _valid();
        mutate(json);
        final e = _reject(json);
        expect(e.incompatible, isFalse);
      });
    });

    test('bukan objek', () {
      expect(
        () => OfflineManifest.fromJson([1]),
        throwsA(isA<ManifestException>()),
      );
      expect(
        () => OfflineManifest.fromJson(null),
        throwsA(isA<ManifestException>()),
      );
    });
  });

  test('versi Valhalla tidak serasi ditolak dan ditandakan incompatible', () {
    for (final v in ['3.5.1', '3.9.0', '3.10.0', '4.0.0']) {
      final json = _valid()..['valhalla'] = v;
      final e = _reject(json);
      expect(e.incompatible, isTrue, reason: v);
      expect(e.message, contains(v));
    }
  });
}
