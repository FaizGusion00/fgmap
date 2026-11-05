import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
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

  test(
    'dengan lokasi: tanpa koordinat ikut pusat daerah, bukan di hujung senarai',
    () {
      MasjidEntry m(
        String name,
        String district,
        String state, [
        GeoPoint? p,
      ]) => MasjidEntry(
        type: MasjidType.surau,
        name: name,
        district: district,
        state: state,
        point: p,
      );
      final dir = MasjidDirectory([
        m('Surau Jauh', 'Kota Kinabalu', 'Sabah', const GeoPoint(5.98, 116.07)),
        m('Surau Tanpa Koordinat', 'Gombak', 'Selangor'),
        m('Surau A', 'Gombak', 'Selangor', const GeoPoint(3.25, 101.65)),
        m('Surau B', 'Gombak', 'Selangor', const GeoPoint(3.27, 101.67)),
        m('Surau Daerah Kosong', 'Hulu Selangor', 'Selangor'),
      ]);
      final r = dir
          .query(const MasjidQuery(), near: const GeoPoint(3.25, 101.65))
          .map((e) => e.name)
          .toList();
      expect(r.first, 'Surau A');
      expect(
        r.indexOf('Surau Tanpa Koordinat'),
        lessThan(r.indexOf('Surau Jauh')),
      );
      // Tiada anggaran langsung: di hujung.
      expect(r.last, 'Surau Daerah Kosong');
    },
  );

  test('carian: ejaan bercantum, petikan pintar, kampong, mosque', () {
    MasjidEntry m(String name) =>
        MasjidEntry(type: MasjidType.masjid, name: name, state: 'Johor');
    final dir = MasjidDirectory([
      m('Masjid As-Syakirin'),
      m("Surau Ma'bud"),
      m('Masjid Kampung Parit Raja'),
      m('Surau Al-Falah'),
    ]);
    List<String> q(String t) =>
        dir.query(MasjidQuery(text: t)).map((e) => e.name).toList();
    expect(q('assyakirin'), ['Masjid As-Syakirin']);
    expect(q('alfalah'), ['Surau Al-Falah']);
    expect(q('ma’bud'), ["Surau Ma'bud"]);
    expect(q('kampong parit'), ['Masjid Kampung Parit Raja']);
    expect(q('pt raja'), ['Masjid Kampung Parit Raja']);
    expect(q('mosque syakirin'), ['Masjid As-Syakirin']);
  });

  test('aset: poskod 5 digit (sifar depan), tiada daerah "Tiada Maklumat"', () {
    expect(
      all.where((e) => e.postcode != null && e.postcode!.length != 5),
      isEmpty,
    );
    expect(
      all.where((e) => (e.district ?? '').toLowerCase().startsWith('tiada')),
      isEmpty,
    );
    expect(all.where((e) => e.postcode == '09100'), isNotEmpty);
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
    'geokod: tolak nama jalan, kawasan besar, nama lain dan hasil terlalu jauh',
    () async {
      final perak = MasjidEntry(
        type: MasjidType.masjid,
        name: 'Masjid Al-Ikhlas',
        state: 'Perak',
        district: 'Kinta',
      );
      final geo = _FakeGeocoder()
        ..results = const [
          // "Jalan Perak" di KL: nama jalan, bukan negeri Perak.
          Place(
            name: 'Masjid Al-Ikhlas',
            subtitle: 'Jalan Perak, Kuala Lumpur, Malaysia',
            point: GeoPoint(3.16, 101.71),
          ),
          // Negeri itu sendiri: pusatnya bukan lokasi masjid.
          Place(
            name: 'Perak',
            subtitle: 'Malaysia',
            point: GeoPoint(4.6, 101.1),
            category: 'state',
            osmKey: 'place',
          ),
          // Nama masjid lain di Perak (carian nama mesti sepadan).
          Place(
            name: 'Masjid Sultan Idris',
            subtitle: 'Ipoh, Kinta, Perak',
            point: GeoPoint(4.59, 101.08),
          ),
          Place(
            name: 'Masjid Al Ikhlas',
            subtitle: 'Ipoh, Kinta, Perak, Malaysia',
            point: GeoPoint(4.61, 101.09),
          ),
        ];
      expect(
        await findMasjidLocation(geo, perak),
        const GeoPoint(4.61, 101.09),
      );
      // Pusat daerah diketahui (Kinta) dan hasil 300 km jauhnya: ditolak.
      geo.results = const [
        Place(
          name: 'Masjid Al-Ikhlas',
          subtitle: 'Kinta, Perak',
          point: GeoPoint(1.9, 103.3),
        ),
      ];
      expect(
        await findMasjidLocation(
          geo,
          perak,
          areaCentre: const GeoPoint(4.6, 101.1),
        ),
        isNull,
      );
    },
  );

  test('geokod: ejaan Photon "Penang" diterima untuk Pulau Pinang', () async {
    final e = MasjidEntry(
      type: MasjidType.surau,
      name: 'Surau Nurul Iman',
      state: 'Pulau Pinang',
      district: 'Timur Laut',
    );
    final geo = _FakeGeocoder()
      ..results = const [
        Place(
          name: 'Surau Nurul Iman',
          subtitle: 'George Town, Penang, Malaysia',
          point: GeoPoint(5.41, 100.33),
        ),
      ];
    expect(await findMasjidLocation(geo, e), const GeoPoint(5.41, 100.33));
  });

  test(
    'FG AI: "senarai masjid Selangor" membuka direktori; "masjid terdekat" tidak',
    () {
      OpenScreenIntent? open(String t) {
        final i = parseIntent(t);
        return i is OpenScreenIntent ? i : null;
      }

      final a = open('senarai masjid selangor')!;
      expect((a.screen, a.arg), (AppScreen.masjidDirectory, 'selangor'));
      expect(open('list of mosques in penang')!.arg, 'Pulau Pinang');
      expect(open('senarai masjid melaka')!.arg, 'Melaka');
      expect(open('senarai masjid kl')!.arg, 'Kuala Lumpur');
      // "Terdekat / near me": buka direktori (disusun ikut jarak), bukan cari "terdekat".
      final near = open('senarai masjid terdekat')!;
      expect((near.screen, near.arg), (AppScreen.masjidDirectory, null));
      expect(open('list mosques near me')!.arg, isNull);
      expect(open('senarai surau dekat sini')!.arg, isNull);
      expect(open('senarai masjid di kuala kedah')!.arg, 'kuala kedah');
      expect(
        open('show all mosques along the route')?.screen,
        isNot(AppScreen.masjidDirectory),
      );
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
