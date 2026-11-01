import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../settings/device_tier.dart';
import 'agent_controller.dart';

/// Lapisan ejen di atas seluruh app (dipasang dalam `MaterialApp.builder`): sorotan malap pada kawalan
/// yang akan ditekan, jari hantu yang bergerak dan beriak semasa menekan, dan kad status dengan senarai
/// semak langkah serta butang Henti. Tidak menghalang sentuhan sintetik ejen; sentuhan pengguna sebenar
/// menghentikan ejen.
class AgentOverlay extends ConsumerWidget {
  const AgentOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agentControllerProvider);
    final motion =
        !LiteMode.enabled && !MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        KeyedSubtree(key: agentAppKey, child: child),
        if (state.active) ...[
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (e.device != kAgentPointerDevice) {
                  ref.read(agentControllerProvider.notifier).stop();
                }
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: _Spotlight(target: state.target, animate: motion),
            ),
          ),
          if (state.pointer != null)
            _GhostFinger(
              at: state.pointer!,
              pressing: state.pressing,
              animate: motion,
            ),
          // Kad status di separuh skrin yang BERTENTANGAN dengan sasaran: jika tidak, ia menutup butang
          // yang hendak ditekan (sentuhan ejen terkena kad, bukan butang).
          Positioned.fill(
            child: SafeArea(
              // Di atas papan kekunci bila ia terbuka (ejen menaip), bukan di belakangnya.
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  8 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: AnimatedAlign(
                  duration: motion
                      ? const Duration(milliseconds: 260)
                      : Duration.zero,
                  curve: Curves.easeOutCubic,
                  alignment:
                      _cardOnTop(
                        state.target,
                        MediaQuery.sizeOf(context).height -
                            MediaQuery.viewInsetsOf(context).bottom,
                      )
                      ? Alignment.topCenter
                      : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _StatusCard(state: state),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kad di atas melainkan sasaran berada di separuh atas ruang yang kelihatan ([visibleHeight]: tinggi
/// skrin tolak papan kekunci).
bool _cardOnTop(Rect? target, double visibleHeight) =>
    target == null || target.center.dy > visibleHeight * 0.45;

class _Spotlight extends StatelessWidget {
  const _Spotlight({required this.target, required this.animate});

  final Rect? target;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target == null ? 0 : 1),
      duration: animate ? const Duration(milliseconds: 260) : Duration.zero,
      builder: (context, t, _) => CustomPaint(
        painter: _SpotlightPainter(
          target: target,
          opacity: 0.30 * t,
          ring: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.target,
    required this.opacity,
    required this.ring,
  });

  final Rect? target;
  final double opacity;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final t = target;
    if (t == null || opacity <= 0) return;
    final hole = RRect.fromRectAndRadius(
      t.inflate(8),
      const Radius.circular(18),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas
      ..drawPath(path, Paint()..color = Colors.black.withValues(alpha: opacity))
      ..drawRRect(
        hole,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = ring.withValues(alpha: (opacity / 0.30).clamp(0, 1)),
      );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.opacity != opacity || old.ring != ring;
}

class _GhostFinger extends StatelessWidget {
  const _GhostFinger({
    required this.at,
    required this.pressing,
    required this.animate,
  });

  final Offset at;
  final bool pressing;
  final bool animate;

  static const _size = 46.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedPositioned(
      duration: animate ? const Duration(milliseconds: 420) : Duration.zero,
      curve: Curves.easeInOutCubic,
      left: at.dx - _size / 2,
      top: at.dy - _size / 2,
      child: IgnorePointer(
        child: AnimatedScale(
          scale: pressing ? 0.78 : 1,
          duration: animate ? const Duration(milliseconds: 120) : Duration.zero,
          child: Container(
            key: const ValueKey('agent-finger'),
            width: _size,
            height: _size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.92),
              border: Border.all(color: scheme.primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(
                    alpha: pressing ? 0.55 : 0.30,
                  ),
                  blurRadius: pressing ? 18 : 10,
                  spreadRadius: pressing ? 6 : 1,
                ),
              ],
            ),
            child: Icon(
              Icons.touch_app_rounded,
              color: scheme.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.state});

  final AgentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final running = state.steps
        .where((s) => s.status == AgentStepStatus.running)
        .firstOrNull;
    return Material(
      key: const ValueKey('agent-status'),
      elevation: 6,
      color: scheme.surface,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFF6D28D9), Color(0xFF2563EB)],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        running?.label ?? l10n.agentWorking,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('agent-stop'),
                  onPressed: () =>
                      ref.read(agentControllerProvider.notifier).stop(),
                  icon: const Icon(Icons.stop_circle_rounded, size: 18),
                  label: Text(l10n.agentStop),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final s in state.steps) _StepRow(step: s),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final AgentStepView step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (step.status) {
      AgentStepStatus.done => (Icons.check_circle_rounded, scheme.primary),
      AgentStepStatus.failed => (Icons.cancel_rounded, scheme.error),
      AgentStepStatus.running => (
        Icons.radio_button_checked_rounded,
        scheme.tertiary,
      ),
      AgentStepStatus.pending => (
        Icons.radio_button_unchecked_rounded,
        scheme.outline,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 2, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: step.status == AgentStepStatus.running
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: step.status == AgentStepStatus.pending
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
