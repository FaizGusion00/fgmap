import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences.dart';
import 'trip_record.dart';

/// Simpanan perjalanan aktif. Dibaca secara segerak (SharedPreferences sudah dimuat sebelum
/// `runApp`) supaya peta pertama tidak memaparkan peta kosong dahulu.
class TripStore {
  TripStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  static const key = 'trip.v1';

  TripRecord? read() {
    final record = decodeTrip(_prefs.getString(key));
    if (record == null) return null;
    if (!record.restorable(_clock())) {
      unawaited(_prefs.remove(key));
      return null;
    }
    return record;
  }

  Future<void> write(TripRecord record) =>
      _prefs.setString(key, encodeTrip(record)!);

  Future<void> clear() => _prefs.remove(key);
}

final tripStoreProvider = Provider<TripStore>(
  (ref) => TripStore(ref.watch(sharedPreferencesProvider)),
);
