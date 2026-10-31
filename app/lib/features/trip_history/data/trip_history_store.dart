import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import '../domain/trip_summary.dart';

const _key = 'trip.history.v1';
const _retentionKey = 'trip.history.retentionDays';

/// -1 = forever, 0 = off (jangan simpan), else days.
class TripHistoryStore {
  TripHistoryStore(this._prefs);

  final SharedPreferences _prefs;

  int get retentionDays => _prefs.getInt(_retentionKey) ?? 90;

  Future<void> setRetentionDays(int days) async {
    await _prefs.setInt(_retentionKey, days);
  }

  List<TripSummary> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <TripSummary>[];
      for (final e in list) {
        if (e is! Map) continue;
        final t = TripSummary.fromJson(e.cast<String, Object?>());
        if (t != null) out.add(t);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(TripSummary trip) async {
    if (retentionDays == 0) return;
    if (trip.distanceM < 1000 && trip.durationS < 180) return;
    final all = [...read(), trip];
    await _write(_purge(all));
  }

  Future<void> clear() => _prefs.remove(_key);

  Future<void> _write(List<TripSummary> trips) async {
    await _prefs.setString(
      _key,
      jsonEncode([for (final t in trips) t.toJson()]),
    );
  }

  List<TripSummary> _purge(List<TripSummary> trips) {
    final days = retentionDays;
    if (days < 0) {
      trips.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      return trips.take(200).toList();
    }
    final cut = DateTime.now().subtract(Duration(days: days));
    final kept = trips.where((t) => t.completedAt.isAfter(cut)).toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return kept.take(200).toList();
  }

  String exportJson() => jsonEncode([for (final t in read()) t.toJson()]);
}

final tripHistoryStoreProvider = Provider((ref) {
  return TripHistoryStore(ref.watch(sharedPreferencesProvider));
});
