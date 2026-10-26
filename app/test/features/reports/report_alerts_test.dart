import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/navigation/data/navigation_settings.dart';
import 'package:fgmap/features/navigation/domain/announcement_planner.dart';
import 'package:fgmap/features/navigation/domain/instruction_text.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/presentation/report_alerts_controller.dart';
import 'package:fgmap/features/reports/presentation/report_icon.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../navigation/nav_test_support.dart';

const _road = GeoPoint(3.0, 101.0);

LocationFix _at(double eastM, {int heading = 90}) => LocationFix(
  point: destinationPoint(_road, 90, eastM),
  headingDegrees: heading,
  accuracyMeters: 5,
  speedMps: 14,
);

void main() {
  late FakeClock clock;
  late ProviderContainer container;

  Future<void> setUp0({Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    final sp = await SharedPreferences.getInstance();
    clock = FakeClock(DateTime.utc(2026, 1, 1, 12));
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        reportsClockProvider.overrideWithValue(clock.call),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reportsControllerProvider, (_, _) {});
    container.listen(reportAlertsProvider, (_, _) {});
  }

  Future<Report> seed(
    ReportType type,
    double eastM, {
    Duration age = Duration.zero,
  }) async {
    final repo = container.read(reportsRepositoryProvider);
    final r = await repo.create(
      type,
      destinationPoint(_road, 90, eastM),
      clock.now.subtract(age),
    );
    await container.read(reportsControllerProvider.notifier).refresh();
    return r.report;
  }

  ReportAlertsController alerts() =>
      container.read(reportAlertsProvider.notifier);

  test('umum sekali apabila masuk jarak amaran; tidak diulang', () async {
    await setUp0();
    await seed(ReportType.police, 1200);

    expect(
      alerts().onFix(_at(0), VoiceLanguage.ms),
      isEmpty,
      reason: '1.2 km: terlalu jauh',
    );
    final ms = alerts().onFix(_at(800), VoiceLanguage.ms);
    expect(ms, hasLength(1));
    expect(ms.single.kind, AnnouncementKind.report);
    expect(ms.single.text, startsWith('Polis di hadapan'));
    expect(
      alerts().onFix(_at(850), VoiceLanguage.ms),
      isEmpty,
      reason: 'sekali sahaja',
    );
  });

  test('bahasa Inggeris', () async {
    await setUp0();
    await seed(ReportType.accident, 300);
    final en = alerts().onFix(_at(0), VoiceLanguage.en);
    expect(en.single.text, startsWith('Accident ahead'));
  });

  test('laporan di belakang atau di sisi arah tidak diumumkan', () async {
    await setUp0();
    await seed(ReportType.hazard, 300);
    // Menuju barat (270): laporan di timur berada di belakang.
    expect(alerts().onFix(_at(0, heading: 270), VoiceLanguage.ms), isEmpty);
  });

  test(
    'amaran dimatikan dalam tetapan: tiada pengumuman atau soalan',
    () async {
      await setUp0(prefs: {'nav.reportAlerts': false});
      await seed(ReportType.police, 300, age: const Duration(hours: 1));
      expect(alerts().onFix(_at(0), VoiceLanguage.ms), isEmpty);
      expect(alerts().onFix(_at(290), VoiceLanguage.ms), isEmpty);
      expect(container.read(reportAlertsProvider).ask, isNull);
      expect(container.read(navigationSettingsProvider).reportAlerts, isFalse);
    },
  );

  test(
    '"Masih ada?": hanya laporan > 10 min, apabila dilepasi; jawapan mengundi',
    () async {
      await setUp0();
      final fresh = await seed(ReportType.police, 200);
      final old = await seed(
        ReportType.roadClosed,
        500,
        age: const Duration(minutes: 30),
      );

      alerts().onFix(_at(190), VoiceLanguage.ms);
      expect(
        container.read(reportAlertsProvider).ask,
        isNull,
        reason: 'laporan baharu tidak ditanya',
      );

      alerts().onFix(_at(470), VoiceLanguage.ms);
      expect(container.read(reportAlertsProvider).ask?.id, old.id);

      await alerts().answer(confirm: true);
      expect(container.read(reportAlertsProvider).ask, isNull);
      final active = container.read(reportsControllerProvider);
      final voted = active.firstWhere((r) => r.id == old.id);
      expect(voted.confirms, 1);
      expect(active.any((r) => r.id == fresh.id), isTrue);
    },
  );

  test('jawapan "tiada" membuang laporan (ambang tempatan 1)', () async {
    await setUp0();
    final old = await seed(
      ReportType.hazard,
      200,
      age: const Duration(minutes: 30),
    );
    alerts().onFix(_at(190), VoiceLanguage.ms);
    await alerts().answer(confirm: false);
    expect(
      container.read(reportsControllerProvider).any((r) => r.id == old.id),
      isFalse,
    );
  });

  test('ditutup tanpa menjawab: tiada undi', () async {
    await setUp0();
    final old = await seed(
      ReportType.hazard,
      200,
      age: const Duration(minutes: 30),
    );
    alerts().onFix(_at(190), VoiceLanguage.ms);
    await alerts().answer(confirm: null);
    final after = container.read(reportsControllerProvider).single;
    expect(after.id, old.id);
    expect(after.confirms, 0);
    expect(after.denies, 0);
  });

  test('reset melupakan laporan yang sudah diumumkan', () async {
    await setUp0();
    await seed(ReportType.flood, 300);
    expect(alerts().onFix(_at(0), VoiceLanguage.ms), hasLength(1));
    expect(alerts().onFix(_at(10), VoiceLanguage.ms), isEmpty);
    alerts().reset();
    expect(alerts().onFix(_at(20), VoiceLanguage.ms), hasLength(1));
  });

  testWidgets('soalan dilepaskan sendiri selepas tamat masa', (tester) async {
    await setUp0();
    final old = await seed(
      ReportType.hazard,
      200,
      age: const Duration(minutes: 30),
    );
    expect(old, isNotNull);
    alerts().onFix(_at(190), VoiceLanguage.ms);
    expect(container.read(reportAlertsProvider).ask, isNotNull);
    await tester.pump(
      ReportAlertsController.askTimeout + const Duration(seconds: 1),
    );
    expect(container.read(reportAlertsProvider).ask, isNull);
    // Pemasa berkala (luput laporan) mesti dihentikan sebelum ujian widget tamat.
    container.dispose();
  });

  group('ikon laporan', () {
    double luminance(Color c) => c.computeLuminance();

    test('putih pada setiap warna jenis sekurang-kurangnya 4.5:1', () {
      for (final type in ReportType.values) {
        final bg = luminance(reportTypeColor(type));
        final ratio = (1.0 + 0.05) / (bg + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5), reason: type.id);
      }
    });

    test('nama imej unik bagi setiap jenis', () {
      final names = {for (final t in ReportType.values) reportImageName(t)};
      expect(names, hasLength(ReportType.values.length));
    });

    testWidgets('dirender sebagai PNG bersaiz sebenar', (tester) async {
      final bytes = await tester.runAsync(
        () => renderReportIcon(ReportType.police),
      );
      expect(bytes, isNotNull);
      // Tandatangan PNG.
      expect(bytes!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    });
  });

  group('suara', () {
    test('frasa jarak dan jenis BM/EN', () {
      const ms = InstructionText(VoiceLanguage.ms);
      const en = InstructionText(VoiceLanguage.en);
      expect(
        ms.reportAhead(ReportType.trafficJam, 300),
        'Kesesakan di hadapan, 300 meter.',
      );
      expect(
        en.reportAhead(ReportType.roadClosed, 1000),
        contains('Road closed ahead'),
      );
      for (final t in ReportType.values) {
        expect(ms.reportTypeName(t), isNotEmpty);
        expect(en.reportTypeName(t), isNotEmpty);
      }
    });
  });
}
