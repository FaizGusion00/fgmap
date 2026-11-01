import 'package:fgmap/core/agent/agent_controller.dart';
import 'package:fgmap/core/agent/agent_overlay.dart';
import 'package:fgmap/core/agent/agent_targets.dart';
import 'package:fgmap/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AgentController.instant = true;
    AgentTargets.reset();
  });
  tearDown(() => AgentController.instant = false);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required VoidCallback onPressed,
    required ValueChanged<String> onChanged,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          builder: (context, child) => AgentOverlay(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                const SizedBox(height: 300),
                AgentTarget(
                  id: 'btn',
                  child: ElevatedButton(
                    onPressed: onPressed,
                    child: const Text('Weather'),
                  ),
                ),
                AgentTarget(
                  id: 'field',
                  child: TextField(onChanged: onChanged),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
  }

  testWidgets('menekan butang SEBENAR dan menaip ke medan teks sebenar', (
    tester,
  ) async {
    var pressed = 0;
    String? typed;
    final c = await pump(
      tester,
      onPressed: () => pressed++,
      onChanged: (v) => typed = v,
    );
    late AgentOutcome outcome;
    await tester.runAsync(() async {
      outcome = await c
          .read(agentControllerProvider.notifier)
          .run('Open weather', [
            AgentStep('Tap weather', (r) => r.tap('btn')),
            AgentStep('Type Kuantan', (r) => r.type('field', 'Kuantan')),
          ]);
    });
    await tester.pumpAndSettle();
    expect(outcome.completed, isTrue);
    expect(pressed, 1);
    expect(typed, 'Kuantan');
    expect(outcome.steps.map((s) => s.status), [
      AgentStepStatus.done,
      AgentStepStatus.done,
    ]);
  });

  testWidgets('sasaran tiada: langkah gagal dengan selamat, larian berhenti', (
    tester,
  ) async {
    var pressed = 0;
    final c = await pump(tester, onPressed: () => pressed++, onChanged: (_) {});
    late AgentOutcome outcome;
    await tester.runAsync(() async {
      outcome = await c.read(agentControllerProvider.notifier).run('Missing', [
        AgentStep(
          'Tap ghost',
          (r) => r.tap('nope', timeout: const Duration(milliseconds: 200)),
        ),
        AgentStep('Tap weather', (r) => r.tap('btn')),
      ]);
    });
    expect(outcome.completed, isFalse);
    expect(outcome.steps.first.status, AgentStepStatus.failed);
    expect(outcome.steps.last.status, AgentStepStatus.pending);
    expect(pressed, 0);
  });

  testWidgets('kad status, senarai semak dan Henti membatalkan', (
    tester,
  ) async {
    var pressed = 0;
    final c = await pump(tester, onPressed: () => pressed++, onChanged: (_) {});
    final ctl = c.read(agentControllerProvider.notifier);
    late Future<AgentOutcome> running;
    await tester.runAsync(() async {
      running = ctl.run('Open weather', [
        AgentStep('Wait a moment', (r) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return !r.cancelled;
        }),
        AgentStep('Tap weather', (r) => r.tap('btn')),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('agent-status')), findsOneWidget);
    expect(find.text('Open weather'), findsOneWidget);
    expect(find.text('Tap weather'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agent-stop')));
    late AgentOutcome outcome;
    await tester.runAsync(() async => outcome = await running);
    await tester.pumpAndSettle();
    expect(outcome.stopped, isTrue);
    expect(pressed, 0);
    expect(find.byKey(const ValueKey('agent-status')), findsNothing);
  });
}
