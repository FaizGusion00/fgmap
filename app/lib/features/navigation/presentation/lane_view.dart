import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/lane_guidance.dart';
import '../domain/lane_plan.dart';
import '../domain/nav_route.dart';
import 'lane_strip.dart' show laneHintText;

/// Kotak "lorong mana" di bawah kad manuver: jalan dilukis berperspektif seperti dilihat dari tempat
/// duduk, setiap lorong dengan anak panahnya, dan lorong yang patut diambil disorot. Untuk bulatan,
/// gambar atas ke bawah dengan keluar yang diambil ditonjolkan.
///
/// Apabila Valhalla tiada data lorong (kebiasaan di Malaysia), lorong dilukis daripada jenis
/// manuver dan ditanda "Anggaran" supaya pemandu tahu ia petunjuk sisi, bukan lorong yang diukur.
class LanePanel extends StatelessWidget {
  const LanePanel({
    super.key,
    required this.maneuver,
    required this.background,
    required this.foreground,
    this.height = 124,
  });

  final NavManeuver maneuver;

  /// Warna kad manuver yang menempatkan kotak ini; latar dan sorotan diterbitkan daripadanya.
  final Color background;
  final Color foreground;
  final double height;

  /// Benar jika ada gambar untuk [maneuver] pada [distanceM] bagi kelajuan dan kenderaan ini.
  static bool shows(
    NavManeuver maneuver, {
    required double distanceM,
    required double speedMps,
    required bool motorcycle,
  }) {
    if (maneuver.isArrival) return false;
    if (distanceM >
        laneViewWithinM(speedMps: speedMps, motorcycle: motorcycle)) {
      return false;
    }
    return lanePlanFor(maneuver) != null || roundaboutPlanFor(maneuver) != null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final easy = EasyModeScope.of(context);
    final palette = _Palette.of(background, foreground, highContrast: easy);
    final lanes = lanePlanFor(maneuver);
    final round = roundaboutPlanFor(maneuver);
    final h = easy ? height * 1.12 : height;

    final String? semantics;
    final Widget art;
    var estimated = false;
    if (lanes != null) {
      final hint = lanes.hint;
      semantics = hint == null
          ? l10n.navLaneViewSemantics(lanes.lanes.length)
          : l10n.navLaneViewHintSemantics(laneHintText(l10n, hint));
      estimated = lanes.estimated;
      art = CustomPaint(
        painter: _LanePainter(plan: lanes, palette: palette),
        size: Size.infinite,
      );
    } else {
      semantics = null;
      art = CustomPaint(
        painter: _RoundaboutViewPainter(plan: round!, palette: palette),
        size: Size.infinite,
      );
    }

    final panel = SizedBox(
      key: const ValueKey('lane-panel'),
      height: h,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: palette.backdrop, child: art),
            if (estimated)
              Positioned(
                top: 8,
                right: 10,
                child: _EstimateChip(text: l10n.navLaneEstimated),
              ),
          ],
        ),
      ),
    );
    // Bulatan: glif nombor keluar pada kad sudah disebut ("ambil simpang keluar ke-2"), jadi gambar
    // ini hiasan sahaja dan tidak diumumkan dua kali.
    if (semantics == null) return ExcludeSemantics(child: panel);
    return Semantics(
      container: true,
      label: semantics,
      excludeSemantics: true,
      child: panel,
    );
  }
}

class _EstimateChip extends StatelessWidget {
  const _EstimateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('lane-estimate-chip'),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      child: Text(
        text,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    ),
  );
}

/// Warna paparan lorong. Mod mudah (kontras tinggi) menyorot dengan warna kad (putih/kuning) dan
/// bukan biru, supaya lorong yang dipilih tidak bergantung pada bezaan warna yang halus.
class _Palette {
  const _Palette({
    required this.backdrop,
    required this.road,
    required this.highlight,
    required this.highlightFar,
    required this.arrow,
    required this.arrowOnHighlight,
    required this.arrowDim,
    required this.line,
  });

  factory _Palette.of(
    Color background,
    Color foreground, {
    required bool highContrast,
  }) {
    final backdrop = Color.lerp(background, Colors.black, 0.5)!;
    final road = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.13),
      backdrop,
    );
    if (highContrast) {
      return _Palette(
        backdrop: backdrop,
        road: road,
        highlight: foreground,
        highlightFar: foreground.withValues(alpha: 0.55),
        arrow: Colors.white,
        arrowOnHighlight: Colors.black,
        arrowDim: Colors.white.withValues(alpha: 0.5),
        line: Colors.white,
      );
    }
    const blue = Color(0xFF4F8FDF);
    return _Palette(
      backdrop: backdrop,
      road: road,
      highlight: blue,
      highlightFar: blue.withValues(alpha: 0.45),
      arrow: Colors.white,
      arrowOnHighlight: Colors.white,
      arrowDim: Colors.white.withValues(alpha: 0.5),
      line: Colors.white,
    );
  }

  final Color backdrop;
  final Color road;
  final Color highlight;
  final Color highlightFar;
  final Color arrow;
  final Color arrowOnHighlight;
  final Color arrowDim;
  final Color line;
}

/// Sudut (darjah dari lurus ke hadapan, positif = kanan) bagi setiap anak panah.
double _angleOf(LaneArrow a) => switch (a) {
  LaneArrow.through => 0,
  LaneArrow.slightLeft => -38,
  LaneArrow.left => -90,
  LaneArrow.sharpLeft => -135,
  LaneArrow.slightRight => 38,
  LaneArrow.right => 90,
  LaneArrow.sharpRight => 135,
  LaneArrow.reverse => 180,
};

/// Anak panah satu lorong dalam ruang rata: asal di tengah-bawah anak panah, naik ke arah -y.
/// [h] ialah tinggi keseluruhan, [t] ketebalan garisan dan [maxReach] jarak sisi paling jauh yang
/// dibenarkan dari tangkai (separuh lebar lorong tolak ruang), supaya anak panah belok tidak
/// terkeluar daripada lorongnya. Setiap arah ialah satu cabang dari tangkai yang sama, jadi lorong
/// "kanan + lurus" menjadi satu anak panah bercabang, bukan dua yang bertindih.
class LaneArrowArt {
  const LaneArrowArt._();

  static void paint(
    Canvas canvas,
    List<LaneArrow> arrows,
    double h,
    double t,
    double maxReach,
    Color color, {
    Set<LaneArrow> dim = const {},
    Color? dimColor,
  }) {
    if (arrows.isEmpty) return;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    // Arah lain dalam lorong yang disyorkan (cth. "lurus" dalam lorong lurus + kanan) dimalapkan:
    // hanya arah yang sebenarnya perlu diambil menyala.
    final dimStroke = Paint()
      ..color = dimColor ?? color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = t
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.round;
    final dimFill = Paint()..color = dimStroke.color;

    // Tangkai penuh hanya jika ada arah lurus; jika tidak, hingga titik belok. Belokan bermula
    // lewat (58% tinggi) supaya tangkai panjang dan lengkung luas, seperti anak panah di jalan
    // sebenar; dahulu 42% dan cabang dihadkan sepertiga lorong, jadi anak panah kelihatan terbantut.
    final hasThrough = arrows.contains(LaneArrow.through);
    final turnY = -h * (hasThrough ? 0.5 : 0.58);
    final from = Offset(0, turnY);

    // Hujung setiap cabang dikira dahulu supaya seluruh anak panah boleh dipusatkan dalam lorong.
    final ends = <LaneArrow, Offset>{};
    for (final a in arrows) {
      if (a == LaneArrow.reverse) continue;
      final deg = _angleOf(a);
      if (a == LaneArrow.through) {
        ends[a] = Offset(0, -h);
        continue;
      }
      final rad = deg * math.pi / 180;
      final sin = math.sin(rad);
      var len = h * 0.45;
      if (sin.abs() > 0.01) len = math.min(len, maxReach / sin.abs());
      // Belok 90 darjah: hujung naik sedikit di atas titik belok, jadi cabang ialah lengkung suku
      // bulatan yang lembut, bukan siku tajam.
      final rise = deg.abs() > 60 && deg.abs() < 100 ? len * 0.55 : 0.0;
      ends[a] = Offset(
        sin * len,
        turnY - math.cos(rad) * len * (deg.abs() > 100 ? 1 : 0.9) - rise,
      );
    }
    final uReach = arrows.contains(LaneArrow.reverse) ? h * 0.2 * 2 : 0.0;
    final xs = [0.0, ...ends.values.map((e) => e.dx), uReach];
    final shift = -(xs.reduce(math.min) + xs.reduce(math.max)) / 2;

    canvas.save();
    canvas.translate(shift, 0);
    canvas.drawLine(Offset.zero, from, stroke);
    for (final a in arrows) {
      if (a == LaneArrow.reverse) {
        _uTurn(canvas, h, t, stroke, fill);
        continue;
      }
      final dimmed = dim.contains(a);
      _branch(
        canvas,
        from,
        ends[a]!,
        _angleOf(a),
        t,
        dimmed ? dimStroke : stroke,
        dimmed ? dimFill : fill,
      );
    }
    canvas.restore();
  }

  static void _branch(
    Canvas canvas,
    Offset from,
    Offset to,
    double deg,
    double t,
    Paint stroke,
    Paint fill,
  ) {
    final rad = deg * math.pi / 180;
    final dir = Offset(math.sin(rad), -math.cos(rad));
    // Kepala tidak pernah melebihi 45% cabang: selebihnya batang yang kelihatan.
    final headLen = math.min(t * 2.8, (to - from).distance * 0.45);
    final shaftEnd = to - dir * (headLen * 0.9);
    final path = Path()..moveTo(from.dx, from.dy);
    if (deg == 0) {
      path.lineTo(shaftEnd.dx, shaftEnd.dy);
    } else {
      // Keluar menegak dari tangkai dan berakhir tepat mengikut arah kepala anak panah.
      final dist = (shaftEnd - from).distance;
      final c1 = from + Offset(0, -dist * 0.6);
      final c2 = shaftEnd - dir * (dist * 0.4);
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, shaftEnd.dx, shaftEnd.dy);
    }
    canvas.drawPath(path, stroke);
    _head(canvas, to, dir, headLen, fill);
  }

  static void _head(
    Canvas canvas,
    Offset tip,
    Offset dir,
    double len,
    Paint fill,
  ) {
    final side = Offset(-dir.dy, dir.dx);
    final base = tip - dir * len;
    final p = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base.dx + side.dx * len * 0.75, base.dy + side.dy * len * 0.75)
      ..lineTo(base.dx - side.dx * len * 0.75, base.dy - side.dy * len * 0.75)
      ..close();
    canvas.drawPath(p, fill);
  }

  /// Pusingan U sebelah kanan (lalu lintas kiri): naik, melengkung ke kanan, turun.
  static void _uTurn(
    Canvas canvas,
    double h,
    double t,
    Paint stroke,
    Paint fill,
  ) {
    final r = h * 0.2;
    final top = -h * 0.74;
    final headLen = t * 2.6;
    final lineEnd = top + r + r * 0.9;
    final path = Path()
      ..moveTo(0, -h * 0.42)
      ..lineTo(0, top + r)
      ..arcToPoint(Offset(r * 2, top + r), radius: Radius.circular(r))
      ..lineTo(r * 2, lineEnd);
    canvas.drawPath(path, stroke);
    _head(
      canvas,
      Offset(r * 2, lineEnd + headLen),
      const Offset(0, 1),
      headLen,
      fill,
    );
  }
}

class _LanePainter extends CustomPainter {
  const _LanePainter({required this.plan, required this.palette});

  final LanePlan plan;
  final _Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final n = plan.lanes.length;
    if (n == 0) return;
    final laneW = math.min(size.width * 0.8 / n, 120.0);
    final roadW = laneW * n;
    // Jalan rata sepanjang L ke hadapan; kamera condong supaya hujung jauh mengecil.
    final length = size.height * 5.6;
    final left = -roadW / 2;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height + size.height * 0.02);
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0034 * (110 / size.height))
      ..rotateX(-1.02);
    canvas.transform(m.storage);

    final roadRect = Rect.fromLTWH(left, -length, roadW, length);
    canvas.drawRect(roadRect, Paint()..color = palette.road);

    for (var i = 0; i < n; i++) {
      final lane = plan.lanes[i];
      final rect = Rect.fromLTWH(left + i * laneW, -length, laneW, length);
      if (lane.recommended) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader =
                LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [palette.highlight, palette.highlightFar],
                ).createShader(
                  Rect.fromLTWH(
                    rect.left,
                    -size.height * 2.4,
                    rect.width,
                    size.height * 2.4,
                  ),
                ),
        );
      }
    }

    final edge = Paint()
      ..color = palette.line
      ..strokeWidth = laneW * 0.07;
    canvas.drawLine(Offset(left, 0), Offset(left, -length), edge);
    canvas.drawLine(
      Offset(left + roadW, 0),
      Offset(left + roadW, -length),
      edge,
    );

    final divider = Paint()
      ..color = palette.line.withValues(alpha: 0.85)
      ..strokeWidth = laneW * 0.05;
    final dash = laneW * 0.42;
    for (var i = 1; i < n; i++) {
      final x = left + i * laneW;
      for (var y = 0.0; y > -length; y -= dash * 2) {
        canvas.drawLine(Offset(x, y), Offset(x, y - dash), divider);
      }
    }

    // Anak panah: satu setiap lorong, dekat dengan pemandu.
    final arrowH = laneW * 1.45;
    for (var i = 0; i < n; i++) {
      final lane = plan.lanes[i];
      canvas.save();
      canvas.translate(left + (i + 0.5) * laneW, -laneW * 0.55);
      LaneArrowArt.paint(
        canvas,
        lane.arrows,
        arrowH,
        laneW * 0.11,
        laneW * 0.6,
        lane.recommended
            ? palette.arrowOnHighlight
            : (plan.hasHighlight ? palette.arrowDim : palette.arrow),
        dim: lane.recommended && lane.highlighted.isNotEmpty
            ? {
                for (final a in lane.arrows)
                  if (!lane.highlighted.contains(a)) a,
              }
            : const {},
        dimColor: palette.arrowOnHighlight.withValues(alpha: 0.45),
      );
      canvas.restore();
    }
    canvas.restore();

    // Kabus jarak jauh: hujung jalan hilang ke latar, bukan terpotong keras.
    final fog = Rect.fromLTWH(0, 0, size.width, size.height * 0.55);
    canvas.drawRect(
      fog,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.backdrop, palette.backdrop.withValues(alpha: 0)],
        ).createShader(fog),
    );
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.plan != plan || old.palette != palette;
}

/// Bulatan dari atas: gelang, jalan masuk di bawah, dan jalan keluar ikut arah lalu lintas (kiri
/// dahulu, ikut jam). Keluar yang diambil disorot dan bernombor; jalan lain skema (pudar).
class _RoundaboutViewPainter extends CustomPainter {
  const _RoundaboutViewPainter({required this.plan, required this.palette});

  final RoundaboutPlan plan;
  final _Palette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.5);
    final ring = size.height * 0.19;
    final armLen = size.height * 0.21;
    final armW = size.height * 0.13;
    final arms = plan.exits + 1;
    final step = 2 * math.pi / arms;

    Paint road(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt;

    // Sudut skrin: 90 darjah = ke bawah (jalan masuk). Ikut jam di skrin ialah arah sudut menaik
    // dalam sistem skrin (y ke bawah): bawah -> kiri -> atas -> kanan.
    Offset dirOf(int k) {
      final a = math.pi / 2 + step * k;
      return Offset(math.cos(a), math.sin(a));
    }

    // Jalan keluar dan masuk.
    for (var k = 0; k < arms; k++) {
      final d = dirOf(k);
      final taken = k == plan.exit;
      final entry = k == 0;
      final from = center + d * ring;
      final to = center + d * (ring + armLen);
      canvas.drawLine(
        from,
        to,
        road(
          taken
              ? palette.highlight
              : (entry ? palette.road : palette.road.withValues(alpha: 0.7)),
          armW,
        ),
      );
    }
    canvas.drawCircle(center, ring, road(palette.road, armW));
    // Sorot gelang dari jalan masuk hingga keluar yang diambil (arah lalu lintas).
    final sweep = step * plan.exit;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring),
      math.pi / 2,
      sweep,
      false,
      road(palette.highlight, armW),
    );

    // Anak panah: masuk dari bawah, keluar ke arah yang diambil.
    final arrow = Paint()
      ..color = palette.arrowOnHighlight
      ..style = PaintingStyle.stroke
      ..strokeWidth = armW * 0.28
      ..strokeCap = StrokeCap.round;
    final inStart = center + dirOf(0) * (ring + armLen * 0.85);
    canvas.drawLine(inStart, center + dirOf(0) * (ring + armW * 0.1), arrow);
    final outD = dirOf(plan.exit);
    final tip = center + outD * (ring + armLen * 0.8);
    canvas.drawLine(center + outD * (ring - armW * 0.2), tip, arrow);
    final side = Offset(-outD.dy, outD.dx);
    final head = Path()
      ..moveTo(tip.dx + outD.dx * armW * 0.5, tip.dy + outD.dy * armW * 0.5)
      ..lineTo(
        tip.dx - outD.dx * armW * 0.1 + side.dx * armW * 0.42,
        tip.dy - outD.dy * armW * 0.1 + side.dy * armW * 0.42,
      )
      ..lineTo(
        tip.dx - outD.dx * armW * 0.1 - side.dx * armW * 0.42,
        tip.dy - outD.dy * armW * 0.1 - side.dy * armW * 0.42,
      )
      ..close();
    canvas.drawPath(head, Paint()..color = palette.arrowOnHighlight);

    // Nombor keluar di hujung setiap jalan.
    for (var k = 1; k < arms; k++) {
      final taken = k == plan.exit;
      final p = center + dirOf(k) * (ring + armLen + armW * 0.05);
      final r = armW * (taken ? 0.62 : 0.5);
      canvas.drawCircle(
        p,
        r,
        Paint()..color = taken ? palette.highlight : palette.backdrop,
      );
      canvas.drawCircle(
        p,
        r,
        Paint()
          ..color = taken ? palette.arrowOnHighlight : palette.arrowDim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '$k',
          style: FgTypography.metricLarge.copyWith(
            color: taken ? palette.arrowOnHighlight : palette.arrowDim,
            fontSize: r * 1.3,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RoundaboutViewPainter old) =>
      old.plan.exit != plan.exit ||
      old.plan.exits != plan.exits ||
      old.palette != palette;
}
