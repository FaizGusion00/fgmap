import 'dart:io';

import 'package:fgmap/features/settings/domain/changelog.dart';
import 'package:fgmap/features/settings/presentation/about_page.dart';
import 'package:fgmap/features/settings/presentation/changelog_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

List<ChangelogRelease> _asset(String language) => parseChangelog(
  File('assets/changelog/changelog.$language.md').readAsStringSync(),
);

/// Aset dibaca terus daripada fail: pemuatan rootBundle tidak selesai dalam masa palsu ujian.
final _assets = changelogProvider.overrideWith(
  (ref, language) async => _asset(language),
);

void main() {
  group('parseChangelog', () {
    test(
      'versi, tarikh, ringkasan, sebelum/selepas/cara guna dan baris sambungan',
      () {
        final list = parseChangelog('''
# 2.0.0 | 2026-12-01
Ringkasan
dua baris.

## Satu
Sebelum: lama
sambungan.
Selepas: baharu.
Cara guna: tekan butang.

## Tanpa selepas
Sebelum: diabaikan.

# 1.9.0
## Dua
Before: old.
After: new.
''');
        expect(list, hasLength(2));
        final a = list.first;
        expect(a.version, '2.0.0');
        expect(a.date, DateTime(2026, 12));
        expect(a.summary, 'Ringkasan dua baris.');
        expect(a.entries, hasLength(1));
        expect(a.entries.single.title, 'Satu');
        expect(a.entries.single.before, 'lama sambungan.');
        expect(a.entries.single.after, 'baharu.');
        expect(a.entries.single.tip, 'tekan butang.');
        final b = list.last;
        expect(b.version, '1.9.0');
        expect(b.date, isNull);
        expect(b.summary, isNull);
        expect(b.entries.single.before, 'old.');
        expect(b.entries.single.tip, isNull);
      },
    );

    test('versi tanpa perubahan sah tidak dipaparkan', () {
      expect(parseChangelog('# 1.0.0\n## X\nSebelum: a\n'), isEmpty);
      expect(parseChangelog(''), isEmpty);
    });
  });

  group('fail log perubahan dalam app', () {
    final ms = _asset('ms');
    final en = _asset('en');

    test('versi terkini sama dengan kad "Baharu" dan pubspec.yaml', () {
      final line = File(
        'pubspec.yaml',
      ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
      final name = line.substring('version:'.length).trim().split('+').first;
      expect(ms.first.version, aboutWhatsNewVersion);
      expect(ms.first.version, name);
      expect(ms.first.date, aboutReleaseDate);
    });

    test('BM dan English sepadan: versi, tarikh dan bilangan perubahan', () {
      expect(ms, isNotEmpty);
      expect([for (final r in en) r.version], [for (final r in ms) r.version]);
      for (var i = 0; i < ms.length; i++) {
        expect(en[i].date, ms[i].date, reason: ms[i].version);
        expect(
          en[i].entries.length,
          ms[i].entries.length,
          reason: 'versi ${ms[i].version}',
        );
        expect(en[i].summary == null, ms[i].summary == null);
        for (var j = 0; j < ms[i].entries.length; j++) {
          expect(
            en[i].entries[j].tip == null,
            ms[i].entries[j].tip == null,
            reason: '${ms[i].version}: ${ms[i].entries[j].title}',
          );
        }
      }
    });

    test(
      'versi tersusun daripada yang terbaharu dan setiap perubahan lengkap',
      () {
        for (final list in [ms, en]) {
          for (var i = 1; i < list.length; i++) {
            expect(
              list[i].date!.isAfter(list[i - 1].date!),
              isFalse,
              reason: list[i].version,
            );
          }
          for (final r in list) {
            expect(r.date, isNotNull, reason: r.version);
            for (final e in r.entries) {
              expect(e.before.length, greaterThan(10), reason: e.title);
              expect(e.after.length, greaterThan(10), reason: e.title);
              expect(e.before, isNot(e.after), reason: e.title);
            }
          }
        }
      },
    );
  });

  testWidgets(
    'halaman Semua perubahan: versi terkini dengan sebelum dan selepas',
    (tester) async {
      usePhoneSurface(tester);
      await pumpApp(tester, const ChangelogPage(), overrides: [_assets]);
      await tester.pumpAndSettle();

      expect(find.text('Semua perubahan'), findsOneWidget);
      expect(find.text('Versi $aboutWhatsNewVersion'), findsOneWidget);
      expect(find.text('Terkini'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('changelog-entry-$aboutWhatsNewVersion-0')),
        findsOneWidget,
      );
      expect(find.text('SEBELUM'), findsWidgets);
      expect(find.text('SELEPAS'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('About > Lihat semua perubahan membuka halaman', (tester) async {
    usePhoneSurface(tester);
    await pumpApp(tester, const AboutPage(), overrides: [_assets]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-all-changes')),
      200,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('about-all-changes')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-all-changes')));
    await tester.pumpAndSettle();
    expect(find.byType(ChangelogPage), findsOneWidget);
    expect(find.text('Versi $aboutWhatsNewVersion'), findsOneWidget);
  });

  testWidgets('English: versi dan label dalam bahasa Inggeris', (tester) async {
    usePhoneSurface(tester);
    await pumpApp(
      tester,
      const ChangelogPage(),
      locale: const Locale('en'),
      overrides: [_assets],
    );
    await tester.pumpAndSettle();

    expect(find.text('All changes'), findsOneWidget);
    expect(find.text('Version $aboutWhatsNewVersion'), findsOneWidget);
    expect(find.text('BEFORE'), findsWidgets);
    expect(find.text('AFTER'), findsWidgets);
  });
}
