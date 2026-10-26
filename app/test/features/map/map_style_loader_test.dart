import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fgmap/core/config/app_config.dart';
import 'package:fgmap/features/map/data/map_style_loader.dart';
import 'package:fgmap/features/map/presentation/maplibre_view.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fakes.dart';

// Gaya SINTETIK minimum yang dikenali NightStyle (>= 5 lapisan OpenMapTiles).
String _style() => jsonEncode({
  'version': 8,
  'sprite': 'https://t.example/sprites/s',
  'glyphs': 'https://t.example/fonts/{fontstack}/{range}.pbf',
  'sources': {
    'o': {'type': 'vector', 'url': 'https://t.example/planet'},
  },
  'layers': [
    {'id': 'background', 'type': 'background'},
    {'id': 'water', 'type': 'fill', 'source-layer': 'water'},
    {'id': 'building', 'type': 'fill', 'source-layer': 'building'},
    {
      'id': 'road_primary',
      'type': 'line',
      'source-layer': 'transportation',
      'paint': {'line-width': 3},
    },
    {
      'id': 'label_city',
      'type': 'symbol',
      'source-layer': 'place',
      'layout': {'text-field': '{name}', 'text-size': 14},
    },
  ],
});

void main() {
  test(
    'firstSymbolLayerId: lapisan simbol pertama dalam JSON, null untuk URL',
    () {
      expect(firstSymbolLayerId(_style()), 'label_city');
      expect(firstSymbolLayerId('https://x.example/style'), isNull);
      expect(
        firstSymbolLayerId('{"layers":[{"id":"a","type":"fill"}]}'),
        isNull,
      );
      expect(firstSymbolLayerId('{rosak'), isNull);
    },
  );

  late Directory dir;
  var now = DateTime(2026, 10, 26, 12);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fg_style_');
    now = DateTime(2026, 10, 26, 12);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  MapStyleLoader loader(
    ResponseBody Function(RequestOptions) respond, {
    Directory? cache,
    Duration timeout = const Duration(seconds: 4),
  }) => MapStyleLoader(
    Dio()..httpClientAdapter = StubAdapter(respond),
    cache,
    clock: () => now,
    timeout: timeout,
  );

  ResponseBody ok() =>
      StubAdapter.text(_style(), status: 200, contentType: 'application/json');

  test('cerah: URL terus, tiada permintaan', () async {
    var calls = 0;
    final l = loader((_) {
      calls++;
      return ok();
    });
    final r = await l.resolve(dark: false);
    expect(r.style, AppConfig.mapStyleLight);
    expect(r.isJson, isFalse);
    expect(calls, 0);
  });

  test('gelap: gaya diambil, diwarnakan malam dan dicache', () async {
    final l = loader((_) => ok(), cache: dir);
    final r = await l.resolve(dark: true);
    expect(r.isJson, isTrue);
    expect(r.key, startsWith('night:'));
    final bg = (jsonDecode(r.style)['layers'] as List).first;
    expect(bg['paint']['background-color'], '#0f141b');
    expect(dir.listSync(), hasLength(1));
  });

  test('cache segar (< 7 hari): tiada permintaan rangkaian', () async {
    await loader((_) => ok(), cache: dir).resolve(dark: true);
    var calls = 0;
    final r = await loader((_) {
      calls++;
      return ok();
    }, cache: dir).resolve(dark: true);
    expect(r.isJson, isTrue);
    expect(calls, 0);
  });

  test('cache lama + rangkaian gagal: guna cache lama', () async {
    await loader((_) => ok(), cache: dir).resolve(dark: true);
    // Jadikan fail "lama" dengan memajukan jam melepasi TTL.
    now = now.add(MapStyleLoader.cacheTtl + const Duration(days: 1));
    final file = dir.listSync().single as File;
    file.setLastModifiedSync(DateTime(2026, 10, 26, 12));
    final r = await loader(
      (_) => StubAdapter.text('x', status: 503),
      cache: dir,
    ).resolve(dark: true);
    expect(r.isJson, isTrue);
  });

  test('tiada cache + rangkaian gagal: URL gaya gelap', () async {
    final r = await loader(
      (_) => StubAdapter.text('x', status: 503),
      cache: dir,
    ).resolve(dark: true);
    expect(r.style, AppConfig.mapStyleDark);
    expect(r.key, 'url:${AppConfig.mapStyleDark}');
  });

  test(
    'gaya tidak dikenali: URL gaya gelap (tiada gaya separuh siap)',
    () async {
      final r = await loader(
        (_) => StubAdapter.text(
          '{"layers":[]}',
          status: 200,
          contentType: 'application/json',
        ),
        cache: dir,
      ).resolve(dark: true);
      expect(r.style, AppConfig.mapStyleDark);
    },
  );

  test('badan bukan JSON (halaman ralat): URL', () async {
    final r = await loader(
      (_) => StubAdapter.text('<html>oops</html>', status: 200),
      cache: dir,
    ).resolve(dark: true);
    expect(r.style, AppConfig.mapStyleDark);
  });

  test('tanpa folder cache tetap berfungsi', () async {
    final r = await loader((_) => ok()).resolve(dark: true);
    expect(r.isJson, isTrue);
  });

  test('terlalu perlahan: jatuh ke URL selepas tamat masa', () async {
    final completer = Completer<ResponseBody>();
    final l = MapStyleLoader(
      Dio()..httpClientAdapter = _SlowAdapter(completer.future),
      dir,
      timeout: const Duration(milliseconds: 20),
    );
    final r = await l.resolve(dark: true);
    expect(r.style, AppConfig.mapStyleDark);
    completer.complete(ok());
  });
}

class _SlowAdapter implements HttpClientAdapter {
  _SlowAdapter(this.response);

  final Future<ResponseBody> response;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => response;

  @override
  void close({bool force = false}) {}
}
