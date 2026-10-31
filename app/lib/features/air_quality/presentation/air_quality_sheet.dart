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
              AirUiReady(:final reading) => Column(
                key: ValueKey('aq-${reading.ipu}-${reading.stationName}'),
                children: [
                  _AirHero(
                    reading: reading,
                    onHere: () => unawaited(
                      ref
                          .read(airQualityControllerProvider.notifier)
                          .loadHere(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _OfficialScale(band: reading.band),
                ],
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
  const _AirHero({required this.reading, required this.onHere});

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
    final pollutant = _pollutantLabel(l10n, reading.pollutant);
    final observed = reading.observedAt;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, Motion.emphasized),
      curve: Motion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg, Color.lerp(bg, Colors.black, 0.35)!],
          ),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 10, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      place,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (reading.fromCache)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: fg.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.airQualityCached,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: l10n.airQualityHere,
                    onPressed: onHere,
                    icon: Icon(Icons.my_location_rounded, color: fg),
                  ),
                ],
              ),
              _Gauge(ipu: reading.ipu, progress: reading.gauge, color: fg),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (pollutant != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    l10n.airQualityDominant(pollutant),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                l10n.airQualityStation(
                  reading.stationName,
                  _stationDistance(reading.stationDistanceM),
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg.withValues(alpha: 0.94),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (observed != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.airQualityObserved(_clock(observed)),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _stationDistance(double meters) {
    if (meters < 995) return '${((meters / 10).round() * 10)} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  static String _clock(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Gauge extends StatefulWidget {
  const _Gauge({
    required this.ipu,
    required this.progress,
    required this.color,
  });

  final int ipu;
  final double progress;
  final Color color;

  @override
  State<_Gauge> createState() => _GaugeState();
}

class _GaugeState extends State<_Gauge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 196,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: widget.progress),
        duration: Motion.of(context, const Duration(milliseconds: 900)),
        curve: Motion.enter,
        builder: (context, t, _) {
          final shown =
              (widget.ipu * (widget.progress == 0 ? 0 : t / widget.progress))
                  .round()
                  .clamp(0, widget.ipu);
          return AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => CustomPaint(
              painter: _ArcPainter(
                progress: t,
                knob: widget.color,
                glow: _pulse.value,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$shown',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: widget.color,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      'IPU',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: widget.color.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.progress, required this.knob, required this.glow});

  final double progress;
  final Color knob;
  final double glow;

  static const _start = -math.pi * 0.75;
  static const _sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = (Offset.zero & size).deflate(16);
    // Lengkok = 0–300. Berbahaya (>300) duduk di hujung; jalur itu ada pada senarai skala.
    const segments = <(AirBand, double)>[
      (AirBand.good, 50 / 300),
      (AirBand.moderate, 50 / 300),
      (AirBand.unhealthy, 100 / 300),
      (AirBand.veryUnhealthy, 100 / 300),
    ];
    const gap = 0.012;
    var cursor = 0.0;
    for (final (band, span) in segments) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.butt
        ..color = _swatch(band);
      canvas.drawArc(
        inset,
        _start + _sweep * (cursor + gap / 2),
        _sweep * (span - gap),
        false,
        paint,
      );
      cursor += span;
    }
    final angle = _start + _sweep * progress.clamp(0.0, 1.0);
    final c = inset.center;
    final r = inset.width / 2;
    final dot = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
    canvas.drawCircle(
      dot,
      8 + 3 * glow,
      Paint()..color = knob.withValues(alpha: 0.28),
    );
    canvas.drawCircle(dot, 7, Paint()..color = Colors.white);
    canvas.drawCircle(dot, 4, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.knob != knob || old.glow != glow;
}

class _OfficialScale extends StatelessWidget {
  const _OfficialScale({required this.band});

  final AirBand band;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.airQualityScale,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        for (final item in AirBand.values)
          _ScaleRow(
            selected: item == band,
            label: _bandLabel(l10n, item),
            range: _rangeLabel(item),
            advice: _advice(l10n, item),
            color: _swatch(item),
          ),
      ],
    );
  }

  static String _rangeLabel(AirBand band) {
    final (min, max) = airBandRange(band);
    return max == null ? '$min+' : '$min–$max';
  }
}

class _ScaleRow extends StatelessWidget {
  const _ScaleRow({
    required this.selected,
    required this.label,
    required this.range,
    required this.advice,
    required this.color,
  });

  final bool selected;
  final String label;
  final String range;
  final String advice;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: Motion.of(context, Motion.normal),
      curve: Motion.standard,
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.fromLTRB(12, 10, 12, selected ? 12 : 10),
      decoration: BoxDecoration(
        color: selected
            ? color.withValues(alpha: 0.16)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: selected ? 1.5 : 0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              Text(
                range,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.normal),
            curve: Motion.standard,
            alignment: Alignment.topCenter,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, left: 18),
                    child: Text(
                      advice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Warna kategori rasmi APIMS: biru, hijau, kuning, oren, merah.
(Color, Color) _palette(AirBand band) => switch (band) {
  AirBand.good => (const Color(0xFF1D4ED8), Colors.white),
  AirBand.moderate => (const Color(0xFF15803D), Colors.white),
  AirBand.unhealthy => (const Color(0xFFCA8A04), const Color(0xFF1C1400)),
  AirBand.veryUnhealthy => (const Color(0xFFEA580C), Colors.white),
  AirBand.hazardous => (const Color(0xFFB91C1C), Colors.white),
};

Color _swatch(AirBand band) => _palette(band).$1;

String _bandLabel(AppLocalizations l10n, AirBand band) => switch (band) {
  AirBand.good => l10n.airBandGood,
  AirBand.moderate => l10n.airBandModerate,
  AirBand.unhealthy => l10n.airBandUnhealthy,
  AirBand.veryUnhealthy => l10n.airBandVeryUnhealthy,
  AirBand.hazardous => l10n.airBandHazardous,
};

String _advice(AppLocalizations l10n, AirBand band) => switch (band) {
  AirBand.good => l10n.airAdviceGood,
  AirBand.moderate => l10n.airAdviceModerate,
  AirBand.unhealthy => l10n.airAdviceUnhealthy,
  AirBand.veryUnhealthy => l10n.airAdviceVeryUnhealthy,
  AirBand.hazardous => l10n.airAdviceHazardous,
};

String? _pollutantLabel(AppLocalizations l10n, DominantPollutant? p) =>
    switch (p) {
      DominantPollutant.pm25 => l10n.airPollutantPm25,
      DominantPollutant.pm10 => l10n.airPollutantPm10,
      DominantPollutant.so2 => l10n.airPollutantSo2,
      DominantPollutant.no2 => l10n.airPollutantNo2,
      DominantPollutant.o3 => l10n.airPollutantO3,
      DominantPollutant.co => l10n.airPollutantCo,
      DominantPollutant.several => l10n.airPollutantSeveral,
      null => null,
    };
