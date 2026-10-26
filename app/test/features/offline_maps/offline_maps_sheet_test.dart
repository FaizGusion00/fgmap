import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/offline_maps/domain/offline_models.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_map_controller.dart';
import 'package:fgmap/features/offline_maps/presentation/offline_maps_sheet.dart';
import 'package:fgmap/features/route_preview/data/route_planner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

OfflineManifest _manifest({
  String version = '20261026',
  int size = 253855993,
}) => OfflineManifest(
  region: 'malaysia',
  version: version,
  valhalla: expectedValhallaVersion,
  file: 'malaysia-$version.tar.gz',
  sizeBytes: size,
  sha256: 'a' * 64,
  extractedSizeBytes: 682844160,
  extractedSha256: 'b' * 64,
);

InstalledMap _installed(String version) => InstalledMap(
  version: version,
  sizeBytes: 682844160,
  tarPath: '/x/valhalla_tiles.tar',
);

class _FakeController extends OfflineMapController {
  _FakeController(this.initial);

  final OfflineMapState initial;
  int downloads = 0;
  int cancels = 0;
  int deletes = 0;
  int refreshes = 0;

  @override
  OfflineMapState build() => initial;

  @override
  Future<void> download() async => downloads++;

  @override
  void cancel() => cancels++;

  @override
  Future<void> delete() async {
    deletes++;
    state = state.copyWith(installed: () => null);
  }

  @override
  Future<void> refresh({bool checkRemote = true}) async {
    refreshes++;
  }
}

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<_FakeController> pumpSheet(
    WidgetTester tester,
    OfflineMapState state, {
    bool metered = false,
    Locale locale = const Locale('ms'),
  }) async {
    usePhoneSurface(tester, size: const Size(390, 1000));
    reduceMotion(tester);
    final fake = _FakeController(state);
    await pumpApp(
      tester,
      const Scaffold(body: OfflineMapsSheet()),
      locale: locale,
      overrides: [
        offlineMapControllerProvider.overrideWith(() => fake),
        isMeteredConnectionProvider.overrideWithValue(() async => metered),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pump();
    return fake;
  }

  testWidgets('tidak dikonfigurasi: mesej jelas, tiada butang muat turun', (
    tester,
  ) async {
    await pumpSheet(tester, const OfflineMapState());
    expect(find.textContaining('belum dikonfigurasi'), findsOneWidget);
    expect(find.text('Muat turun'), findsNothing);
  });

  testWidgets(
    'belum dipasang: tunjuk saiz dan butang Muat turun yang memulakan muat turun',
    (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(configured: true, latest: _manifest()),
      );
      expect(find.text('Belum dimuat turun'), findsOneWidget);
      expect(find.text('Saiz muat turun 254 MB'), findsOneWidget);

      await tester.tap(find.text('Muat turun'));
      await tester.pumpAndSettle();
      expect(fake.downloads, 1);
    },
  );

  testWidgets(
    'belum dipasang tetapi manifest belum diketahui: tiada butang (tiada apa untuk dimuat turun)',
    (tester) async {
      await pumpSheet(tester, const OfflineMapState(configured: true));
      expect(find.text('Muat turun'), findsNothing);
    },
  );

  testWidgets('manifest gagal disemak: mesej dan butang cuba lagi dipaparkan', (
    tester,
  ) async {
    final fake = await pumpSheet(
      tester,
      const OfflineMapState(configured: true, error: OfflineMapFailure.network),
    );

    expect(find.textContaining('pelayan peta offline'), findsOneWidget);
    await tester.tap(find.text('Cuba lagi'));
    await tester.pumpAndSettle();
    expect(fake.refreshes, 1);
  });

  group('data mudah alih', () {
    testWidgets('mengesahkan dahulu; Batal tidak memuat turun', (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(configured: true, latest: _manifest()),
        metered: true,
      );
      await tester.tap(find.text('Muat turun'));
      await tester.pumpAndSettle();

      expect(find.text('Guna data mudah alih?'), findsOneWidget);
      expect(find.textContaining('254 MB'), findsWidgets);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.downloads, 0);
    });

    testWidgets('Muat turun dalam dialog meneruskan', (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(configured: true, latest: _manifest()),
        metered: true,
      );
      await tester.tap(find.text('Muat turun'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Muat turun'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.downloads, 1);
    });

    testWidgets('Wi-Fi: tiada dialog', (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(configured: true, latest: _manifest()),
      );
      await tester.tap(find.text('Muat turun'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(fake.downloads, 1);
    });
  });

  group('kemajuan', () {
    testWidgets('memuat turun: peratusan, bar bernilai, butang Batal', (
      tester,
    ) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(
          configured: true,
          latest: _manifest(),
          op: OfflineOp.downloading,
          receivedBytes: 50,
          totalBytes: 200,
        ),
      );
      expect(find.text('Memuat turun… 25%'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.25);

      await tester.tap(find.text('Batal'));
      expect(fake.cancels, 1);
      expect(
        find.text('Muat turun'),
        findsNothing,
        reason: 'tiada muat turun kedua semasa sibuk',
      );
    });

    // Regresi: TweenAnimationBuilder menegaskan end != null, tetapi fasa ini tidak mempunyai peratusan.
    for (final (op, label) in [
      (OfflineOp.checking, 'Menyemak…'),
      (OfflineOp.verifying, 'Mengesahkan fail…'),
      (OfflineOp.installing, 'Memasang…'),
    ]) {
      testWidgets('$op: bar tidak tentu tanpa pengecualian', (tester) async {
        await pumpSheet(
          tester,
          OfflineMapState(
            configured: true,
            latest: _manifest(),
            op: op,
            receivedBytes: 10,
            totalBytes: 10,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text(label), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator),
              )
              .value,
          isNull,
        );
      });
    }

    testWidgets(
      'semasa memasang tiada butang Batal (tidak boleh dibatalkan dengan selamat)',
      (tester) async {
        await pumpSheet(
          tester,
          OfflineMapState(
            configured: true,
            latest: _manifest(),
            op: OfflineOp.installing,
          ),
        );
        expect(find.text('Batal'), findsNothing);
      },
    );
  });

  group('dipasang', () {
    testWidgets(
      'terkini: tarikh dan "terkini", tiada muat turun, boleh padam',
      (tester) async {
        final fake = await pumpSheet(
          tester,
          OfflineMapState(
            configured: true,
            installed: _installed('20261026'),
            latest: _manifest(),
          ),
        );
        expect(find.textContaining('Dipasang:'), findsOneWidget);
        expect(find.text('Peta offline terkini'), findsOneWidget);
        expect(find.text('Muat turun'), findsNothing);
        expect(find.text('Kemas kini'), findsNothing);

        await tester.tap(find.text('Padam'));
        await tester.pumpAndSettle();
        expect(find.text('Padam peta offline?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Padam'),
          ),
        );
        await tester.pumpAndSettle();
        expect(fake.deletes, 1);
      },
    );

    testWidgets('batal padam tidak memadam', (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(
          configured: true,
          installed: _installed('20261026'),
          latest: _manifest(),
        ),
      );
      await tester.tap(find.text('Padam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(fake.deletes, 0);
    });

    testWidgets('kemas kini tersedia: butang Kemas kini', (tester) async {
      final fake = await pumpSheet(
        tester,
        OfflineMapState(
          configured: true,
          installed: _installed('20261001'),
          latest: _manifest(),
        ),
      );
      expect(find.textContaining('Kemas kini tersedia'), findsOneWidget);
      await tester.tap(find.text('Kemas kini'));
      await tester.pumpAndSettle();
      expect(fake.downloads, 1);
    });

    testWidgets(
      'dipasang tanpa internet (manifest tidak diketahui): masih boleh padam, tiada ralat',
      (tester) async {
        await pumpSheet(
          tester,
          OfflineMapState(configured: true, installed: _installed('20261026')),
        );
        expect(find.text('Padam'), findsOneWidget);
        expect(find.text('Muat turun'), findsNothing);
      },
    );
  });

  group('ralat', () {
    final cases = {
      OfflineMapFailure.network: 'pelayan peta',
      OfflineMapFailure.storage: 'Ruang simpanan',
      OfflineMapFailure.checksum: 'rosak',
      OfflineMapFailure.incompatible: 'tidak serasi',
      OfflineMapFailure.manifestInvalid: 'tidak sah',
      OfflineMapFailure.generic: 'Sesuatu tidak kena',
    };
    cases.forEach((kind, text) {
      testWidgets('$kind', (tester) async {
        await pumpSheet(
          tester,
          OfflineMapState(configured: true, latest: _manifest(), error: kind),
        );
        expect(find.textContaining(text), findsOneWidget);
        expect(
          find.text('Muat turun'),
          findsOneWidget,
          reason: 'boleh cuba lagi',
        );
      });
    });
  });

  group('sumber laluan', () {
    testWidgets(
      'lalai Auto dengan petunjuk; menukar ke Offline sahaja disimpan',
      (tester) async {
        await pumpSheet(tester, const OfflineMapState());
        expect(find.textContaining('Online dahulu'), findsOneWidget);

        await tester.tap(find.text('Offline sahaja'));
        await tester.pumpAndSettle();

        expect(prefs.getString('routing.mode'), 'offlineOnly');
        expect(
          find.textContaining('Online dahulu'),
          findsNothing,
          reason: 'petunjuk hanya untuk Auto',
        );
      },
    );

    testWidgets('mod tersimpan dipulihkan', (tester) async {
      SharedPreferences.setMockInitialValues({'routing.mode': 'onlineOnly'});
      prefs = await SharedPreferences.getInstance();
      await pumpSheet(tester, const OfflineMapState());

      final selected = tester
          .widget<SegmentedButton<RoutingMode>>(
            find.byType(SegmentedButton<RoutingMode>),
          )
          .selected;
      expect(selected, {RoutingMode.onlineOnly});
    });
  });

  testWidgets('English', (tester) async {
    await pumpSheet(
      tester,
      OfflineMapState(configured: true, latest: _manifest()),
      locale: const Locale('en'),
    );
    expect(find.text('Not downloaded'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Offline only'), findsOneWidget);
  });

  group('pemformat', () {
    test('formatBytes', () {
      expect(formatBytes(253855993), '254 MB');
      expect(formatBytes(999 * 1000 * 1000), '999 MB');
      expect(formatBytes(1500 * 1000 * 1000), '1.5 GB');
    });

    test('formatPackDate: tarikh setempat atau versi asal jika tidak sah', () {
      expect(formatPackDate('20261026', 'en'), 'Oct 26, 2026');
      expect(formatPackDate('bukan-tarikh', 'ms'), 'bukan-tarikh');
    });
  });
}
