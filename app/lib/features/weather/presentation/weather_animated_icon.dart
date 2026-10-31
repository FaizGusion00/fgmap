import 'package:flutter/material.dart';

import 'weather_icon_painter.dart';

/// Ikon cuaca berwarna dengan gerakan: matahari bersinar dan berputar, bulan dan bintang berkelip,
/// awan hanyut, hujan dan salji jatuh, kilat berkelip, kabus bergerak. Dilukis sendiri
/// ([WeatherIconPainter]) supaya konsisten pada semua peranti, bukan glif Material satu warna.
/// Hormati Reduce Motion: ikon kekal statik (tetapi masih berwarna).
class WeatherAnimatedIcon extends StatefulWidget {
  const WeatherAnimatedIcon({
    super.key,
    required this.weatherCode,
    this.size = 40,
    this.isDay,
  });

  final int weatherCode;
  final double size;

  /// Siang atau malam (matahari atau bulan). Null = ikut waktu setempat sekarang.
  final bool? isDay;

  @override
  State<WeatherAnimatedIcon> createState() => _WeatherAnimatedIconState();
}

class _WeatherAnimatedIconState extends State<WeatherAnimatedIcon>
    with SingleTickerProviderStateMixin {
  // Gandaan 1/8 saat dalam painter: gelung 8 saat tidak tersentak.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// Bingkai tetap untuk Reduce Motion: sinar, titisan dan awan berada pada kedudukan yang menarik.
  static const _stillProgress = 0.3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = _stillProgress;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDay = widget.isDay ?? isDaytime(DateTime.now());
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: WeatherIconPainter(
            glyph: weatherGlyphFor(widget.weatherCode),
            isDay: isDay,
            progress: _c,
          ),
        ),
      ),
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
            const WeatherAnimatedIcon(weatherCode: 95, size: 28),
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
