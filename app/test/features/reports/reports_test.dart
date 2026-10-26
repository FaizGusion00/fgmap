import 'dart:convert';
import 'dart:io';

import 'package:fgmap/core/location/location_service.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/reports/data/reports_repository.dart';
import 'package:fgmap/features/reports/domain/report.dart';
import 'package:fgmap/features/reports/domain/report_alerts.dart';
import 'package:fgmap/features/reports/presentation/reports_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

final t0 = DateTime.utc(2026, 10, 26, 12);
const here = GeoPoint(3.1579, 101.7116);

/// ~[m] meter ke utara daripada [from] (1 darjah latitud ≈ 111.32 km).
GeoPoint north(GeoPoint from, double m) =>
    GeoPoint(from.lat + m / 111320.0, from.lng);

Report _report(
  String id,
  GeoPoint p, {
  ReportType type = ReportType.police,
  DateTime? created,
  DateTime? expires,
}) {
  final c = created ?? t0;
  return Report(
    id: id,
    type: type,
    point: p,
    createdAt: c,
    expiresAt: expires ?? c.add(type.baseLifetime),
  );
}

void main() {
  group('ReportType', () {
    test('hayat asas mengikut pelan Bahagian 9', () {
      expect(ReportType.police.baseLifetime, const Duration(minutes: 90));
      expect(ReportType.accident.baseLifetime, const Duration(hours: 1));
      expect(ReportType.hazard.baseLifetime, const Duration(hours: 3));
      expect(ReportType.trafficJam.baseLifetime, const Duration(minutes: 30));
      expect(ReportType.roadClosed.baseLifetime, const Duration(hours: 6));
      expect(ReportType.flood.baseLifetime, const Duration(hours: 3));
    });

    test('id unik dan boleh dipulihkan; id tidak dikenali -> null', () {
      expect(
        ReportType.values.map((t) => t.id).toSet().length,
        ReportType.values.length,
      );
      for (final t in ReportType.values) {
        expect(ReportType.fromId(t.id), t);
      }
      expect(ReportType.fromId('ufo'), isNull);
      expect(ReportType.fromId(null), isNull);
    });
  });

  group('Report JSON', () {
    test('pergi-balik', () {
      final r = _report('a', here).copyWith(confirms: 2, denies: 1);
      final back = Report.tryFromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back!.id, 'a');
      expect(back.type, ReportType.police);
      expect(back.point, here);
      expect(back.createdAt, t0);
      expect(back.expiresAt, r.expiresAt);
      expect(back.confirms, 2);
      expect(back.denies, 1);
    });

    final bad = <String, Object?>{
      'bukan objek': 5,
      'jenis tidak dikenali': {
        'id': 'a',
        'type': 'ufo',
        'lat': 3,
        'lng': 101,
        'createdAt': '2026-10-26T12:00:00Z',
        'expiresAt': '2026-10-26T13:00:00Z',
      },
      'lat di luar julat': {
        'id': 'a',
        'type': 'police',
        'lat': 95,
        'lng': 101,
        'createdAt': '2026-10-26T12:00:00Z',
        'expiresAt': '2026-10-26T13:00:00Z',
      },
      'tarikh rosak': {
        'id': 'a',
        'type': 'police',
        'lat': 3,
        'lng': 101,
        'createdAt': 'semalam',
        'expiresAt': '2026-10-26T13:00:00Z',
      },
      'id hilang': {
        'type': 'police',
        'lat': 3,
        'lng': 101,
        'createdAt': '2026-10-26T12:00:00Z',
        'expiresAt': '2026-10-26T13:00:00Z',
      },
    };
    bad.forEach(
      (name, json) => test(
        'rosak ditolak: $name',
        () => expect(Report.tryFromJson(json), isNull),
      ),
    );

    test('isActive: sempadan luput', () {
      final r = _report('a', here);
      expect(
        r.isActive(r.expiresAt.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(r.isActive(r.expiresAt), isFalse);
    });
  });

  group('LocalReportsRepository', () {
    late Directory dir;
    late File file;
    late LocalReportsRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fg_reports_');
      file = File('${dir.path}/sub/reports.json');
      repo = LocalReportsRepository(file);
    });
    tearDown(() => dir.delete(recursive: true));

    test(
      'mencipta laporan dengan hayat asas dan menyimpannya pada cakera',
      () async {
        final out = await repo.create(ReportType.accident, here, t0);
        expect(out.isNew, isTrue);
        expect(out.report.expiresAt, t0.add(const Duration(hours: 1)));
        expect(file.existsSync(), isTrue);
        expect(
          File('${file.path}.tmp').existsSync(),
          isFalse,
          reason: 'tiada fail sementara tertinggal',
        );

        final reloaded = LocalReportsRepository(file);
        final active = await reloaded.active(t0);
        expect(active.single.id, out.report.id);
      },
    );

    test('laporan luput tidak disenaraikan dan dibuang oleh purge', () async {
      await repo.create(ReportType.trafficJam, here, t0);
      expect(
        await repo.active(t0.add(const Duration(minutes: 29))),
        hasLength(1),
      );
      expect(await repo.active(t0.add(const Duration(minutes: 31))), isEmpty);
      expect(await repo.purgeExpired(t0.add(const Duration(minutes: 31))), 1);
      expect(await repo.purgeExpired(t0.add(const Duration(minutes: 31))), 0);
    });

    test(
      'jenis sama dalam 150 m = kejadian sama: disahkan, bukan diduakan',
      () async {
        final first = await repo.create(ReportType.police, here, t0);
        final second = await repo.create(
          ReportType.police,
          north(here, 100),
          t0.add(const Duration(minutes: 5)),
        );
        expect(second.isNew, isFalse);
        expect(second.report.id, first.report.id);
        expect(second.report.confirms, 1);
        expect(second.report.expiresAt.isAfter(first.report.expiresAt), isTrue);
        expect(await repo.active(t0), hasLength(1));
      },
    );

    test(
      'jenis berbeza atau lebih jauh daripada 150 m ialah laporan baharu',
      () async {
        await repo.create(ReportType.police, here, t0);
        expect(
          (await repo.create(ReportType.accident, here, t0)).isNew,
          isTrue,
        );
        expect(
          (await repo.create(ReportType.police, north(here, 400), t0)).isNew,
          isTrue,
        );
        expect(await repo.active(t0), hasLength(3));
      },
    );

    test('laporan luput di tempat sama bukan pendua', () async {
      await repo.create(ReportType.trafficJam, here, t0);
      final later = t0.add(const Duration(hours: 1));
      expect(
        (await repo.create(ReportType.trafficJam, here, later)).isNew,
        isTrue,
      );
    });

    test(
      'pengesahan melanjutkan hayat separuh hayat asas, dihadkan 3x hayat asas',
      () async {
        final r = (await repo.create(
          ReportType.accident,
          here,
          t0,
        )).report; // 1 jam
        var cur = r;
        for (var i = 0; i < 10; i++) {
          cur = (await repo.vote(
            r.id,
            confirm: true,
            now: t0.add(Duration(minutes: i + 1)),
          ))!;
        }
        expect(cur.confirms, 10);
        expect(
          cur.expiresAt,
          t0.add(const Duration(hours: 3)),
          reason: 'had 3x hayat asas dari masa dicipta',
        );
      },
    );

    test('satu pengesahan: +30 minit untuk hayat asas 1 jam', () async {
      final r = (await repo.create(ReportType.accident, here, t0)).report;
      final v = (await repo.vote(
        r.id,
        confirm: true,
        now: t0.add(const Duration(minutes: 10)),
      ))!;
      expect(v.expiresAt, t0.add(const Duration(minutes: 90)));
    });

    test('penafian membuang laporan (ambang tempatan = 1)', () async {
      final r = (await repo.create(ReportType.hazard, here, t0)).report;
      expect(await repo.vote(r.id, confirm: false, now: t0), isNull);
      expect(await repo.active(t0), isEmpty);
    });

    test('ambang penafian boleh dilaraskan (backend kongsi: 3)', () async {
      final shared = LocalReportsRepository(
        File('${dir.path}/shared.json'),
        denyThreshold: 3,
      );
      final r = (await shared.create(ReportType.hazard, here, t0)).report;
      expect((await shared.vote(r.id, confirm: false, now: t0))!.denies, 1);
      expect((await shared.vote(r.id, confirm: false, now: t0))!.denies, 2);
      expect(await shared.vote(r.id, confirm: false, now: t0), isNull);
    });

    test(
      'mengundi laporan yang tidak wujud atau sudah luput -> null',
      () async {
        expect(await repo.vote('tiada', confirm: true, now: t0), isNull);
        final r = (await repo.create(ReportType.trafficJam, here, t0)).report;
        expect(
          await repo.vote(
            r.id,
            confirm: true,
            now: t0.add(const Duration(hours: 2)),
          ),
          isNull,
        );
      },
    );

    test(
      'fail rosak tidak menghalang app: bermula kosong dan boleh menulis semula',
      () async {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('{bukan json');
        expect(await repo.active(t0), isEmpty);
        await repo.create(ReportType.police, here, t0);
        expect(await LocalReportsRepository(file).active(t0), hasLength(1));
      },
    );

    test('rekod rosak dalam fail dilangkau, rekod sah kekal', () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        jsonEncode([
          'sampah',
          _report('baik', here).toJson(),
          {'id': 'x', 'type': 'ufo'},
        ]),
      );
      expect((await repo.active(t0)).map((r) => r.id), ['baik']);
    });

    test('operasi serentak tidak merosakkan fail (disiri)', () async {
      await Future.wait([
        for (var i = 0; i < 20; i++)
          repo.create(ReportType.hazard, north(here, i * 1000.0), t0),
      ]);
      expect(await LocalReportsRepository(file).active(t0), hasLength(20));
      expect(() => jsonDecode(file.readAsStringSync()), returnsNormally);
    });
  });

  group('reportsAhead', () {
    test('hanya dalam jejari dan di hadapan arah perjalanan', () {
      final ahead = _report('depan', north(here, 300)); // utara
      final behind = _report('belakang', north(here, -300)); // selatan
      final far = _report('jauh', north(here, 900));
      final out = reportsAhead(
        [ahead, behind, far],
        here,
        headingDegrees: 0,
        now: t0,
      );
      expect(out.map((a) => a.report.id), ['depan']);
      expect(out.single.distanceM, closeTo(300, 3));
    });

    test(
      'arah tidak diketahui: semua dalam jejari (berlebihan lebih selamat)',
      () {
        final out = reportsAhead(
          [_report('a', north(here, 300)), _report('b', north(here, -300))],
          here,
          headingDegrees: null,
          now: t0,
        );
        expect(out, hasLength(2));
      },
    );

    test(
      'sangat dekat (<30 m) sentiasa disertakan walaupun bearing tidak stabil',
      () {
        final out = reportsAhead(
          [_report('dekat', north(here, -20))],
          here,
          headingDegrees: 0,
          now: t0,
        );
        expect(out, hasLength(1));
      },
    );

    test('disusun dari yang terdekat; laporan luput dilangkau', () {
      final out = reportsAhead(
        [
          _report('b', north(here, 400)),
          _report('a', north(here, 100)),
          _report(
            'luput',
            north(here, 50),
            expires: t0.subtract(const Duration(minutes: 1)),
          ),
        ],
        here,
        headingDegrees: 0,
        now: t0,
      );
      expect(out.map((e) => e.report.id), ['a', 'b']);
    });

    test(
      'lencongan sudut: 90 darjah ke sisi dikecualikan; 45 darjah disertakan',
      () {
        final east = GeoPoint(
          here.lat,
          here.lng + 300 / (111320.0 * 0.998),
        ); // ~300 m timur
        expect(
          reportsAhead(
            [_report('timur', east)],
            here,
            headingDegrees: 0,
            now: t0,
          ),
          isEmpty,
        );
        final northEast = GeoPoint(
          here.lat + 212 / 111320.0,
          here.lng + 212 / (111320.0 * 0.998),
        );
        expect(
          reportsAhead(
            [_report('tl', northEast)],
            here,
            headingDegrees: 0,
            now: t0,
          ),
          hasLength(1),
        );
      },
    );
  });

  group('ReportAlertTracker', () {
    test('umumkan sekali sahaja setiap laporan', () {
      final tracker = ReportAlertTracker();
      final r = _report('a', north(here, 400));
      final first = tracker.update([r], here, headingDegrees: 0, now: t0);
      final second = tracker.update(
        [r],
        north(here, 20),
        headingDegrees: 0,
        now: t0,
      );
      expect(first.announce.single.report.id, 'a');
      expect(second.announce, isEmpty);
    });

    test(
      'tidak diumumkan jika masih di luar jarak amaran; diumumkan bila masuk',
      () {
        final tracker = ReportAlertTracker();
        final r = _report('a', north(here, 2000));
        expect(
          tracker.update([r], here, headingDegrees: 0, now: t0).isEmpty,
          isTrue,
        );
        expect(
          tracker
              .update([r], north(here, 1700), headingDegrees: 0, now: t0)
              .announce,
          hasLength(1),
        );
      },
    );

    test(
      '"Masih ada?" hanya untuk laporan lebih 10 minit, dalam 80 m, dan sekali',
      () {
        final tracker = ReportAlertTracker();
        final old = _report(
          'lama',
          north(here, 40),
          created: t0.subtract(const Duration(minutes: 20)),
          expires: t0.add(const Duration(hours: 1)),
        );
        final fresh = _report(
          'baru',
          north(here, 40),
          created: t0.subtract(const Duration(minutes: 2)),
          expires: t0.add(const Duration(hours: 1)),
        );

        final first = tracker.update(
          [old, fresh],
          here,
          headingDegrees: 0,
          now: t0,
        );
        expect(first.ask.map((a) => a.report.id), ['lama']);
        expect(
          tracker.update([old, fresh], here, headingDegrees: 0, now: t0).ask,
          isEmpty,
        );
      },
    );

    test('laporan 100 m jauhnya belum ditanya', () {
      final tracker = ReportAlertTracker();
      final old = _report(
        'lama',
        north(here, 100),
        created: t0.subtract(const Duration(minutes: 20)),
        expires: t0.add(const Duration(hours: 1)),
      );
      expect(
        tracker.update([old], here, headingDegrees: 0, now: t0).ask,
        isEmpty,
      );
    });

    test('reset: perjalanan baharu mengumumkan semula', () {
      final tracker = ReportAlertTracker();
      final r = _report('a', north(here, 300));
      tracker.update([r], here, headingDegrees: 0, now: t0);
      tracker.reset();
      expect(
        tracker.update([r], here, headingDegrees: 0, now: t0).announce,
        hasLength(1),
      );
    });
  });

  group('ReportsController', () {
    late Directory dir;
    late DateTime now;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('fg_reports_ctrl_');
      now = t0;
    });
    tearDown(() => dir.delete(recursive: true));

    ProviderContainer container({FakeLocationService? location}) {
      final c = ProviderContainer(
        overrides: [
          reportsRepositoryProvider.overrideWithValue(
            LocalReportsRepository(File('${dir.path}/r.json')),
          ),
          reportsClockProvider.overrideWithValue(() => now),
          locationServiceProvider.overrideWithValue(
            location ??
                FakeLocationService(fix: const LocationFix(point: here)),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(reportsControllerProvider, (_, _) {});
      return c;
    }

    ReportsController ctl(ProviderContainer c) =>
        c.read(reportsControllerProvider.notifier);
    List<Report> state(ProviderContainer c) =>
        c.read(reportsControllerProvider);

    test(
      'melaporkan di kedudukan GPS (bukan lokasi yang ditaip) dan keadaan dikemas kini',
      () async {
        final c = container();
        expect(
          await ctl(c).report(ReportType.police),
          CreateReportResult.created,
        );
        expect(state(c).single.point, here);
      },
    );

    test(
      'tiada fix GPS: tidak ada laporan dicipta (mesti dari lokasi sebenar)',
      () async {
        final c = container(location: FakeLocationService(fix: null));
        expect(
          await ctl(c).report(ReportType.police),
          CreateReportResult.noLocation,
        );
        expect(state(c), isEmpty);
      },
    );

    test('laporan sama berdekatan -> disahkan, bukan pendua', () async {
      final c = container();
      await ctl(c).report(ReportType.accident);
      expect(
        await ctl(c).report(ReportType.accident),
        CreateReportResult.confirmedExisting,
      );
      expect(state(c), hasLength(1));
      expect(state(c).single.confirms, 1);
    });

    test('luput dikuatkuasakan pada refresh', () async {
      final c = container();
      await ctl(c).report(ReportType.trafficJam);
      expect(state(c), hasLength(1));
      now = t0.add(const Duration(minutes: 31));
      await ctl(c).refresh();
      expect(state(c), isEmpty);
    });

    test('vote: Tiada membuang, Ya melanjutkan', () async {
      final c = container();
      await ctl(c).report(ReportType.hazard);
      final id = state(c).single.id;
      final before = state(c).single.expiresAt;
      await ctl(c).vote(id, confirm: true);
      expect(state(c).single.expiresAt.isAfter(before), isTrue);
      await ctl(c).vote(id, confirm: false);
      expect(state(c), isEmpty);
    });

    test('laporan yang disimpan dipulihkan oleh sesi baharu', () async {
      final c1 = container();
      await ctl(c1).report(ReportType.flood);
      final c2 = container();
      await ctl(c2).refresh();
      expect(state(c2).single.type, ReportType.flood);
    });
  });
}
