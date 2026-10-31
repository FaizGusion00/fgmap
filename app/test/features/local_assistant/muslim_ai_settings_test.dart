import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/data/muslim_ai_settings.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/local_llm.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

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
        localLlmRuntimeProvider.overrideWithValue(_FakeLlm()),
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
    await tester.ensureVisible(find.byKey(const ValueKey('muslim-terms-agree')));
    await tester.tap(find.byKey(const ValueKey('muslim-terms-agree')));
    await tester.pumpAndSettle();

    expect(prefs.getBool(muslimAiEnabledKey), isTrue);
    final switchTile = tester.widget<SwitchListTile>(toggle);
    expect(switchTile.value, isTrue);
  });
}

class _FakeLlm implements LocalLlmRuntime {
  @override
  Future<bool> isInstalled() async => false;

  @override
  Future<void> download({void Function(double progress)? onProgress}) async {}

  @override
  Future<void> delete() async {}

  @override
  Future<String> chat({
    required String system,
    required List<AssistantMessage> history,
    required String userText,
    required Future<Map<String, Object?>> Function(
      String name,
      Map<String, Object?> args,
    )
    onTool,
    int maxToolTurns = 2,
  }) async =>
      '';

  @override
  Future<void> release() async {}
}
