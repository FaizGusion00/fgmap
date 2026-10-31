import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/weather_codes.dart';

/// Ikon cuaca dengan gerakan lembut (nadi / hujan / drift) — hormati Reduce Motion.
class WeatherAnimatedIcon extends StatefulWidget {
  const WeatherAnimatedIcon({
    super.key,
    required this.weatherCode,
    this.size = 40,
    this.color,
  });

  final int weatherCode;
  final double size;
  final Color? color;

  @override
  State<WeatherAnimatedIcon> createState() => _WeatherAnimatedIconState();
}

class _WeatherAnimatedIconState extends State<WeatherAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant WeatherAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherCode != widget.weatherCode) _sync();
  }

  void _sync() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0;
      return;
    }
    if (!_c.isAnimating) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final icon = WeatherCodes.icon(widget.weatherCode);
    final rainy = WeatherCodes.isRainy(widget.weatherCode);
    final clear = widget.weatherCode == 0;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        var scale = 1.0;
        var dy = 0.0;
        var angle = 0.0;
        if (clear) {
          scale = 1.0 + 0.04 * math.sin(t * math.pi * 2);
        } else if (rainy) {
          dy = 2.5 * math.sin(t * math.pi * 2);
        } else {
          angle = 0.06 * math.sin(t * math.pi * 2);
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Icon(icon, size: widget.size, color: color),
    );
  }
}

/// Banner amaran cuaca semasa navigasi — nadi lembut pada bekas.
class WeatherSevereBanner extends StatefulWidget {
  const WeatherSevereBanner({super.key, required this.message});

  final String message;

  @override
  State<WeatherSevereBanner> createState() => _WeatherSevereBannerState();
}

class _WeatherSevereBannerState extends State<WeatherSevereBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onTertiaryContainer;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final glow = 0.08 + 0.1 * _c.value;
        return Material(
          key: const ValueKey('weather-severe-banner'),
          color: theme.colorScheme.tertiaryContainer.withValues(
            alpha: 0.92 + glow * 0.08,
          ),
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            WeatherAnimatedIcon(weatherCode: 95, size: 22, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
