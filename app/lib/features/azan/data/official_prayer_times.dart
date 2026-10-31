import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/preferences.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/log.dart';
import '../domain/azan_plan.dart';
import '../domain/prayer.dart';
import '../domain/prayer_calculator.dart';
import '../domain/prayer_times.dart';

/// Kunci cache waktu rasmi; mengandungi koordinat kasar jadi dipadam oleh "Padam semua data saya".
const azanOfficialCacheKey = 'azan.official.v1';

/// Jarak (meter) cache zon masih sah untuk lokasi baharu. Zon JAKIM seluas beberapa puluh km; 15 km
/// mengekalkan ralat di sempadan zon dalam satu atau dua minit.
const _cacheRadiusMeters = 15000.0;

/// Satu bulan waktu rasmi JAKIM untuk satu zon.
@immutable
class OfficialMonth {
  const OfficialMonth({
    required this.zone,
    required this.at,
    required this.year,
    required this.month,
    required this.days,
  });

  final String zone;

  /// Titik (dibundarkan) yang digunakan untuk mendapatkan zon ini.
  final GeoPoint at;
  final int year;
  final int month;

  /// Hari dalam bulan -> waktu (Subuh, Syuruk, Zohor, Asar, Maghrib, Isyak) dalam waktu tempatan.
  final Map<int, Map<Prayer, DateTime>> days;

  DailyPrayerTimes? timesFor(DateTime day) {
    if (day.year != year || day.month != month) return null;
    final t = days[day.day];
    if (t == null) return null;
    return DailyPrayerTimes(
      day: DateTime(day.year, day.month, day.day),
      times: t,
      zone: zone,
    );
  }

  Map<String, Object?> toJson() => {
    'z': zone,
    'lat': at.lat,
    'lng': at.lng,
    'y': year,
    'm': month,
    'd': {
      for (final e in days.entries)
        '${e.key}': [
          for (final p in Prayer.values) e.value[p]!.millisecondsSinceEpoch,
        ],
    },
  };

  static OfficialMonth? fromJson(Object? json) {
    if (json is! Map) return null;
    final zone = json['z'];
    final lat = json['lat'];
    final lng = json['lng'];
    final y = json['y'];
    final m = json['m'];
    final d = json['d'];
    if (zone is! String ||
        lat is! num ||
        lng is! num ||
        y is! int ||
        m is! int ||
        d is! Map) {
      return null;
    }
    final days = <int, Map<Prayer, DateTime>>{};
    for (final e in d.entries) {
      final day = int.tryParse('${e.key}');
      final v = e.value;
      if (day == null || v is! List || v.length != Prayer.values.length) {
        continue;
      }
      final ms = [
        for (final x in v)
          if (x is int) x,
      ];
      if (ms.length != Prayer.values.length) continue;
      days[day] = {
        for (var i = 0; i < Prayer.values.length; i++)
          Prayer.values[i]: DateTime.fromMillisecondsSinceEpoch(ms[i]),
      };
    }
    if (days.isEmpty) return null;
    return OfficialMonth(
      zone: zone,
      at: GeoPoint(lat.toDouble(), lng.toDouble()),
      year: y,
      month: m,
      days: days,
    );
  }
}

/// Menghurai respons `/v2/solat/gps/{lat}/{lng}` (jadual bulanan rasmi JAKIM). Hari yang tidak
/// lengkap atau tidak menaik (Subuh < Syuruk < ... < Isyak) dibuang supaya data rosak tidak pernah
/// mengatasi pengiraan pada telefon. Null jika respons bukan jadual sah (cth. di luar Malaysia).
OfficialMonth? parseWaktuSolat(Object? json, {required GeoPoint at}) {
  if (json is! Map) return null;
  final zone = json['zone'];
  final year = json['year'];
  final month = json['month_number'];
  final prayers = json['prayers'];
  if (zone is! String ||
      zone.isEmpty ||
      year is! int ||
      month is! int ||
      prayers is! List) {
    return null;
  }
  final days = <int, Map<Prayer, DateTime>>{};
  for (final item in prayers) {
    if (item is! Map) continue;
    final day = item['day'];
    if (day is! int) continue;
    final raw = <Prayer, Object?>{
      Prayer.fajr: item['fajr'],
      Prayer.sunrise: item['syuruk'],
      Prayer.dhuhr: item['dhuhr'],
      Prayer.asr: item['asr'],
      Prayer.maghrib: item['maghrib'],
      Prayer.isha: item['isha'],
    };
    if (raw.values.any((v) => v is! num)) continue;
    final times = {
      for (final e in raw.entries)
        e.key: DateTime.fromMillisecondsSinceEpoch(
          (e.value! as num).toInt() * 1000,
        ),
    };
    var ascending = true;
    for (var i = 1; i < Prayer.values.length; i++) {
      if (!times[Prayer.values[i]]!.isAfter(times[Prayer.values[i - 1]]!)) {
        ascending = false;
      }
    }
    if (ascending) days[day] = times;
  }
  if (days.isEmpty) return null;
  return OfficialMonth(
    zone: zone,
    at: at,
    year: year,
    month: month,
    days: days,
  );
}

/// Mengambil satu bulan waktu rasmi untuk koordinat. Antara muka supaya ujian tidak menyentuh rangkaian.
abstract interface class OfficialTimesClient {
  /// Null jika tiada data (di luar Malaysia, respons rosak atau rangkaian gagal).
  Future<OfficialMonth?> fetchMonth(GeoPoint at, int year, int month);
}

class DioOfficialTimesClient implements OfficialTimesClient {
  DioOfficialTimesClient(this._dio, {String? baseUrl})
    : _base = (baseUrl ?? AppConfig.waktuSolatUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final Dio _dio;
  final String _base;

  @override
  Future<OfficialMonth?> fetchMonth(GeoPoint at, int year, int month) async {
    try {
      final res = await _dio.get<Object?>(
        '$_base/v2/solat/gps/${at.lat}/${at.lng}',
        queryParameters: {'year': year, 'month': month},
        options: Options(
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      return parseWaktuSolat(res.data, at: at);
    } on Object catch (e) {
      logDiag('Waktu rasmi JAKIM tidak dapat diambil: $e');
      return null;
    }
  }
}

final officialTimesClientProvider = Provider<OfficialTimesClient>(
  (ref) => DioOfficialTimesClient(ref.watch(dioProvider)),
);

/// Cache bulan rasmi pada peranti (SharedPreferences). Hanya menyimpan bulan semasa dan sekitarnya.
class OfficialTimesStore extends Notifier<List<OfficialMonth>> {
  Future<void>? _running;

  @override
  List<OfficialMonth> build() {
    final raw = ref
        .watch(sharedPreferencesProvider)
        .getString(azanOfficialCacheKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [for (final j in list) ?OfficialMonth.fromJson(j)];
    } on Object {
      return const [];
    }
  }

  /// Pastikan bulan-bulan untuk [days] hari bermula [now] ada dalam cache untuk lokasi [at].
  /// Mengembalikan true jika ada data baharu. Tidak pernah melempar; kegagalan = guna pengiraan.
  Future<bool> ensure({
    required GeoPoint at,
    required DateTime now,
    int days = azanScheduleDays + 1,
  }) async {
    // Satu permintaan pada satu masa; panggilan serentak menunggu yang sedang berjalan.
    // Ulang sehingga kita memegang slot — dua waiter boleh bangun sekali gus.
    while (_running != null) {
      await _running;
      if (!ref.mounted) return false;
    }
    final completer = Completer<void>();
    _running = completer.future;
    try {
      var changed = false;
      final needed = <(int, int)>{};
      for (var d = 0; d < days; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        needed.add((day.year, day.month));
      }
      for (final (year, month) in needed) {
        if (_find(state, at, year, month) != null) continue;
        final fetched = await ref
            .read(officialTimesClientProvider)
            .fetchMonth(at, year, month);
        // Keluar awal OK: `finally` di bawah mesti menyelesaikan completer supaya
        // waiter serentak tidak tergantung selama-lamanya selepas dispose.
        if (!ref.mounted) return changed;
        if (fetched == null) continue;
        // Gantikan bulan yang sama untuk zon berdekatan; simpan hanya 6 bulan terkini.
        final next =
            [
              for (final m in state)
                if (!(m.year == year &&
                    m.month == month &&
                    distanceMeters(m.at, at) < _cacheRadiusMeters))
                  m,
              fetched,
            ]..sort(
              (a, b) =>
                  (b.year * 12 + b.month).compareTo(a.year * 12 + a.month),
            );
        state = next.take(6).toList();
        changed = true;
      }
      if (changed) {
        await ref
            .read(sharedPreferencesProvider)
            .setString(
              azanOfficialCacheKey,
              jsonEncode([for (final m in state) m.toJson()]),
            );
      }
      return changed;
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (identical(_running, completer.future)) _running = null;
    }
  }

  static OfficialMonth? _find(
    List<OfficialMonth> months,
    GeoPoint at,
    int year,
    int month,
  ) {
    for (final m in months) {
      if (m.year == year &&
          m.month == month &&
          distanceMeters(m.at, at) < _cacheRadiusMeters) {
        return m;
      }
    }
    return null;
  }

  /// Waktu rasmi untuk [day] di [at] jika ada dalam cache.
  static DailyPrayerTimes? lookup(
    List<OfficialMonth> months,
    GeoPoint at,
    DateTime day,
  ) => _find(months, at, day.year, day.month)?.timesFor(day);
}

final officialTimesProvider =
    NotifierProvider<OfficialTimesStore, List<OfficialMonth>>(
      OfficialTimesStore.new,
    );

/// Waktu rasmi JAKIM dahulu (kaedah JAKIM + mazhab Syafie sahaja: itulah yang jadual rasmi
/// gunakan), selebihnya dikira pada telefon.
class OfficialFirstCalculator implements PrayerCalculator {
  const OfficialFirstCalculator({required this.months, required this.fallback});

  final List<OfficialMonth> months;
  final PrayerCalculator fallback;

  @override
  DailyPrayerTimes compute({
    required GeoPoint at,
    required DateTime day,
    required AzanMethod method,
    required AzanMadhab madhab,
  }) {
    if (method == AzanMethod.jakim && madhab == AzanMadhab.shafi) {
      final official = OfficialTimesStore.lookup(months, at, day);
      if (official != null) return official;
    }
    return fallback.compute(at: at, day: day, method: method, madhab: madhab);
  }
}
