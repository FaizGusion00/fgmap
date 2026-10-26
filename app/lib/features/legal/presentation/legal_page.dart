import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/legal_config.dart';
import '../../../l10n/generated/app_localizations.dart';

enum LegalDoc { privacy, terms }

/// Teks dokumen undang-undang mengikut bahasa (`ms` atau `en`), dengan butiran entiti diisi.
final legalTextProvider = FutureProvider.family<String, (LegalDoc, String)>((
  ref,
  key,
) async {
  final (doc, language) = key;
  final lang = language == 'ms' ? 'ms' : 'en';
  final raw = await rootBundle.loadString(
    'assets/legal/${doc == LegalDoc.privacy ? 'privacy' : 'terms'}.$lang.md',
  );
  return fillLegalTemplate(raw, LegalConfig.values);
});

Future<void> showLegalPage(BuildContext context, LegalDoc doc) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => LegalPage(doc: doc)));

/// Dokumen undang-undang yang boleh dibaca dan digulung (Dasar Privasi atau Terma).
class LegalPage extends ConsumerWidget {
  const LegalPage({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = ref.watch(legalTextProvider((doc, l10n.localeName)));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc == LegalDoc.privacy
              ? l10n.legalPrivacyTitle
              : l10n.legalTermsTitle,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: text.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(l10n.legalLoadFailed)),
              data: (markdown) => ListView(
                key: const ValueKey('legal-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (!LegalConfig.reviewedByLawyer)
                    Container(
                      key: const ValueKey('legal-draft-banner'),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.legalDraftNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ...MarkdownBlocks(markdown).build(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Penyaji Markdown ringkas untuk dokumen undang-undang kita sahaja: tajuk (`#`, `##`, `###`), senarai
/// bertitik (`- `), perenggan dan teks tebal (`**...**`). Sengaja tidak menggunakan pakej luar (tiada
/// HTML, tiada pautan, tiada imej) supaya permukaan serangan kecil dan teks tidak boleh melaksanakan apa-apa.
class MarkdownBlocks {
  const MarkdownBlocks(this.source);

  final String source;

  List<Widget> build(BuildContext context) {
    final theme = Theme.of(context);
    final widgets = <Widget>[];
    final paragraph = <String>[];

    void flush() {
      if (paragraph.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            _inline(paragraph.join('\n'), theme.textTheme.bodyMedium!),
          ),
        ),
      );
      paragraph.clear();
    }

    for (final line in source.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        flush();
      } else if (trimmed.startsWith('### ')) {
        flush();
        widgets.add(
          _heading(theme, trimmed.substring(4), theme.textTheme.titleSmall!),
        );
      } else if (trimmed.startsWith('## ')) {
        flush();
        widgets.add(
          _heading(theme, trimmed.substring(3), theme.textTheme.titleMedium!),
        );
      } else if (trimmed.startsWith('# ')) {
        flush();
        widgets.add(
          _heading(theme, trimmed.substring(2), theme.textTheme.headlineSmall!),
        );
      } else if (trimmed.startsWith('- ')) {
        flush();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: Text('•', style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  child: Text.rich(
                    _inline(trimmed.substring(2), theme.textTheme.bodyMedium!),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        paragraph.add(trimmed);
      }
    }
    flush();
    return widgets;
  }

  static Widget _heading(ThemeData theme, String text, TextStyle style) {
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(text, style: style),
      ),
    );
  }

  /// `**tebal**` -> span tebal; selebihnya teks biasa.
  static TextSpan _inline(String text, TextStyle base) {
    final spans = <TextSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in bold.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return TextSpan(style: base, children: spans);
  }
}
