import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import 'car_mesh.dart';

/// Warna kereta. Badan mengikut warna utama tema; selebihnya tetap supaya kereta sentiasa kelihatan
/// seperti kereta dalam tema cerah dan gelap.
@immutable
class CarPalette {
  const CarPalette({
    required this.body,
    required this.bodyTop,
    this.glass = const Color(0xFF14233A),
    this.tire = const Color(0xFF151922),
    this.rider = const Color(0xFF51617A),
    this.metal = const Color(0xFF4B5361),
    this.headlight = const Color(0xFFFFF4C9),
    this.taillight = const Color(0xFFFF4D5E),
    this.halo,
  });

  factory CarPalette.fromPrimary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return CarPalette(
      body: hsl
          .withLightness((hsl.lightness * 0.92).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation * 1.05).clamp(0.0, 1.0))
          .toColor(),
      bodyTop: hsl
          .withLightness((hsl.lightness + 0.1).clamp(0.0, 1.0))
          .toColor(),
      halo: primary,
    );
  }

  final Color body;
  final Color bodyTop;
  final Color glass;
  final Color tire;
  final Color rider;
  final Color metal;
  final Color headlight;
  final Color taillight;

  /// Cahaya lembut di atas jalan di bawah kereta; null = tiada.
  final Color? halo;

  CarPalette withoutHalo() => CarPalette(
    body: body,
    bodyTop: bodyTop,
    glass: glass,
    tire: tire,
    rider: rider,
    metal: metal,
    headlight: headlight,
    taillight: taillight,
  );

  Color of(CarMaterial material) => switch (material) {
    CarMaterial.body => body,
    CarMaterial.bodyTop => bodyTop,
    CarMaterial.glass => glass,
    CarMaterial.tire => tire,
    CarMaterial.rider => rider,
    CarMaterial.metal => metal,
    CarMaterial.headlight => headlight,
    CarMaterial.taillight => taillight,
  };

  @override
  bool operator ==(Object other) =>
      other is CarPalette &&
      other.body == body &&
      other.bodyTop == bodyTop &&
      other.glass == glass &&
      other.tire == tire &&
      other.rider == rider &&
      other.metal == metal &&
      other.headlight == headlight &&
      other.taillight == taillight &&
      other.halo == halo;

  @override
  int get hashCode => Object.hashAll([
    body,
    bodyTop,
    glass,
    tire,
    rider,
    metal,
    headlight,
    taillight,
    halo,
  ]);
}

/// Melukis [CarMesh] sebagai kereta 3D sebenar pada kanvas 2D, diputar dan dicondongkan mengikut
/// kamera peta.
///
/// Mengapa bukan imej rata di atas peta: kamera navigasi condong sehingga 60 darjah. Sprite rata yang
/// dilekatkan pada jalan hanya menjadi kepingan nipis yang diperspektifkan, dan kereta kelihatan
/// seperti pelekat. Di sini setiap muka diunjurkan dengan sudut condong yang SAMA seperti kamera, jadi
/// bumbung, cermin dan sisi kereta kelihatan betul pada setiap condongan dan arah.
///
/// Tiada panggilan platform: kereta dilukis oleh Flutter pada kedudukan skrin tetap, jadi ia tidak
/// pernah berselisih dengan kamera dan tidak berkelip.
class CarRenderer {
  CarRenderer([CarMesh? mesh]) : mesh = mesh ?? CarMesh.standard {
    final n = this.mesh.vertexCount;
    _sx = Float64List(n);
    _sy = Float64List(n);
    _depth = Float64List(n);
    _order = List<int>.filled(this.mesh.faces.length, 0);
    _faceDepth = Float64List(this.mesh.faces.length);
  }

  final CarMesh mesh;
  late final Float64List _sx, _sy, _depth, _faceDepth;
  late final List<int> _order;

  // Cahaya tetap pada skrin: dari kiri atas dan sedikit ke arah pemandang. (kanan, atas, ke pemandang)
  static const _lx = -0.38, _ly = 0.30, _lz = 0.87;

  static const _ambient = 0.56;
  static const _diffuse = 0.5;

  /// Lukis kereta dengan tapaknya di [anchor].
  ///
  /// [lengthPx] panjang kereta pada skrin dengan condongan 0. [yawDeg] arah kereta relatif kepada atas
  /// skrin (ikut jam positif). [tiltDeg] condongan kamera dari menegak (0 = pandangan atas).
  void paint(
    Canvas canvas, {
    required Offset anchor,
    required double lengthPx,
    required double yawDeg,
    required double tiltDeg,
    required CarPalette palette,
    double brake = 0,
    bool shadow = true,
  }) {
    final ppm = lengthPx / mesh.lengthM;
    final yaw = yawDeg * math.pi / 180;
    final tilt = tiltDeg.clamp(0.0, 75.0) * math.pi / 180;
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final ct = math.cos(tilt), st = math.sin(tilt);

    final pos = mesh.positions;
    final count = mesh.vertexCount;
    for (var i = 0; i < count; i++) {
      final x = pos[i * 3], y = pos[i * 3 + 1], z = pos[i * 3 + 2];
      final xr = x * cy + y * sy;
      final yr = -x * sy + y * cy;
      _sx[i] = anchor.dx + xr * ppm;
      _sy[i] = anchor.dy - (yr * ct + z * st) * ppm;
      _depth[i] = z * ct - yr * st;
    }

    final halo = palette.halo;
    if (halo != null) _paintHalo(canvas, anchor, lengthPx, ct, halo);
    if (shadow) _paintShadow(canvas, anchor, ppm, cy, sy, ct, st);

    // Muka yang menghadap pemandang, disusun jauh -> dekat dalam setiap kumpulan.
    final faces = mesh.faces;
    var visible = 0;
    for (var f = 0; f < faces.length; f++) {
      final face = faces[f];
      final nyr = -face.nx * sy + face.ny * cy;
      final nDepth = face.nz * ct - nyr * st;
      if (nDepth <= 0.001) continue;
      var d = 0.0;
      for (final v in face.vertices) {
        d += _depth[v];
      }
      _faceDepth[f] = d / face.vertices.length;
      _order[visible++] = f;
    }
    final drawOrder = _order.sublist(0, visible)
      ..sort((a, b) {
        final byGroup = faces[a].order.compareTo(faces[b].order);
        return byGroup != 0 ? byGroup : _faceDepth[a].compareTo(_faceDepth[b]);
      });

    final fill = Paint()..style = PaintingStyle.fill;
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (final f in drawOrder) {
      final face = faces[f];
      final nxr = face.nx * cy + face.ny * sy;
      final nyr = -face.nx * sy + face.ny * cy;
      final nUp = nyr * ct + face.nz * st;
      final nDepth = face.nz * ct - nyr * st;
      final lambert = math.max(0.0, nxr * _lx + nUp * _ly + nDepth * _lz);

      var color = palette.of(face.material);
      switch (face.material) {
        case CarMaterial.headlight:
          color = _shade(color, 1.0);
        case CarMaterial.taillight:
          color = _shade(Color.lerp(color, const Color(0xFFFF8A94), brake)!, 1);
        case CarMaterial.glass:
          // Kaca memantulkan langit pada permukaan yang menghadap atas, gelap di sisi.
          color = _shade(
            Color.lerp(color, const Color(0xFF6E8FB8), 0.35 * nUp.clamp(0, 1))!,
            _ambient * 0.9 + _diffuse * lambert * 0.35,
          );
        default:
          color = _shade(color, _ambient + _diffuse * lambert);
      }

      path.reset();
      for (var i = 0; i < face.vertices.length; i++) {
        final v = face.vertices[i];
        if (i == 0) {
          path.moveTo(_sx[v], _sy[v]);
        } else {
          path.lineTo(_sx[v], _sy[v]);
        }
      }
      path.close();
      fill.color = color;
      canvas.drawPath(path, fill);
      // Garis halus warna sama menutup retakan antara muka bersebelahan.
      seam.color = color;
      canvas.drawPath(path, seam);
    }

    if (brake > 0.01) {
      _paintBrakeGlow(canvas, anchor, ppm, cy, sy, ct, st, brake, palette);
    }
  }

  static Color _shade(Color c, double k) {
    if (k <= 1) {
      return Color.from(
        alpha: c.a,
        red: c.r * k,
        green: c.g * k,
        blue: c.b * k,
      );
    }
    final t = (k - 1).clamp(0.0, 1.0);
    return Color.from(
      alpha: c.a,
      red: c.r + (1 - c.r) * t,
      green: c.g + (1 - c.g) * t,
      blue: c.b + (1 - c.b) * t,
    );
  }

  void _paintHalo(
    Canvas canvas,
    Offset anchor,
    double lengthPx,
    double ct,
    Color color,
  ) {
    // Bulatan yang dipepatkan menjadi elips mengikut condongan: cahaya terbaring di atas jalan.
    final r = lengthPx * 0.78;
    canvas
      ..save()
      ..translate(anchor.dx, anchor.dy)
      ..scale(1, 0.55 + 0.45 * ct)
      ..drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            r,
            [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
            const [0.25, 1],
          ),
      )
      ..restore();
  }

  void _paintShadow(
    Canvas canvas,
    Offset anchor,
    double ppm,
    double cy,
    double sy,
    double ct,
    double st,
  ) {
    final fp = mesh.footprint;
    final path = Path();
    // Cahaya dari kiri atas: bayang jatuh ke kanan bawah di atas jalan.
    const offX = 0.22, offY = -0.28;
    for (var i = 0; i < fp.length ~/ 2; i++) {
      final x = fp[i * 2], y = fp[i * 2 + 1];
      final xr = x * cy + y * sy + offX;
      final yr = -x * sy + y * cy + offY;
      final px = anchor.dx + xr * ppm;
      final py = anchor.dy - yr * ct * ppm;
      if (i == 0) {
        path.moveTo(px, py);
      } else {
        path.lineTo(px, py);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          math.max(1.5, ppm * 0.22),
        ),
    );
  }

  void _paintBrakeGlow(
    Canvas canvas,
    Offset anchor,
    double ppm,
    double cy,
    double sy,
    double ct,
    double st,
    double brake,
    CarPalette palette,
  ) {
    for (final (x, y0, z0) in mesh.tailLights) {
      final xr = x * cy + y0 * sy;
      final yr = -x * sy + y0 * cy;
      final c = Offset(
        anchor.dx + xr * ppm,
        anchor.dy - (yr * ct + z0 * st) * ppm,
      );
      final r = ppm * 0.9 * (mesh.lengthM / 4.5).clamp(0.5, 1.0);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = ui.Gradient.radial(c, r, [
            palette.taillight.withValues(alpha: 0.55 * brake),
            palette.taillight.withValues(alpha: 0),
          ]),
      );
    }
  }
}
