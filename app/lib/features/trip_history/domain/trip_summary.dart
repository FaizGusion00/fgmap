import 'package:flutter/foundation.dart';

@immutable
class TripSummary {
  const TripSummary({
    required this.id,
    required this.completedAt,
    required this.distanceM,
    required this.durationS,
    this.originLabel,
    this.destinationLabel,
    this.vehicle = 'car',
    this.tollRm,
    this.fuelRm,
  });

  final String id;
  final DateTime completedAt;
  final double distanceM;
  final double durationS;
  final String? originLabel;
  final String? destinationLabel;
  final String vehicle;
  final double? tollRm;
  final double? fuelRm;

  Map<String, Object?> toJson() => {
    'id': id,
    'completedAt': completedAt.toIso8601String(),
    'distanceM': distanceM,
    'durationS': durationS,
    'originLabel': originLabel,
    'destinationLabel': destinationLabel,
    'vehicle': vehicle,
    'tollRm': tollRm,
    'fuelRm': fuelRm,
  };

  static TripSummary? fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    final completed = DateTime.tryParse(json['completedAt'] as String? ?? '');
    final distance = (json['distanceM'] as num?)?.toDouble();
    final duration = (json['durationS'] as num?)?.toDouble();
    if (id == null ||
        completed == null ||
        distance == null ||
        duration == null) {
      return null;
    }
    return TripSummary(
      id: id,
      completedAt: completed,
      distanceM: distance,
      durationS: duration,
      originLabel: json['originLabel'] as String?,
      destinationLabel: json['destinationLabel'] as String?,
      vehicle: (json['vehicle'] as String?) ?? 'car',
      tollRm: (json['tollRm'] as num?)?.toDouble(),
      fuelRm: (json['fuelRm'] as num?)?.toDouble(),
    );
  }
}

@immutable
class MonthlyTripStats {
  const MonthlyTripStats({
    required this.tripCount,
    required this.distanceM,
    required this.durationS,
    required this.tollRm,
  });

  final int tripCount;
  final double distanceM;
  final double durationS;
  final double tollRm;

  static MonthlyTripStats from(List<TripSummary> trips, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final month = trips.where(
      (t) => t.completedAt.year == n.year && t.completedAt.month == n.month,
    );
    var dist = 0.0;
    var dur = 0.0;
    var toll = 0.0;
    var count = 0;
    for (final t in month) {
      count++;
      dist += t.distanceM;
      dur += t.durationS;
      toll += t.tollRm ?? 0;
    }
    return MonthlyTripStats(
      tripCount: count,
      distanceM: dist,
      durationS: dur,
      tollRm: toll,
    );
  }
}
