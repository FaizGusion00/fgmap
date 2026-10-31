import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/theme/motion.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/qibla.dart';

Future<void> showQiblaSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const SheetBottomInset(child: QiblaSheet()),
  );
}

class QiblaSheet extends ConsumerStatefulWidget {
  const QiblaSheet({super.key});

  @override
  ConsumerState<QiblaSheet> createState() => _QiblaSheetState();
}

class _QiblaSheetState extends ConsumerState<QiblaSheet> {
  GeoPoint? _point;
  double? _heading;
  var _loading = true;
  StreamSubscription<LocationFix>? _sub;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final loc = ref.read(locationServiceProvider);
    try {
      final fix =
          await loc.currentFix(
            timeout: const Duration(seconds: 6),
            maxAccuracyMeters: 500,
            fallbackAccuracyMeters: 5000,
          ) ??
          await loc.lastKnownFix();
      if (!mounted) return;
      setState(() {
        _point = fix?.point;
        _heading = fix?.headingDegrees?.toDouble();
        _loading = false;
      });
      _sub = loc.trackingFixes().listen((f) {
        if (!mounted) return;
        setState(() {
          _point = f.point;
          _heading = f.headingDegrees?.toDouble() ?? _heading;
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final point = _point;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.36,
      maxChildSize: 0.85,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            l10n.qiblaTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.qiblaHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (point == null)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(l10n.qiblaUnavailable, textAlign: TextAlign.center),
              ),
            )
          else
            _QiblaDial(
              bearing: qiblaBearingDegrees(point),
              relative: qiblaRelativeDegrees(point, _heading),
              distanceKm: qiblaDistanceKm(point),
            ),
        ],
      ),
    );
  }
}

class _QiblaDial extends StatelessWidget {
  const _QiblaDial({
    required this.bearing,
    required this.relative,
    required this.distanceKm,
  });

  final double bearing;
  final double? relative;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final deg = bearing.round() % 360;
    // Jika heading GPS ada, putar anak panah relatif; jika tidak, anak panah
    // tunjuk arah mutlak dari utara (bahagian atas = utara).
    final turn = (relative ?? bearing) * math.pi / 180;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.emphasized),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _DialPainter(
                turn: turn,
                color: theme.colorScheme.primary,
                ring: theme.colorScheme.outlineVariant,
                labelColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.qiblaDegrees('$deg'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '~${distanceKm.round()} km',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.turn,
    required this.color,
    required this.ring,
    required this.labelColor,
  });

  final double turn;
  final Color color;
  final Color ring;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String s, Offset o) {
      tp.text = TextSpan(
        text: s,
        style: TextStyle(
          color: labelColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      );
      tp.layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    }

    label('U', Offset(c.dx, c.dy - r + 14));
    label('S', Offset(c.dx, c.dy + r - 14));
    label('T', Offset(c.dx + r - 14, c.dy));
    label('B', Offset(c.dx - r + 14, c.dy));

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn);
    final path = Path()
      ..moveTo(0, -r + 28)
      ..lineTo(16, 18)
      ..lineTo(0, 6)
      ..lineTo(-16, 18)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DialPainter old) =>
      old.turn != turn || old.color != color;
}
