import 'package:fgmap/core/widgets/sheet_bottom_inset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('kandungan lembaran dijarakkan daripada bar navigasi sistem', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(300, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SheetBottomInset(
              child: SizedBox(key: Key('btn'), height: 40, width: 100),
            ),
          ),
        ),
      ),
    );
    expect(tester.getBottomLeft(find.byKey(const Key('btn'))).dy, 600 - 48);
  });
}
