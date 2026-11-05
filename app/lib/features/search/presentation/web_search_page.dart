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
  final fromLink = sharedLocationFromUri(original)?.label?.trim();
  final label = fromLink == null || fromLink.isEmpty
      ? sanitizeSharedLabel(fallbackLabel)?.trim()
      : fromLink;
  return Uri.https('maps.google.com', '/maps', {
    'daddr': label == null || label.isEmpty ? '$lat,$lng' : '$label @$lat,$lng',
  });
}

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
            await _web?.runJavaScript(_interceptScript);
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
    final decision = decideWebNavigation(url);
    if (decision is HandToMaps) _onMapUri(decision.uri, pagePin: pin);
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
    // Navigasi tanpa klik (tiada konteks kad): cari pin unik pada halaman semasa dahulu.
    try {
      final r = await web.runJavaScriptReturningResult(
        'window.__fgPagePin ? window.__fgPagePin() : ""',
      );
      final pin = '$r'.replaceAll('"', '');
      final withPin = pin.isEmpty
          ? null
          : withGooglePin(uri, pin, fallbackLabel: _serpQuery);
      if (withPin != null) {
        _handOff(withPin);
        return;
      }
    } on Object {
      // Halaman tanpa skrip (belum siap dimuat): teruskan ke Google Maps web.
    }
    if (_handedOff || !mounted) return;
    _resolveTimeout = Timer(const Duration(seconds: 20), () {
      // Google tidak memberi koordinat: pulangkan pautan asal (FGMaps mencari nama tempat itu).
      final original = _resolving;
      if (original != null) _handOff(original);
    });
    // Google Maps web mudah alih mengalih ke app (`intent://`) dan berhenti; versi desktop memuat
    // halaman tempat, yang membawa pin dalam URL atau data tempatnya.
    await web.setUserAgent(_desktopUserAgent);
    await web.loadRequest(uri);
    _resolvePoll = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (_resolving == null || _handedOff) return;
      unawaited(
        _web?.runJavaScript(_resolvePinScript).catchError((Object _) {}),
      );
    });
  }

  void _onResolvedPin(String pin) {
    final original = _resolving;
    if (original == null) return;
    final withPin = withGooglePin(original, pin, fallbackLabel: _serpQuery);
    if (withPin != null) _handOff(withPin);
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
    Navigator.of(context).pop(uri);
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
      canPop: !_canBack,
      onPopInvokedWithResult: (didPop, _) async {
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
              onPressed: () => web?.reload(),
            ),
            PopupMenuButton<String>(
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
  var re = /(google\.[a-z.]+\/maps|maps\.google\.|maps\.app\.goo\.gl|goo\.gl\/maps|^intent:|^geo:|^google\.navigation:)/i;
  function abs(u) { try { return new URL(u, location.href).href; } catch (e) { return String(u); } }
  function dec(u) { try { return decodeURIComponent(String(u).replace(/\+/g, ' ')); } catch (e) { return String(u); } }
  // Koordinat pin dalam pautan Google: daddr/destination "… @lat,lng" atau data "!3dlat!4dlng".
  function pinOf(u) {
    var t = dec(u), m = /[?&](?:daddr|destination)=[^&]*@(-?\d{1,2}\.\d+),\s*(-?\d{1,3}\.\d+)/.exec(t);
    if (!m) m = /!3d(-?\d{1,2}\.\d+)!4d(-?\d{1,3}\.\d+)/.exec(t);
    return m ? m[1] + ',' + m[2] : null;
  }
  function linkOf(el) { return el.getAttribute && (el.getAttribute('href') || el.getAttribute('data-url') || el.getAttribute('data-href')) || ''; }
  // Satu pin unik dalam [root]; null jika tiada atau lebih daripada satu tempat.
  function uniquePin(root) {
    var found = null, els = root.querySelectorAll('a[href],[data-url],[data-href]');
    for (var i = 0; i < els.length; i++) {
      var p = pinOf(linkOf(els[i]));
      if (!p) continue;
      if (found && found !== p) return false;
      found = p;
    }
    return found;
  }
  // Naik dari elemen yang ditekan sehingga bekas pertama yang ada pin: kad tempat yang sama.
  function pinNear(el) {
    for (var n = 0; el && el !== document && n < 14; n++, el = el.parentNode) {
      if (!el.querySelectorAll) continue;
      var p = uniquePin(el);
      if (p === false) return null;
      if (p) return p;
    }
    var all = uniquePin(document);
    return all || null;
  }
  window.__fgPagePin = function () { return uniquePin(document) || ''; };
  function send(u, p) { try { FGMapsLink.postMessage(JSON.stringify({u: abs(u), p: p || pinOf(u)})); } catch (e) {} }
  document.addEventListener('click', function (e) {
    var el = e.target;
    while (el && el !== document) {
      var u = linkOf(el);
      if (u && re.test(abs(u))) { e.preventDefault(); e.stopPropagation(); send(u, pinOf(u) || pinNear(el)); return; }
      el = el.parentNode;
    }
  }, true);
  var open = window.open;
  window.open = function (u) {
    if (u && re.test(abs(u))) { send(u, pinOf(u) || window.__fgPagePin() || null); return null; }
    return open.apply(window, arguments);
  };
})();
""";
