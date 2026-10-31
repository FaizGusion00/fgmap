import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/official_prayer_times.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'azan_test_support.dart';

/// Menahan [fetchMonth] sehingga [gate] selesai — untuk ujian dispose semasa fetch.
class _GatedOfficialClient implements OfficialTimesClient {
  _GatedOfficialClient(this._inner, this.gate);

  final OfficialTimesClient _inner;
  final Completer<void> gate;
  final entered = Completer<void>();

  @override
  Future<OfficialMonth?> fetchMonth(GeoPoint at, int year, int month) async {
    if (!entered.isCompleted) entered.complete();
    await gate.future;
    return _inner.fetchMonth(at, year, month);
  }
}

void main() {
  const kl = GeoPoint(3.139, 101.687);
  late Object fixture;

  setUp(() {
    fixture =
        jsonDecode(
              File(
                'test/fixtures/azan/waktusolat_wly01_2026_10.json',
              ).readAsStringSync(),
            )
            as Object;
  });

  DateTime utc(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  group('parseWaktuSolat (respons sebenar WaktuSolat API)', () {
    test('zon, bulan dan 31 hari dihuraikan; masa tepat mengikut JAKIM', () {
      final month = parseWaktuSolat(fixture, at: kl)!;
      expect(month.zone, 'WLY01');
      expect(month.year, 2026);
      expect(month.month, 10);
      expect(month.days, hasLength(31));
      final d31 = month.timesFor(DateTime(2026, 10, 31))!;
      expect(d31.zone, 'WLY01');
      expect(d31.isOfficial, isTrue);
      // 31 Okt 2026: Zohor 13:00, Asar 16:20, Maghrib 18:58 (waktu Malaysia, UTC+8).
      final dhuhr = d31.timeOf(Prayer.dhuhr)!.toUtc();
      expect(dhuhr.hour, 5);
      expect(dhuhr.minute, 0);
      final maghrib = d31.timeOf(Prayer.maghrib)!.toUtc();
      expect(maghrib.hour, 10);
      expect(maghrib.minute, 58);
      // Hari lain bulan atau bulan lain: tiada.
      expect(month.timesFor(DateTime(2026, 11, 1)), isNull);
    });

    test('hari rosak atau tidak menaik dibuang; selebihnya kekal', () {
      final json = jsonDecode(jsonEncode(fixture)) as Map<String, Object?>;
      final days = (json['prayers']! as List).cast<Map<String, Object?>>();
      days[0]['isha'] = days[0]['fajr']; // tidak menaik
      days[1].remove('asr'); // tidak lengkap
      final month = parseWaktuSolat(json, at: kl)!;
      expect(month.days.containsKey(1), isFalse);
      expect(month.days.containsKey(2), isFalse);
      expect(month.days, hasLength(29));
    });

    test('bukan jadual sah (di luar Malaysia / rosak) -> null', () {
      expect(parseWaktuSolat({'message': 'No zone found'}, at: kl), isNull);
      expect(parseWaktuSolat(null, at: kl), isNull);
      expect(parseWaktuSolat([], at: kl), isNull);
      expect(
        parseWaktuSolat({
          'zone': 'X',
          'year': 2026,
          'month_number': 10,
          'prayers': [],
        }, at: kl),
        isNull,
      );
    });

    test('JSON pergi-balik mengekalkan semua waktu', () {
      final month = parseWaktuSolat(fixture, at: kl)!;
      final back = OfficialMonth.fromJson(
        jsonDecode(jsonEncode(month.toJson())),
      )!;
      expect(back.zone, month.zone);
      expect(back.days.length, month.days.length);
      for (final e in month.days.entries) {
        for (final p in Prayer.values) {
          expect(back.days[e.key]![p], e.value[p]);
        }
      }
      expect(OfficialMonth.fromJson({'z': 1}), isNull);
    });
  });

  group('OfficialTimesStore', () {
    late SharedPreferences prefs;
    late FakeOfficialClient client;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      client = FakeOfficialClient()..available = true;
    });

    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          officialTimesClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'mengambil bulan yang diperlukan sekali sahaja dan menyimpannya',
      () async {
        final c = make();
        final store = c.read(officialTimesProvider.notifier);
        // 31 Okt + 7 hari -> Oktober dan November.
        expect(
          await store.ensure(at: kl, now: DateTime(2026, 10, 31, 12)),
          isTrue,
        );
        expect(client.calls.map((e) => e.$3).toSet(), {10, 11});
        expect(prefs.getString(azanOfficialCacheKey), isNotNull);
        // Kali kedua (lokasi sama): cache, tiada permintaan.
        client.calls.clear();
        expect(
          await store.ensure(at: kl, now: DateTime(2026, 10, 31, 13)),
          isFalse,
        );
        expect(client.calls, isEmpty);
        // Kontena baharu (app dimulakan semula): dibaca daripada cache.
        final c2 = make();
        expect(c2.read(officialTimesProvider), hasLength(2));
        expect(
          OfficialTimesStore.lookup(
            c2.read(officialTimesProvider),
            kl,
            DateTime(2026, 11, 3),
          ),
          isNotNull,
        );
      },
    );

    test(
      'lokasi jauh (> 15 km) mengambil zon baharu; dekat menggunakan cache',
      () async {
        final c = make();
        final store = c.read(officialTimesProvider.notifier);
        await store.ensure(at: kl, now: DateTime(2026, 10, 31), days: 1);
        client.calls.clear();
        // ~5 km: cache.
        await store.ensure(
          at: const GeoPoint(3.18, 101.69),
          now: DateTime(2026, 10, 31),
          days: 1,
        );
        expect(client.calls, isEmpty);
        // Johor Bahru: zon lain.
        await store.ensure(
          at: const GeoPoint(1.49, 103.74),
          now: DateTime(2026, 10, 31),
          days: 1,
        );
        expect(client.calls, hasLength(1));
      },
    );

    test('rangkaian gagal: tiada ralat, tiada cache, tidak melempar', () async {
      client.available = false;
      final c = make();
      final store = c.read(officialTimesProvider.notifier);
      expect(await store.ensure(at: kl, now: DateTime(2026, 10, 31)), isFalse);
      expect(c.read(officialTimesProvider), isEmpty);
      expect(prefs.getString(azanOfficialCacheKey), isNull);
    });

    test(
      'dispose semasa fetch: completer selesai; ensure baharu tidak tergantung',
      () async {
        final gate = Completer<void>();
        final slow = _GatedOfficialClient(client, gate);
        final c = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            officialTimesClientProvider.overrideWithValue(slow),
          ],
        );
        final pending = c.read(officialTimesProvider.notifier).ensure(
          at: kl,
          now: DateTime(2026, 10, 31),
          days: 1,
        );
        await slow.entered.future.timeout(const Duration(seconds: 2));
        c.dispose();
        gate.complete();
        await pending.timeout(const Duration(seconds: 2));

        final c2 = make();
        client.available = true;
        expect(
          await c2
              .read(officialTimesProvider.notifier)
              .ensure(at: kl, now: DateTime(2026, 10, 31), days: 1)
              .timeout(const Duration(seconds: 2)),
          isTrue,
        );
      },
    );

    test('cache rosak diabaikan', () async {
      await prefs.setString(azanOfficialCacheKey, '{bukan json');
      expect(make().read(officialTimesProvider), isEmpty);
    });
  });

  group('OfficialFirstCalculator', () {
    test('JAKIM + Syafie: rasmi; kaedah/mazhab lain: pengiraan', () async {
      final client = FakeOfficialClient()..available = true;
      final month = (await client.fetchMonth(kl, 2026, 10))!;
      final fallback = FakePrayerCalculator();
      final calc = OfficialFirstCalculator(months: [month], fallback: fallback);
      final day = DateTime(2026, 10, 31);
      final official = calc.compute(
        at: kl,
        day: day,
        method: AzanMethod.jakim,
        madhab: AzanMadhab.shafi,
      );
      expect(official.isOfficial, isTrue);
      expect(fallback.calls, isEmpty);
      for (final (method, madhab) in [
        (AzanMethod.mwl, AzanMadhab.shafi),
        (AzanMethod.jakim, AzanMadhab.hanafi),
      ]) {
        final r = calc.compute(
          at: kl,
          day: day,
          method: method,
          madhab: madhab,
        );
        expect(r.isOfficial, isFalse);
      }
      expect(fallback.calls, hasLength(2));
      // Hari di luar bulan yang di-cache: jatuh balik.
      expect(
        calc
            .compute(
              at: kl,
              day: DateTime(2026, 12, 1),
              method: AzanMethod.jakim,
              madhab: AzanMadhab.shafi,
            )
            .isOfficial,
        isFalse,
      );
      expect(utc(0).year, 1970);
    });
  });
}
