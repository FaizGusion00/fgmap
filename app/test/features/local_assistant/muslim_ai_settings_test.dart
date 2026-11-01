import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/muslim_ai_settings.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

import 'fake_llm.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('isActive hanya selepas enableAfterAgreement', () async {
    expect(readMuslimAiSettings(prefs).isActive, isFalse);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await container
        .read(muslimAiSettingsProvider.notifier)
        .enableAfterAgreement();
    expect(container.read(muslimAiSettingsProvider).isActive, isTrue);
    expect(prefs.getBool(muslimAiEnabledKey), isTrue);
    expect(prefs.getInt(muslimAiTermsVersionKey), muslimAiTermsVersion);

    await container.read(muslimAiSettingsProvider.notifier).disable();
    expect(container.read(muslimAiSettingsProvider).isActive, isFalse);
  });

  testWidgets('toggle tetapan buka syarat; setuju mengaktifkan', (
    tester,
  ) async {
    usePhoneSurface(tester, size: const Size(390, 900));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(
        body: SingleChildScrollView(child: AssistantSettingsSection()),
      ),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(FakeLlm(installed: false)),
      ],
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('muslim-ai-toggle'));
    expect(toggle, findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('muslim-terms-agree')), findsOneWidget);

    final boxes = find.byType(CheckboxListTile);
    expect(boxes, findsNWidgets(5));
    for (var i = 0; i < 5; i++) {
      await tester.ensureVisible(boxes.at(i));
      await tester.tap(boxes.at(i));
      await tester.pump();
    }
    await tester.ensureVisible(
      find.byKey(const ValueKey('muslim-terms-agree')),
    );
    await tester.tap(find.byKey(const ValueKey('muslim-terms-agree')));
    await tester.pumpAndSettle();

    expect(prefs.getBool(muslimAiEnabledKey), isTrue);
    final switchTile = tester.widget<SwitchListTile>(toggle);
    expect(switchTile.value, isTrue);
  });
}
