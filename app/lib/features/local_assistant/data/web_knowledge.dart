import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html;

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/network/response_text.dart';
import '../../../core/network/retry_interceptor.dart';
import 'wikipedia_client.dart';

/// Satu petikan maklumat dari internet, dengan sumber yang boleh dibuka pengguna.
@immutable
class WebSnippet {
  const WebSnippet({
    required this.title,
    required this.text,
    required this.url,
    required this.source,
    this.date,
  });

  final String title;

  /// Ringkasan/isi (kosong untuk tajuk berita sahaja).
  final String text;
  final String url;

  /// Nama penerbit ("Berita Harian", "Wikipedia", "Bank Negara Malaysia").
  final String source;
  final DateTime? date;
}

/// Maklumat terkini daripada sumber percuma tanpa kunci (ADR 0018):
/// - DuckDuckGo Instant Answer (ringkasan entiti; carian web penuh DDG menyekat permintaan automatik),
/// - Wikipedia (carian halaman + ringkasan),
/// - Google News RSS (tajuk berita terkini Malaysia, dengan penerbit dan tarikh),
/// - Bank Negara Malaysia (kadar tukaran rasmi),
/// - membaca satu pautan yang diberi pengguna.
///
/// Setiap sumber gagal secara senyap (senarai kosong) supaya satu sumber yang mati tidak menjatuhkan
/// jawapan; pemanggil membezakan "tiada hasil" dengan "tiada internet" melalui [WebSearchResult.failed].
class WebKnowledge {
  WebKnowledge(this._dio, this._wiki);

  final Dio _dio;
  final WikipediaClient _wiki;

  static const sourceBudget = Duration(seconds: 6);

  Options _opts({Map<String, String>? headers, ResponseType? type}) =>
      RetryInterceptor.options(
        Options(
          responseType: type ?? ResponseType.bytes,
          receiveTimeout: sourceBudget,
          headers: headers,
        ),
      );

  /// Ringkasan entiti DuckDuckGo (Answer, AbstractText, Definition).
  Future<List<WebSnippet>> instantAnswer(String query) async {
    final r = await _dio.get<Object>(
      AppConfig.duckDuckGoApiUrl,
      queryParameters: {
        'q': query,
        'format': 'json',
        'no_html': '1',
        'skip_disambig': '1',
      },
      options: _opts(),
    );
    return parseInstantAnswer(responseText(r.data) ?? '');
  }

  /// Tajuk berita terkini (Malaysia) untuk [query], terbaharu dahulu.
  Future<List<WebSnippet>> news(String query, {required bool malay}) async {
    final lang = malay ? 'ms' : 'en';
    final r = await _dio.get<Object>(
      AppConfig.googleNewsRssUrl,
      queryParameters: {
        'q': query,
        'hl': '$lang-MY',
        'gl': 'MY',
        'ceid': 'MY:$lang',
      },
      options: _opts(headers: {'Accept': 'application/rss+xml, */*'}),
    );
    return parseNewsRss(responseText(r.data) ?? '');
  }

  /// Ringkasan Wikipedia yang paling hampir dengan [query] (BM dahulu jika [malay], kemudian BI).
  Future<List<WebSnippet>> wikipedia(
    String query, {
    required bool malay,
  }) async {
    for (final lang in [if (malay) 'ms', 'en']) {
      final s = await _wiki.summary(query, lang: lang);
      if (s == null) continue;
      final dash = s.indexOf(' — ');
      final title = dash > 0 ? s.substring(0, dash).trim() : query;
      final body = dash > 0 ? s.substring(dash + 3).trim() : s;
      return [
        WebSnippet(
          title: title,
          text: body,
          url:
              'https://$lang.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}',
          source: 'Wikipedia',
        ),
      ];
    }
    return const [];
  }

  /// Kadar tukaran rasmi BNM untuk 1 unit [currency] (cth. USD) dalam ringgit.
  Future<WebSnippet?> exchangeRate(String currency) async {
    final code = currency.toUpperCase();
    final r = await _dio.get<Object>(
      '${AppConfig.bnmApiUrl}/exchange-rate/$code',
      options: _opts(headers: {'Accept': 'application/vnd.BNM.API.v1+json'}),
    );
    return parseBnmRate(responseText(r.data) ?? '', code);
  }

  /// Teks utama satu halaman web (pautan yang diberi pengguna). HTTPS sahaja; tiada alamat rangkaian
  /// setempat. Dihadkan 2 MB dan 1,500 aksara teks.
  Future<WebSnippet?> readUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !isSafePublicUrl(uri)) return null;
    final r = await _dio.getUri<List<int>>(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'text/html,application/xhtml+xml'},
      ),
    );
    final bytes = r.data;
    if (bytes == null || bytes.length > 2 * 1024 * 1024) return null;
    return extractPage(utf8.decode(bytes, allowMalformed: true), uri);
  }

  /// Carian gabungan untuk soalan umum/berita: berita + DDG + Wikipedia serentak, setiap satu dalam
  /// [sourceBudget]. Tertib hasil: jawapan terus DDG, berita terkini, kemudian ensiklopedia.
  Future<WebSearchResult> search(String query, {required bool malay}) async {
    var failures = 0;
    Future<List<WebSnippet>> safe(Future<List<WebSnippet>> f) => f
        .timeout(sourceBudget + const Duration(seconds: 1))
        .catchError((Object _) {
          failures++;
          return const <WebSnippet>[];
        });
    final results = await Future.wait([
      safe(instantAnswer(query)),
      safe(news(query, malay: malay)),
      safe(wikipedia(query, malay: malay)),
    ]);
    final ia = results[0];
    final headlines = results[1].take(4);
    final wiki = results[2];
    final all = <WebSnippet>[
      ...ia.take(1),
      ...headlines,
      // Ensiklopedia hanya jika DDG tidak sudah memberi ringkasan yang sama (selalunya dari Wikipedia).
      if (ia.isEmpty) ...wiki,
    ];
    return WebSearchResult(all, failed: all.isEmpty && failures == 3);
  }
}

@immutable
class WebSearchResult {
  const WebSearchResult(this.snippets, {this.failed = false});

  final List<WebSnippet> snippets;

  /// Semua sumber gagal (biasanya tiada internet), bukan sekadar tiada hasil.
  final bool failed;
}

/// Hanya `https://` ke hos awam: pautan ke rangkaian setempat atau alamat dalaman ditolak.
bool isSafePublicUrl(Uri uri) {
  if (uri.scheme != 'https' || uri.host.isEmpty) return false;
  final h = uri.host.toLowerCase();
  if (h == 'localhost' || h.endsWith('.local') || h.endsWith('.internal')) {
    return false;
  }
  final ipv4 = RegExp(r'^(\d+)\.(\d+)\.(\d+)\.(\d+)$').firstMatch(h);
  if (ipv4 != null) {
    final a = int.parse(ipv4.group(1)!);
    final b = int.parse(ipv4.group(2)!);
    if (a == 10 || a == 127 || a == 0 || a >= 224) return false;
    if (a == 169 && b == 254) return false;
    if (a == 172 && b >= 16 && b <= 31) return false;
    if (a == 192 && b == 168) return false;
    if (a == 100 && b >= 64 && b <= 127) return false;
  }
  if (h.contains(':')) return false; // IPv6 literal
  return true;
}

List<WebSnippet> parseInstantAnswer(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return const [];
  }
  if (json is! Map) return const [];
  final map = json;
  String s(String k) => (map[k] ?? '').toString().trim();
  final heading = s('Heading');
  final answer = s('Answer');
  final abstract = s('AbstractText');
  final definition = s('Definition');
  final text = answer.isNotEmpty
      ? answer
      : abstract.isNotEmpty
      ? abstract
      : definition;
  if (text.isEmpty) return const [];
  final url = s('AbstractURL').isNotEmpty
      ? s('AbstractURL')
      : s('DefinitionURL').isNotEmpty
      ? s('DefinitionURL')
      : 'https://duckduckgo.com/?q=${Uri.encodeQueryComponent(heading)}';
  final source = s('AbstractSource').isNotEmpty
      ? s('AbstractSource')
      : 'DuckDuckGo';
  return [
    WebSnippet(
      title: heading.isEmpty ? source : heading,
      text: text,
      url: url,
      source: source,
    ),
  ];
}

final _item = RegExp(r'<item>(.*?)</item>', dotAll: true);
String? _tag(String item, String tag) {
  final m = RegExp(
    '<$tag(?:\\s[^>]*)?>(.*?)</$tag>',
    dotAll: true,
  ).firstMatch(item);
  return m == null ? null : _xmlText(m.group(1)!);
}

String _xmlText(String raw) {
  var t = raw.trim();
  final cdata = RegExp(r'^<!\[CDATA\[(.*)\]\]>$', dotAll: true).firstMatch(t);
  if (cdata != null) t = cdata.group(1)!;
  return t
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Google News RSS: tajuk ("Tajuk - Penerbit"), pautan, tarikh, penerbit. Terbaharu dahulu.
List<WebSnippet> parseNewsRss(String body) {
  final out = <WebSnippet>[];
  for (final m in _item.allMatches(body)) {
    final item = m.group(1)!;
    final rawTitle = _tag(item, 'title');
    final link = _tag(item, 'link');
    if (rawTitle == null || link == null || !link.startsWith('https://')) {
      continue;
    }
    final source = _tag(item, 'source') ?? '';
    var title = rawTitle;
    if (source.isNotEmpty && title.endsWith(' - $source')) {
      title = title.substring(0, title.length - source.length - 3).trim();
    }
    out.add(
      WebSnippet(
        title: title,
        text: '',
        url: link,
        source: source.isEmpty ? 'Google News' : source,
        date: _rfc822(_tag(item, 'pubDate')),
      ),
    );
  }
  out.sort((a, b) {
    final da = a.date;
    final db = b.date;
    if (da == null || db == null) return 0;
    return db.compareTo(da);
  });
  return out;
}

DateTime? _rfc822(String? s) {
  if (s == null) return null;
  // "Fri, 31 Oct 2026 07:12:00 GMT"
  final m = RegExp(
    r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(s);
  if (m == null) return null;
  const months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  final month = months.indexOf(m.group(2)!.toLowerCase()) + 1;
  if (month == 0) return null;
  return DateTime.utc(
    int.parse(m.group(3)!),
    month,
    int.parse(m.group(1)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6) ?? '0'),
  );
}

/// BNM `/exchange-rate/{CUR}`: kadar beli/jual (RM bagi `unit` mata wang) dan tarikh.
WebSnippet? parseBnmRate(String body, String code) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (json is! Map || json['data'] is! Map) return null;
  final data = json['data'] as Map;
  final rate = data['rate'];
  if (rate is! Map) return null;
  final unit = (data['unit'] as num?)?.toInt() ?? 1;
  final buy = (rate['buying_rate'] as num?)?.toDouble();
  final sell = (rate['selling_rate'] as num?)?.toDouble();
  final mid = (rate['middle_rate'] as num?)?.toDouble();
  final date = DateTime.tryParse('${rate['date']}');
  if (buy == null && sell == null && mid == null) return null;
  String rm(double v) => 'RM ${v.toStringAsFixed(4)}';
  final parts = [
    if (buy != null) 'beli/buy ${rm(buy)}',
    if (sell != null) 'jual/sell ${rm(sell)}',
    if (mid != null && buy == null) 'tengah/middle ${rm(mid)}',
  ];
  return WebSnippet(
    title: '$unit $code',
    text: parts.join(' · '),
    url: 'https://www.bnm.gov.my/exchange-rates',
    source: 'Bank Negara Malaysia',
    date: date,
  );
}

/// Teks utama halaman HTML: buang skrip/gaya/navigasi, utamakan `<article>`/`<main>`.
WebSnippet? extractPage(String body, Uri uri) {
  final doc = html.parse(body);
  for (final sel in [
    'script',
    'style',
    'noscript',
    'nav',
    'header',
    'footer',
    'aside',
    'form',
    'iframe',
    'svg',
  ]) {
    for (final e in doc.querySelectorAll(sel)) {
      e.remove();
    }
  }
  final main =
      doc.querySelector('article') ?? doc.querySelector('main') ?? doc.body;
  final text = (main?.text ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length < 40) return null;
  final title =
      doc.querySelector('meta[property="og:title"]')?.attributes['content'] ??
      doc.querySelector('title')?.text.trim() ??
      uri.host;
  return WebSnippet(
    title: title.trim(),
    text: text.length > 1500 ? '${text.substring(0, 1499)}…' : text,
    url: uri.toString(),
    source: uri.host.replaceFirst(RegExp(r'^www\.'), ''),
  );
}

final webKnowledgeProvider = Provider<WebKnowledge>(
  (ref) =>
      WebKnowledge(ref.watch(dioProvider), ref.watch(wikipediaClientProvider)),
);
