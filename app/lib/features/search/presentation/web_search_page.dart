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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_web != null) return;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final decision = decideWebNavigation(request.url);
            switch (decision) {
              case HandToMaps(:final uri):
                _handOff(uri);
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
            final decision = decideWebNavigation(url);
            if (decision is HandToMaps) _handOff(decision.uri);
          },
          onProgress: (p) {
            if (mounted) setState(() => _progress = p / 100);
          },
          onPageFinished: (_) async {
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

  void _handOff(Uri uri) {
    if (_handedOff || !mounted) return;
    _handedOff = true;
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
              child: web == null
                  ? const SizedBox.shrink()
                  : WebViewWidget(controller: web),
            ),
          ],
        ),
      ),
    );
  }
}
