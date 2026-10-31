import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/azan/data/adhan_prayer_calculator.dart';
import 'package:fgmap/features/azan/data/azan_player.dart';
import 'package:fgmap/features/azan/data/azan_scheduler.dart';
import 'package:fgmap/features/azan/data/azan_settings.dart';
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
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    scheduler = FakeAzanScheduler();
    player = FakeAzanPlayer();
    calc = FakePrayerCalculator();
    now = DateTime(2026, 10, 31, 14, 0);
  });

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        azanSchedulerProvider.overrideWithValue(scheduler),
        azanPlayerProvider.overrideWithValue(player),
        prayerCalculatorProvider.overrideWithValue(calc),
        azanClockProvider.overrideWithValue(() => now),
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        routePlannerProvider.overrideWithValue(FakeRoutePlanner((_) async => [])),
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

  test('hidupkan: minta kebenaran, simpan, jadualkan 2 hari dengan teks', () async {
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    expect(await ctrl.enable(), isTrue);
    expect(scheduler.permissionRequests, 1);
    expect(c.read(azanSettingsProvider).enabled, isTrue);
    expect(scheduler.pending, hasLength(8));
    expect(scheduler.lastTexts, isNotNull);
    expect(prefs.getInt('azan.scheduledAt'), now.millisecondsSinceEpoch);
    expect(c.read(azanControllerProvider).exactAllowed, isTrue);
  });

  test('kebenaran ditolak: kekal mati dan ditandakan', () async {
    scheduler.permissionGranted = false;
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    expect(await ctrl.enable(), isFalse);
    expect(c.read(azanSettingsProvider).enabled, isFalse);
    expect(c.read(azanControllerProvider).permissionDenied, isTrue);
    expect(scheduler.replaced, isEmpty);
  });

  test('penggera tepat tidak dibenarkan dilaporkan dalam keadaan', () async {
    scheduler.exact = false;
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
    await ctrl.enable();
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

  test('jadual semula: dilangkau jika hari sama dan < 20 km; dibuat jika jauh', () async {
    final c = make();
    final ctrl = c.read(azanControllerProvider.notifier)..setTexts(testTexts());
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
    expect(scheduler.replaced.length, greaterThan(before));
    expect(prefs.getDouble('azan.scheduledLat'), 1.49);
  });

  test('tanpa teks (UI belum dipasang) jadual OS dilangkau tetapi tetapan disimpan', () async {
    final c = make();
    await c.read(azanControllerProvider.notifier).enable();
    expect(c.read(azanSettingsProvider).enabled, isTrue);
    expect(scheduler.replaced, isEmpty);
  });

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

  test('semasa navigasi: nada pendek sahaja, melainkan tetapan membenarkan', () async {
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
  });

  test('dismiss menghentikan azan dan membersihkan sepanduk; tamat sendiri juga', () async {
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
  });

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
}

/// Navigasi "aktif" tanpa laluan sebenar: hanya fasa yang dibaca oleh AzanController.
class _ActiveNavController extends NavigationController {
  @override
  NavigationState build() => const NavigationState(phase: NavPhase.active);
}
