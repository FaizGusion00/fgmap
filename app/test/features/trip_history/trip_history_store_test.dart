import 'dart:convert';

import 'package:fgmap/features/trip_history/data/trip_history_store.dart';
import 'package:fgmap/features/trip_history/domain/trip_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TripSummary _trip(
  String id, {
  double distanceM = 5000,
  double durationS = 600,
  DateTime? at,
  double? tollRm,
}) => TripSummary(
  id: id,
  completedAt: at ?? DateTime.now(),
  distanceM: distanceM,
  durationS: durationS,
  tollRm: tollRm,
);

Future<TripHistoryStore> _store([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return TripHistoryStore(await SharedPreferences.getInstance());
}

void main() {
  group('syarat simpan', () {
    test(
      'perjalanan pendek dan singkat (<1 km dan <3 min) tidak disimpan',
      () async {
        final s = await _store();
        await s.add(_trip('a', distanceM: 999, durationS: 179));
        expect(s.read(), isEmpty);
      },
    );

    test('>= 1 km sahaja cukup', () async {
      final s = await _store();
      await s.add(_trip('a', distanceM: 1000, durationS: 10));
      expect(s.read().map((t) => t.id), ['a']);
    });

    test('>= 3 minit sahaja cukup', () async {
      final s = await _store();
      await s.add(_trip('a', distanceM: 100, durationS: 180));
      expect(s.read().map((t) => t.id), ['a']);
    });

    test('retensi 0 (mati) tidak menyimpan apa-apa', () async {
      final s = await _store();
      await s.setRetentionDays(0);
      await s.add(_trip('a'));
      expect(s.read(), isEmpty);
    });
  });

  group('retensi', () {
    test('lalai 90 hari', () async {
      expect((await _store()).retentionDays, 90);
    });

    test('perjalanan lebih lama daripada tempoh retensi dibuang', () async {
      final now = DateTime.now();
      final old = _trip('lama', at: now.subtract(const Duration(days: 100)));
      final s = await _store({
        'trip.history.v1': jsonEncode([old.toJson()]),
      });
      await s.add(_trip('baru', at: now));
      expect(s.read().map((t) => t.id), ['baru']);
    });

    test('susunan terbaru dahulu', () async {
      final now = DateTime.now();
      final s = await _store();
      await s.add(_trip('a', at: now.subtract(const Duration(days: 3))));
      await s.add(_trip('b', at: now.subtract(const Duration(days: 1))));
      await s.add(_trip('c', at: now.subtract(const Duration(days: 2))));
      expect(s.read().map((t) => t.id), ['b', 'c', 'a']);
    });

    test('-1 = selamanya (tiada buang mengikut umur)', () async {
      final old = _trip(
        'lama',
        at: DateTime.now().subtract(const Duration(days: 2000)),
      );
      final s = await _store({
        'trip.history.v1': jsonEncode([old.toJson()]),
        'trip.history.retentionDays': -1,
      });
      await s.add(_trip('baru'));
      expect(s.read().map((t) => t.id), ['baru', 'lama']);
    });

    test('dihadkan 200 rekod', () async {
      final now = DateTime.now();
      final seed = [
        for (var i = 0; i < 205; i++)
          _trip('t$i', at: now.subtract(Duration(minutes: i + 1))).toJson(),
      ];
      final s = await _store({'trip.history.v1': jsonEncode(seed)});
      await s.add(_trip('baru', at: now));
      final out = s.read();
      expect(out.length, 200);
      expect(out.first.id, 'baru');
    });

    test('clear memadam semua', () async {
      final s = await _store();
      await s.add(_trip('a'));
      await s.clear();
      expect(s.read(), isEmpty);
      expect(jsonDecode(s.exportJson()), isEmpty);
    });
  });

  group('ketahanan data', () {
    test('JSON rosak atau bukan senarai memberi senarai kosong', () async {
      expect(
        (await _store({'trip.history.v1': '{bukan json'})).read(),
        isEmpty,
      );
      expect((await _store({'trip.history.v1': '{"a":1}'})).read(), isEmpty);
    });

    test('rekod tidak lengkap dilangkau', () async {
      final good = _trip('ok').toJson();
      final s = await _store({
        'trip.history.v1': jsonEncode([
          good,
          {'id': 'x'},
          'sampah',
        ]),
      });
      expect(s.read().map((t) => t.id), ['ok']);
    });

    test('toJson/fromJson pergi balik', () {
      final t = TripSummary(
        id: 'z',
        completedAt: DateTime.utc(2026, 5, 1, 8),
        distanceM: 12345,
        durationS: 900,
        originLabel: 'KLCC',
        destinationLabel: 'KLIA',
        vehicle: 'motorcycle',
        tollRm: 4.5,
        fuelRm: 3.2,
      );
      final b = TripSummary.fromJson(
        (jsonDecode(jsonEncode(t.toJson())) as Map).cast<String, Object?>(),
      )!;
      expect(b.id, 'z');
      expect(b.completedAt, t.completedAt);
      expect(b.originLabel, 'KLCC');
      expect(b.destinationLabel, 'KLIA');
      expect(b.vehicle, 'motorcycle');
      expect(b.tollRm, 4.5);
      expect(b.fuelRm, 3.2);
    });
  });

  group('MonthlyTripStats', () {
    test('menjumlah hanya bulan semasa', () {
      final now = DateTime(2026, 5, 15);
      final stats = MonthlyTripStats.from([
        _trip(
          'a',
          distanceM: 10000,
          durationS: 600,
          at: DateTime(2026, 5, 2),
          tollRm: 3,
        ),
        _trip('b', distanceM: 5000, durationS: 300, at: DateTime(2026, 5, 14)),
        _trip(
          'c',
          distanceM: 99999,
          durationS: 999,
          at: DateTime(2026, 4, 30),
          tollRm: 50,
        ),
        _trip(
          'd',
          distanceM: 99999,
          durationS: 999,
          at: DateTime(2025, 5, 10),
          tollRm: 50,
        ),
      ], now: now);
      expect(stats.tripCount, 2);
      expect(stats.distanceM, 15000);
      expect(stats.durationS, 900);
      expect(stats.tollRm, 3);
    });

    test('kosong memberi sifar', () {
      final stats = MonthlyTripStats.from(const [], now: DateTime(2026, 5, 1));
      expect(stats.tripCount, 0);
      expect(stats.distanceM, 0);
      expect(stats.tollRm, 0);
    });
  });
}
