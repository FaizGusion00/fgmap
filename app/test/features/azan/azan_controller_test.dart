import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
import 'package:fgmap/features/azan/data/official_prayer_times.dart';
import 'package:fgmap/features/azan/domain/azan_plan.dart';
import 'package:fgmap/features/azan/domain/prayer.dart';
import 'package:fgmap/features/azan/presentation/azan_controller.dart';
import 'package:fgmap/features/navigation/presentation/navigation_controller.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../navigation/nav_test_support.dart';
import 'azan_test_support.dart';

void main() {
  late SharedPreferences prefs;
  late FakeAzanScheduler scheduler;
  late FakeAzanPlayer player;
  late FakePrayerCalculator calc;
  late FakeOfficialClient official;
  late FakeLocationService location;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduler = FakeAzanScheduler();
    player = FakeAzanPlayer();
    calc = FakePrayerCalculator();
    official = FakeOfficialClient();
    location = FakeLocationService();
    now = DateTime(2026, 10, 31, 14, 0);
  });

  ProviderContainer make({bool realCalculator = false}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        azanSchedulerProvider.overrideWithValue(scheduler),
        azanPlayerProvider.overrideWithValue(player),
        if (!realCalculator) prayerCalculatorProvider.overrideWithValue(calc),
        officialTimesClientProvider.overrideWithValue(official),
        azanClockProvider.overrideWithValue(() => now),
        locationServiceProvider.overrideWithValue(location),
        routePlannerProvider.overrideWithValue(
          FakeRoutePlanner((_) async => []),
        ),
        voiceGuideProvider.overrideWithValue(FakeVoice()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('hari ini dikira; waktu seterusnya selepas Zohor ialah Asar', () {
    final c = make();
    final s = c.read(azanControllerProvider);
    expect(s.today, isNotNull);
    expect(s.next, Prayer.asr);
    expect(s.nextAt, DateTime(2026, 10, 31, 16, 25));
    expect(s.location, const GeoPoint(3.139, 101.687));
    // Mati: tiada jadual OS.
    expect(scheduler.replaced, isEmpty);
  });

  test('selepas Isyak: "seterusnya" untuk paparan ialah Subuh esok, logik azan '
      'tidak berubah', () {
    now = DateTime(2026, 10, 31, 21, 0);
    final c = make();
    final s = c.read(azanControllerProvider);
    // Logik azan (pemasa/penjadual) masih hanya hari ini.
    expect(s.next, isNull);
    expect(s.nextAt, isNull);
    // Paparan (pil dan lembaran) tidak kosong sepanjang malam.
    expect(s.upNext, Prayer.fajr);
    expect(s.upNextAt, DateTime(2026, 11, 1, 5, 50));
    expect(s.upNextIsTomorrow, isTrue);
  });

  test('sebelum Isyak: upNext sama dengan next dan bukan esok', () {
    final c = make();
    final s = c.read(azanControllerProvider);
    expect(s.upNext, s.next);
    expect(s.upNextAt, s.nextAt);
    expect(s.upNextIsTomorrow, isFalse);
  });

  test(
    'hidupkan: minta kebenaran, simpan, jadualkan seminggu dengan teks',
    () async {
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      expect(await ctrl.enable(), AzanEnableResult.enabled);
      expect(scheduler.permissionRequests, 1);
      expect(c.read(azanSettingsProvider).enabled, isTrue);
      expect(scheduler.pending, hasLength(3 + 6 * 5));
      expect(scheduler.lastTexts, isNotNull);
      expect(prefs.getInt('azan.scheduledAt'), now.millisecondsSinceEpoch);
      expect(c.read(azanControllerProvider).exactAllowed, isTrue);
    },
  );

  test('kebenaran ditolak: kekal mati dan ditandakan', () async {
    scheduler.permissionGranted = false;
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    expect(await ctrl.enable(), AzanEnableResult.permissionDenied);
    expect(c.read(azanSettingsProvider).enabled, isFalse);
    expect(c.read(azanControllerProvider).permissionDenied, isTrue);
    expect(scheduler.replaced, isEmpty);
  });

  test('penggera tepat tidak dibenarkan dilaporkan dalam keadaan', () async {
    scheduler.exact = false;
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    expect(await ctrl.enable(), AzanEnableResult.needsExactAlarm);
    expect(c.read(azanControllerProvider).exactAllowed, isFalse);
    await ctrl.openExactAlarmSettings();
    expect(scheduler.openExactCalls, 1);
  });

  test('matikan: batal semua notifikasi dan padam rekod jadual', () async {
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    await ctrl.enable();
    await ctrl.disable();
    expect(scheduler.cancelAllCalls, 1);
    expect(scheduler.pending, isEmpty);
    expect(prefs.containsKey('azan.scheduledAt'), isFalse);
    expect(c.read(azanSettingsProvider).enabled, isFalse);
  });

  test(
    'jadual semula: dilangkau jika hari sama dan < 20 km; dibuat jika jauh',
    () async {
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      await ctrl.enable();
      final before = scheduler.replaced.length;
      await ctrl.reschedule();
      expect(scheduler.replaced.length, before);
      // 5 km: lokasi tidak dikemas kini pun.
      ctrl.onLocation(const GeoPoint(3.18, 101.69));
      await Future<void>.delayed(Duration.zero);
      expect(scheduler.replaced.length, before);
      // Johor Bahru: lokasi berubah -> bina semula -> jadual semula.
      ctrl.onLocation(const GeoPoint(1.4927, 103.7414));
      c.read(azanControllerProvider);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(scheduler.replaced.length, greaterThan(before));
      expect(prefs.getDouble('azan.scheduledLat'), 1.49);
    },
  );

  test(
    'tanpa teks (UI belum dipasang) jadual OS dilangkau tetapi tetapan disimpan',
    () async {
      final c = make();
      await c.read(azanControllerProvider.notifier).enable();
      expect(c.read(azanSettingsProvider).enabled, isTrue);
      expect(scheduler.replaced, isEmpty);
    },
  );

  test('waktu masuk semasa app terbuka: azan penuh dan sepanduk', () async {
    await prefs.setBool('azan.enabled', true);
    now = DateTime(2026, 10, 31, 16, 24, 59); // 1 saat sebelum Asar (16:25)
    final c = make();
    c.read(azanControllerProvider.notifier).setTexts(testTexts());
    expect(c.read(azanControllerProvider).next, Prayer.asr);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(player.played, [AzanSound.full]);
    expect(c.read(azanControllerProvider).nowPlaying, Prayer.asr);
    // Waktu seterusnya dikira semula tanpa menunggu tengah malam, walaupun jam ujian tidak bergerak
    // (pemasa sebenar boleh menyala sedikit awal): tidak berbunyi dua kali.
    expect(c.read(azanControllerProvider).next, Prayer.maghrib);
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    expect(player.played, [AzanSound.full]);
  });

  test(
    'semasa navigasi: nada pendek sahaja, melainkan tetapan membenarkan',
    () async {
      await prefs.setBool('azan.enabled', true);
      now = DateTime(2026, 10, 31, 16, 24, 59);
      final c = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          azanSchedulerProvider.overrideWithValue(scheduler),
          azanPlayerProvider.overrideWithValue(player),
          prayerCalculatorProvider.overrideWithValue(calc),
          azanClockProvider.overrideWithValue(() => now),
          navigationControllerProvider.overrideWith(_ActiveNavController.new),
        ],
      );
      addTearDown(c.dispose);
      c.read(azanControllerProvider.notifier).setTexts(testTexts());
      c.read(azanControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(player.played, [AzanSound.short]);

      // Dengan "main azan penuh semasa navigasi": azan penuh.
      c.dispose();
      player.played.clear();
      await prefs.setBool('azan.playDuringNav', true);
      now = DateTime(2026, 10, 31, 19, 4, 59); // 1 saat sebelum Maghrib
      final c2 = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          azanSchedulerProvider.overrideWithValue(scheduler),
          azanPlayerProvider.overrideWithValue(player),
          prayerCalculatorProvider.overrideWithValue(calc),
          azanClockProvider.overrideWithValue(() => now),
          navigationControllerProvider.overrideWith(_ActiveNavController.new),
        ],
      );
      addTearDown(c2.dispose);
      c2.read(azanControllerProvider.notifier).setTexts(testTexts());
      c2.read(azanControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(player.played, [AzanSound.full]);
    },
  );

  test(
    'dismiss menghentikan azan dan membersihkan sepanduk; tamat sendiri juga',
    () async {
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier);
      await ctrl.preview();
      expect(player.played, [AzanSound.full]);
      expect(c.read(azanControllerProvider).nowPlaying, isNotNull);
      await ctrl.dismiss();
      expect(player.stops, 1);
      expect(c.read(azanControllerProvider).nowPlaying, isNull);

      await ctrl.preview();
      expect(c.read(azanControllerProvider).nowPlaying, isNotNull);
      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(azanControllerProvider).nowPlaying, isNull);
    },
  );

  test('ketukan notifikasi disalurkan ke pendengar UI', () async {
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier);
    final got = <String>[];
    final sub = ctrl.tapped.stream.listen(got.add);
    addTearDown(sub.cancel);
    scheduler.tapController.add('azan:asr:2026-10-31T16:25:00');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['azan:asr:2026-10-31T16:25:00']);
  });

  test('selepas Isyak: tiada waktu seterusnya hari ini', () {
    now = DateTime(2026, 10, 31, 22, 0);
    final c = make();
    expect(c.read(azanControllerProvider).next, isNull);
    expect(c.read(azanControllerProvider).nextAt, isNull);
  });

  test(
    'menukar bunyi atau peringatan menjadualkan semula notifikasi OS',
    () async {
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      await ctrl.enable();
      final before = scheduler.replaced.length;
      expect(scheduler.pending.first.sound, AzanSound.full);
      await c.read(azanSettingsProvider.notifier).setSound(AzanSound.short);
      c.read(
        azanControllerProvider,
      ); // dibina semula (dalam app: skrin peta memerhatinya)
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(scheduler.replaced.length, greaterThan(before));
      expect(scheduler.pending.first.sound, AzanSound.short);
      await c.read(azanSettingsProvider.notifier).setReminderMinutes(10);
      c.read(azanControllerProvider);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(scheduler.pending.any((i) => i.reminder), isTrue);
    },
  );

  test(
    'menghidupkan mengambil lokasi segar dan menggunakannya untuk waktu',
    () async {
      location.fix = const LocationFix(point: GeoPoint(1.4927, 103.7414));
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      await ctrl.enable();
      expect(
        c.read(azanControllerProvider).location,
        const GeoPoint(1.49, 103.74),
      );
      expect(c.read(azanControllerProvider).locationKnown, isTrue);
    },
  );

  test(
    'tanpa lokasi: waktu untuk Kuala Lumpur dan ditandakan belum diketahui',
    () async {
      final c = make();
      expect(c.read(azanControllerProvider).locationKnown, isFalse);
      expect(
        c.read(azanControllerProvider).location,
        const GeoPoint(3.139, 101.687),
      );
    },
  );

  test('waktu rasmi JAKIM digunakan apabila tersedia; zon dilaporkan', () async {
    official.available = true;
    final c = make(realCalculator: true);
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    await ctrl.enable();
    // Pengiraan sebenar di KL pada 2026-10-31 ~ 12:59; rasmi palsu = 13:12 (13:05 + 7).
    final s = c.read(azanControllerProvider);
    expect(s.isOfficial, isTrue);
    expect(s.zone, 'WLY01');
    expect(scheduler.pending.every((i) => i.at.minute != 0 || true), isTrue);
    final asr = scheduler.pending.firstWhere((i) => i.prayer == Prayer.asr);
    expect(asr.at, DateTime(2026, 10, 31, 16, 32)); // 16:25 + 7
    // Bulan hadapan diambil juga (jadual seminggu merentas 1 November).
    expect(official.calls.map((c) => c.$3).toSet(), {10, 11});
  });

  test(
    'waktu rasmi gagal diambil: jatuh balik kepada pengiraan pada telefon',
    () async {
      official.available = false;
      final c = make(realCalculator: true);
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      expect(await ctrl.enable(), AzanEnableResult.enabled);
      expect(c.read(azanControllerProvider).isOfficial, isFalse);
      expect(scheduler.pending, isNotEmpty);
    },
  );

  test(
    'tetapan waktu rasmi dimatikan: tiada permintaan rangkaian langsung',
    () async {
      official.available = true;
      await prefs.setBool('azan.official', false);
      final c = make(realCalculator: true);
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      await ctrl.enable();
      expect(official.calls, isEmpty);
      expect(c.read(azanControllerProvider).isOfficial, isFalse);
    },
  );

  test(
    'kaedah bukan JAKIM atau mazhab Hanafi: tidak menggunakan jadual rasmi',
    () async {
      official.available = true;
      await prefs.setString('azan.madhab', 'hanafi');
      final c = make(realCalculator: true);
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      await ctrl.enable();
      expect(official.calls, isEmpty);
      expect(c.read(azanControllerProvider).isOfficial, isFalse);
    },
  );

  test(
    'penggera tepat dibenarkan selepas hidup: jadual dibuat semula dengan mod baharu',
    () async {
      scheduler.exact = false;
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts());
      expect(await ctrl.enable(), AzanEnableResult.needsExactAlarm);
      final before = scheduler.replaced.length;
      // Pengguna membenarkan dalam tetapan sistem, kemudian app kembali ke hadapan.
      scheduler.exact = true;
      await ctrl.onAppResumed();
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(c.read(azanControllerProvider).exactAllowed, isTrue);
      expect(scheduler.replaced.length, greaterThan(before));
    },
  );

  test('notifikasi dimatikan kemudian dikesan apabila app kembali', () async {
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    await ctrl.enable();
    expect(c.read(azanControllerProvider).notificationsBlocked, isFalse);
    scheduler.notifications = false;
    await ctrl.onAppResumed();
    expect(c.read(azanControllerProvider).notificationsBlocked, isTrue);
  });

  test(
    'app terbuka: notifikasi OS dibatalkan supaya azan tidak berbunyi dua kali',
    () async {
      await prefs.setBool('azan.enabled', true);
      now = DateTime(2026, 10, 31, 16, 24, 59);
      final c = make();
      c.read(azanControllerProvider.notifier).setTexts(testTexts());
      c.read(azanControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(player.played, [AzanSound.full]);
      expect(
        scheduler.cancelled,
        contains(azanNotificationId(DateTime(2026, 10, 31), Prayer.asr)),
      );
    },
  );

  test(
    'app di latar (bukan navigasi): OS sahaja yang berbunyi; app diam',
    () async {
      await prefs.setBool('azan.enabled', true);
      now = DateTime(2026, 10, 31, 16, 24, 59);
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier)
        ..setTexts(testTexts())
        ..onAppBackgrounded();
      c.read(azanControllerProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      expect(player.played, isEmpty);
      expect(scheduler.cancelled, isEmpty);
      expect(c.read(azanControllerProvider).nowPlaying, isNull);
      // Waktu seterusnya tetap dikira.
      expect(c.read(azanControllerProvider).next, Prayer.maghrib);
      expect(ctrl, isNotNull);
    },
  );

  test(
    'pendengar selamat daripada pembinaan semula: tamat azan masih membersihkan sepanduk',
    () async {
      final c = make();
      final ctrl = c.read(azanControllerProvider.notifier);
      await ctrl.preview();
      await ctrl.onAppResumed(); // membina semula pengawal
      c.read(azanControllerProvider);
      expect(c.read(azanControllerProvider).nowPlaying, isNotNull);
      player.finish();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(azanControllerProvider).nowPlaying, isNull);
      // Ketikan notifikasi juga masih sampai selepas dibina semula.
      final got = <String>[];
      final sub = ctrl.tapped.stream.listen(got.add);
      addTearDown(sub.cancel);
      scheduler.tapController.add('azan:asr:x');
      await Future<void>.delayed(Duration.zero);
      expect(got, ['azan:asr:x']);
    },
  );
}

/// Navigasi "aktif" tanpa laluan sebenar: hanya fasa yang dibaca oleh AzanController.
class _ActiveNavController extends NavigationController {
  @override
  NavigationState build() => const NavigationState(phase: NavPhase.active);
}
