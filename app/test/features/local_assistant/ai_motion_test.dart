import 'package:fgmap/features/local_assistant/presentation/widgets/typing_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'mod jimat bateri (animasi sistem dimatikan): penunjuk menaip masih bergerak',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TypingIndicator(color: Colors.indigo, label: 'Thinking…'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(tester.binding.hasScheduledFrame, isTrue);
      // Buang widget supaya ujian tamat tanpa animasi berulang yang tergantung.
      await tester.pumpWidget(const SizedBox());
    },
  );
}
