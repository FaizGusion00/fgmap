import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/settings/presentation/about_page.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../helpers/pump_app.dart';

void main() {
  testWidgets('shows app version, developer and owner', (tester) async {
    usePhoneSurface(tester);
    await pumpApp(
      tester,
      const AboutPage(),
      theme: AppTheme.dark(amoled: true),
      overrides: [
        appPackageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'FGMaps',
            packageName: 'com.example.fgmap',
            version: '1.2.3',
            buildNumber: '42',
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentang FGMaps'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-logo')), findsOneWidget);
    expect(find.byIcon(Icons.navigation_rounded), findsNothing);
    expect(find.text('1.2.3'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Faiz Nasir'), findsOneWidget);
    expect(find.text('FG Universal Empire Company'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-whats-new')),
      300,
    );
    expect(find.text('Baharu dalam versi 1.8.2'), findsOneWidget);
    expect(find.textContaining('Amaran kamera kelajuan'), findsOneWidget);
    expect(find.textContaining('GPS lebih cepat'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-all-changes')),
      200,
    );
    expect(find.byKey(const ValueKey('about-all-changes')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-attribution')),
      300,
    );
    expect(find.byKey(const ValueKey('about-attribution')), findsOneWidget);
    // Semua sumber data dalam senarai berstruktur (satu baris setiap jenis data).
    expect(find.textContaining('OpenStreetMap'), findsWidgets);
    expect(find.textContaining('data.gov.my'), findsWidgets);
    await tester.scrollUntilVisible(find.textContaining('WaktuSolat'), 200);
    expect(find.textContaining('WaktuSolat'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-licenses')),
      200,
    );
    expect(find.byKey(const ValueKey('about-licenses')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('kad "Baharu" menerangkan versi dalam pubspec.yaml', () {
    final line = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final name = line.substring('version:'.length).trim().split('+').first;
    expect(
      aboutWhatsNewVersion,
      name,
      reason:
          'Naikkan versi di pubspec.yaml dan tulis kad "Baharu" (aboutNew*) '
          'bersama-sama supaya About tidak menerangkan versi lama.',
    );
  });
}
