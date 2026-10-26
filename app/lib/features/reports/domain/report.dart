import 'package:flutter/foundation.dart';

import '../../../core/utils/geo.dart';

/// Jenis laporan komuniti. Hanya jenis tetap (tiada teks bebas) untuk mengelak spam dan kandungan berbahaya
/// (Bahagian 9 pelan). Nilai `id` disimpan pada cakera; jangan ubah nama.
enum ReportType {
  police('police', Duration(minutes: 90)),
  accident('accident', Duration(hours: 1)),
  hazard('hazard', Duration(hours: 3)),
  trafficJam('traffic_jam', Duration(minutes: 30)),
  roadClosed('road_closed', Duration(hours: 6)),
  brokenDown('broken_down', Duration(hours: 1)),
  flood('flood', Duration(hours: 3));

  const ReportType(this.id, this.baseLifetime);

  final String id;

  /// Hayat lalai (Bahagian 9). "Kenderaan rosak" tiada dalam pelan; 1 jam ialah andaian.
  final Duration baseLifetime;

  static ReportType? fromId(String? id) {
    for (final t in values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

@immutable
class Report {
  const Report({
    required this.id,
    required this.type,
    required this.point,
    required this.createdAt,
    required this.expiresAt,
    this.confirms = 0,
    this.denies = 0,
  });

  final String id;
  final ReportType type;
  final GeoPoint point;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int confirms;
  final int denies;

  bool isActive(DateTime now) => now.isBefore(expiresAt);

  Report copyWith({DateTime? expiresAt, int? confirms, int? denies}) => Report(
    id: id,
    type: type,
    point: point,
    createdAt: createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    confirms: confirms ?? this.confirms,
    denies: denies ?? this.denies,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type.id,
    'lat': point.lat,
    'lng': point.lng,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'confirms': confirms,
    'denies': denies,
  };

  /// Menghurai satu rekod; memulangkan null jika rosak atau jenis tidak dikenali (versi app lebih baharu).
  static Report? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final type = ReportType.fromId(json['type'] as String?);
    final id = json['id'];
    final lat = json['lat'];
    final lng = json['lng'];
    final created = DateTime.tryParse('${json['createdAt']}');
    final expires = DateTime.tryParse('${json['expiresAt']}');
    if (type == null ||
        id is! String ||
        lat is! num ||
        lng is! num ||
        created == null ||
        expires == null) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return Report(
      id: id,
      type: type,
      point: GeoPoint(lat.toDouble(), lng.toDouble()),
      createdAt: created,
      expiresAt: expires,
      confirms: json['confirms'] is int ? json['confirms'] as int : 0,
      denies: json['denies'] is int ? json['denies'] as int : 0,
    );
  }
}

/// Peraturan laporan, dikumpulkan di satu tempat supaya sama untuk simpanan tempatan dan backend kongsi kemudian.
abstract final class ReportRules {
  /// Laporan jenis sama dalam jarak ini dianggap kejadian yang sama (disahkan, bukan laporan baharu).
  static const duplicateRadiusM = 150.0;

  /// "Masih ada?" ditanya bila pemandu melepasi laporan dalam jarak ini.
  static const askRadiusM = 80.0;

  /// Laporan baharu tidak ditanya "Masih ada?" sebelum umurnya melebihi ini (pelapor baru melaporkannya).
  static const minAgeToAsk = Duration(minutes: 10);

  /// Setiap pengesahan melanjutkan hayat sebanyak pecahan ini daripada hayat asas jenis itu.
  static const confirmExtensionFraction = 0.5;

  /// Hayat maksimum (kali hayat asas) supaya laporan tidak hidup selama-lamanya melalui pengesahan berulang.
  static const maxLifetimeFactor = 3.0;

  /// Jumlah penafian yang membuang laporan. Simpanan tempatan hanya ada satu pengundi, jadi 1.
  static const localDenyThreshold = 1;
}
