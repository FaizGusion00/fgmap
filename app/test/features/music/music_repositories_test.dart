import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/features/music/data/audius_repository.dart';
import 'package:fgmap/features/music/data/local_library.dart';
import 'package:fgmap/features/music/data/radio_browser_repository.dart';
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
    test('respons carian sebenar: lagu boleh strim sahaja, URL strim + app_name', () {
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
    });

    test('trending dihurai; data kosong/rosak -> senarai kosong', () {
      expect(
        parseAudiusTracks(jsonDecode(_fixture('audius_trending.json')), baseUrl: 'x'),
        hasLength(3),
      );
      expect(parseAudiusTracks({'data': []}, baseUrl: 'x'), isEmpty);
      expect(parseAudiusTracks('bukan json', baseUrl: 'x'), isEmpty);
      expect(parseAudiusTracks({'data': [{'id': 'a'}]}, baseUrl: 'x'), isEmpty);
    });

    test('permintaan: /v1/tracks/search dengan query dan app_name=FGMaps', () async {
      final dio = Dio();
      final adapter = StubAdapter((_) => _json(_fixture('audius_search.json')));
      dio.httpClientAdapter = adapter;
      final repo = DioAudiusRepository(dio, baseUrl: 'https://api.audius.co/');
      final tracks = await repo.search('lagu raya');
      expect(tracks, isNotEmpty);
      final uri = adapter.lastRequest!.uri;
      expect(uri.path, '/v1/tracks/search');
      expect(uri.queryParameters['query'], 'lagu raya');
      expect(uri.queryParameters['app_name'], 'FGMaps');
      expect(await repo.search('   '), isEmpty);
      await repo.trending();
      expect(adapter.lastRequest!.uri.path, '/v1/tracks/trending');
    });
  });

  group('Radio Browser', () {
    test('respons sebenar: hanya HTTPS, stesen Malaysia, tag sebagai subtajuk', () {
      final stations = parseRadioStations(jsonDecode(_fixture('radio_browser_my.json')));
      // Fixture: 6 https + 2 http.
      expect(stations, hasLength(6));
      expect(stations.every((t) => t.streamUri.scheme == 'https'), isTrue);
      expect(stations.every((t) => t.source == TrackSource.radio), isTrue);
      expect(stations.every((t) => t.isLive && t.duration == null), isTrue);
      expect(stations.first.radioUuid, isNotNull);
      expect(stations.map((t) => t.title), contains('Sinar FM'));
      expect(stations.any((t) => t.title.startsWith('Jazz Lounge')), isFalse);
    });

    test('cermin: gagal -> cuba seterusnya; klik dihantar ke cermin yang berjaya', () async {
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
      );
      final stations = await repo.stations();
      expect(stations, hasLength(6));
      expect(calls, 2);
      final uri = adapter.lastRequest!.uri;
      expect(uri.host, 'good.example');
      expect(uri.path, '/json/stations/search');
      expect(uri.queryParameters['countrycode'], 'MY');
      expect(uri.queryParameters['hidebroken'], 'true');

      // Penapis nama guna cache (tiada permintaan baharu).
      final filtered = await repo.stations(query: 'sinar');
      expect(filtered.map((t) => t.title), ['Sinar FM']);
      expect(calls, 2);

      await repo.countClick(stations.first.radioUuid!);
      expect(adapter.lastRequest!.uri.host, 'good.example');
      expect(adapter.lastRequest!.uri.path, '/json/url/${stations.first.radioUuid}');
    });

    test('semua cermin gagal -> melontar', () async {
      final dio = Dio();
      dio.httpClientAdapter = FailingAdapter(DioExceptionType.connectionError);
      final repo = DioRadioBrowserRepository(dio, mirrors: ['https://a.example']);
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
      Track(id: 'abc', source: TrackSource.radio, title: 'lain', streamUri: Uri.parse('https://z')),
      isNot(t),
    );
  });
}
