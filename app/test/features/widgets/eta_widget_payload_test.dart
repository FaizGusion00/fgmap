import 'package:fgmap/features/widgets/eta_widget_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('payload round-trip', () {
    final payload = EtaWidgetPayload(
      home: const EtaWidgetRow(label: 'Rumah', value: '12 min', isSet: true),
      work: const EtaWidgetRow.unset(
        label: 'Kerja',
        cta: 'Tetapkan dalam FGMaps',
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000),
    );
    final again = EtaWidgetPayload.fromMap(payload.toMap());
    expect(again, isNotNull);
    expect(again!.home.value, '12 min');
    expect(again.home.isSet, isTrue);
    expect(again.work.isSet, isFalse);
    expect(again.isEmpty, isFalse);
  });

  test('duration formatting BM / EN', () {
    final ms = EtaWidgetText.forLanguage('ms');
    final en = EtaWidgetText.forLanguage('en');
    expect(ms.duration(90), '2 min');
    expect(en.duration(3700), contains('h'));
    expect(ms.duration(4000, approximate: true), startsWith('~'));
  });
}
