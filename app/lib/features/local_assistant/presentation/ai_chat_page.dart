import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../data/chat_history_store.dart';
import '../data/muslim_ai_settings.dart';
import '../domain/assistant_message.dart';
import '../domain/local_llm.dart';
import 'ai_chat_controller.dart';
import 'ai_map_bridge.dart';
import 'assistant_controller.dart';
import 'muslim_ai_controller.dart';
import 'muslim_terms_sheet.dart';
import 'widgets/answer_text.dart';
import 'widgets/sources_section.dart';
import 'widgets/typing_indicator.dart';

/// Buka halaman penuh FG AI atau FGMuslim AI (dua AI berasingan, masing-masing dengan senarai sembang).
Future<void> showAiPage(BuildContext context, AiMode mode) =>
    Navigator.of(context).push<void>(fadeThroughRoute(AiChatPage(mode: mode)));

/// Warna identiti setiap AI (sama dengan butang pada peta).
Color aiAccent(BuildContext context, AiMode mode) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return switch (mode) {
    AiMode.fg => dark ? const Color(0xFFA78BFA) : const Color(0xFF6D28D9),
    AiMode.muslim => dark ? const Color(0xFF34D399) : const Color(0xFF047857),
  };
}

List<Color> _aiGradient(AiMode mode) => switch (mode) {
  AiMode.fg => const [Color(0xFF6D28D9), Color(0xFF2563EB)],
  AiMode.muslim => const [Color(0xFF047857), Color(0xFFCA8A04)],
};

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, required this.mode});

  final AiMode mode;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final _scaffold = GlobalKey<ScaffoldState>();

  /// Jawapan yang sudah dipaparkan secara langsung (dialirkan) tidak perlu dianimasi semula.
  final _skipTypewriter = <DateTime>{};
  final _typed = <DateTime>{};
  Timer? _keyboardScroll;

  bool get _isMuslim => widget.mode == AiMode.muslim;

  NotifierProvider<AiChatController, AssistantUiState> get _provider =>
      _isMuslim ? muslimAiControllerProvider : assistantControllerProvider;

  @override
  void initState() {
    super.initState();
    if (!_isMuslim) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(ref.read(assistantControllerProvider.notifier).warmUp());
        }
      });
    }
    _focus.addListener(() {
      if (_focus.hasFocus) _scrollToEnd(delayed: true);
    });
  }

  @override
  void dispose() {
    _keyboardScroll?.cancel();
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _uiMalay => Localizations.localeOf(context).languageCode == 'ms';

  void _scrollToEnd({bool delayed = false, bool jump = false}) {
    void go() {
      if (!mounted || !_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (jump || MediaQuery.disableAnimationsOf(context)) {
        _scroll.jumpTo(target);
      } else {
        unawaited(
          _scroll.animateTo(
            target,
            duration: Motion.normal,
            curve: Motion.standard,
          ),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (delayed) {
        // Tunggu papan kekunci selesai naik.
        _keyboardScroll?.cancel();
        _keyboardScroll = Timer(const Duration(milliseconds: 280), go);
      } else {
        go();
      }
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    _scrollToEnd();
    if (_isMuslim) {
      await ref
          .read(muslimAiControllerProvider.notifier)
          .send(text, uiMalay: _uiMalay);
    } else {
      await ref
          .read(assistantControllerProvider.notifier)
          .send(text, uiMalay: _uiMalay);
    }
  }

  Future<void> _enableMuslim() async {
    await showMuslimTermsSheet(context, ref);
  }

  void _onAction(AssistantAction action) {
    final bridge = ref.read(aiMapRequestProvider.notifier);
    switch (action.kind) {
      case AssistantActionKind.startNavigation:
        bridge.startNavigation();
      case AssistantActionKind.showRoute:
        bridge.showRoute();
      case AssistantActionKind.routeTo:
        final lat = action.lat;
        final lng = action.lng;
        if (lat == null || lng == null) return;
        unawaited(
          ref
              .read(routePreviewControllerProvider.notifier)
              .planTo(GeoPoint(lat, lng), destinationLabel: action.label),
        );
        bridge.showRoute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(_provider);
    final muslimActive = ref.watch(muslimAiSettingsProvider).isActive;
    final accent = aiAccent(context, widget.mode);

    ref.listen(_provider, (prev, next) {
      if (prev?.messages.length != next.messages.length ||
          (next.streamingText != null &&
              prev?.streamingText != next.streamingText)) {
        _scrollToEnd(jump: next.streamingText != null);
      }
      // Jawapan yang sudah dialirkan tidak ditaip semula.
      if (prev?.streamingText != null &&
          next.streamingText == null &&
          next.freshAt != null &&
          next.freshAt != prev?.freshAt) {
        _skipTypewriter.add(next.freshAt!);
      }
    });

    final gated = _isMuslim && !muslimActive;
    final needsModel =
        !_isMuslim &&
        !state.modelReady &&
        state.modelStatus != AssistantModelStatus.downloading;
    final canType = !gated && !state.busy;
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final Widget body;
    if (gated) {
      body = _MuslimGate(onEnable: () => unawaited(_enableMuslim()));
    } else if (!_isMuslim &&
        state.modelStatus == AssistantModelStatus.downloading) {
      body = _DownloadProgress(progress: state.downloadProgress);
    } else if (state.messages.isEmpty && !state.busy) {
      body = _EmptyState(
        mode: widget.mode,
        accent: accent,
        onSuggest: (s) => unawaited(_send(s)),
        footer: needsModel
            ? _DownloadCard(
                error: state.error,
                onDownload: () => unawaited(
                  ref
                      .read(assistantControllerProvider.notifier)
                      .downloadModel(),
                ),
              )
            : null,
      );
    } else {
      body = _MessageList(
        state: state,
        mode: widget.mode,
        accent: accent,
        scroll: _scroll,
        skipTypewriter: _skipTypewriter,
        typed: _typed,
        onAction: _onAction,
      );
    }

    final title = _isMuslim ? l10n.muslimAiTitle : l10n.assistantTitle;
    return Scaffold(
      key: _scaffold,
      resizeToAvoidBottomInset: true,
      endDrawer: _ConversationDrawer(
        mode: widget.mode,
        provider: _provider,
        accent: accent,
        onPicked: () => _scrollToEnd(jump: true),
      ),
      appBar: AppBar(
        titleSpacing: 0,
        scrolledUnderElevation: 0.5,
        title: Row(
          children: [
            _AiAvatar(mode: widget.mode, size: 34),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: Motion.of(context, Motion.fast),
                    child: Text(
                      state.phase == AiPhase.preparing
                          ? l10n.aiPreparing
                          : (state.current?.title.isNotEmpty ?? false)
                          ? state.current!.title
                          : l10n.aiNewChat,
                      key: ValueKey(
                        '${state.phase == AiPhase.preparing}-${state.current?.id}',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('ai-new-chat'),
            tooltip: l10n.aiNewChat,
            onPressed: state.busy || state.messages.isEmpty
                ? null
                : () {
                    ref.read(_provider.notifier).newConversation();
                    _focus.requestFocus();
                  },
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            key: const ValueKey('ai-chats'),
            tooltip: l10n.aiChats,
            onPressed: () => _scaffold.currentState?.openEndDrawer(),
            icon: Badge(
              isLabelVisible: state.conversations.length > 1,
              label: Text('${state.conversations.length}'),
              child: const Icon(Icons.forum_outlined),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 760 : double.infinity),
            child: Column(
              children: [
                Expanded(
                  child: AnimatedSwitcher(
                    duration: Motion.of(context, Motion.normal),
                    switchInCurve: Motion.enter,
                    switchOutCurve: Motion.exit,
                    child: KeyedSubtree(
                      key: ValueKey('${body.runtimeType}-${state.current?.id}'),
                      child: body,
                    ),
                  ),
                ),
                if (!gated)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                    child: _Composer(
                      controller: _input,
                      focusNode: _focus,
                      enabled: canType,
                      busy: state.busy,
                      accent: accent,
                      hint: _isMuslim
                          ? l10n.muslimAiInputHint
                          : l10n.assistantInputHint,
                      onSend: () => unawaited(_send()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({required this.mode, this.size = 30});

  final AiMode mode;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _aiGradient(mode),
        ),
      ),
      child: Icon(
        mode == AiMode.muslim
            ? Icons.menu_book_rounded
            : Icons.auto_awesome_rounded,
        size: size * 0.52,
        color: Colors.white,
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.state,
    required this.mode,
    required this.accent,
    required this.scroll,
    required this.skipTypewriter,
    required this.typed,
    required this.onAction,
  });

  final AssistantUiState state;
  final AiMode mode;
  final Color accent;
  final ScrollController scroll;
  final Set<DateTime> skipTypewriter;
  final Set<DateTime> typed;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = state.messages;
    final pending = state.busy;
    final streaming = state.streamingText;
    return ListView.builder(
      controller: scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: messages.length + (pending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= messages.length) {
          if (streaming != null && streaming.isNotEmpty) {
            return _AssistantBlock(
              mode: mode,
              accent: accent,
              child: AnswerText(
                streaming,
                citationColor: accent,
                trailing: BlinkingCaret(color: accent),
              ),
            );
          }
          final label = switch (state.phase) {
            AiPhase.preparing => l10n.aiPreparing,
            AiPhase.working => l10n.aiWorking,
            AiPhase.searching => l10n.aiSearchingSources,
            _ => l10n.aiThinking,
          };
          return _AssistantBlock(
            mode: mode,
            accent: accent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: TypingIndicator(color: accent, label: label),
            ),
          );
        }
        final m = messages[i];
        if (m.role == AssistantRole.user) {
          return _UserBubble(message: m, accent: accent);
        }
        final at = m.at;
        final animate =
            at != null &&
            at == state.freshAt &&
            i == messages.length - 1 &&
            !skipTypewriter.contains(at) &&
            !typed.contains(at);
        return _AssistantMessageView(
          key: ValueKey('ai-msg-$i-${at?.microsecondsSinceEpoch}'),
          message: m,
          mode: mode,
          accent: accent,
          animate: animate,
          onTyped: at == null ? null : () => typed.add(at),
          onAction: onAction,
        );
      },
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message, required this.accent});

  final AssistantMessage message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxW = (MediaQuery.sizeOf(context).width * 0.8).clamp(220.0, 560.0);
    return _EnterAnimation(
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          constraints: BoxConstraints(maxWidth: maxW),
          decoration: BoxDecoration(
            color: accent.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: SelectableText(
            message.text,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.4,
              fontSize: 15.5,
            ),
          ),
        ),
      ),
    );
  }
}

/// Jawapan AI: avatar kecil + kandungan penuh lebar (gaya ChatGPT), bukan gelembung sempit.
class _AssistantBlock extends StatelessWidget {
  const _AssistantBlock({
    required this.mode,
    required this.accent,
    required this.child,
  });

  final AiMode mode;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _EnterAnimation(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _AiAvatar(mode: mode, size: 26),
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AssistantMessageView extends StatelessWidget {
  const _AssistantMessageView({
    super.key,
    required this.message,
    required this.mode,
    required this.accent,
    required this.animate,
    required this.onAction,
    this.onTyped,
  });

  final AssistantMessage message;
  final AiMode mode;
  final Color accent;
  final bool animate;
  final ValueChanged<AssistantAction> onAction;
  final VoidCallback? onTyped;

  @override
  Widget build(BuildContext context) {
    Widget content(String visible, bool done) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.notice != null) ...[
          AnswerNoticePill(notice: message.notice!, color: accent),
          if (message.text.isNotEmpty) const SizedBox(height: 10),
        ],
        if (message.text.isNotEmpty)
          AnswerText(
            visible,
            citationColor: accent,
            trailing: done ? null : BlinkingCaret(color: accent),
          ),
        AnimatedSwitcher(
          duration: Motion.of(context, Motion.normal),
          child: !done
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.sources.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SourcesSection(sources: message.sources, color: accent),
                    ],
                    if (message.actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _ActionsRow(
                        actions: message.actions,
                        accent: accent,
                        onAction: onAction,
                      ),
                    ],
                    if (message.text.isNotEmpty)
                      _CopyButton(text: message.text),
                  ],
                ),
        ),
      ],
    );

    return _AssistantBlock(
      mode: mode,
      accent: accent,
      child: animate && message.text.isNotEmpty
          ? TypewriterAnswer(
              text: message.text,
              wordDelay: Duration(
                milliseconds: mode == AiMode.muslim ? 26 : 14,
              ),
              onDone: onTyped,
              builder: (context, visible, done) => content(visible, done),
            )
          : content(message.text, true),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: l10n.aiCopy,
        iconSize: 17,
        color: theme.colorScheme.onSurfaceVariant,
        onPressed: () {
          unawaited(
            Clipboard.setData(ClipboardData(text: text.replaceAll('**', ''))),
          );
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(l10n.aiCopied),
                duration: const Duration(seconds: 1),
              ),
            );
        },
        icon: const Icon(Icons.copy_rounded),
      ),
    );
  }
}

class _ActionsRow extends StatelessWidget {
  const _ActionsRow({
    required this.actions,
    required this.accent,
    required this.onAction,
  });

  final List<AssistantAction> actions;
  final Color accent;
  final ValueChanged<AssistantAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in actions)
          switch (a.kind) {
            AssistantActionKind.startNavigation => FilledButton.icon(
              key: const ValueKey('ai-action-start'),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onAction(a),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(l10n.aiActionStart),
            ),
            AssistantActionKind.showRoute => OutlinedButton.icon(
              key: const ValueKey('ai-action-show'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onAction(a),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: Text(l10n.aiActionShowRoute),
            ),
            AssistantActionKind.routeTo => ActionChip(
              avatar: Icon(Icons.directions_rounded, size: 18, color: accent),
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  l10n.aiActionRouteTo(a.label ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              onPressed: () => onAction(a),
            ),
          },
      ],
    );
  }
}

class _EnterAnimation extends StatelessWidget {
  const _EnterAnimation({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.normal),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.busy,
    required this.accent,
    required this.hint,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool busy;
  final Color accent;
  final String hint;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 5, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('ai-input'),
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 5,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: hint,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final ready = enabled && value.text.trim().isNotEmpty;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: AnimatedContainer(
                    duration: Motion.of(context, Motion.fast),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ready
                          ? accent
                          : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                    ),
                    child: IconButton(
                      key: const ValueKey('ai-send'),
                      onPressed: ready ? onSend : null,
                      icon: busy
                          ? SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: accent,
                              ),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              color: ready
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.mode,
    required this.accent,
    required this.onSuggest,
    this.footer,
  });

  final AiMode mode;
  final Color accent;
  final ValueChanged<String> onSuggest;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muslim = mode == AiMode.muslim;
    final suggestions = muslim
        ? [
            (Icons.volunteer_activism_rounded, l10n.muslimAiSuggestZakat),
            (Icons.self_improvement_rounded, l10n.muslimAiSuggestSolat),
            (Icons.account_balance_rounded, l10n.muslimAiSuggestRiba),
          ]
        : [
            (Icons.directions_car_rounded, l10n.assistantSuggestRoute),
            (Icons.local_gas_station_rounded, l10n.assistantSuggestFuel),
            (Icons.cloud_rounded, l10n.assistantSuggestWeather),
            (Icons.lightbulb_outline_rounded, l10n.assistantSuggestGeneral),
          ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: Motion.of(context, Motion.emphasized),
            curve: Motion.enter,
            builder: (context, s, child) =>
                Transform.scale(scale: s, child: child),
            child: _AiAvatar(mode: mode, size: 64),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          muslim ? l10n.muslimAiEmptyTitle : l10n.assistantEmptyTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          muslim ? l10n.muslimAiHint : l10n.assistantHint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < suggestions.length; i++)
          _FadeIn(
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSuggest(suggestions[i].$2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        Icon(suggestions[i].$1, size: 20, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            suggestions[i].$2,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.north_east_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ],
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = Motion.of(context, Duration(milliseconds: 280 + index * 70));
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        total == Duration.zero ? 0 : (index * 70) / total.inMilliseconds,
        1,
        curve: Motion.enter,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.onDownload, this.error});

  final VoidCallback onDownload;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.download_for_offline_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.assistantDownloadTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${l10n.assistantDownloadBody}\n${l10n.aiNeedModel}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
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

class _MuslimGate extends StatelessWidget {
  const _MuslimGate({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      children: [
        const Center(child: _AiAvatar(mode: AiMode.muslim, size: 72)),
        const SizedBox(height: 18),
        Text(
          l10n.muslimAiGateTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.muslimAiGateBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: FilledButton.tonalIcon(
            key: const ValueKey('muslim-enable'),
            onPressed: onEnable,
            icon: const Icon(Icons.verified_user_outlined),
            label: Text(l10n.muslimAiEnableAction),
          ),
        ),
      ],
    );
  }
}

/// Senarai sembang (seperti ChatGPT): baharu, buka, namakan semula, padam (dengan buat asal).
class _ConversationDrawer extends ConsumerWidget {
  const _ConversationDrawer({
    required this.mode,
    required this.provider,
    required this.accent,
    required this.onPicked,
  });

  final AiMode mode;
  final NotifierProvider<AiChatController, AssistantUiState> provider;
  final Color accent;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(provider);
    final ctrl = ref.read(provider.notifier);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<ConversationMeta>>{};
    for (final c in state.conversations) {
      final day = DateTime(
        c.updatedAt.year,
        c.updatedAt.month,
        c.updatedAt.day,
      );
      final key = !day.isBefore(today)
          ? l10n.aiToday
          : today.difference(day).inDays <= 7
          ? l10n.aiPrevious7Days
          : l10n.aiOlder;
      (groups[key] ??= []).add(c);
    }
    final messenger = ScaffoldMessenger.of(context);

    Future<void> rename(ConversationMeta c) async {
      final controller = TextEditingController(text: c.title);
      final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.aiRenameTitle),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.aiCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(l10n.aiSave),
            ),
          ],
        ),
      );
      controller.dispose();
      if (title != null) await ctrl.renameConversation(c.id, title);
    }

    Future<void> delete(ConversationMeta c) async {
      final removed = await ctrl.deleteConversation(c.id);
      if (removed == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.aiDeleted),
            action: SnackBarAction(
              label: l10n.aiUndo,
              onPressed: () => unawaited(
                ctrl.restoreConversation(removed.meta, removed.messages),
              ),
            ),
          ),
        );
    }

    Future<void> deleteAll() async {
      final name = mode == AiMode.muslim
          ? l10n.muslimAiTitle
          : l10n.assistantTitle;
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.aiDeleteAll),
          content: Text(l10n.aiDeleteAllConfirm(name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.aiCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.aiDelete),
            ),
          ],
        ),
      );
      if (ok ?? false) await ctrl.deleteAllConversations();
    }

    return Drawer(
      width: (MediaQuery.sizeOf(context).width * 0.86).clamp(260.0, 360.0),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _AiAvatar(mode: mode, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.aiChats,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: state.busy
                    ? null
                    : () {
                        ctrl.newConversation();
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.aiNewChat),
              ),
            ),
            Expanded(
              child: state.conversations.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          l10n.aiNoChats,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      children: [
                        for (final g in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            child: Text(
                              g.key,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final c in g.value)
                            ListTile(
                              key: ValueKey('ai-conv-${c.id}'),
                              dense: true,
                              selected: state.current?.id == c.id,
                              selectedTileColor: accent.withValues(alpha: 0.1),
                              selectedColor: theme.colorScheme.onSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              title: Text(
                                c.title.isEmpty ? l10n.aiNewChat : c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: state.current?.id == c.id
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              onTap: () {
                                ctrl.openConversation(c.id);
                                Navigator.pop(context);
                                onPicked();
                              },
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz_rounded),
                                onSelected: (v) => unawaited(
                                  v == 'rename' ? rename(c) : delete(c),
                                ),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: ListTile(
                                      leading: const Icon(Icons.edit_outlined),
                                      title: Text(l10n.aiRename),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.delete_outline_rounded,
                                        color: theme.colorScheme.error,
                                      ),
                                      title: Text(l10n.aiDelete),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
            if (state.conversations.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: state.busy ? null : () => unawaited(deleteAll()),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: Text(l10n.aiDeleteAll),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
