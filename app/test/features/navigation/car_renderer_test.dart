import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fgmap/features/navigation/presentation/car/car_mesh.dart';
import 'package:fgmap/features/navigation/presentation/car/car_renderer.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kotak sempadan piksel yang dilukis (alfa > 40) dan piksel berwarna tertentu.
class _Render {
  _Render(this.minX, this.maxX, this.minY, this.maxY, this.rgba, this.size);

  final int minX, maxX, minY, maxY;
  final Uint8List rgba;
  final int size;

  int get width => maxX - minX + 1;
  int get height => maxY - minY + 1;
  double get centerX => (minX + maxX) / 2;
  double get centerY => (minY + maxY) / 2;

  int count(bool Function(int r, int g, int b, int a) test) {
    var n = 0;
    for (var i = 0; i < size * size; i++) {
      if (test(
        rgba[i * 4],
        rgba[i * 4 + 1],
        rgba[i * 4 + 2],
        rgba[i * 4 + 3],
      )) {
        n++;
      }
    }
    return n;
  }
}

Future<_Render> _render({
  double yaw = 0,
  double tilt = 0,
  double length = 200,
  double brake = 0,
  CarPalette? palette,
}) async {
  const size = 480;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CarRenderer().paint(
    canvas,
    anchor: const Offset(size / 2, size / 2),
    lengthPx: length,
    yawDeg: yaw,
    tiltDeg: tilt,
    brake: brake,
    shadow: false,
    palette:
        palette ??
        CarPalette.fromPrimary(const Color(0xFF2563EB)).withoutHalo(),
  );
  final image = await recorder.endRecording().toImage(size, size);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  final rgba = data.buffer.asUint8List();
  var minX = size, maxX = -1, minY = size, maxY = -1;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      if (rgba[(y * size + x) * 4 + 3] > 40) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }
  return _Render(minX, maxX, minY, maxY, rgba, size);
}

bool _isTaillight(int r, int g, int b, int a) =>
    a > 200 && r > 220 && g < 120 && b < 140;
bool _isHeadlight(int r, int g, int b, int a) =>
    a > 200 && r > 235 && g > 225 && b > 160 && b < 235;

void main() {
  group('CarMesh', () {
    final mesh = CarMesh.standard;

    test('model sah: muka, indeks dan normal', () {
      expect(mesh.faces.length, greaterThan(100));
      expect(mesh.vertexCount, greaterThan(100));
      for (final face in mesh.faces) {
        expect(face.vertices.length, greaterThanOrEqualTo(3));
        for (final v in face.vertices) {
          expect(v, inInclusiveRange(0, mesh.vertexCount - 1));
        }
        final len = math.sqrt(
          face.nx * face.nx + face.ny * face.ny + face.nz * face.nz,
        );
        expect(len, closeTo(1, 1e-9));
      }
      expect(mesh.positions.every((v) => v.isFinite), isTrue);
      expect(mesh.footprint.length % 2, 0);
    });

    test('ukuran seperti kereta sebenar (meter)', () {
      var minX = 1e9,
          maxX = -1e9,
          minY = 1e9,
          maxY = -1e9,
          minZ = 1e9,
          maxZ = -1e9;
      for (var i = 0; i < mesh.vertexCount; i++) {
        final x = mesh.positions[i * 3];
        final y = mesh.positions[i * 3 + 1];
        final z = mesh.positions[i * 3 + 2];
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
        minZ = math.min(minZ, z);
        maxZ = math.max(maxZ, z);
      }
      expect(maxY - minY, closeTo(CarMesh.length, 0.2));
      expect(maxX - minX, inInclusiveRange(1.8, 2.2));
      expect(minZ, 0, reason: 'roda di atas tanah');
      expect(maxZ, closeTo(CarMesh.height, 0.01));
      // Simetri kiri-kanan.
      expect(minX, closeTo(-maxX, 1e-6));
    });

    test(
      'sisi badan, bahu dan kabin menghala ke luar (bukan ke dalam kereta)',
      () {
        var checked = 0;
        for (final face in mesh.faces.where(
          (f) => f.order >= 1 && f.order <= 3,
        )) {
          var cx = 0.0, cy = 0.0;
          for (final v in face.vertices) {
            cx += mesh.positions[v * 3];
            cy += mesh.positions[v * 3 + 1];
          }
          cx /= face.vertices.length;
          cy /= face.vertices.length;
          final horizontal = math.sqrt(face.nx * face.nx + face.ny * face.ny);
          if (horizontal > 0.5) {
            checked++;
            expect(
              face.nx * cx + face.ny * (cy + 0.3),
              greaterThan(-0.3),
              reason: 'normal ke dalam pada muka ${face.material}',
            );
          } else {
            // Muka hampir mendatar: atas, bukan bawah.
            expect(face.nz, greaterThan(0));
          }
        }
        expect(checked, greaterThan(50));
      },
    );
  });

  group('CarRenderer: perspektif', () {
    test('pandangan atas: panjang dan lebar mengikut nisbah kereta', () async {
      final r = await _render();
      expect(r.height, inInclusiveRange(195, 225));
      expect(r.width, inInclusiveRange(75, 105));
      expect(r.height, greaterThan(r.width * 1.9), reason: 'kereta memanjang');
      expect(
        (r.centerX - 240).abs(),
        lessThan(3),
        reason: 'dipusatkan pada tapak',
      );
    });

    test('diputar 90 darjah: panjang menjadi lebar', () async {
      final up = await _render();
      final side = await _render(yaw: 90);
      expect(side.width, closeTo(up.height, 12));
      expect(side.height, closeTo(up.width, 12));
    });

    test(
      'condongan memendekkan kereta di skrin tetapi menampakkan ketinggian',
      () async {
        final flat = await _render();
        final tilted = await _render(tilt: 56);
        expect(tilted.height, lessThan(flat.height * 0.85));
        expect(tilted.height, greaterThan(flat.height * 0.4));
        // Kereta naik ke atas skrin apabila z diunjurkan (badan menjulang dari tapak).
        expect(tilted.minY, lessThan(240 - 0.3 * 200 * 0.5));
      },
    );

    test(
      'dari belakang lampu belakang paling dekat (lebih bawah di skrin); dari depan sebaliknya',
      () async {
        double meanY(_Render r, bool Function(int, int, int, int) test) {
          var sum = 0, n = 0;
          for (var i = 0; i < r.size * r.size; i++) {
            if (test(
              r.rgba[i * 4],
              r.rgba[i * 4 + 1],
              r.rgba[i * 4 + 2],
              r.rgba[i * 4 + 3],
            )) {
              sum += i ~/ r.size;
              n++;
            }
          }
          return n == 0 ? double.nan : sum / n;
        }

        final rear = await _render(tilt: 56);
        expect(rear.count(_isTaillight), greaterThan(30));
        expect(rear.count(_isHeadlight), greaterThan(30));
        expect(
          meanY(rear, _isTaillight),
          greaterThan(meanY(rear, _isHeadlight) + 40),
        );

        final front = await _render(tilt: 56, yaw: 180);
        expect(
          meanY(front, _isHeadlight),
          greaterThan(meanY(front, _isTaillight) + 40),
        );
      },
    );

    test('lampu brek menambah cahaya merah', () async {
      final off = await _render(tilt: 56);
      final on = await _render(tilt: 56, brake: 1);
      bool reddish(int r, int g, int b, int a) =>
          a > 20 && r > 200 && g < 150 && b < 160;
      expect(on.count(reddish), greaterThan(off.count(reddish)));
    });

    test(
      'semua sudut dan condongan dilukis tanpa ralat dan tidak kosong',
      () async {
        for (var yaw = -180.0; yaw <= 180; yaw += 30) {
          for (var tilt = 0.0; tilt <= 70; tilt += 14) {
            final r = await _render(yaw: yaw, tilt: tilt, length: 120);
            expect(r.width, greaterThan(20), reason: 'yaw $yaw tilt $tilt');
            expect(r.height, greaterThan(20), reason: 'yaw $yaw tilt $tilt');
          }
        }
      },
    );

    test(
      'tilt di luar julat dihad, bukan menghasilkan unjuran songsang',
      () async {
        final capped = await _render(tilt: 200);
        final max = await _render(tilt: 75);
        expect(capped.height, max.height);
      },
    );
  });

  group('CarPalette', () {
    test('warna badan mengikut warna utama; sama nilai = sama', () {
      final a = CarPalette.fromPrimary(const Color(0xFF2563EB));
      final b = CarPalette.fromPrimary(const Color(0xFF2563EB));
      final c = CarPalette.fromPrimary(const Color(0xFFEF4444));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.halo, isNotNull);
      expect(a.withoutHalo().halo, isNull);
      expect(
        HSLColor.fromColor(a.bodyTop).lightness,
        greaterThan(HSLColor.fromColor(a.body).lightness),
      );
    });
  });
}
