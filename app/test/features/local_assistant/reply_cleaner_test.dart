import 'package:fgmap/features/local_assistant/domain/reply_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'buang "." sisa giliran alat dan ayat berulang (tangkapan skrin pengguna)',
    () {
      const raw =
          '.\n\nKLCC is a destination you can plan a route to. Let me know if '
          "you'd like to set a start point or choose a toll-free option.KLCC is a "
          'destination you can plan a route to. The route preview is open for '
          "navigation. Let me know if you'd like to set a start point or choose a "
          'toll-free option.';
      final out = cleanReply(raw);
      expect(out.startsWith('.'), isFalse);
      expect('KLCC is a destination'.allMatches(out).length, 1);
      expect('Let me know'.allMatches(out).length, 1);
      expect(out, contains('The route preview is open'));
    },
  );

  test('senarai dikekalkan pada baris sendiri', () {
    const raw = 'Pilihan:\n- Satu\n- Dua\nSelesai.';
    expect(cleanReply(raw), 'Pilihan:\n- Satu\n- Dua\nSelesai.');
  });

  test('tag pemikiran dibuang', () {
    expect(cleanReply('<think>hmm</think>Hello there.'), 'Hello there.');
  });
}
