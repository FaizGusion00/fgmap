import 'package:fgmap/core/theme/app_theme.dart';
import 'package:fgmap/features/settings/presentation/about_page.dart';
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
    expect(find.text('1.2.3+42'), findsOneWidget);
    expect(find.text('Faiz Nasir'), findsOneWidget);
    expect(find.text('FG Universal Empire Company'), findsOneWidget);
    expect(find.byKey(const ValueKey('about-attribution')), findsOneWidget);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(find.textContaining('data.gov.my'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
