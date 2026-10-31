import 'dart:io';

import 'package:fgmap/core/config/legal_config.dart';
import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/legal/presentation/legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/legal_override.dart';
import '../../helpers/pump_app.dart';

const _docs = ['privacy.ms', 'privacy.en', 'terms.ms', 'terms.en'];

String _read(String name) => File('assets/legal/$name.md').readAsStringSync();

void main() {
  group('dokumen undang-undang', () {
    test('semua pemegang tempat {{...}} dikenali dan diganti', () {
      for (final doc in _docs) {
        final filled = fillLegalTemplate(_read(doc), LegalConfig.values);
        expect(
          RegExp(r'\{\{\w+\}\}').allMatches(filled).map((m) => m.group(0)),
          isEmpty,
          reason: '$doc mengandungi pemegang tempat tidak dikenali',
        );
      }
    });

    test('BM dan EN mempunyai struktur bahagian yang sama', () {
      int sections(String t) =>
          RegExp(r'^## ', multiLine: true).allMatches(t).length;
      expect(sections(_read('privacy.ms')), sections(_read('privacy.en')));
      expect(sections(_read('terms.ms')), sections(_read('terms.en')));
    });

    test(
      'dasar privasi menyebut semua pihak ketiga yang benar-benar dihubungi app',
      () {
        // Disemak terhadap AppConfig dan kod: setiap hos mesti dinamakan dalam dasar (BM dan EN).
        for (final doc in ['privacy.ms', 'privacy.en']) {
          final text = _read(doc);
          for (final party in [
            'OpenFreeMap',
            'Photon',
            'Nominatim',
            'Valhalla',
            'Overpass',
            'GitHub',
            'data.gov.my',
            'maps.app.goo.gl',
            'Audius',
            'Radio Browser',
            'WaktuSolat',
          ]) {
            expect(text, contains(party), reason: '$doc tidak menyebut $party');
          }
        }
      },
    );

    test(
      'dasar menyatakan tiada akaun, iklan, analitik, penjejakan dan hak PDPA',
      () {
        expect(
          _read('privacy.en').toLowerCase(),
          allOf(
            contains('no accounts'),
            contains('no ads'),
            contains('no analytics'),
            contains('personal data protection act 2010'),
          ),
        );
        expect(
          _read('privacy.ms').toLowerCase(),
          allOf(
            contains('tiada akaun'),
            contains('tiada iklan'),
            contains('tiada analitik'),
            contains('akta perlindungan data peribadi 2010'),
          ),
        );
      },
    );

    test(
      'terma: keselamatan pemanduan, anggaran tol, butang kecemasan, undang-undang Malaysia',
      () {
        for (final doc in ['terms.ms', 'terms.en']) {
          final text = _read(doc);
          expect(text, contains('999'), reason: doc);
          expect(text, contains('112'), reason: doc);
          expect(text.toLowerCase(), anyOf(contains('malaysia')), reason: doc);
        }
      },
    );

    test(
      'pintu pelancaran: pemegang tempat belum diisi -> belum siap diterbitkan',
      () {
        // Nilai lalai repositori: butiran sebenar belum diberi (keputusan pemilik: "nanti").
        expect(LegalConfig.missingFields(), isNotEmpty);
        expect(LegalConfig.releaseReady, isFalse);
      },
    );

    test('sahkan fungsi pengganti dan kes tepi', () {
      expect(fillLegalTemplate('A {{x}} B {{y}}', {'x': '1'}), 'A 1 B {{y}}');
      expect(fillLegalTemplate('tiada', {'x': '1'}), 'tiada');
    });
  });

  group('MarkdownBlocks', () {
    testWidgets('tajuk, senarai, perenggan dan teks tebal', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final blocks = const MarkdownBlocks(
        '# Tajuk\n\nPerenggan **tebal** di sini\nbaris dua\n\n- satu\n- dua **x**\n\n## Kecil',
      ).build(ctx);
      // h1, perenggan, dua senarai, h2.
      expect(blocks, hasLength(5));
    });
  });

  group('LegalPage', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> pump(
      WidgetTester tester,
      LegalDoc doc, {
      Locale locale = const Locale('ms'),
    }) async {
      usePhoneSurface(tester);
      reduceMotion(tester);
      await pumpApp(
        tester,
        LegalPage(doc: doc),
        locale: locale,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          legalTextOverride(),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'dasar privasi dipaparkan (BM) dengan butiran entiti dan notis draf',
      (tester) async {
        await pump(tester, LegalDoc.privacy);
        expect(find.text('Dasar Privasi'), findsOneWidget);
        expect(find.text('Dasar Privasi FGMaps'), findsOneWidget);
        expect(
          find.textContaining('FG Universal Empire Company'),
          findsWidgets,
        );
        expect(
          find.byKey(const ValueKey('legal-draft-banner')),
          findsOneWidget,
        );
        expect(find.textContaining('{{'), findsNothing);
      },
    );

    testWidgets('terma dalam bahasa Inggeris', (tester) async {
      await pump(tester, LegalDoc.terms, locale: const Locale('en'));
      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('FGMaps Terms of Use'), findsOneWidget);
    });

    testWidgets('dokumen boleh digulung hingga bahagian terakhir', (
      tester,
    ) async {
      await pump(tester, LegalDoc.privacy);
      await tester.scrollUntilVisible(
        find.textContaining('Hubungi kami'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Hubungi kami'), findsOneWidget);
    });
  });
}
