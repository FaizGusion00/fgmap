import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../domain/air_quality.dart';
import 'air_quality_controller.dart';

Future<void> showAirQualitySheet(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final current = container.read(airQualityControllerProvider);
  if (current is AirUiIdle) {
    unawaited(container.read(airQualityControllerProvider.notifier).loadHere());
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const SheetBottomInset(child: AirQualitySheet()),
  );
}

class AirQualitySheet extends ConsumerStatefulWidget {
  const AirQualitySheet({super.key});

  @override
  ConsumerState<AirQualitySheet> createState() => _AirQualitySheetState();
}

class _AirQualitySheetState extends ConsumerState<AirQualitySheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Place> _hits = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    _debounce?.cancel();
    final q = text.trim();
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final places = await ref.read(geocoderProvider).search(q);
        if (!mounted || _query.text.trim() != q) return;
        setState(() {
          _hits = places.take(6).toList();
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _hits = const [];
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(airQualityControllerProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          Text(
            l10n.airQualityTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.airQualityDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.normal),
            child: switch (state) {
              AirUiIdle() ||
              AirUiLoading() => const _AirLoading(key: ValueKey('aq-load')),
              AirUiUnavailable() => _AirEmpty(
                key: const ValueKey('aq-empty'),
                onRetry: () => unawaited(
                  ref.read(airQualityControllerProvider.notifier).loadHere(),
                ),
              ),
              AirUiReady(:final reading) => _AirHero(
                key: ValueKey('aq-${reading.usAqi}-${reading.placeLabel}'),
                reading: reading,
                onHere: () => unawaited(
                  ref.read(airQualityControllerProvider.notifier).loadHere(),
                ),
              ),
            },
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _query,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.airQualitySearchHint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_query.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _query.clear();
                              _onQuery('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          )),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (_hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final p in _hits)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(p.name),
                subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
                onTap: () {
                  _query.text = p.name;
                  setState(() => _hits = const []);
                  FocusScope.of(context).unfocus();
                  unawaited(
                    ref
                        .read(airQualityControllerProvider.notifier)
                        .loadAt(p.point, label: p.name),
                  );
                },
              ),
          ],
          const SizedBox(height: 12),
          Text(
            l10n.airQualityAttribution,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AirLoading extends StatelessWidget {
  const _AirLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 180,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _AirEmpty extends StatelessWidget {
  const _AirEmpty({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 36),
          const SizedBox(height: 8),
          Text(l10n.airQualityUnavailable, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(l10n.airQualityHere)),
        ],
      ),
    );
  }
}

class _AirHero extends StatelessWidget {
  const _AirHero({super.key, required this.reading, required this.onHere});

  final AirReading reading;
  final VoidCallback onHere;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (bg, fg) = _palette(reading.band);
    final label = _bandLabel(l10n, reading.band);
    final place = reading.here
        ? l10n.airQualityHere
        : (reading.placeLabel ?? l10n.airQualityTitle);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.emphasized),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Color.lerp(bg, Colors.black, 0.28)!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (reading.fromCache)
                    Text(
                      l10n.airQualityCached,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: fg.withValues(alpha: 0.8),
                      ),
                    ),
                  IconButton(
                    tooltip: l10n.airQualityHere,
                    onPressed: onHere,
                    icon: Icon(Icons.my_location_rounded, color: fg),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _Gauge(aqi: reading.usAqi, progress: reading.gauge, color: fg),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (reading.pm25 != null) _Chip('PM2.5', reading.pm25!, fg),
                  if (reading.pm10 != null) _Chip('PM10', reading.pm10!, fg),
                  if (reading.no2 != null) _Chip('NO₂', reading.no2!, fg),
                  if (reading.ozone != null) _Chip('O₃', reading.ozone!, fg),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.name, this.value, this.fg);

  final String name;
  final double value;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    final text = value >= 10
        ? value.round().toString()
        : value.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$name  $text',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.aqi,
    required this.progress,
    required this.color,
  });

  final int aqi;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: Motion.of(context, Motion.emphasized),
        curve: Motion.enter,
        builder: (context, t, _) => CustomPaint(
          painter: _ArcPainter(progress: t, color: color),
          child: Center(
            child: Text(
              '$aqi',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.22);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color;
    final inset = rect.deflate(8);
    canvas.drawArc(inset, -math.pi * 0.75, math.pi * 1.5, false, stroke);
    canvas.drawArc(
      inset,
      -math.pi * 0.75,
      math.pi * 1.5 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}

(Color, Color) _palette(AirBand band) => switch (band) {
  AirBand.good => (const Color(0xFF1B7F4E), Colors.white),
  AirBand.moderate => (const Color(0xFFC9A227), const Color(0xFF1C1400)),
  AirBand.sensitive => (const Color(0xFFE07A1F), Colors.white),
  AirBand.unhealthy => (const Color(0xFFC62828), Colors.white),
  AirBand.veryUnhealthy => (const Color(0xFF6A1B9A), Colors.white),
  AirBand.hazardous => (const Color(0xFF4A1014), Colors.white),
};

String _bandLabel(AppLocalizations l10n, AirBand band) => switch (band) {
  AirBand.good => l10n.airBandGood,
  AirBand.moderate => l10n.airBandModerate,
  AirBand.sensitive => l10n.airBandSensitive,
  AirBand.unhealthy => l10n.airBandUnhealthy,
  AirBand.veryUnhealthy => l10n.airBandVeryUnhealthy,
  AirBand.hazardous => l10n.airBandHazardous,
};
