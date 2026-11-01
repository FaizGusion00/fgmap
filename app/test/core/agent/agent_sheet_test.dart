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

  testWidgets(
    'lembaran bawah: tunggu animasi selesai, taip, kemudian tekan hasil pertama',
    (tester) async {
      String? picked;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => AgentOverlay(child: child!),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: AgentTarget(
                    id: 'open',
                    child: ElevatedButton(
                      onPressed: () async {
                        picked = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => SizedBox(
                            height: 500,
                            child: Column(
                              children: [
                                AgentTarget(
                                  id: 'input',
                                  child: TextField(
                                    autofocus: true,
                                    onChanged: (_) {},
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      for (var i = 0; i < 5; i++)
                                        AgentTarget(
                                          id: 'r.$i',
                                          child: Builder(
                                            builder: (c) => ListTile(
                                              title: Text('R$i'),
                                              onTap: () =>
                                                  Navigator.of(c).pop('R$i'),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text('open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final c = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold)),
      );
      late AgentOutcome outcome;
      await tester.runAsync(() async {
        final f = c.read(agentControllerProvider.notifier).run('x', [
          AgentStep('open', (r) => r.tap('open')),
          AgentStep('type', (r) => r.type('input', 'kuantan')),
          AgentStep('pick', (r) => r.tap('r.0')),
        ]);
        for (var i = 0; i < 40; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 100));
        }
        outcome = await f;
      });
      await tester.pumpAndSettle();
      expect(outcome.completed, isTrue);
      expect(picked, 'R0');
    },
  );

  testWidgets('sasaran tertutup: tidak menekan apa-apa dan langkah GAGAL', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => AgentOverlay(child: child!),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Stack(
              children: [
                Center(
                  child: AgentTarget(
                    id: 'btn',
                    child: ElevatedButton(
                      onPressed: () => pressed++,
                      child: const Text('btn'),
                    ),
                  ),
                ),
                // Lapisan legap di atas butang (cth. dialog/lembaran lain).
                const Positioned.fill(
                  child: AbsorbPointer(child: SizedBox.expand()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    late AgentOutcome outcome;
    await tester.runAsync(() async {
      outcome = await c.read(agentControllerProvider.notifier).run('x', [
        AgentStep('tap', (r) => r.tap('btn')),
      ]);
    });
    await tester.pumpAndSettle();
    expect(pressed, 0);
    expect(outcome.completed, isFalse);
    expect(outcome.steps.single.status, AgentStepStatus.failed);
  });
}
