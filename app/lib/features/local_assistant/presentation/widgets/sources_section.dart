import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/motion.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/assistant_message.dart';

/// Nota piawai di atas jawapan FGMuslim (penafian / had kadar), dalam bahasa UI.
class AnswerNoticePill extends StatelessWidget {
  const AnswerNoticePill({
    super.key,
    required this.notice,
    required this.color,
  });

  final AnswerNotice notice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (icon, text, warn) = switch (notice) {
      AnswerNotice.classicalSummary => (
        Icons.verified_outlined,
        l10n.muslimNoticeSummary,
        false,
      ),
      AnswerNotice.rateLimited => (
        Icons.hourglass_top_rounded,
        l10n.muslimNoticeRateLimited,
        true,
      ),
      AnswerNotice.notGrounded => (
        Icons.search_off_rounded,
        l10n.muslimNoticeNotGrounded,
        true,
      ),
      AnswerNotice.unreachable => (
        Icons.cloud_off_rounded,
        l10n.muslimNoticeUnreachable,
        true,
      ),
    };
    final tint = warn ? theme.colorScheme.error : color;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sumber (5)" yang boleh dilipat: kad bernombor dikumpulkan (teks klasik, fatwa). Dilipat secara
/// lalai supaya jawapan kekal kemas.
class SourcesSection extends StatefulWidget {
  const SourcesSection({super.key, required this.sources, required this.color});

  final List<AnswerSource> sources;
  final Color color;

  @override
  State<SourcesSection> createState() => _SourcesSectionState();
}

class _SourcesSectionState extends State<SourcesSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final classical = widget.sources
        .where((s) => s.kind == AnswerSourceKind.classical)
        .toList();
    final fatwa = widget.sources
        .where((s) => s.kind == AnswerSourceKind.fatwa)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.6,
          ),
          shape: const StadiumBorder(),
          child: InkWell(
            key: const ValueKey('ai-sources-toggle'),
            customBorder: const StadiumBorder(),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 16,
                    color: widget.color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.muslimSources(widget.sources.length),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: Motion.of(context, Motion.normal),
                    child: const Icon(Icons.expand_more_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.of(context, Motion.normal),
          curve: Motion.standard,
          alignment: Alignment.topLeft,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (classical.isNotEmpty) ...[
                        _GroupLabel(l10n.muslimClassical),
                        for (var i = 0; i < classical.length; i++)
                          _SourceCard(
                            source: classical[i],
                            index: classical[i].n ?? i + 1,
                            color: widget.color,
                          ),
                      ],
                      if (fatwa.isNotEmpty) ...[
                        if (classical.isNotEmpty) const SizedBox(height: 6),
                        _GroupLabel(l10n.muslimFatwa),
                        for (var i = 0; i < fatwa.length; i++)
                          _SourceCard(
                            source: fatwa[i],
                            index: i + 1,
                            color: theme.colorScheme.secondary,
                            fatwa: true,
                          ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.source,
    required this.index,
    required this.color,
    this.fatwa = false,
  });

  final AnswerSource source;
  final int index;
  final Color color;
  final bool fatwa;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = source.subtitle?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => launchUrl(
            Uri.parse(source.url),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: fatwa
                      ? Icon(Icons.gavel_rounded, size: 14, color: color)
                      : Text(
                          '$index',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (source.original != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          source.original!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: _hasArabic(subtitle)
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 2),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasArabic(String s) => RegExp(r'[؀-ۿ]').hasMatch(s);
}
