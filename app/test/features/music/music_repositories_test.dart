import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/curated_stations.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
import 'package:fgmap/features/music/domain/music_repository.dart';
import 'package:fgmap/features/music/domain/track.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

String _fixture(String name) =>
    File('test/fixtures/music/$name').readAsStringSync();

ResponseBody _json(String text) => ResponseBody.fromString(
  text,
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  group('Audius', () {
    test(
      'respons carian sebenar: lagu boleh strim sahaja, URL strim + app_name',
      () {
        final tracks = parseAudiusTracks(
          jsonDecode(_fixture('audius_search.json')),
          baseUrl: 'https://api.audius.co',
        );
        expect(tracks, hasLength(4)); // fixture ada 5, satu is_streamable=false
        expect(tracks.any((t) => t.title == 'Tidak boleh strim'), isFalse);
        final first = tracks.first;
        expect(first.source, TrackSource.audius);
        expect(first.title, isNotEmpty);
        expect(first.artist, isNotNull);
        expect(
          first.streamUri.toString(),
          'https://api.audius.co/v1/tracks/${first.id}/stream?app_name=FGMaps',
        );
        expect(first.artworkUri?.scheme, 'https');
        expect(first.permalink.toString(), startsWith('https://audius.co/'));
        expect(first.duration, isNotNull);
        expect(first.isLive, isFalse);
      },
    );

    test('trending dihurai; data kosong/rosak -> senarai kosong', () {
      expect(
        parseAudiusTracks(
          jsonDecode(_fixture('audius_trending.json')),
          baseUrl: 'x',
        ),
        hasLength(3),
      );
      expect(parseAudiusTracks({'data': []}, baseUrl: 'x'), isEmpty);
      expect(parseAudiusTracks('bukan json', baseUrl: 'x'), isEmpty);
      expect(
        parseAudiusTracks({
          'data': [
            {'id': 'a'},
          ],
        }, baseUrl: 'x'),
        isEmpty,
      );
    });

    test(
      'permintaan: /v1/tracks/search dengan query dan app_name=FGMaps',
      () async {
        final dio = Dio();
        final adapter = StubAdapter(
          (_) => _json(_fixture('audius_search.json')),
        );
        dio.httpClientAdapter = adapter;
        final repo = DioAudiusRepository(
          dio,
          baseUrl: 'https://api.audius.co/',
        );
        final tracks = await repo.search('lagu raya');
        expect(tracks, isNotEmpty);
        final uri = adapter.lastRequest!.uri;
        expect(uri.path, '/v1/tracks/search');
        expect(uri.queryParameters['query'], 'lagu raya');
        expect(uri.queryParameters['app_name'], 'FGMaps');
        expect(await repo.search('   '), isEmpty);
        await repo.trending();
        expect(adapter.lastRequest!.uri.path, '/v1/tracks/trending');
      },
    );
  });

  group('Radio Browser', () {
    test(
      'respons sebenar: hanya HTTPS, stesen Malaysia, tag sebagai subtajuk',
      () {
        final stations = parseRadioStations(
          jsonDecode(_fixture('radio_browser_my.json')),
        );
        // Fixture: 6 https + 2 http.
        expect(stations, hasLength(6));
        expect(stations.every((t) => t.streamUri.scheme == 'https'), isTrue);
        expect(stations.every((t) => t.source == TrackSource.radio), isTrue);
        expect(stations.every((t) => t.isLive && t.duration == null), isTrue);
        expect(stations.first.radioUuid, isNotNull);
        expect(stations.map((t) => t.title), contains('Sinar FM'));
        expect(stations.any((t) => t.title.startsWith('Jazz Lounge')), isFalse);
      },
    );

    test(
      'kawasan: Indonesia, Japan, J-pop, Korea dan K-pop menggunakan penapis yang betul',
      () async {
        final dio = Dio();
        final adapter = StubAdapter(
          (options) => _json(_fixture('radio_browser_my.json')),
        );
        dio.httpClientAdapter = adapter;
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://m.example'],
          upgradeHttp: false,
        );
        await repo.stations(region: RadioRegion.indonesia);
        expect(adapter.lastRequest!.uri.queryParameters['countrycode'], 'ID');
        await repo.stations(region: RadioRegion.japan);
        expect(adapter.lastRequest!.uri.queryParameters['countrycode'], 'JP');
        await repo.stations(region: RadioRegion.jpop);
        expect(adapter.lastRequest!.uri.queryParameters['tag'], 'jpop');
        expect(
          adapter.lastRequest!.uri.queryParameters.containsKey('countrycode'),
          isFalse,
        );
        await repo.stations(region: RadioRegion.korea);
        expect(adapter.lastRequest!.uri.queryParameters['countrycode'], 'KR');
        await repo.stations(region: RadioRegion.kpop);
        final q = adapter.lastRequest!.uri.queryParameters;
        expect(q['tag'], 'kpop');
        expect(q.containsKey('countrycode'), isFalse);
        // `language=malay` memadankan Malayalam: tidak pernah digunakan.
        expect(q.containsKey('language'), isFalse);
      },
    );

    test(
      'cermin: gagal -> cuba seterusnya; klik dihantar ke cermin yang berjaya',
      () async {
        final dio = Dio();
        var calls = 0;
        final adapter = StubAdapter((options) {
          calls++;
          if (options.uri.host == 'bad.example') {
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'down',
            );
          }
          return _json(_fixture('radio_browser_my.json'));
        });
        dio.httpClientAdapter = adapter;
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://bad.example', 'https://good.example'],
          upgradeHttp: false,
          curated: const [],
        );
        final stations = await repo.stations();
        expect(stations, hasLength(6));
        expect(calls, 2);
        final uri = adapter.lastRequest!.uri;
        expect(uri.host, 'good.example');
        expect(uri.path, '/json/stations/search');
        expect(uri.queryParameters['countrycode'], 'MY');
        expect(uri.queryParameters['hidebroken'], 'true');

        // Carian nama: senarai kawasan (cache) dahulu, kemudian carian nama sedunia (satu
        // permintaan baharu tanpa penapis negara). Hasil bertindih tidak digandakan.
        final filtered = await repo.stations(query: 'sinar');
        expect(filtered.first.title, 'Sinar FM');
        expect(filtered.map((t) => t.id).toSet(), hasLength(filtered.length));
        expect(calls, 3);
        final byName = adapter.lastRequest!.uri.queryParameters;
        expect(byName['name'], 'sinar');
        expect(byName.containsKey('countrycode'), isFalse);

        await repo.countClick(stations.first.radioUuid!);
        expect(adapter.lastRequest!.uri.host, 'good.example');
        expect(
          adapter.lastRequest!.uri.path,
          '/json/url/${stations.first.radioUuid}',
        );
      },
    );

    test('hurai: ssl_error dibuang; http hanya jika disahkan (upgraded)', () {
      final json = [
        {
          'stationuuid': 'a',
          'name': 'Sijil Rosak',
          'url_resolved': 'https://a.example/live',
          'lastcheckok': 1,
          'ssl_error': 1,
        },
        {
          'stationuuid': 'b',
          'name': 'Hanya Http',
          'url_resolved': 'http://b.example/live',
          'lastcheckok': 1,
        },
        {
          'stationuuid': 'c',
          'name': 'Url Resolved Kosong',
          'url_resolved': '',
          'url': 'https://c.example/live',
          'lastcheckok': 1,
        },
      ];
      expect(parseRadioStations(json).map((t) => t.title), [
        'Url Resolved Kosong',
      ]);
      final up = parseRadioStations(json, upgraded: {'b'});
      expect(up.map((t) => t.title), ['Hanya Http', 'Url Resolved Kosong']);
      expect(up.first.streamUri.toString(), 'https://b.example/live');
      expect(radioUpgradeCandidates(json).keys, ['b']);
      expect(radioUpgradeCandidates('bukan senarai'), isEmpty);
    });

    test('naik taraf HTTPS: hanya varian yang menyiar audio dipaparkan; '
        'keputusan diingat untuk muatan seterusnya', () async {
      final dio = Dio();
      final probed = <String>[];
      final adapter = StubAdapter((options) {
        if (options.uri.host == 'm.example') {
          return _json(_fixture('radio_browser_my.json'));
        }
        probed.add(options.uri.toString());
        if (options.uri.host == 'playerservices.streamtheworld.com') {
          return ResponseBody.fromString(
            'x' * 64,
            200,
            headers: {
              Headers.contentTypeHeader: ['audio/mpeg'],
            },
          );
        }
        return ResponseBody.fromString('Not Found', 404);
      });
      dio.httpClientAdapter = adapter;
      final repo = DioRadioBrowserRepository(
        dio,
        mirrors: ['https://m.example'],
        curated: const [],
      );
      final stations = await repo.stations();
      // 6 https + Klasik FM (varian https berfungsi); Jazz Lounge (404) kekal tersembunyi.
      expect(stations, hasLength(7));
      final klasik = stations.firstWhere((t) => t.title.startsWith('Klasik'));
      expect(klasik.streamUri.scheme, 'https');
      expect(stations.any((t) => t.title.startsWith('Jazz Lounge')), isFalse);
      expect(probed, hasLength(2));
      expect(probed.every((u) => u.startsWith('https://')), isTrue);

      // Kawasan lain, respons sama: tiada probe baharu.
      await repo.stations(region: RadioRegion.indonesia);
      expect(probed, hasLength(2));
    });

    test(
      'naik taraf HTTPS dimatikan: tiada probe, http kekal tersembunyi',
      () async {
        final dio = Dio();
        var requests = 0;
        dio.httpClientAdapter = StubAdapter((_) {
          requests++;
          return _json(_fixture('radio_browser_my.json'));
        });
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://m.example'],
          upgradeHttp: false,
          curated: const [],
        );
        expect(await repo.stations(), hasLength(6));
        expect(requests, 1);
        expect(await repo.stations(region: RadioRegion.favorites), isEmpty);
        expect(requests, 1);
      },
    );

    test(
      'stesen disahkan: digabung ke hadapan, nama sama diganti, kawasan lain tidak terkesan',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = StubAdapter(
          (_) => _json(_fixture('radio_browser_my.json')),
        );
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://m.example'],
          upgradeHttp: false,
        );
        final my = await repo.stations();
        final curatedNames = curatedStations.map((c) => c.name).toList();
        expect(
          my.take(curatedStations.length).map((t) => t.title),
          curatedNames,
        );
        expect(my.length, curatedStations.length + 6);
        expect(my.first.streamUri.scheme, 'https');
        expect(
          my.first.radioUuid,
          isNull,
          reason: 'tiada kiraan klik untuk stesen tanpa uuid',
        );
        expect(my.first.key, 'radio:curated-era');
        // Fixture ada "Sinar FM" (bukan senarai disahkan): kekal; tiada penggandaan.
        expect(my.where((t) => t.title == 'Sinar FM'), hasLength(1));

        expect(
          (await repo.stations(
            region: RadioRegion.indonesia,
          )).any((t) => t.id.startsWith('curated-')),
          isFalse,
        );
        // Carian nama menemui stesen disahkan tanpa permintaan khas.
        final found = await repo.stations(query: 'suria');
        expect(found.first.title, 'Suria FM');
      },
    );

    test(
      'stesen disahkan menggantikan stesen Radio Browser bernama sama '
      '(termasuk akhiran frekuensi) tetapi bukan nama yang berbeza',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = StubAdapter(
          (_) => _json(
            jsonEncode([
              for (final (i, name) in [
                'Suria FM',
                'SURIA FM 105.1',
                'Suria FM Kuching',
              ].indexed)
                {
                  'stationuuid': 'u$i',
                  'name': name,
                  'url_resolved': 'https://rb.example/$i',
                  'lastcheckok': 1,
                },
            ]),
          ),
        );
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://m.example'],
          upgradeHttp: false,
          curated: const [
            CuratedStation(
              id: 'suria',
              name: 'Suria FM',
              stream: 'https://c.example/suria',
            ),
          ],
        );
        final titles = (await repo.stations()).map((t) => t.title).toList();
        expect(titles, ['Suria FM', 'Suria FM Kuching']);
      },
    );

    test(
      'direktori tidak dapat dicapai: stesen disahkan tetap dipaparkan (tidak di-cache)',
      () async {
        final dio = Dio();
        dio.httpClientAdapter = FailingAdapter(
          DioExceptionType.connectionError,
        );
        final repo = DioRadioBrowserRepository(
          dio,
          mirrors: ['https://a.example'],
        );
        final my = await repo.stations();
        expect(my.map((t) => t.title), curatedStations.map((c) => c.name));
        // Kawasan tanpa stesen disahkan masih melontar.
        expect(repo.stations(region: RadioRegion.korea), throwsA(anything));
      },
    );

    test(
      'data stesen disahkan sah: HTTPS, ID dan nama unik, bukan Radio Browser',
      () {
        expect(curatedStations, isNotEmpty);
        final ids = curatedStations.map((c) => c.id).toSet();
        final names = curatedStations
            .map((c) => normalizeStationName(c.name))
            .toSet();
        expect(ids, hasLength(curatedStations.length));
        expect(names, hasLength(curatedStations.length));
        for (final c in curatedStations) {
          expect(Uri.parse(c.stream).scheme, 'https', reason: c.name);
          expect(c.region, isNot(RadioRegion.favorites));
          expect(c.toTrack().isLive, isTrue);
        }
        expect(normalizeStationName('Suria FM Malaysia'), 'suria');
        expect(sameStation('suria', 'suria1051'), isTrue);
        expect(sameStation('suria', 'suriakuching'), isFalse);
        expect(sameStation('', 'apa-apa'), isFalse);
      },
    );

    test('semua cermin gagal -> melontar', () async {
      final dio = Dio();
      dio.httpClientAdapter = FailingAdapter(DioExceptionType.connectionError);
      final repo = DioRadioBrowserRepository(
        dio,
        mirrors: ['https://a.example'],
        curated: const [],
      );
      expect(repo.stations(), throwsA(anything));
    });
  });

  group('FileLocalLibrary', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('fgmap_music'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('import menyalin fail, mengindeks, membuang dan memadam', () async {
      final src = File('${tmp.path}/src/Lagu Raya.mp3')
        ..createSync(recursive: true)
        ..writeAsBytesSync([1, 2, 3]);
      final lib = FileLocalLibrary(
        Directory('${tmp.path}/music'),
        pickPaths: () async => [src.path],
      );
      expect(await lib.list(), isEmpty);
      final added = await lib.import();
      expect(added, hasLength(1));
      expect(added.first.title, 'Lagu Raya');
      expect(added.first.source, TrackSource.local);
      expect(File(added.first.streamUri.toFilePath()).existsSync(), isTrue);
      expect(await lib.list(), hasLength(1));
      // Import semula fail sama: tiada pendua.
      expect(await lib.import(), isEmpty);
      expect(await lib.list(), hasLength(1));
      await lib.remove(added.first);
      expect(await lib.list(), isEmpty);
      expect(File(added.first.streamUri.toFilePath()).existsSync(), isFalse);
      await lib.import();
      await lib.clear();
      expect(Directory('${tmp.path}/music').existsSync(), isFalse);
    });

    test('indeks rosak atau fail hilang diabaikan', () async {
      final dir = Directory('${tmp.path}/music')..createSync();
      File('${dir.path}/index.json').writeAsStringSync('{bukan json');
      final lib = FileLocalLibrary(dir, pickPaths: () async => []);
      expect(await lib.list(), isEmpty);
      File('${dir.path}/index.json').writeAsStringSync(
        jsonEncode([
          Track(
            id: 'hilang.mp3',
            source: TrackSource.local,
            title: 'hilang',
            streamUri: Uri.file('${dir.path}/hilang.mp3'),
          ).toJson(),
        ]),
      );
      expect(await lib.list(), isEmpty);
      expect(await lib.import(), isEmpty);
    });
  });

  test('Track JSON pergi balik dan kesamaan mengikut sumber+id', () {
    final t = Track(
      id: 'abc',
      source: TrackSource.audius,
      title: 'T',
      artist: 'A',
      streamUri: Uri.parse('https://x/y'),
      artworkUri: Uri.parse('https://x/art.jpg'),
      duration: const Duration(seconds: 90),
      permalink: Uri.parse('https://audius.co/a/t'),
    );
    final back = Track.fromJson(t.toJson())!;
    expect(back, t);
    expect(back.title, 'T');
    expect(back.duration, const Duration(seconds: 90));
    expect(back.permalink, t.permalink);
    expect(Track.fromJson({'id': 'x'}), isNull);
    expect(
      Track(
        id: 'abc',
        source: TrackSource.radio,
        title: 'lain',
        streamUri: Uri.parse('https://z'),
      ),
      isNot(t),
    );
  });
}
