import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:fgmap/features/local_assistant/domain/nlu/intents.dart';
import 'package:fgmap/features/masjid/data/masjid_directory.dart';
import 'package:fgmap/features/masjid/presentation/masjid_directory_page.dart';
import 'package:fgmap/features/search/data/photon_geocoder.dart';
import 'package:fgmap/features/search/domain/place.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _FakeGeocoder implements Geocoder {
  final List<String> queries = [];
  List<Place> results = const [];

  @override
  Future<List<Place>> search(
    String query, {
    GeoPoint? near,
    CancelToken? cancel,
  }) async {
    queries.add(query);
    return results;
  }
}

/// Direktori masjid & surau JAKIM (aset sebenar dalam app).
void main() {
  late List<MasjidEntry> all;
  setUpAll(() {
    all = decodeMasjidRows(
      Uint8List.fromList(
        File('assets/jakim/masjid_surau.json.gz').readAsBytesSync(),
      ),
    );
  });

  test('aset: lebih 20 ribu tempat, 16 negeri, ada masjid tepat OSM', () {
    final dir = MasjidDirectory(all);
    expect(all.length, greaterThan(20000));
    expect(dir.states, hasLength(16));
    expect(dir.states, containsAll(['Selangor', 'Sabah', 'Kuala Lumpur']));
    expect(all.where((e) => e.point != null).length, greaterThan(1000));
    expect(
      all.where((e) => e.type == MasjidType.masjid).length,
      greaterThan(6000),
    );
    // Tiada "TIADA MAKLUMAT" sebagai nilai.
    expect(
      all.where((e) => (e.phone ?? '').toUpperCase().contains('TIADA')),
      isEmpty,
    );
  });

  test('carian teks, negeri, daerah dan jenis', () {
    final dir = MasjidDirectory(all);
    final sel = dir.query(
      const MasjidQuery(state: 'Selangor', type: MasjidType.masjid),
    );
    expect(sel, isNotEmpty);
    expect(sel.every((e) => e.state == 'Selangor'), isTrue);
    expect(sel.every((e) => e.type == MasjidType.masjid), isTrue);
    // Singkatan "Kg." dipadankan dengan "kampung".
    final kg = dir.query(const MasjidQuery(text: 'kampung'));
    expect(kg.any((e) => e.name.contains('Kg.')), isTrue);
    final district = dir.districtsOf('Selangor');
    expect(district, contains('Petaling'));
    expect(
      dir
          .query(const MasjidQuery(state: 'Selangor', district: 'Petaling'))
          .every((e) => e.district == 'Petaling'),
      isTrue,
    );
  });

  test('dengan lokasi: yang berkoordinat disusun ikut jarak dahulu', () {
    final dir = MasjidDirectory(all);
    const klcc = GeoPoint(3.1579, 101.7117);
    final r = dir.query(const MasjidQuery(state: 'Kuala Lumpur'), near: klcc);
    final located = r.takeWhile((e) => e.point != null).toList();
    expect(located.length, greaterThan(5));
    for (var i = 1; i < located.length; i++) {
      expect(
        distanceMeters(klcc, located[i].point!),
        greaterThanOrEqualTo(distanceMeters(klcc, located[i - 1].point!)),
      );
    }
    expect(r.skip(located.length).every((e) => e.point == null), isTrue);
  });

  test(
    'tanpa koordinat: cari alamat, hanya terima hasil dalam negeri yang sama',
    () async {
      final e = MasjidEntry(
        type: MasjidType.surau,
        name: 'Surau Al-Hidayah',
        state: 'Kedah',
        district: 'Kuala Muda',
        postcode: '08000',
      );
      final geo = _FakeGeocoder()
        ..results = const [
          Place(
            name: 'Surau Al-Hidayah',
            subtitle: 'Johor Bahru, Johor',
            point: GeoPoint(1.5, 103.7),
          ),
          Place(
            name: 'Surau Al-Hidayah',
            subtitle: 'Sungai Petani, Kuala Muda, Kedah',
            point: GeoPoint(5.64, 100.49),
          ),
        ];
      final p = await findMasjidLocation(geo, e);
      expect(p, const GeoPoint(5.64, 100.49));
      expect(geo.queries.first, 'Surau Al-Hidayah, Kuala Muda, Kedah');

      geo.results = const [];
      expect(await findMasjidLocation(geo, e), isNull);
      expect(
        geo.queries.length,
        greaterThan(2),
        reason: 'cuba alamat dan poskod',
      );
    },
  );

  test(
    'FG AI: "senarai masjid Selangor" membuka direktori; "masjid terdekat" tidak',
    () {
      OpenScreenIntent? open(String t) {
        final i = parseIntent(t);
        return i is OpenScreenIntent ? i : null;
      }

      final a = open('senarai masjid selangor')!;
      expect((a.screen, a.arg), (AppScreen.masjidDirectory, 'selangor'));
      expect(open('list of mosques in penang')!.arg, 'penang');
      expect(
        open('buka senarai masjid dan surau')!.screen,
        AppScreen.masjidDirectory,
      );
      expect(open('buka masjid dan surau')!.screen, AppScreen.masjidDirectory);
      expect(
        open('pergi ke masjid negara')?.screen,
        isNot(AppScreen.masjidDirectory),
      );
      expect(
        open('cari masjid terdekat')?.screen,
        isNot(AppScreen.masjidDirectory),
      );
    },
  );

  testWidgets(
    'halaman: penapis mengubah kiraan, baris tepat memulangkan tempat',
    (tester) async {
      final dir = MasjidDirectory(all);
      MasjidPick? picked;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async =>
                    picked = await showMasjidDirectory(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [masjidDirectoryProvider.overrideWith((ref) async => dir)],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      String count() =>
          tester.widget<Text>(find.byKey(const ValueKey('masjid-count'))).data!;
      final before = count();
      await tester.tap(find.byKey(const ValueKey('masjid-type-surau')));
      await tester.pumpAndSettle();
      expect(count(), isNot(before));
      await tester.enterText(
        find.byKey(const ValueKey('masjid-search')),
        'Masjid Seksyen 7',
      );
      await tester.tap(find.byKey(const ValueKey('masjid-type-all')));
      await tester.pumpAndSettle();
      final exact = dir
          .query(const MasjidQuery(text: 'Masjid Seksyen 7'))
          .firstWhere((e) => e.point != null);
      // Baris senarai (bukan teks dalam kotak carian).
      await tester.tap(
        find
            .descendant(
              of: find.byType(ListTile),
              matching: find.text(exact.name),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('masjid-go')));
      await tester.pumpAndSettle();
      expect(picked, isNotNull);
      expect(picked!.go, isTrue);
      expect(picked!.approximate, isFalse);
      expect(picked!.place.point, exact.point);
    },
  );

  testWidgets('penapis negeri sekecil cip lain, lembaran menapis daerah', (
    tester,
  ) async {
    final dir = MasjidDirectory(all);
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showMasjidDirectory(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [masjidDirectoryProvider.overrideWith((ref) async => dir)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    String count() =>
        tester.widget<Text>(find.byKey(const ValueKey('masjid-count'))).data!;
    final allCount = count();
    final typeChip = tester.getSize(
      find.byKey(const ValueKey('masjid-type-all')),
    );
    final stateChip = tester.getSize(
      find.descendant(
        of: find.byKey(const ValueKey('masjid-state')),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(stateChip.height, lessThanOrEqualTo(typeChip.height + 1));
    expect(stateChip.width, lessThan(220));
    expect(find.byType(DropdownButton<String?>), findsNothing);

    await tester.tap(find.byKey(const ValueKey('masjid-state')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('masjid-filter-search')),
      'sela',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('masjid-filter-state-Selangor')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('masjid-filter-state-Johor')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('masjid-filter-state-Selangor')),
    );
    await tester.pumpAndSettle();
    final selangor = count();
    expect(selangor, isNot(allCount));
    expect(find.byKey(const ValueKey('masjid-district')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('masjid-district')));
    await tester.tap(find.byKey(const ValueKey('masjid-district')));
    await tester.pumpAndSettle();
    final districtList = find.descendant(
      of: find.byKey(const ValueKey('masjid-filter-list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('masjid-filter-district-Petaling')),
      160,
      scrollable: districtList,
    );
    await tester.tap(
      find.byKey(const ValueKey('masjid-filter-district-Petaling')),
    );
    await tester.pumpAndSettle();
    expect(count(), isNot(selangor));
    expect(tester.takeException(), isNull);
  });
}
