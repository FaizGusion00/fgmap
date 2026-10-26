import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/report.dart';
import 'report_sheet.dart';

/// Ukuran piksel imej penanda laporan pada peta.
const reportIconPixels = 96;

/// Warna penanda mengikut jenis. Putih pada setiap warna ini sekurang-kurangnya 4.5:1 (diuji).
Color reportTypeColor(ReportType type) => switch (type) {
  ReportType.police => const Color(0xFF1D4ED8),
  ReportType.accident => const Color(0xFFB91C1C),
  ReportType.hazard => const Color(0xFFB45309),
  ReportType.trafficJam => const Color(0xFFC2410C),
  ReportType.roadClosed => const Color(0xFF7F1D1D),
  ReportType.brokenDown => const Color(0xFF475569),
  ReportType.flood => const Color(0xFF0E7490),
};

/// Nama imej dalam gaya peta untuk [type].
String reportImageName(ReportType type) => 'fg-report-${type.id}';

/// Penanda laporan: bulatan berwarna, cincin putih dan ikon jenis, supaya mudah dibezakan sekilas.
Future<Uint8List> renderReportIcon(ReportType type) async {
  const s = reportIconPixels * 1.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, s, s));
  const center = Offset(s / 2, s / 2);
  canvas.drawCircle(
    center.translate(0, 2),
    s * 0.42,
    Paint()
      ..color = const Color(0x55000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
  );
  canvas.drawCircle(center, s * 0.42, Paint()..color = Colors.white);
  canvas.drawCircle(center, s * 0.36, Paint()..color = reportTypeColor(type));
  final icon = reportTypeIcon(type);
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: s * 0.46,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  final image = await recorder.endRecording().toImage(
    reportIconPixels,
    reportIconPixels,
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
