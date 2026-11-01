import 'dart:io';

import 'package:fgmap/features/local_assistant/data/web_knowledge.dart';
import 'package:flutter_test/flutter_test.dart';

String _fixture(String name) =>
    File('test/features/local_assistant/fixtures/$name').readAsStringSync();

void main() {
  test('DuckDuckGo Instant Answer: ringkasan entiti, sumber dan pautan', () {
    final s = parseInstantAnswer(_fixture('ddg_anwar.json'));
    expect(s, hasLength(1));
    expect(s.single.title, 'Anwar Ibrahim');
    expect(s.single.text, contains('prime minister of Malaysia'));
    expect(s.single.source, 'Wikipedia');
    expect(s.single.url, startsWith('https://'));
    expect(parseInstantAnswer('{"Heading":"","AbstractText":""}'), isEmpty);
    expect(parseInstantAnswer('bukan json'), isEmpty);
  });

  test(
    'Google News RSS: tajuk tanpa nama penerbit, penerbit, tarikh, terbaharu dahulu',
    () {
      final s = parseNewsRss(_fixture('gnews_harga_minyak.xml'));
      expect(s, hasLength(3));
      for (final n in s) {
        expect(n.url, startsWith('https://news.google.com/'));
        expect(n.source, isNotEmpty);
        expect(n.title, isNot(endsWith(' - ${n.source}')));
        expect(n.date, isNotNull);
      }
      for (var i = 1; i < s.length; i++) {
        expect(s[i - 1].date!.isBefore(s[i].date!), isFalse);
      }
      expect(parseNewsRss('<rss></rss>'), isEmpty);
    },
  );

  test('RSS: entiti XML dan CDATA dinyahkod', () {
    const rss =
        '<rss><channel><item><title><![CDATA[Harga &amp; kadar - Utusan]]></title>'
        '<link>https://news.google.com/x</link><pubDate>Fri, 31 Oct 2026 07:12:00 GMT</pubDate>'
        '<source url="https://utusan.com.my">Utusan</source></item></channel></rss>';
    final s = parseNewsRss(rss).single;
    expect(s.title, 'Harga & kadar');
    expect(s.source, 'Utusan');
    expect(s.date, DateTime.utc(2026, 10, 31, 7, 12));
  });

  test('BNM: kadar beli/jual dan tarikh', () {
    final s = parseBnmRate(_fixture('bnm_usd.json'), 'USD')!;
    expect(s.title, '1 USD');
    expect(s.text, contains('RM '));
    expect(s.source, 'Bank Negara Malaysia');
    expect(s.date, isNotNull);
    expect(parseBnmRate('{"data":{}}', 'USD'), isNull);
  });

  test('halaman web: teks utama tanpa skrip/navigasi; tajuk og', () {
    const page = '''
<html><head><title>T</title><meta property="og:title" content="Banjir di Kelantan"></head>
<body><nav>Menu Utama Log masuk</nav><script>var x=1;</script>
<article><h1>Banjir</h1><p>Lebih 3,000 mangsa dipindahkan ke pusat pemindahan sementara di Kota Bharu pagi ini.</p></article>
<footer>Hak cipta</footer></body></html>''';
    final s = extractPage(page, Uri.parse('https://www.contoh.my/berita/1'))!;
    expect(s.title, 'Banjir di Kelantan');
    expect(s.text, contains('3,000 mangsa'));
    expect(s.text, isNot(contains('Menu Utama')));
    expect(s.text, isNot(contains('var x')));
    expect(s.source, 'contoh.my');
  });

  test('berita utama: URL carian RSS ditukar ke suapan utama', () {
    expect(
      topNewsUrl('https://news.google.com/rss/search'),
      'https://news.google.com/rss',
    );
  });

  test('pautan: hanya HTTPS ke hos awam', () {
    expect(isSafePublicUrl(Uri.parse('https://www.bernama.com/x')), isTrue);
    for (final u in [
      'http://www.bernama.com/x',
      'https://localhost/x',
      'https://192.168.1.1/',
      'https://10.0.0.5/',
      'https://172.20.1.1/',
      'https://127.0.0.1/',
      'https://router.local/',
      'file:///etc/passwd',
    ]) {
      expect(isSafePublicUrl(Uri.parse(u)), isFalse, reason: u);
    }
  });
}
