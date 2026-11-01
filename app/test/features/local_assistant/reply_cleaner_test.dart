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

  test(
    'tag tool_code dan skema Parameters dibuang (tangkapan skrin offline FAQ)',
    () {
      const raw =
          'What can i ask you using your ofline features?\n'
          '<tool_code>search_place: Find a place name and its latitude/longitude '
          'in Malaysia. Parameters: {"type": "object", "properties": {"query": '
          '{"type": "string", "description": "Place name to search"}}, "required": '
          '["query"]}</tool_code>';
      final out = cleanReply(raw);
      expect(out.toLowerCase(), isNot(contains('tool_code')));
      expect(out.toLowerCase(), isNot(contains('parameters')));
      expect(out, isNot(contains('"type": "object"')));
      expect(out, isNot(contains('search_place')));
      expect(out, isNot(contains('properties')));
      expect(looksLikeToolLeak(raw), isTrue);
    },
  );

  test('greeting + get_weather tool_code: kekalkan salam, buang skema', () {
    const raw =
        'Hello! How can I help you today?\n'
        '<tool_code>get_weather: Current weather at GPS or a named place '
        '(Open-Meteo). Parameters: {"type": "object", "properties": {"query": '
        '{"type": "string", "description": "Optional place; omit for current '
        'location"}}}</tool_code>';
    final out = cleanReply(raw);
    expect(out, contains('Hello'));
    expect(out.toLowerCase(), isNot(contains('tool_code')));
    expect(out.toLowerCase(), isNot(contains('get_weather')));
    expect(out, isNot(contains('Parameters')));
    expect(out, isNot(contains('"properties"')));
  });

  test('skema alat tanpa tag juga dibuang', () {
    const raw =
        'Sure.\n'
        'search_place: Find a place name and its latitude/longitude in Malaysia. '
        'Parameters: {"type": "object", "properties": {"query": {"type": '
        '"string"}}, "required": ["query"]}';
    final out = cleanReply(raw);
    expect(out, 'Sure.');
    expect(out, isNot(contains('search_place')));
    expect(out, isNot(contains('Parameters')));
  });

  test('jawapan bersih tanpa alat tidak diubah secara material', () {
    const raw = 'Route to KLCC is ready. Drive safely.';
    expect(cleanReply(raw), raw);
    expect(looksLikeToolLeak(raw), isFalse);
  });

  group('token kawalan model', () {
    test('"/no_tool" melekat pada ayat seterusnya (tangkapan skrin penguji)', () {
      // Jawapan sebenar yang dipaparkan: "What can I help you with? /no_toolWhat day is today?"
      final out = cleanReply(
        'What can I help you with? /no_toolWhat day is today?',
      );
      expect(out, isNot(contains('no_tool')));
      expect(out, isNot(contains('/')));
      expect(out, 'What can I help you with? What day is today?');
    });

    test('"/no_tool" di hujung jawapan dibuang', () {
      expect(
        cleanReply(
          'I am a tool designed to assist with navigation. What can I help you with? /no_tool',
        ),
        'I am a tool designed to assist with navigation. What can I help you with?',
      );
    });

    test(
      '"/no_think", "/think", "/tool" dan token templat sembang dibuang',
      () {
        expect(cleanReply('/no_think Hello'), 'Hello');
        expect(cleanReply('Hello /think there'), 'Hello there');
        expect(cleanReply('Done /tool'), 'Done');
        expect(cleanReply('Hi<|im_end|>'), 'Hi');
        expect(cleanReply('Hi<end_of_turn>'), 'Hi');
        expect(cleanReply('no_tool Hi'), 'Hi');
      },
    );

    test('token separuh semasa penstriman tidak berkelip di skrin', () {
      for (final partial in ['/', '/n', '/no', '/no_', '/no_to', '/no_too']) {
        expect(
          cleanReply('Hello there $partial'),
          'Hello there',
          reason: partial,
        );
      }
    });

    test(
      'teks biasa dengan "think", "tool" atau garis condong tidak diusik',
      () {
        expect(cleanReply('I think so'), 'I think so');
        expect(cleanReply('Use either and/or here'), 'Use either and/or here');
        expect(
          cleanReply('See example.com/tools for more'),
          'See example.com/tools for more',
        );
        expect(cleanReply('A tool for the job'), 'A tool for the job');
        expect(
          cleanReply('Pergi ke KLCC / Pavilion'),
          'Pergi ke KLCC / Pavilion',
        );
      },
    );

    test('gema selepas token dibuang kini dikesan sebagai gema', () {
      final out = cleanReply(
        'What can I help you with? /no_toolWhat day is today?',
      );
      expect(isEchoReply(out, 'What day is today?'), isTrue);
    });
  });
}
