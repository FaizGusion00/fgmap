import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/theme/motion.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/weather_codes.dart';
import '../domain/weather_snapshot.dart';
import 'weather_animated_icon.dart';
import 'weather_controller.dart';
import 'weather_icon_painter.dart' show isDaytime;

/// Jalur cuaca destinasi (+ lokasi semasa) pada lembaran pratonton laluan.
class WeatherStrip extends ConsumerWidget {
  const WeatherStrip({super.key, this.destinationHint});

  /// Nama destinasi untuk tajuk (jika snapshot belum ada label).
  final String? destinationHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weatherControllerProvider);
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.normal),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      child: switch (state) {
        WeatherUiIdle() => const SizedBox.shrink(key: ValueKey('wx-idle')),
        WeatherUiLoading() => const _WeatherLoading(key: ValueKey('wx-load')),
        WeatherUiUnavailable() => const _WeatherEmpty(
          key: ValueKey('wx-empty'),
        ),
        WeatherUiReady(:final weather) => _WeatherReady(
          key: ValueKey('wx-${weather.fetchedAt.millisecondsSinceEpoch}'),
          weather: weather,
          destinationHint: destinationHint,
        ),
      },
    );
  }
}

class _WeatherLoading extends StatelessWidget {
  const _WeatherLoading({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.weatherTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        const SkeletonBox(height: 88, radius: 16),
      ],
    );
  }
}

class _WeatherEmpty extends StatelessWidget {
  const _WeatherEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.weatherUnavailable,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherReady extends StatelessWidget {
  const _WeatherReady({super.key, required this.weather, this.destinationHint});

  final WeatherSnapshot weather;
  final String? destinationHint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final malay = Localizations.localeOf(context).languageCode == 'ms';
    final dest = weather.destination;
    final (top, bottom) = WeatherCodes.atmosphere(
      dest.weatherCode,
      theme.brightness,
    );
    final label = WeatherCodes.label(dest.weatherCode, malay: malay);
    final place =
        weather.destinationLabel ??
        destinationHint ??
        l10n.weatherAtDestination;
    final wide = MediaQuery.sizeOf(context).width >= 520;

    return Column(
      key: const ValueKey('weather-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(l10n.weatherTitle, style: theme.textTheme.titleSmall),
            const Spacer(),
            if (weather.fromCache || weather.isStale)
              Text(
                l10n.weatherCached,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
              border: Border.all(
                color: context.fg.glassBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                easy ? 16 : 14,
                easy ? 14 : 12,
                easy ? 16 : 14,
                easy ? 14 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (wide && weather.origin != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PlaceBlock(
                            title: l10n.weatherHere,
                            point: weather.origin!,
                            malay: malay,
                            easy: easy,
                            emphasize: false,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: easy ? 72 : 64,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.12,
                          ),
                        ),
                        Expanded(
                          child: _PlaceBlock(
                            title: place,
                            point: dest,
                            malay: malay,
                            easy: easy,
                            emphasize: true,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    if (weather.origin != null) ...[
                      _PlaceBlock(
                        title: l10n.weatherHere,
                        point: weather.origin!,
                        malay: malay,
                        easy: easy,
                        emphasize: false,
                        compact: true,
                      ),
                      const SizedBox(height: 10),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    _PlaceBlock(
                      title: place,
                      point: dest,
                      malay: malay,
                      easy: easy,
                      emphasize: true,
                      subtitle: label,
                    ),
                  ],
                  if (!easy && weather.hours.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: weather.hours.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final h = weather.hours[i];
                          return _HourChip(hour: h);
                        },
                      ),
                    ),
                  ],
                  if (weather.rainAlongRoute) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.umbrella_rounded,
                          size: 16,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.75,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            l10n.weatherRainAlong,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (weather.severe) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.weatherSevere,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    l10n.weatherAttribution,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlaceBlock extends StatelessWidget {
  const _PlaceBlock({
    required this.title,
    required this.point,
    required this.malay,
    required this.easy,
    required this.emphasize,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final WeatherPoint point;
  final bool malay;
  final bool easy;
  final bool emphasize;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label =
        subtitle ?? WeatherCodes.label(point.weatherCode, malay: malay);
    final iconSize = easy ? 56.0 : (emphasize ? 48.0 : 38.0);
    final tempStyle =
        (emphasize ? theme.textTheme.headlineSmall : theme.textTheme.titleLarge)
            ?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.05,
              fontSize: easy && emphasize ? 32 : null,
            );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeatherAnimatedIcon(weatherCode: point.weatherCode, size: iconSize),
        SizedBox(width: easy ? 12 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${point.tempC.round()}°', style: tempStyle),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    Text(
                      '${point.precipProb}%',
                      style: theme.textTheme.labelSmall,
                    ),
                    if (point.feelsLikeC != null)
                      Text(
                        '${AppLocalizations.of(context).weatherFeelsLike} ${point.feelsLikeC!.round()}°',
                        style: theme.textTheme.labelSmall,
                      ),
                    if (point.windKmh != null)
                      Text(
                        '${point.windKmh!.round()} km/j',
                        style: theme.textTheme.labelSmall,
                      ),
                    if (point.humidityPct != null)
                      Text(
                        '${point.humidityPct}%',
                        style: theme.textTheme.labelSmall,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({required this.hour});

  final WeatherHour hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.Hm().format(hour.time.toLocal());
    return Container(
      width: 56,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(time, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          WeatherAnimatedIcon(
            weatherCode: hour.weatherCode,
            size: 30,
            isDay: isDaytime(hour.time.toLocal()),
          ),
          Text(
            '${hour.tempC.round()}°',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${hour.precipProb}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
