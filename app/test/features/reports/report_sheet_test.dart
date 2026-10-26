import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/reports/data/reports_repository.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/presentation/report_sheet.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

/// Repositori dalam ingatan: `testWidgets` berjalan dalam zon masa palsu, jadi I/O fail sebenar akan tergantung.
/// Logik fail diuji dalam reports_test.dart dengan `test()` biasa.
class _MemoryRepo implements ReportsRepository {
  final List<Report> reports = [];

  @override
  Future<void> clear() async => reports.clear();

  @override
  Future<List<Report>> active(DateTime now) async => [
    for (final r in reports)
      if (r.isActive(now)) r,
  ];

  @override
  Future<({Report report, bool isNew})> create(
    ReportType type,
    GeoPoint point,
    DateTime now,
  ) async {
    final i = reports.indexWhere((r) => r.type == type && r.isActive(now));
    if (i >= 0) {
      reports[i] = reports[i].copyWith(confirms: reports[i].confirms + 1);
      return (report: reports[i], isNew: false);
    }
    final r = Report(
      id: '${reports.length}',
      type: type,
      point: point,
      createdAt: now,
      expiresAt: now.add(type.baseLifetime),
    );
    reports.add(r);
    return (report: r, isNew: true);
  }

  @override
  Future<Report?> vote(
    String id, {
    required bool confirm,
    required DateTime now,
  }) async => null;

  @override
  Future<int> purgeExpired(DateTime now) async => 0;
}

void main() {
  late _MemoryRepo repo;
  setUp(() => repo = _MemoryRepo());

  List<Override> overrides({
    LocationFix? fix = const LocationFix(point: klcc),
  }) => [
    reportsRepositoryProvider.overrideWithValue(repo),
    locationServiceProvider.overrideWithValue(FakeLocationService(fix: fix)),
  ];

  /// Memaparkan butang yang membuka helaian dan menyimpan keputusannya.
  Future<ValueNotifier<Object?>> open(
    WidgetTester tester, {
    LocationFix? fix = const LocationFix(point: klcc),
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester);
    reduceMotion(tester);
    final result = ValueNotifier<Object?>('belum');
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async =>
                  result.value = await showReportSheet(context),
              child: const Text('buka'),
            ),
          ),
        ),
      ),
      locale: locale,
      overrides: overrides(fix: fix),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets(
    'semua 7 jenis dipaparkan dengan nama BM, dan nota "tempatan sahaja" jujur',
    (tester) async {
      await open(tester);
      for (final label in [
        'Polis',
        'Kemalangan',
        'Bahaya',
        'Sesak',
        'Jalan ditutup',
        'Kenderaan rosak',
        'Banjir',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('peranti ini sahaja'), findsOneWidget);
    },
  );

  testWidgets('English', (tester) async {
    await open(tester, locale: const Locale('en'));
    expect(find.text('Police'), findsOneWidget);
    expect(find.text('Road closed'), findsOneWidget);
    expect(find.textContaining('this device only'), findsOneWidget);
  });

  testWidgets(
    'satu ketukan: laporan dicipta pada GPS dan helaian ditutup dengan keputusan',
    (tester) async {
      final result = await open(tester);
      await tester.tap(find.byKey(const ValueKey('report-police')));
      await tester.pumpAndSettle();

      expect(result.value, CreateReportResult.created);
      expect(repo.reports.single.type, ReportType.police);
      expect(repo.reports.single.point, klcc);
    },
  );

  testWidgets(
    'ketukan kedua pada jenis sama berdekatan: disahkan, bukan pendua',
    (tester) async {
      final result = await open(tester);
      await tester.tap(find.byKey(const ValueKey('report-hazard')));
      await tester.pumpAndSettle();
      expect(result.value, CreateReportResult.created);

      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('report-hazard')));
      await tester.pumpAndSettle();
      expect(result.value, CreateReportResult.confirmedExisting);
      expect(repo.reports, hasLength(1));
    },
  );

  testWidgets('tiada GPS: keputusan noLocation dan tiada laporan disimpan', (
    tester,
  ) async {
    final result = await open(tester, fix: null);
    await tester.tap(find.byKey(const ValueKey('report-accident')));
    await tester.pumpAndSettle();
    expect(result.value, CreateReportResult.noLocation);
    expect(repo.reports, isEmpty);
  });

  testWidgets('semua butang sekurang-kurangnya 72 dp (selamat memandu)', (
    tester,
  ) async {
    await open(tester);
    for (final type in ReportType.values) {
      final size = tester.getSize(find.byKey(ValueKey('report-${type.id}')));
      expect(size.width, greaterThanOrEqualTo(72));
      expect(size.height, greaterThanOrEqualTo(72));
    }
  });

  testWidgets('teks sistem 2x tidak melimpah', (tester) async {
    usePhoneSurface(tester, size: const Size(360, 800));
    reduceMotion(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(
      tester,
      const Scaffold(body: SingleChildScrollView(child: ReportSheet())),
      overrides: overrides(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  group('Masih ada?', () {
    final report = Report(
      id: 'a',
      type: ReportType.police,
      point: klcc,
      createdAt: DateTime(2026, 10, 26, 12),
      expiresAt: DateTime(2026, 10, 26, 14),
    );

    Future<ValueNotifier<Object?>> pumpDialog(
      WidgetTester tester, {
      Locale locale = const Locale('ms'),
    }) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      final result = ValueNotifier<Object?>('belum');
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async =>
                  result.value = await showStillThereDialog(context, report),
              child: const Text('tanya'),
            ),
          ),
        ),
        locale: locale,
      );
      await tester.tap(find.text('tanya'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Ya', (tester) async {
      final result = await pumpDialog(tester);
      expect(find.text('Polis masih ada?'), findsOneWidget);
      await tester.tap(find.text('Ya, masih ada'));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
    });

    testWidgets('Tiada', (tester) async {
      final result = await pumpDialog(tester);
      await tester.tap(find.text('Tiada'));
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
    });

    testWidgets('English', (tester) async {
      await pumpDialog(tester, locale: const Locale('en'));
      expect(find.text('Is the Police still there?'), findsOneWidget);
    });
  });
}
