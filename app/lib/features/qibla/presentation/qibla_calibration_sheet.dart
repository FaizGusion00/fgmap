import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/compass_heading.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Lembaran kalibrasi: animasi telefon melukis angka 8, ketepatan semasa (±°) dan amaran gangguan
/// magnet. Tutup sendiri sebaik bacaan stabil dan tepat (≤ 15° atau tahap "tinggi").
Future<void> showQiblaCalibration(
  BuildContext context,
  ValueListenable<CompassReading?> reading,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) =>
      SheetBottomInset(child: QiblaCalibrationSheet(reading: reading)),
);

class QiblaCalibrationSheet extends StatefulWidget {
  const QiblaCalibrationSheet({super.key, required this.reading});

  final ValueListenable<CompassReading?> reading;

  @override
  State<QiblaCalibrationSheet> createState() => _QiblaCalibrationSheetState();
}

class _QiblaCalibrationSheetState extends State<QiblaCalibrationSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  Timer? _close;
  var _done = false;

  @override
  void initState() {
    super.initState();
    widget.reading.addListener(_onReading);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
    } else if (!_loop.isAnimating && !_done) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    widget.reading.removeListener(_onReading);
    _close?.cancel();
    _loop.dispose();
    super.dispose();
  }

  static bool _good(CompassReading r) {
    if (r.interference) return false;
    final deg = r.accuracyDeg;
    if (deg != null) return deg <= 15;
    return r.accuracy == CompassAccuracy.high;
  }

  void _onReading() {
    final r = widget.reading.value;
    if (r == null || _done) {
      setState(() {});
      return;
    }
    if (_good(r)) {
      // Mesti kekal baik seketika (bukan satu bacaan bertuah).
      _close ??= Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _done = true);
        _loop.stop();
        unawaited(HapticFeedback.mediumImpact());
        Timer(const Duration(milliseconds: 900), () {
          if (mounted) Navigator.of(context).maybePop();
        });
      });
    } else {
      _close?.cancel();
      _close = null;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = widget.reading.value;
    final good = r != null && _good(r);
    final accent = _done || good
        ? const Color(0xFF16A34A)
        : theme.colorScheme.primary;
    final deg = r?.accuracyDeg;
    final status = _done
        ? l10n.qiblaCalibrateDone
        : r == null
        ? l10n.qiblaWaitingSensor
        : deg != null
        ? l10n.qiblaCalibrateProgress(math.max(1, deg.round()).toString())
        : l10n.qiblaCalibrateProgressLevel(_levelLabel(l10n, r.accuracy));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.qiblaCalibrateTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.qiblaCalibrateSteps,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: Motion.of(context, Motion.normal),
              child: _done
                  ? Icon(
                      Icons.check_circle_rounded,
                      key: const ValueKey('done'),
                      size: 96,
                      color: accent,
                    )
                  : AnimatedBuilder(
                      key: const ValueKey('figure8'),
                      animation: _loop,
                      builder: (context, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _FigureEightPainter(
                          t: _loop.value,
                          track: theme.colorScheme.outlineVariant,
                          accent: accent,
                          phone: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: Motion.of(context, Motion.normal),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _done || good ? Icons.verified_rounded : Icons.sync_rounded,
                  size: 18,
                  color: accent,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    status,
                    key: const ValueKey('qibla-calibration-status'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (r?.interference ?? false) ...[
            const SizedBox(height: 10),
            _InterferenceNote(),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.qiblaDone),
            ),
          ),
        ],
      ),
    );
  }

  static String _levelLabel(AppLocalizations l10n, CompassAccuracy a) =>
      switch (a) {
        CompassAccuracy.high => l10n.qiblaAccuracyHigh,
        CompassAccuracy.medium => l10n.qiblaAccuracyMedium,
        CompassAccuracy.low => l10n.qiblaAccuracyLow,
        CompassAccuracy.unreliable => l10n.qiblaAccuracyUnreliable,
      };
}

class _InterferenceNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.qiblaInterferenceBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lemniskat (angka 8 mendatar) dengan telefon kecil yang bergerak dan condong sepanjangnya.
class _FigureEightPainter extends CustomPainter {
  _FigureEightPainter({
    required this.t,
    required this.track,
    required this.accent,
    required this.phone,
  });

  final double t;
  final Color track;
  final Color accent;
  final Color phone;

  Offset _at(double u, Size size) {
    // Lemniskat Bernoulli: x = a cos / (1 + sin²), y = a sin cos / (1 + sin²).
    final a = size.width * 0.32;
    final th = u * 2 * math.pi;
    final d = 1 + math.pow(math.sin(th), 2);
    return Offset(
      size.width / 2 + a * math.cos(th) / d,
      size.height / 2 + a * math.sin(th) * math.cos(th) / d * 1.25,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i <= 120; i++) {
      final p = _at(i / 120, size);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = track,
    );
    // Ekor bercahaya di belakang telefon.
    for (var k = 0; k < 18; k++) {
      final p = _at(t - k * 0.008, size);
      canvas.drawCircle(
        p,
        5 - k * 0.22,
        Paint()..color = accent.withValues(alpha: (1 - k / 18) * 0.5),
      );
    }
    final pos = _at(t, size);
    final ahead = _at(t + 0.01, size);
    final angle = math.atan2(ahead.dy - pos.dy, ahead.dx - pos.dx);
    canvas
      ..save()
      ..translate(pos.dx, pos.dy)
      ..rotate(angle * 0.35);
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 26, height: 46),
      const Radius.circular(6),
    );
    canvas
      ..drawRRect(body, Paint()..color = accent)
      ..drawRRect(
        body.deflate(3),
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      )
      ..drawCircle(const Offset(0, 17), 1.8, Paint()..color = phone)
      ..restore();
  }

  @override
  bool shouldRepaint(_FigureEightPainter old) =>
      old.t != t || old.accent != accent;
}
