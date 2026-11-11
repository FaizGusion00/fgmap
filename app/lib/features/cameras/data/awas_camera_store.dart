import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../domain/osm_camera_tags.dart';
import '../domain/speed_camera.dart';

/// Memuatkan kamera yang dibundel (AwAS JPJ yang disahkan + OSM) daripada aset app.
///
/// Aset dijana oleh `tools/cameras/build_cameras.py`; tidak perlu rangkaian.
class AwasCameraStore {
  static const assetPath = 'assets/cameras/cameras_my.json';

  List<SpeedCamera>? _cache;

  Future<List<SpeedCamera>> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString(assetPath);
    return _cache = parse(raw);
  }

  /// Huraikan JSON aset; entri rosak dilangkau.
  @visibleForTesting
  static List<SpeedCamera> parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const [];
    final list = decoded['cameras'];
    if (list is! List) return const [];
    final out = <SpeedCamera>[];
    for (final e in list) {
      if (e is! Map) continue;
      final lat = (e['lat'] as num?)?.toDouble();
      final lng = (e['lng'] as num?)?.toDouble();
      final id = e['id'];
      final name = e['name'];
      if (lat == null || lng == null || id is! String || name is! String) {
        continue;
      }
      if (id.isEmpty || !lat.isFinite || !lng.isFinite) continue;
      final bound = e['bound'];
      final type = e['type'];
      out.add(
        SpeedCamera(
          id: id,
          name: name,
          point: GeoPoint(lat, lng),
          source: e['source'] == 'osm'
              ? SpeedCameraSource.osm
              : SpeedCameraSource.jpjAwas,
          type: type is String && type.isNotEmpty ? type : 'speed',
          bound: bound is String && bound.isNotEmpty ? bound : null,
          directionDegrees: parseOsmDirection(e['direction']),
          maxSpeedKmh: parseMaxspeedKmh(e['maxspeed']),
          confidence: e['confidence'] == 'approx'
              ? SpeedCameraConfidence.approx
              : SpeedCameraConfidence.high,
        ),
      );
    }
    return List.unmodifiable(out);
  }
}

final awasCameraStoreProvider = Provider((ref) => AwasCameraStore());
