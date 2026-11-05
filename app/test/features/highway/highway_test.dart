import 'dart:io';

import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/core/utils/geo.dart';
import 'package:fgmap/features/highway/data/llm_cctv.dart';
import 'package:fgmap/features/highway/data/llm_toll_client.dart';
import 'package:fgmap/features/highway/domain/highways.dart';
import 'package:fgmap/features/highway/presentation/highway_page.dart';
import 'package:fgmap/features/local_assistant/domain/intent_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class _FakeCctv implements LlmCctvClient {
  _FakeCctv(this.result);

  final Object result;
  final calls = <String>[];

  @override
  Future<List<CctvCamera>> fetch(
    String code, {
    Map<String, GeoPoint> positions = const {},
  }) async {
    calls.add(code);
    final r = result;
    if (r is Exception) throw r;
    return r as List<CctvCamera>;
  }
}

void main() {
  final fixture = File('test/fixtures/cctv/llm_spl.json').readAsStringSync();

  group('parseLlmCctv', () {
    test(
      'respons sebenar LLM (dengan BOM): 3 kamera, kedudukan dipadankan',
      () {
        final cams = parseLlmCctv(
          fixture,
          positions: {
            cctvKey('PLS_CAM_S4_SIMPANG_RENGGAM_KM60.1_NB.web.jpg'):
                const GeoPoint(1.9, 103.4),
          },
        );
        expect(cams, hasLength(3));
        expect(
          cams.every((c) => c.imageUrl.startsWith('https://api.llm.gov.my/')),
          isTrue,
        );
        final sr = cams.firstWhere((c) => c.name.contains('SIMPANG RENGGAM'));
        expect(sr.point, const GeoPoint(1.9, 103.4));
        expect(sr.direction, 'N');
        expect(sr.label, 'SIMPANG RENGGAM KM60.1');
        expect(cams.where((c) => c.point != null), hasLength(1));
      },
    );

    test('hos bukan LLM dan URL bukan https ditolak', () {
      final cams = parseLlmCctv(
        '{"status":"success","data":['
        '{"file_name":"a.web.jpg","url":"https://evil.example/a.jpg","location_name":"A"},'
        '{"file_name":"b.web.jpg","url":"http://api.llm.gov.my/b.jpg","location_name":"B"},'
        '{"file_name":"c.web.jpg","url":"https://api.llm.gov.my/c.jpg","location_name":"C SB"}]}',
      );
      expect(cams.map((c) => c.name), ['C SB']);
      expect(cams.single.direction, 'S');
    });

    test('badan rosak atau status gagal -> CctvFailure', () {
      for (final bad in ['', 'x', '[]', '{"status":"error"}']) {
        expect(
          () => parseLlmCctv(bad),
          throwsA(isA<CctvFailure>()),
          reason: bad,
        );
      }
    });

    test('kunci padanan sama dengan alat pembina', () {
      expect(
        cctvKey('SRT_CAM_65_M.KIARA_KM1.53_WB.web.jpg'),
        'srtcam65mkiarakm153wb',
      );
    });

    test('aset kedudukan GIS LLM sah dan dalam Malaysia', () {
      final raw = File(
        'assets/cctv/llm_cctv_positions.json',
      ).readAsStringSync();
      expect(raw, contains('"cameras"'));
      expect(
        RegExp(r'"[a-z0-9]+":\[').allMatches(raw).length,
        greaterThan(300),
      );
    });
  });

  group('lebuh raya', () {
    test('nama jalan laluan -> kod LLM (E1 dikongsi NKVE dan PLUS Utara)', () {
      expect(
        highwayCodesForStreetNames([
          'Persiaran Setia Alam',
          'E1',
          'Lebuhraya NKVE',
          'E6',
          'E2',
          'e2',
        ]),
        ['NKV', 'PLS', 'ELT', 'SPL'],
      );
      expect(highwayCodesForStreetNames(['Jalan Ampang', 'FT1']), isEmpty);
    });

    test('teks bebas: nama khusus menang', () {
      expect(highwayCodesInText('cctv plus selatan'), ['SPL']);
      expect(highwayCodesInText('tengok nkve'), ['NKV']);
      expect(highwayCodesInText('cctv plus'), ['PLS', 'SPL']);
      expect(highwayCodesInText('kamera MEX'), ['KLP']);
      expect(highwayCodesInText('apa khabar'), isEmpty);
    });

    test('setiap kod unik dan ada nama pendek', () {
      final codes = llmHighways.map((h) => h.code).toSet();
      expect(codes.length, llmHighways.length);
      expect(llmHighwayByCode('SPL')!.short, 'PLUS Selatan');
      expect(llmHighwayByCode('LLB')!.short, 'LLB');
    });
  });

  group('kalkulator LLM', () {
    test('pilihan: baris "Sila Pilih" dibuang, id rentetan dan nombor', () {
      final o = parseLlmOptions(
        '﻿[{"id":"","name":"Sila Pilih Plaza Masuk"},{"id":244,"name":"SETIA ALAM"},{"id":"002","name":"LIMA KEDAI"}]',
      );
      expect(o, const [
        LlmOption('244', 'SETIA ALAM'),
        LlmOption('002', 'LIMA KEDAI'),
      ]);
    });

    test('kadar: ikut kelas, nilai tidak sah dibuang', () {
      final r = parseLlmRates(
        '[{"transCode":2,"rate":67.9,"distance":null},{"transCode":1,"rate":37.15,"distance":null},{"transCode":3,"rate":"x"}]',
      );
      expect(r.map((x) => x.vehicleClass), [1, 2]);
      expect(r.first.rm, 37.15);
      expect(() => parseLlmRates('{}'), throwsA(isA<LlmTollFailure>()));
    });
  });

  group('halaman', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });
    testWidgets('lebuh raya laluan didahulukan; kamera dipaparkan', (
      tester,
    ) async {
      final fake = _FakeCctv(const [
        CctvCamera(
          name: 'PLS CAM S4 SKUDAI KM13.5 SB',
          imageUrl: 'https://api.llm.gov.my/cctv/image/SPL/x',
          fileName: 'x.web.jpg',
        ),
      ]);
      await pumpApp(
        tester,
        const HighwayPage(routeCodes: ['SPL', 'ELT']),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          llmCctvClientProvider.overrideWithValue(fake),
          cctvPositionsProvider.overrideWith((ref) async => const {}),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(fake.calls.first, 'SPL');
      expect(find.text('SKUDAI KM13.5'), findsOneWidget);
      expect(find.text('Arah selatan'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('cctv-hw-ELT')));
      await tester.pump();
      await tester.pump();
      expect(fake.calls.last, 'ELT');
    });

    testWidgets('gagal: mesej dan cuba lagi', (tester) async {
      final fake = _FakeCctv(const CctvFailure('timeout'));
      await pumpApp(
        tester,
        const HighwayPage(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          llmCctvClientProvider.overrideWithValue(fake),
          cctvPositionsProvider.overrideWith((ref) async => const {}),
        ],
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('cctv-error')), findsOneWidget);
    });
  });

  test('FG AI: CCTV dan kalkulator tol', () {
    OpenScreenIntent? open(String t) {
      final i = parseIntent(t);
      return i is OpenScreenIntent ? i : null;
    }

    final a = open('cctv plus selatan')!;
    expect((a.screen, a.arg), (AppScreen.highwayCctv, 'SPL'));
    final b = open('tengok cctv nkve')!;
    expect((b.screen, b.arg), (AppScreen.highwayCctv, 'NKV'));
    final c = open('buka cctv')!;
    expect((c.screen, c.arg), (AppScreen.highwayCctv, null));
    expect(open('kalkulator tol')!.screen, AppScreen.tollCalculator);
    expect(open('toll calculator')!.screen, AppScreen.tollCalculator);
  });
}
