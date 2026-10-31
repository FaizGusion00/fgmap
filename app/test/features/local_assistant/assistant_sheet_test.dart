import 'package:fgmap/core/storage/preferences.dart';
import 'package:fgmap/features/local_assistant/domain/assistant_message.dart';
import 'package:fgmap/features/local_assistant/domain/local_llm.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_controller.dart';
import 'package:fgmap/features/local_assistant/presentation/assistant_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('tanpa model tunjuk butang muat turun', (tester) async {
    usePhoneSurface(tester, size: const Size(390, 900));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: AssistantSheet()),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(_FakeLlm(installed: false)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-download')), findsOneWidget);
    expect(find.textContaining('Qwen3'), findsOneWidget);
  });

  testWidgets('model sedia: hantar mesej memanggil runtime', (tester) async {
    usePhoneSurface(tester, size: const Size(390, 900));
    reduceMotion(tester);
    final llm = _FakeLlm(installed: true);
    await pumpApp(
      tester,
      const Scaffold(body: AssistantSheet()),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(llm),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'IPU sekarang');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(llm.lastUserText, 'IPU sekarang');
    expect(find.textContaining('IPU 42'), findsOneWidget);
  });

  testWidgets('tab FGMuslim tunjuk pintu opt-in', (tester) async {
    usePhoneSurface(tester, size: const Size(390, 900));
    reduceMotion(tester);
    await pumpApp(
      tester,
      const Scaffold(body: AssistantSheet()),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLlmRuntimeProvider.overrideWithValue(_FakeLlm(installed: true)),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-mode-tabs')), findsOneWidget);
    await tester.tap(find.text('FGMuslim'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('muslim-enable')), findsOneWidget);
    expect(find.textContaining('Muslim'), findsWidgets);
  });
}

class _FakeLlm implements LocalLlmRuntime {
  _FakeLlm({required this.installed});

  bool installed;
  String? lastUserText;

  @override
  Future<bool> isInstalled() async => installed;

  @override
  Future<void> download({void Function(double progress)? onProgress}) async {
    onProgress?.call(1);
    installed = true;
  }

  @override
  Future<void> delete() async => installed = false;

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
  }) async {
    lastUserText = userText;
    return 'IPU 42 di Cheras (JAS).';
  }

  @override
  Future<void> release() async {}
}
