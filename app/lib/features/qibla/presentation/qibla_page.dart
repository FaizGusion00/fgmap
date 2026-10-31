import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/platform/compass_heading.dart';
import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../azan/data/azan_location.dart';
import '../domain/qibla.dart';
import 'qibla_dial.dart';

/// Buka skrin Kiblat (kompas sensor sebenar).
Future<void> showQibla(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const QiblaPage()));

/// Kompas kiblat. Arah telefon dibaca daripada sensor (bukan arah GPS yang hanya wujud semasa
/// bergerak), diputar ke utara benar, dilicinkan, dan dibandingkan dengan arah kiblat geodesik WGS84.
/// "Tepat" hanya didakwa apabila bacaan sensor boleh dipercayai; jika tidak, pengguna diminta
/// mengkalibrasi kompas, bukan diberi keyakinan palsu.
class QiblaPage extends ConsumerStatefulWidget {
  const QiblaPage({super.key});

  @override
  ConsumerState<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends ConsumerState<QiblaPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _noSensorAfter = Duration(seconds: 3);

  GeoPoint? _point;
  double? _qibla;
  double? _distanceKm;
  var _locating = true;
  GeoPoint? _sentToSource;

  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<CompassReading>? _compassSub;
  Timer? _noSensorTimer;

  var _sensorSeen = false;
  var _sensorMissing = false;
  var _accuracy = CompassAccuracy.unreliable;
  var _trueNorth = false;
  double? _target;
  double? _gpsHeading;

  final _smoother = HeadingSmoother();
  final _alignment = QiblaAlignment();
  final _heading = ValueNotifier<double>(0);
  final _turn = ValueNotifier<int?>(null);
  var _aligned = false;

  late final Ticker _ticker = createTicker(_onTick);
  var _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCompass();
    unawaited(_bootstrapLocation());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _noSensorTimer?.cancel();
    unawaited(_compassSub?.cancel());
    unawaited(_fixSub?.cancel());
    _ticker.dispose();
    _heading.dispose();
    _turn.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sensor tidak berjalan di latar belakang (jimat bateri).
    if (state == AppLifecycleState.resumed) {
      _startCompass();
    } else if (state == AppLifecycleState.paused) {
      _noSensorTimer?.cancel();
      unawaited(_compassSub?.cancel());
      _compassSub = null;
      if (_ticker.isActive) _ticker.stop();
    }
  }

  void _startCompass() {
    unawaited(_compassSub?.cancel());
    final source = ref.read(compassHeadingSourceProvider);
    _compassSub = source.readings().listen(
      _onReading,
      onDone: () {
        if (!_sensorSeen && mounted) setState(() => _sensorMissing = true);
      },
    );
    _noSensorTimer?.cancel();
    _noSensorTimer = Timer(_noSensorAfter, () {
      if (!_sensorSeen && mounted) setState(() => _sensorMissing = true);
    });
    _sentToSource = null;
    _pushLocationToSource();
  }

  void _pushLocationToSource() {
    final p = _point;
    if (p == null) return;
    final sent = _sentToSource;
    if (sent != null && distanceMeters(sent, p) < 5000) return;
    _sentToSource = p;
    unawaited(ref.read(compassHeadingSourceProvider).setLocation(p));
  }

  void _onReading(CompassReading r) {
    _target = r.headingDegrees;
    final changed =
        !_sensorSeen ||
        _sensorMissing ||
        _accuracy != r.accuracy ||
        _trueNorth != r.trueNorth;
    _sensorSeen = true;
    _sensorMissing = false;
    _accuracy = r.accuracy;
    _trueNorth = r.trueNorth;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      unawaited(_ticker.start());
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _bootstrapLocation() async {
    final loc = ref.read(locationServiceProvider);
    try {
      // Paparan segera daripada lokasi terakhir/tersimpan, kemudian diperhalusi oleh fix semasa.
      final stored = ref.read(azanLocationProvider);
      if (stored != null) _setPoint(stored);
      final last = await loc.lastKnownFix();
      if (last != null) _setPoint(last.point);
      final fix = await loc.currentFix(
        timeout: const Duration(seconds: 6),
        maxAccuracyMeters: 500,
        fallbackAccuracyMeters: 5000,
      );
      if (fix != null) _setPoint(fix.point);
      _fixSub = loc.trackingFixes().listen((f) {
        _setPoint(f.point);
        final h = f.headingDegrees;
        if (h != null && (f.speedMps ?? 0) > 1.5) _gpsHeading = h.toDouble();
      });
    } catch (_) {
      // Tanpa lokasi: UI menunjukkan mesej, kompas tetap berjalan.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setPoint(GeoPoint p) {
    if (!mounted) return;
    final old = _point;
    if (old != null && distanceMeters(old, p) < 50) return;
    setState(() {
      _point = p;
      _qibla = qiblaBearingDegrees(p);
      _distanceKm = qiblaDistanceKm(p);
    });
    _pushLocationToSource();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    final target = _target ?? (_sensorMissing ? _gpsHeading : null);
    if (target == null) return;
    final shown = _smoother.step(target, dt);
    _heading.value = shown;

    final qibla = _qibla;
    if (qibla == null) return;
    final turn = qiblaTurnDegrees(qibla: qibla, heading: shown);
    final rounded = turn.round();
    if (_turn.value != rounded) _turn.value = rounded;

    // Jangan dakwa "tepat" apabila sensor tiada atau tidak boleh dipercayai.
    final trusted = !_sensorMissing && _accuracy != CompassAccuracy.unreliable;
    final now = trusted && _alignment.update(turn);
    if (!trusted) _alignment.reset();
    if (now != _aligned) {
      _aligned = now;
      if (now) unawaited(HapticFeedback.heavyImpact());
      if (mounted) setState(() {});
    }
  }

  bool get _hasHeading =>
      _target != null || (_sensorMissing && _gpsHeading != null);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = QiblaDialColors.of(theme);
    final cardinals = l10n.qiblaCardinals.split(',');
    final qibla = _qibla;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qiblaTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final dial = (box.maxWidth - 32).clamp(220.0, 360.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _StatusCard(
                        key: const ValueKey('qibla-status'),
                        aligned: _aligned,
                        hasHeading: _hasHeading,
                        sensorMissing: _sensorMissing && !_hasHeading,
                        locating: _locating && qibla == null,
                        noLocation: !_locating && qibla == null,
                        turn: _turn,
                        colors: colors,
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label: _semantics(l10n),
                        child: SizedBox.square(
                          dimension: dial,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              RepaintBoundary(
                                child: CustomPaint(
                                  key: const ValueKey('qibla-dial'),
                                  size: Size.square(dial),
                                  painter: QiblaDialPainter(
                                    heading: _heading,
                                    qibla: qibla ?? 0,
                                    aligned: _aligned,
                                    hasHeading: _hasHeading,
                                    colors: colors,
                                    cardinals: cardinals,
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<double>(
                                valueListenable: _heading,
                                builder: (context, h, _) => Text(
                                  _hasHeading ? '${h.round() % 360}°' : '—',
                                  key: const ValueKey('qibla-heading'),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: l10n.qiblaDirectionLabel,
                              value: qibla == null
                                  ? '—'
                                  : '${qibla.toStringAsFixed(1)}°',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoTile(
                              label: l10n.qiblaDistanceLabel,
                              value: _distanceKm == null
                                  ? '—'
                                  : l10n.qiblaDistanceValue(
                                      _formatKm(_distanceKm!),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _InfoTile(
                              key: const ValueKey('qibla-accuracy'),
                              label: l10n.qiblaSensorLabel,
                              value: _sensorSeen
                                  ? _accuracyLabel(l10n, _accuracy)
                                  : '—',
                              dot: _sensorSeen
                                  ? _accuracyColor(_accuracy, colors)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_sensorSeen &&
                          (_accuracy == CompassAccuracy.unreliable ||
                              _accuracy == CompassAccuracy.low))
                        _TipCard(
                          key: const ValueKey('qibla-calibrate'),
                          icon: Icons.screen_rotation_alt_rounded,
                          title: l10n.qiblaCalibrateTitle,
                          body: l10n.qiblaCalibrateBody,
                          color: theme.colorScheme.tertiaryContainer,
                          onColor: theme.colorScheme.onTertiaryContainer,
                        )
                      else
                        _TipCard(
                          icon: Icons.phone_android_rounded,
                          title: l10n.qiblaFlatTip,
                          color: theme.colorScheme.surfaceContainerHigh,
                          onColor: theme.colorScheme.onSurface,
                        ),
                      if (_sensorSeen) ...[
                        const SizedBox(height: 10),
                        Text(
                          _trueNorth
                              ? l10n.qiblaNorthTrue
                              : l10n.qiblaNorthMagnetic,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _semantics(AppLocalizations l10n) {
    final q = _qibla;
    final turn = _turn.value;
    final guidance = _aligned
        ? l10n.qiblaFacing
        : turn == null
        ? ''
        : (turn >= 0
              ? l10n.qiblaTurnRight('$turn')
              : l10n.qiblaTurnLeft('${-turn}'));
    return l10n.qiblaSemantics(
      _hasHeading ? '${_heading.value.round() % 360}' : '?',
      q == null ? '?' : q.toStringAsFixed(1),
      guidance,
    );
  }

  static String _formatKm(double km) {
    final n = km.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < n.length; i++) {
      if (i > 0 && (n.length - i) % 3 == 0) b.write(',');
      b.write(n[i]);
    }
    return b.toString();
  }

  static String _accuracyLabel(AppLocalizations l10n, CompassAccuracy a) =>
      switch (a) {
        CompassAccuracy.high => l10n.qiblaAccuracyHigh,
        CompassAccuracy.medium => l10n.qiblaAccuracyMedium,
        CompassAccuracy.low => l10n.qiblaAccuracyLow,
        CompassAccuracy.unreliable => l10n.qiblaAccuracyUnreliable,
      };

  static Color _accuracyColor(CompassAccuracy a, QiblaDialColors c) =>
      switch (a) {
        CompassAccuracy.high => c.ok,
        CompassAccuracy.medium => c.gold,
        CompassAccuracy.low || CompassAccuracy.unreliable => c.north,
      };
}

/// Kad status di atas dail: tepat / arah pusing / menunggu / tiada sensor.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    super.key,
    required this.aligned,
    required this.hasHeading,
    required this.sensorMissing,
    required this.locating,
    required this.noLocation,
    required this.turn,
    required this.colors,
  });

  final bool aligned;
  final bool hasHeading;
  final bool sensorMissing;
  final bool locating;
  final bool noLocation;
  final ValueListenable<int?> turn;
  final QiblaDialColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    Widget card({
      required Key key,
      required Color bg,
      required Color fg,
      required IconData icon,
      required String text,
      String? sub,
      bool spinner = false,
    }) {
      return Container(
        key: key,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            spinner
                ? SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: fg,
                    ),
                  )
                : Icon(icon, color: fg, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg.withValues(alpha: 0.85),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int?>(
      valueListenable: turn,
      builder: (context, t, _) {
        final Widget child;
        if (noLocation) {
          child = card(
            key: const ValueKey('qibla-state-nolocation'),
            bg: theme.colorScheme.surfaceContainerHigh,
            fg: theme.colorScheme.onSurface,
            icon: Icons.location_off_rounded,
            text: l10n.qiblaUnavailable,
          );
        } else if (sensorMissing) {
          child = card(
            key: const ValueKey('qibla-state-nosensor'),
            bg: theme.colorScheme.tertiaryContainer,
            fg: theme.colorScheme.onTertiaryContainer,
            icon: Icons.explore_off_rounded,
            text: l10n.qiblaNoSensor,
          );
        } else if (aligned) {
          child = card(
            key: const ValueKey('qibla-state-aligned'),
            bg: colors.ok,
            fg: Colors.black,
            icon: Icons.check_circle_rounded,
            text: l10n.qiblaFacing,
          );
        } else if (!hasHeading || t == null || locating) {
          child = card(
            key: const ValueKey('qibla-state-waiting'),
            bg: theme.colorScheme.surfaceContainerHigh,
            fg: theme.colorScheme.onSurface,
            icon: Icons.explore_rounded,
            text: locating ? l10n.qiblaLocating : l10n.qiblaWaitingSensor,
            spinner: true,
          );
        } else {
          final right = t >= 0;
          child = card(
            key: ValueKey('qibla-state-turn-${right ? 'right' : 'left'}'),
            bg: theme.colorScheme.primaryContainer,
            fg: theme.colorScheme.onPrimaryContainer,
            icon: right
                ? Icons.rotate_right_rounded
                : Icons.rotate_left_rounded,
            text: right
                ? l10n.qiblaTurnRight('$t')
                : l10n.qiblaTurnLeft('${-t}'),
            sub: l10n.qiblaHint,
          );
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: child,
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    super.key,
    required this.label,
    required this.value,
    this.dot,
  });

  final String label;
  final String value;
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: onColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: theme.textTheme.bodySmall?.copyWith(color: onColor),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
