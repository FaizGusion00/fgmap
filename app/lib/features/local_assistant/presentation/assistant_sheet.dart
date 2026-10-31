import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/deen_fatwa_client.dart';
import '../data/islamic_app_client.dart';
import '../domain/assistant_message.dart';
import '../domain/local_llm.dart';
import 'assistant_controller.dart';
import 'muslim_ai_controller.dart';
import 'muslim_terms_sheet.dart';
import '../data/muslim_ai_settings.dart';

enum _AiMode { fgmaps, muslim }

/// Mod yang dibuka terus daripada peta: dua butang, dua pintu.
enum AssistantOpenMode { fgmaps, muslim }

Future<void> showAssistantSheet(
  BuildContext context,
  WidgetRef ref, {
  AssistantOpenMode mode = AssistantOpenMode.fgmaps,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => SheetBottomInset(child: AssistantSheet(initialMode: mode)),
  ).whenComplete(() {
    unawaited(ref.read(assistantControllerProvider.notifier).releaseModel());
  });
}

class AssistantSheet extends ConsumerStatefulWidget {
  const AssistantSheet({
    super.key,
    this.initialMode = AssistantOpenMode.fgmaps,
  });

  final AssistantOpenMode initialMode;

  @override
  ConsumerState<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends ConsumerState<AssistantSheet> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late _AiMode _mode = widget.initialMode == AssistantOpenMode.muslim
      ? _AiMode.muslim
      : _AiMode.fgmaps;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _malay => Localizations.localeOf(context).languageCode == 'ms';

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.of(context, Motion.normal),
        curve: Motion.standard,
      );
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    if (_mode == _AiMode.muslim) {
      await ref
          .read(muslimAiControllerProvider.notifier)
          .send(text, malay: _malay);
    } else {
      await ref.read(assistantControllerProvider.notifier).send(text);
    }
    _scrollToEnd();
  }

  void _suggest(String text) {
    if (_mode == _AiMode.muslim) {
      final active = ref.read(muslimAiSettingsProvider).isActive;
      if (!active) {
        unawaited(_enableMuslim());
        return;
      }
    } else {
      final ready = ref.read(assistantControllerProvider).modelReady;
      if (!ready) return;
    }
    unawaited(_send(text));
  }

  Future<void> _enableMuslim() async {
    final ok = await showMuslimTermsSheet(context, ref);
    if (!mounted) return;
    if (ok) setState(() => _mode = _AiMode.muslim);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maps = ref.watch(assistantControllerProvider);
    final muslim = ref.watch(muslimAiControllerProvider);
    final muslimSettings = ref.watch(muslimAiSettingsProvider);
    final muslimActive = muslimSettings.isActive;
    final isMuslim = _mode == _AiMode.muslim;

    ref.listen(assistantControllerProvider, (prev, next) {
      if (!isMuslim && prev?.messages.length != next.messages.length) {
        _scrollToEnd();
      }
    });
    ref.listen(muslimAiControllerProvider, (prev, next) {
      if (isMuslim && prev?.messages.length != next.messages.length) {
        _scrollToEnd();
      }
    });

    final busy = isMuslim ? muslim.busy : maps.busy;
    final error = isMuslim ? muslim.error : maps.error;
    final messages = isMuslim ? muslim.messages : maps.messages;
    final canType = isMuslim ? muslimActive && !busy : maps.modelReady && !busy;

    final wide = MediaQuery.sizeOf(context).width >= 700;
    final hPad = wide ? 28.0 : 16.0;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: wide ? 0.88 : 0.84,
      minChildSize: 0.46,
      maxChildSize: 0.97,
      builder: (context, _) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 720 : double.infinity),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 0, 8, 0),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: Motion.of(context, Motion.fast),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isMuslim
                              ? [
                                  theme.colorScheme.tertiaryContainer,
                                  theme.colorScheme.secondaryContainer,
                                ]
                              : [
                                  theme.colorScheme.primaryContainer,
                                  theme.colorScheme.secondaryContainer,
                                ],
                        ),
                      ),
                      child: Icon(
                        isMuslim
                            ? Icons.menu_book_rounded
                            : Icons.auto_awesome_rounded,
                        size: 20,
                        color: isMuslim
                            ? theme.colorScheme.onTertiaryContainer
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: Motion.of(context, Motion.fast),
                        child: Text(
                          isMuslim ? l10n.muslimAiTitle : l10n.assistantTitle,
                          key: ValueKey(
                            isMuslim ? 'muslim-title' : 'maps-title',
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    if (messages.isNotEmpty)
                      IconButton(
                        tooltip: l10n.assistantClearChat,
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                isMuslim
                                    ? ref
                                          .read(
                                            muslimAiControllerProvider.notifier,
                                          )
                                          .clearChat()
                                    : ref
                                          .read(
                                            assistantControllerProvider
                                                .notifier,
                                          )
                                          .clearChat(),
                              ),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 4),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_AiMode>(
                    key: const ValueKey('assistant-mode-tabs'),
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: isMuslim
                          ? theme.colorScheme.tertiaryContainer
                          : theme.colorScheme.primaryContainer,
                    ),
                    segments: [
                      ButtonSegment(
                        value: _AiMode.fgmaps,
                        icon: const Icon(Icons.smart_toy_rounded, size: 18),
                        label: Text(l10n.assistantModeFgmaps),
                      ),
                      ButtonSegment(
                        value: _AiMode.muslim,
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        label: Text(l10n.assistantModeMuslim),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: busy
                        ? null
                        : (s) => setState(() => _mode = s.first),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(hPad + 4, 4, hPad + 4, 6),
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.fast),
                  child: Text(
                    isMuslim ? l10n.muslimAiHint : l10n.assistantHint,
                    key: ValueKey(isMuslim ? 'muslim-hint' : 'maps-hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.of(context, Motion.normal),
                  switchInCurve: Motion.enter,
                  switchOutCurve: Motion.exit,
                  child: isMuslim
                      ? KeyedSubtree(
                          key: const ValueKey('muslim-body'),
                          child: _MuslimBody(
                            active: muslimActive,
                            messages: messages,
                            busy: busy,
                            librarySources: muslim.lastLibrarySources,
                            fatwaHits: muslim.lastFatwaHits,
                            scroll: _scroll,
                            onEnable: () => unawaited(_enableMuslim()),
                            onSuggest: _suggest,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('maps-body'),
                          child: _MapsBody(
                            state: maps,
                            scroll: _scroll,
                            onSuggest: _suggest,
                          ),
                        ),
                ),
              ),
              if (error != null &&
                  error != 'not_enabled' &&
                  (isMuslim || maps.modelReady))
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: Text(
                    error,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad - 4, 6, hPad - 4, 12),
                  child: _Composer(
                    controller: _input,
                    enabled: canType,
                    hint: isMuslim
                        ? l10n.muslimAiInputHint
                        : l10n.assistantInputHint,
                    busy: busy,
                    accentMuslim: isMuslim,
                    onSend: () => unawaited(_send()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapsBody extends ConsumerWidget {
  const _MapsBody({
    required this.state,
    required this.scroll,
    required this.onSuggest,
  });

  final AssistantUiState state;
  final ScrollController scroll;
  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.modelReady &&
        state.modelStatus != AssistantModelStatus.downloading) {
      return _DownloadPrompt(
        error: state.error,
        onDownload: () => unawaited(
          ref.read(assistantControllerProvider.notifier).downloadModel(),
        ),
      );
    }
    if (state.modelStatus == AssistantModelStatus.downloading) {
      return _DownloadProgress(progress: state.downloadProgress);
    }
    return _MessageList(
      messages: state.messages,
      busy: state.busy,
      scroll: scroll,
      empty: _EmptyMaps(onSuggest: onSuggest),
    );
  }
}

class _MuslimBody extends StatelessWidget {
  const _MuslimBody({
    required this.active,
    required this.messages,
    required this.busy,
    required this.librarySources,
    required this.fatwaHits,
    required this.scroll,
    required this.onEnable,
    required this.onSuggest,
  });

  final bool active;
  final List<AssistantMessage> messages;
  final bool busy;
  final List<IslamicAppSource> librarySources;
  final List<DeenFatwaHit> fatwaHits;
  final ScrollController scroll;
  final VoidCallback onEnable;
  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return _MuslimGate(onEnable: onEnable);
    }
    final chips = <({String label, String url, IconData icon})>[
      for (final s in librarySources.take(4))
        (
          label: s.translit?.isNotEmpty == true ? s.translit! : s.bookTitle,
          url: s.url,
          icon: Icons.menu_book_outlined,
        ),
      for (final h in fatwaHits.take(3))
        (label: h.title, url: h.url, icon: Icons.gavel_rounded),
    ];
    return Column(
      children: [
        if (chips.isNotEmpty)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: chips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = chips[i];
                return ActionChip(
                  avatar: Icon(c.icon, size: 16),
                  label: Text(
                    c.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => launchUrl(
                    Uri.parse(c.url),
                    mode: LaunchMode.externalApplication,
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: _MessageList(
            messages: messages,
            busy: busy,
            scroll: scroll,
            empty: _EmptyMuslim(onSuggest: onSuggest),
            muslimTone: true,
          ),
        ),
      ],
    );
  }
}

class _MuslimGate extends StatelessWidget {
  const _MuslimGate({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final minHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.92, end: 1),
                      duration: Motion.of(context, Motion.emphasized),
                      curve: Motion.enter,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.tertiaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 40,
                          color: theme.colorScheme.onTertiaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.muslimAiGateTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.muslimAiGateBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      key: const ValueKey('muslim-enable'),
                      onPressed: onEnable,
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(l10n.muslimAiEnableAction),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyMaps extends StatelessWidget {
  const _EmptyMaps({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _EmptyHints(
      icon: Icons.auto_awesome_rounded,
      title: l10n.assistantEmptyTitle,
      chips: [
        l10n.assistantSuggestRoute,
        l10n.assistantSuggestIpu,
        l10n.assistantSuggestGeneral,
      ],
      color: theme.colorScheme.primary,
      onSuggest: onSuggest,
    );
  }
}

class _EmptyMuslim extends StatelessWidget {
  const _EmptyMuslim({required this.onSuggest});

  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _EmptyHints(
      icon: Icons.mosque_rounded,
      title: l10n.muslimAiEmptyTitle,
      chips: [
        l10n.muslimAiSuggestZakat,
        l10n.muslimAiSuggestSolat,
        l10n.muslimAiSuggestRiba,
      ],
      color: theme.colorScheme.tertiary,
      onSuggest: onSuggest,
    );
  }
}

class _EmptyHints extends StatelessWidget {
  const _EmptyHints({
    required this.icon,
    required this.title,
    required this.chips,
    required this.color,
    required this.onSuggest,
  });

  final IconData icon;
  final String title;
  final List<String> chips;
  final Color color;
  final ValueChanged<String> onSuggest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth >= 520 ? 40.0 : 24.0;
        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: pad, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.88, end: 1),
                  duration: Motion.of(context, Motion.emphasized),
                  curve: Motion.enter,
                  builder: (context, scale, child) =>
                      Transform.scale(scale: scale, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, size: 32, color: color),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in chips)
                      ActionChip(
                        label: Text(c),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onSuggest(c),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.busy,
    required this.scroll,
    required this.empty,
    this.muslimTone = false,
  });

  final List<AssistantMessage> messages;
  final bool busy;
  final ScrollController scroll;
  final Widget empty;
  final bool muslimTone;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty && !busy) return empty;
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: messages.length + (busy ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= messages.length) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: _TypingDots(),
          );
        }
        return _Bubble(message: messages[i], muslimTone: muslimTone);
      },
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: reduce
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 5),
                        Opacity(
                          opacity:
                              0.35 +
                              0.65 *
                                  (((_c.value + i / 3) % 1.0) < 0.5
                                      ? (_c.value + i / 3) % 1.0 * 2
                                      : 1 - ((_c.value + i / 3) % 1.0) * 2),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurfaceVariant,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.busy,
    required this.accentMuslim,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final String hint;
  final bool busy;
  final bool accentMuslim;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentMuslim
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.fast),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              textInputAction: TextInputAction.send,
              minLines: 1,
              maxLines: 4,
              onSubmitted: enabled ? (_) => onSend() : null,
              decoration: InputDecoration(
                hintText: hint,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),
          AnimatedScale(
            scale: enabled ? 1 : 0.92,
            duration: Motion.of(context, Motion.fast),
            child: FilledButton(
              onPressed: enabled ? onSend : null,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: accentMuslim
                    ? theme.colorScheme.onTertiary
                    : theme.colorScheme.onPrimary,
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(12),
                minimumSize: const Size(46, 46),
              ),
              child: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.arrow_upward_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadPrompt extends StatelessWidget {
  const _DownloadPrompt({required this.onDownload, this.error});

  final VoidCallback onDownload;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.9, end: 1),
            duration: Motion.of(context, Motion.emphasized),
            curve: Motion.enter,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.assistantDownloadTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.assistantDownloadBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('assistant-download'),
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded),
            label: Text(l10n.assistantDownloadAction),
          ),
        ],
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pct = (progress * 100).clamp(0, 100).round();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress <= 0 ? null : progress,
            ),
          ),
          const SizedBox(height: 16),
          Text(l10n.assistantDownloading(pct)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.muslimTone = false});

  final AssistantMessage message;
  final bool muslimTone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.role == AssistantRole.user;
    final bg = mine
        ? (muslimTone
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.primaryContainer)
        : theme.colorScheme.surfaceContainerHighest;
    final fg = mine
        ? (muslimTone
              ? theme.colorScheme.onTertiaryContainer
              : theme.colorScheme.onPrimaryContainer)
        : theme.colorScheme.onSurface;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          constraints: BoxConstraints(
            maxWidth:
                (MediaQuery.sizeOf(context).width *
                        (MediaQuery.sizeOf(context).width >= 700 ? 0.62 : 0.84))
                    .clamp(220.0, 560.0),
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(mine ? 20 : 6),
              bottomRight: Radius.circular(mine ? 6 : 20),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SelectableText(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(color: fg, height: 1.4),
          ),
        ),
      ),
    );
  }
}
