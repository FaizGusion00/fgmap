import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/location_link.dart';

/// Carian Google dalam app. Pengguna mencari seperti biasa; apabila mereka menekan "Arah"/peta pada
/// sesuatu tempat, pautan itu tidak dibuka dalam pelayar tetapi dipulangkan kepada FGMaps (laluan
/// sendiri). App tidak membaca halaman Google: hanya URL yang pengguna tekan.
///
/// Memulangkan pautan peta yang dipilih, atau null jika ditutup.
Future<Uri?> showWebSearch(BuildContext context, {String query = ''}) =>
    Navigator.of(
      context,
    ).push<Uri>(fadeThroughRoute(WebSearchPage(initialQuery: query)));

/// URL carian Google untuk [query] dalam bahasa app.
Uri googleSearchUrl(String query, {required String languageCode}) => Uri.https(
  'www.google.com',
  '/search',
  {'q': query, 'hl': languageCode == 'ms' ? 'ms' : 'en', 'gl': 'my'},
);

/// Keputusan untuk satu navigasi dalam pelayar: diserahkan kepada FGMaps (pautan peta), disekat
/// (skema lain yang tidak boleh dibuka dalam pelayar), atau dimuat seperti biasa.
sealed class WebNavDecision {
  const WebNavDecision();
}

class HandToMaps extends WebNavDecision {
  const HandToMaps(this.uri);
  final Uri uri;
}

class BlockNav extends WebNavDecision {
  const BlockNav();
}

class LoadNav extends WebNavDecision {
  const LoadNav();
}

/// Nama terbaik untuk tempat dalam pautan Google [link]: nama tempat dalam pautan (`q=`, `/place/<nama>`)
/// diutamakan kerana `daddr` Google biasanya ALAMAT; kemudian [serpQuery] (carian Google semasa);
/// akhirnya label pautan (alamat). Teks tidak dipercayai: dibersihkan.
String? googlePlaceName(Uri link, {String? serpQuery}) {
  String? clean(String? v) {
    final t = sanitizeSharedLabel(v)?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  final p = link.queryParameters;
  for (final v in [p['q'], p['query']]) {
    if (v == null || v.contains('@')) continue;
    final coords = RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$');
    if (coords.hasMatch(v)) continue;
    final n = clean(v);
    if (n != null) return n;
  }
  final segs = link.pathSegments;
  final i = segs.indexOf('place');
  if (i >= 0 && i + 1 < segs.length) {
    final n = clean(segs[i + 1].replaceAll('+', ' '));
    if (n != null) return n;
  }
  return clean(serpQuery) ?? clean(sharedLocationFromUri(link)?.label);
}

/// Pautan serahan seragam `daddr=Nama @lat,lng` (satu bentuk untuk perancang dan peta).
Uri pinnedGoogleLink(double lat, double lng, String? name) => Uri.https(
  'maps.google.com',
  '/maps',
  {'daddr': name == null || name.isEmpty ? '$lat,$lng' : '$name @$lat,$lng'},
);

/// Pautan peta [original] (tanpa pin) digabung dengan koordinat [pin] (`"lat,lng"`) yang Google
/// sendiri letak pada kad tempat yang sama (pautan "Arah" `daddr=…@lat,lng` / `!3d!4d`). Hasil:
/// pautan `daddr=Nama @lat,lng` yang terus membawa pin; null jika [pin] tidak sah.
///
/// [fallbackLabel] (cth. carian Google semasa) digunakan jika pautan asal tiada nama tempat.
Uri? withGooglePin(Uri original, String pin, {String? fallbackLabel}) {
  final m = RegExp(
    r'^\s*(-?\d{1,2}(?:\.\d+)?)\s*,\s*(-?\d{1,3}(?:\.\d+)?)\s*$',
  ).firstMatch(pin);
  if (m == null) return null;
  final lat = double.parse(m.group(1)!);
  final lng = double.parse(m.group(2)!);
  if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) {
    return null;
  }
  return pinnedGoogleLink(
    lat,
    lng,
    googlePlaceName(original, serpQuery: fallbackLabel),
  );
}

/// Pautan berpin yang ditekan, diseragamkan dengan nama terbaik; pautan tanpa pin (atau `geo:`)
/// dipulangkan seadanya.
Uri normalizeGoogleHandoff(Uri uri, {String? serpQuery}) {
  if (uri.scheme != 'http' && uri.scheme != 'https') return uri;
  final pin = mapPinFromUri(uri);
  if (pin == null) return uri;
  return pinnedGoogleLink(
    pin.lat,
    pin.lng,
    googlePlaceName(uri, serpQuery: serpQuery),
  );
}

/// Hos Google (halaman yang dibenarkan menyerahkan pautan kepada FGMaps).
bool isGoogleHost(String host) => RegExp(
  r'(^|\.)google\.(com|com\.my|[a-z]{2,3}|co\.[a-z]{2}|com\.[a-z]{2})$',
).hasMatch(host.toLowerCase());

/// Fungsi tulen (diuji tanpa WebView).
WebNavDecision decideWebNavigation(String url) {
  final fromIntent = mapLinkFromIntent(url);
  if (fromIntent != null) return HandToMaps(fromIntent);
  final uri = Uri.tryParse(url);
  if (uri == null) return const BlockNav();
  if (isMapHandoffUrl(uri)) return HandToMaps(uri);
  // intent:// bukan peta, market://, tel: dsb.: tidak dimuat dalam pelayar carian.
  if (uri.scheme != 'http' && uri.scheme != 'https') return const BlockNav();
  return const LoadNav();
}

class WebSearchPage extends StatefulWidget {
  const WebSearchPage({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<WebSearchPage> createState() => _WebSearchPageState();
}

class _WebSearchPageState extends State<WebSearchPage> {
  late final TextEditingController _text = TextEditingController(
    text: widget.initialQuery,
  );
  WebViewController? _web;
  double _progress = 0;
  bool _handedOff = false;
  bool _canBack = false;

  /// Pautan peta tanpa koordinat pin sedang dibuka di latar (Google Maps web) untuk mendapatkan
  /// koordinat tepat daripada URL-nya; null jika tidak.
  Uri? _resolving;
  Timer? _resolveTimeout;

  /// Carian Google terakhir (nama untuk pautan peta yang tidak membawa nama tempat).
  String? _serpQuery;
  Timer? _resolvePoll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_web != null) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Butang "Arah" Google sering dibuka melalui JavaScript (`window.open`, klik dengan jsaction):
      // WebView tidak menghantarnya sebagai navigasi, jadi ketikan pertama "tidak berlaku apa-apa".
      // Skrip [_interceptScript] menangkap klik/`window.open` ke pautan peta dan menghantarnya ke sini.
      ..addJavaScriptChannel(
        'FGMapsLink',
        onMessageReceived: (m) => _onMapLink(m.message),
      )
      // Pin tempat daripada halaman Google Maps yang dibuka di latar ([_resolvePinScript]).
      ..addJavaScriptChannel(
        'FGMapsPin',
        onMessageReceived: (m) => _onResolvedPin(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (_resolving != null) return _resolveStep(request.url);
            final decision = decideWebNavigation(request.url);
            switch (decision) {
              case HandToMaps(:final uri):
                _onMapUri(uri);
                return NavigationDecision.prevent;
              case BlockNav():
                return NavigationDecision.prevent;
              case LoadNav():
                return NavigationDecision.navigate;
            }
          },
          // Sesetengah pautan "Arah" berubah melalui JavaScript (tiada permintaan navigasi): semak
          // URL halaman juga.
          onUrlChange: (change) {
            final url = change.url;
            if (url == null) return;
            if (_resolving != null) {
              _resolveStep(url);
              return;
            }
            final decision = decideWebNavigation(url);
            if (decision is HandToMaps) _onMapUri(decision.uri);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageFinished: (url) async {
            final page = Uri.tryParse(url);
            final q = page?.path == '/search'
                ? page?.queryParameters['q']
                : null;
            if (q != null && q.trim().isNotEmpty) _serpQuery = q.trim();
            if (page != null && isGoogleHost(page.host)) {
              await _web?.runJavaScript(_interceptScript);
            }
            final back = await _web?.canGoBack() ?? false;
            if (mounted) setState(() => _canBack = back);
          },
        ),
      );
    _web = controller;
    final start = widget.initialQuery.trim();
    controller.loadRequest(
      start.isEmpty
          ? Uri.https('www.google.com', '/', {'hl': _lang, 'gl': 'my'})
          : googleSearchUrl(start, languageCode: _lang),
    );
  }

  String get _lang => Localizations.localeOf(context).languageCode;

  /// Mesej daripada [_interceptScript]: JSON `{"u": pautan, "p": "lat,lng" | null}` (atau URL biasa).
  void _onMapLink(String raw) {
    var url = raw;
    String? pin;
    if (raw.startsWith('{')) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        url = '${m['u'] ?? ''}';
        pin = m['p'] as String?;
      } on Object {
        return;
      }
    }
    unawaited(_onMapLinkFromPage(url, pin));
  }

  Future<void> _onMapLinkFromPage(String url, String? pin) async {
    // Hanya halaman Google boleh menyerahkan pautan (bukan laman lain yang dibuka dari hasil carian).
    final current = Uri.tryParse(await _web?.currentUrl() ?? '');
    if (current == null || !isGoogleHost(current.host) || !mounted) return;
    switch (decideWebNavigation(url)) {
      case HandToMaps(:final uri):
        _onMapUri(uri, pagePin: pin);
      case LoadNav():
        // Skrip tersalah tangkap pautan biasa: buka seperti biasa, jangan telan ketikan.
        final u = Uri.tryParse(url);
        if (u != null) await _web?.loadRequest(u);
      case BlockNav():
        break;
    }
  }

  /// Pautan peta ditekan. Dengan koordinat pin: terus pulang ke FGMaps. Tanpa (nama sahaja, pautan
  /// pendek, `/maps/dir//Nama`): buka di Google Maps web di latar sehingga URL-nya membawa pin, supaya
  /// FGMaps menerima koordinat Google sendiri, bukan carian nama semula.
  void _onMapUri(Uri uri, {String? pagePin}) {
    if (_handedOff || !mounted) return;
    // Ada pin, atau skema app (geo:) yang tidak boleh dibuka di pelayar: terus ke FGMaps.
    if (mapPinFromUri(uri) != null ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      _handOff(uri);
      return;
    }
    // Koordinat Google pada kad tempat yang sama (pautan "Arah"): terus, tanpa menunggu.
    final withPin = pagePin == null
        ? null
        : withGooglePin(uri, pagePin, fallbackLabel: _serpQuery);
    if (withPin != null) {
      _handOff(withPin);
      return;
    }
    if (_resolving != null) return;
    setState(() => _resolving = uri);
    unawaited(_resolve(uri));
  }

  Future<void> _resolve(Uri uri) async {
    final web = _web;
    if (web == null) return;
    _resolveTimeout = Timer(const Duration(seconds: 20), () {
      // Google tidak memberi koordinat: serahkan NAMA sahaja (FGMaps mencarinya), jangan sekali-kali
      // pusat paparan `@` pautan asal yang boleh jauh dari tempat sebenar.
      final original = _resolving;
      if (original == null) return;
      final name = googlePlaceName(original, serpQuery: _serpQuery);
      if (name == null) {
        _cancelResolve();
        return;
      }
      _handOff(Uri.https('maps.google.com', '/maps', {'q': name}));
    });
    // Google Maps web mudah alih mengalih ke app (`intent://`) dan berhenti; versi desktop memuat
    // halaman tempat, yang membawa pin dalam URL atau data tempatnya.
    await web.setUserAgent(_desktopUserAgent);
    if (_handedOff || !mounted || _resolving != uri) return;
    await web.loadRequest(uri);
    if (_handedOff || !mounted || _resolving != uri) return;
    _resolvePoll?.cancel();
    _resolvePoll = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_resolving == null || _handedOff) return;
      unawaited(
        _web?.runJavaScript(_resolvePinScript).catchError((Object _) {}),
      );
    });
  }

  Future<void> _onResolvedPin(String pin) async {
    if (_resolving == null) return;
    final current = Uri.tryParse(await _web?.currentUrl() ?? '');
    final original = _resolving;
    if (original == null || current == null || !isGoogleHost(current.host)) {
      return;
    }
    final withPin = withGooglePin(original, pin, fallbackLabel: _serpQuery);
    if (withPin != null) _handOff(withPin);
  }

  /// Batal menyelesaikan (pengguna menekan kembali, atau Google tidak memberi apa-apa): kembali ke
  /// carian Google dengan pelayar mudah alih biasa.
  void _cancelResolve() {
    _resolveTimeout?.cancel();
    _resolvePoll?.cancel();
    if (_resolving == null) return;
    final web = _web;
    if (mounted) setState(() => _resolving = null);
    unawaited(() async {
      await web?.setUserAgent(null);
      if (await web?.canGoBack() == true) await web?.goBack();
    }());
  }

  /// Semasa menyelesaikan: setiap URL disemak untuk koordinat pin. `intent://` (Google Maps cuba
  /// membuka app) dibaca, tidak dibuka.
  NavigationDecision _resolveStep(String url) {
    final fromIntent = mapLinkFromIntent(url);
    final uri = fromIntent ?? Uri.tryParse(url);
    if (uri != null && mapPinFromUri(uri) != null) {
      _handOff(uri);
      return NavigationDecision.prevent;
    }
    if (fromIntent != null || uri == null) return NavigationDecision.prevent;
    return uri.scheme == 'http' || uri.scheme == 'https'
        ? NavigationDecision.navigate
        : NavigationDecision.prevent;
  }

  void _handOff(Uri uri) {
    if (_handedOff || !mounted) return;
    _handedOff = true;
    _resolveTimeout?.cancel();
    _resolvePoll?.cancel();
    final route = ModalRoute.of(context);
    final nav = Navigator.of(context);
    // Menu/dialog terbuka di atas halaman ini: tutup dahulu, kemudian halaman ini sendiri.
    if (route != null && !route.isCurrent) nav.popUntil((r) => r == route);
    nav.pop(normalizeGoogleHandoff(uri, serpQuery: _serpQuery));
  }

  void _search(String q) {
    final t = q.trim();
    if (t.isEmpty) return;
    FocusScope.of(context).unfocus();
    _web?.loadRequest(googleSearchUrl(t, languageCode: _lang));
  }

  @override
  void dispose() {
    _resolveTimeout?.cancel();
    _resolvePoll?.cancel();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final web = _web;
    return PopScope(
      canPop: !_canBack && _resolving == null,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && _resolving != null) {
          _cancelResolve();
          return;
        }
        if (!didPop && await web?.canGoBack() == true) await web?.goBack();
        final back = await web?.canGoBack() ?? false;
        if (mounted) setState(() => _canBack = back);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: TextField(
            key: const ValueKey('web-search-field'),
            controller: _text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.webSearchHint,
              border: InputBorder.none,
            ),
            onSubmitted: _search,
          ),
          actions: [
            IconButton(
              tooltip: l10n.webSearchReload,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _resolving != null ? null : () => web?.reload(),
            ),
            PopupMenuButton<String>(
              enabled: _resolving == null,
              onSelected: (v) async {
                if (v == 'clear') {
                  await WebViewCookieManager().clearCookies();
                  await web?.clearCache();
                  await web?.clearLocalStorage();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.webSearchCleared)),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'clear', child: Text(l10n.webSearchClear)),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: _progress > 0 && _progress < 1
                ? LinearProgressIndicator(value: _progress, minHeight: 3)
                : const SizedBox(height: 3),
          ),
        ),
        body: Column(
          children: [
            Material(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_rounded,
                      size: 18,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.webSearchBanner,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (web != null) WebViewWidget(controller: web),
                  // Mendapatkan koordinat tempat daripada Google Maps: halaman peta tidak dipaparkan.
                  if (_resolving != null)
                    ColoredBox(
                      key: const ValueKey('web-search-resolving'),
                      color: theme.colorScheme.surface,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            Text(
                              l10n.webSearchResolving,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ],
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
  }
}

const _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';

/// Dijalankan berulang pada halaman Google Maps (desktop) semasa menyelesaikan: pin daripada URL
/// (`!3d…!4d…`), atau daripada data tempat yang halaman itu sendiri muat (`/maps/preview/place`,
/// asal yang sama). Hanya koordinat dihantar ke `FGMapsPin`.
const _resolvePinScript = r"""
(function () {
  function post(lat, lng) { try { FGMapsPin.postMessage(lat + ',' + lng); } catch (e) {} }
  var href = location.href;
  try { href = decodeURIComponent(href); } catch (e) {}
  var m = /!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)/.exec(href);
  if (m) { post(m[1], m[2]); return; }
  if (window.__fgPinFetch) return;
  var link = document.querySelector('link[href*="/maps/preview/place"]');
  if (!link) return;
  window.__fgPinFetch = true;
  fetch(link.href, { credentials: 'include' })
    .then(function (r) { return r.text(); })
    .then(function (t) {
      var p = /\[null,null,(-?\d{1,2}\.\d+),(-?\d{1,3}\.\d+)\]/.exec(t);
      if (p) post(p[1], p[2]);
      else window.__fgPinFetch = false;
    })
    .catch(function () { window.__fgPinFetch = false; });
})();
""";

/// Disuntik pada setiap halaman: klik pada pautan/elemen peta dan `window.open` ke peta dihantar ke
/// FGMaps (saluran `FGMapsLink`) dan tidak dibuka. Idempoten.
const _interceptScript = r"""
(function () {
  if (window.__fgMapsHook) return;
  window.__fgMapsHook = true;
  function abs(u) { try { return new URL(u, location.href).href; } catch (e) { return String(u); } }
  function dec(u) { try { return decodeURIComponent(String(u).replace(/\+/g, ' ')); } catch (e) { return String(u); } }
  // Pautan peta sebenar (bukan sebarang URL yang kebetulan mengandungi "google.com/maps"). Pembalut
  // `google.com/url?q=<peta>` dibuka balutannya.
  function mapUrl(raw) {
    var u = abs(raw);
    if (/^(intent|geo|google\.navigation):/i.test(u)) return u;
    var x;
    try { x = new URL(u); } catch (e) { return null; }
    var h = x.hostname.toLowerCase(), p = x.pathname;
    if (/(^|\.)google\.[a-z.]+$/.test(h) && p === '/url') {
      var t = x.searchParams.get('q') || x.searchParams.get('url');
      return t && t !== u ? mapUrl(t) : null;
    }
    if (/^maps\.google\.[a-z.]+$/.test(h)) return u;
    if (/^(www\.)?google\.[a-z.]+$/.test(h) && /^\/maps(\/|$)/.test(p)) return u;
    if (h === 'maps.app.goo.gl') return u;
    if (h === 'goo.gl' && /^\/maps(\/|$)/.test(p)) return u;
    return null;
  }
  // Koordinat pin dalam pautan Google: daddr/destination "… @lat,lng" atau data "!3dlat!4dlng".
  function pinOf(u) {
    var t = dec(u), m = /[?&](?:daddr|destination)=[^&]*@(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)/.exec(t);
    if (!m) m = /!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)/.exec(t);
    return m ? m[1] + ',' + m[2] : null;
  }
  function linkOf(el) { return el.getAttribute && (el.getAttribute('href') || el.getAttribute('data-url') || el.getAttribute('data-href')) || ''; }
  function send(u) { try { FGMapsLink.postMessage(JSON.stringify({u: u, p: pinOf(u)})); } catch (e) {} }
  document.addEventListener('click', function (e) {
    var el = e.target;
    while (el && el !== document) {
      var raw = linkOf(el), u = raw && mapUrl(raw);
      if (u) { e.preventDefault(); e.stopPropagation(); send(u); return; }
      el = el.parentNode;
    }
  }, true);
  var open = window.open;
  window.open = function (raw) {
    var u = raw && mapUrl(raw);
    if (u) { send(u); return null; }
    return open.apply(window, arguments);
  };
})();
""";
