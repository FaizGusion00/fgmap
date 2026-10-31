import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../domain/speed_camera.dart';

/// Memuatkan kamera AwAS JPJ yang dikurasi daripada aset app.
class AwasCameraStore {
  List<SpeedCamera>? _cache;

  Future<List<SpeedCamera>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/cameras/awas_my.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return _cache = const [];
    final list = decoded['cameras'];
    if (list is! List) return _cache = const [];
    final out = <SpeedCamera>[];
    for (final e in list) {
      if (e is! Map) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lng = (e['lng'] as num?)?.toDouble();
      final id = e['id'] as String?;
      final name = e['name'] as String?;
      if (lat == null || lng == null || id == null || name == null) continue;
      // Pin dibundarkan ≤2 perpuluhan (~1 km) dianggap anggaran KM.
      final approx =
          e['confidence'] == 'approx' ||
          _looksRounded(lat) ||
          _looksRounded(lng);
      out.add(
        SpeedCamera(
          id: id,
          name: name,
          point: GeoPoint(lat, lng),
          source: SpeedCameraSource.jpjAwas,
          type: (e['type'] as String?) ?? 'speed',
          bound: e['bound'] as String?,
          confidence: approx
              ? SpeedCameraConfidence.approx
              : SpeedCameraConfidence.high,
        ),
      );
    }
    return _cache = out;
  }

  /// True jika nilai pada dasarnya 2 perpuluhan (pin KM lebuh raya).
  static bool _looksRounded(double v) {
    final scaled = v * 100;
    return (scaled - scaled.roundToDouble()).abs() < 1e-6;
  }
}

final awasCameraStoreProvider = Provider((ref) => AwasCameraStore());
