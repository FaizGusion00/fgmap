import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/motion.dart';
import '../../../core/widgets/fade_through_route.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../domain/weather_codes.dart';
import '../domain/weather_forecast.dart';
import 'weather_animated_icon.dart';
import 'weather_page_controller.dart';

/// Buka halaman Cuaca penuh (lokasi semasa + tempat disimpan).
Future<void> showWeatherPage(BuildContext context) =>
    Navigator.of(context).push<void>(fadeThroughRoute(const WeatherPage()));

/// Label keadaan cuaca (kod WMO) dalam bahasa UI.
String weatherCodeLabel(AppLocalizations l10n, int code) {
  if (code == 0) return l10n.weatherCodeClear;
  if (code == 1) return l10n.weatherCodeMainlyClear;
  if (code == 2) return l10n.weatherCodePartlyCloudy;
  if (code == 3) return l10n.weatherCodeOvercast;
  if (code <= 48) return l10n.weatherCodeFog;
  if (code <= 57) return l10n.weatherCodeDrizzle;
  if (code <= 63) return l10n.weatherCodeRain;
  if (code <= 67) return l10n.weatherCodeHeavyRain;
  if (code <= 77) return l10n.weatherCodeSnow;
  if (code <= 81) return l10n.weatherCodeShowers;
  if (code == 82) return l10n.weatherCodeHeavyShowers;
  return l10n.weatherCodeThunderstorm;
}

/// Langit mengikut cuaca dan siang/malam. Sentiasa cukup gelap untuk teks putih (kontras AA).
List<Color> _sky(int code, bool isDay) {
  final storm = code >= 95 || code == 82 || code == 65 || code == 67;
  final rain = WeatherCodes.isRainy(code);
  final cloudy = code >= 2 && code <= 48;
  if (!isDay) {
    if (storm) return const [Color(0xFF111827), Color(0xFF1F2937)];
    if (rain || cloudy) return const [Color(0xFF1E293B), Color(0xFF334155)];
    return const [Color(0xFF0B1E3B), Color(0xFF1E3A5F)];
  }
  if (storm) return const [Color(0xFF2B3442), Color(0xFF4B5563)];
  if (rain) return const [Color(0xFF3D5A73), Color(0xFF64809A)];
  if (cloudy) return const [Color(0xFF4A6A8A), Color(0xFF7B97B2)];
  return const [Color(0xFF1D6FD8), Color(0xFF4FA8E8)];
}

class WeatherPage extends ConsumerStatefulWidget {
  const WeatherPage({super.key});

  @override
  ConsumerState<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends ConsumerState<WeatherPage> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final place = await showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _WeatherSearchSheet(),
    );
    if (place == null || !mounted) return;
    await ref.read(weatherPageControllerProvider.notifier).addPlace(place);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(weatherPageControllerProvider);
    final ctrl = ref.read(weatherPageControllerProvider.notifier);
    ref.listen(weatherPageControllerProvider.select((s) => s.index), (_, i) {
      if (_pages.hasClients && _pages.page?.round() != i) {
        unawaited(
          _pages.animateToPage(
            i,
            duration: Motion.of(context, Motion.normal),
            curve: Motion.standard,
          ),
        );
      }
    });

    final selected = state.selected;
    final forecast = selected == null ? null : state.forecasts[selected.id];
    final code = forecast?.current.weatherCode ?? 1;
    final isDay = forecast?.current.isDay ?? true;
    final sky = _sky(code, isDay);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: sky.first,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: state.places.length > 1
              ? _PageDots(count: state.places.length, index: state.index)
              : Text(l10n.weatherTitle),
          centerTitle: true,
          actions: [
            if (selected != null && !selected.isCurrent)
              IconButton(
                key: const ValueKey('weather-remove'),
                tooltip: l10n.weatherRemovePlace,
                onPressed: () => unawaited(ctrl.removePlace(selected.id)),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            IconButton(
              key: const ValueKey('weather-search'),
              tooltip: l10n.weatherAddPlace,
              onPressed: () => unawaited(_search()),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            _SkyBackground(colors: sky, code: code, isDay: isDay),
            if (state.places.isEmpty)
              state.locating
                  ? const _LoadingView()
                  : _MessageView(
                      icon: Icons.location_off_rounded,
                      text: l10n.weatherNoLocation,
                      action: l10n.weatherAddPlace,
                      onAction: () => unawaited(_search()),
                    )
            else
              PageView.builder(
                controller: _pages,
                itemCount: state.places.length,
                onPageChanged: ctrl.select,
                itemBuilder: (context, i) {
                  final place = state.places[i];
                  return _PlaceView(
                    key: ValueKey('weather-place-${place.id}'),
                    place: place,
                    forecast: state.forecasts[place.id],
                    loading: state.loading.contains(place.id),
                    failed: state.failed.contains(place.id),
                    onRefresh: () => ctrl.load(place, force: true),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.of(context, Motion.fast),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: i == index ? 0.95 : 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Langit beranimasi: kecerunan bertukar lembut, ditambah titisan hujan, awan atau bintang.
class _SkyBackground extends StatefulWidget {
  const _SkyBackground({
    required this.colors,
    required this.code,
    required this.isDay,
  });

  final List<Color> colors;
  final int code;
  final bool isDay;

  @override
  State<_SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<_SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
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
    return AnimatedContainer(
      duration: Motion.of(context, Motion.emphasized),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.colors,
        ),
      ),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _SkyPainter(
              t: _c.value,
              code: widget.code,
              isDay: widget.isDay,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.t, required this.code, required this.isDay});

  final double t;
  final int code;
  final bool isDay;

  static final _rand = math.Random(7);
  static final _drops = List.generate(
    70,
    (_) => (_rand.nextDouble(), _rand.nextDouble(), 0.6 + _rand.nextDouble()),
  );
  static final _stars = List.generate(
    45,
    (_) => (_rand.nextDouble(), _rand.nextDouble() * 0.55, _rand.nextDouble()),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rain = WeatherCodes.isRainy(code);
    final cloudy = code >= 2 && code <= 48;
    if (isDay && !rain && code <= 2) {
      // Cahaya matahari berdenyut perlahan di sudut atas.
      final pulse = 0.85 + 0.15 * math.sin(t * 2 * math.pi);
      final c = Offset(size.width * 0.82, size.height * 0.08);
      canvas.drawCircle(
        c,
        size.width * 0.45 * pulse,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0x66FFE8A3), Color(0x00FFE8A3)],
          ).createShader(Rect.fromCircle(center: c, radius: size.width * 0.45)),
      );
    }
    if (!isDay && !rain && !cloudy) {
      for (final (x, y, phase) in _stars) {
        final a =
            0.25 + 0.6 * (0.5 + 0.5 * math.sin((t * 6 + phase * 6) * math.pi));
        canvas.drawCircle(
          Offset(x * size.width, y * size.height),
          1.2,
          Paint()..color = Colors.white.withValues(alpha: a),
        );
      }
    }
    if (cloudy || rain) {
      final cloud = Paint()
        ..color = Colors.white.withValues(alpha: rain ? 0.06 : 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
      for (var i = 0; i < 3; i++) {
        final x = ((t + i / 3) % 1.0) * (size.width + 300) - 150;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, size.height * (0.12 + i * 0.1)),
            width: 260,
            height: 90,
          ),
          cloud,
        );
      }
    }
    if (rain) {
      final heavy = WeatherCodes.isSevere(code) || code >= 63;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      final count = heavy ? _drops.length : _drops.length ~/ 2;
      for (var i = 0; i < count; i++) {
        final (x, y, speed) = _drops[i];
        final py = ((y + t * 14 * speed) % 1.0) * size.height;
        final px = x * size.width;
        canvas.drawLine(Offset(px, py), Offset(px - 3, py + 14), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.t != t || old.code != code || old.isDay != isDay;
}

class _PlaceView extends ConsumerWidget {
  const _PlaceView({
    super.key,
    required this.place,
    required this.forecast,
    required this.loading,
    required this.failed,
    required this.onRefresh,
  });

  final WeatherPlace place;
  final WeatherForecast? forecast;
  final bool loading;
  final bool failed;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final f = forecast;
    if (f == null) {
      return failed
          ? _MessageView(
              icon: Icons.cloud_off_rounded,
              text: l10n.weatherLoadFailed,
              action: l10n.routeRetry,
              onAction: () => unawaited(onRefresh()),
            )
          : const _LoadingView();
    }
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return RefreshIndicator(
      onRefresh: onRefresh,
      edgeOffset: top,
      color: Colors.white,
      backgroundColor: Colors.black26,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 640 : double.infinity),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, top + 4, 16, 32),
            children: [
              _Header(place: place, forecast: f),
              if (failed) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.cloud_off_rounded,
                  text: l10n.weatherOfflineStale(_ago(context, f.fetchedAt)),
                ),
              ],
              if (f.severeSoonCode != null) ...[
                const SizedBox(height: 12),
                _Notice(
                  icon: Icons.thunderstorm_rounded,
                  text: l10n.weatherSevereSoon,
                  strong: true,
                ),
              ],
              const SizedBox(height: 18),
              _HourlyCard(forecast: f),
              const SizedBox(height: 12),
              _DailyCard(forecast: f),
              const SizedBox(height: 12),
              _DetailsGrid(forecast: f),
              const SizedBox(height: 16),
              Text(
                '${l10n.weatherAttribution} · ${l10n.weatherUpdated(_ago(context, f.fetchedAt))}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              if (loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _ago(BuildContext context, DateTime at) {
    final locale = AppLocalizations.of(context).localeName;
    final now = DateTime.now();
    final sameDay =
        now.year == at.year && now.month == at.month && now.day == at.day;
    return sameDay
        ? DateFormat.jm(locale).format(at)
        : DateFormat.MMMd(locale).add_jm().format(at);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.place, required this.forecast});

  final WeatherPlace place;
  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final c = forecast.current;
    final today = forecast.today;
    final name = place.isCurrent && place.name.isEmpty
        ? l10n.weatherCurrentLocation
        : place.name;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (place.isCurrent) ...[
              const Icon(Icons.near_me_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                name,
                key: const ValueKey('weather-place-name'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (place.subtitle != null && place.subtitle!.isNotEmpty)
          Text(
            place.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            WeatherAnimatedIcon(
              weatherCode: c.weatherCode,
              isDay: c.isDay,
              size: 64,
            ),
            const SizedBox(width: 8),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: c.tempC - 4, end: c.tempC),
              duration: Motion.of(context, Motion.emphasized),
              curve: Motion.enter,
              builder: (context, v, _) => Text(
                '${v.round()}°',
                key: const ValueKey('weather-temp'),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w300,
                  fontSize: 84,
                  height: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          weatherCodeLabel(l10n, c.weatherCode),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          [
            if (today != null)
              l10n.weatherHighLow(
                today.maxC.round().toString(),
                today.minC.round().toString(),
              ),
            if (c.feelsLikeC != null)
              l10n.weatherFeelsLikeValue(c.feelsLikeC!.round().toString()),
          ].join('  ·  '),
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      color: strong ? const Color(0x55B45309) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kad kaca separa lutsinar di atas langit.
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white70),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

IconData _iconFor(int code, bool isDay) {
  if (!isDay && code <= 1) return Icons.nightlight_round;
  if (!isDay && code == 2) return Icons.nights_stay_rounded;
  return WeatherCodes.icon(code);
}

class _HourlyCard extends StatelessWidget {
  const _HourlyCard({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = forecast.current.time;
    final hours = [
      for (final h in forecast.hours)
        if (now == null ||
            !h.time.isBefore(DateTime(now.year, now.month, now.day, now.hour)))
          h,
    ].take(24).toList();
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(Icons.schedule_rounded, l10n.weatherHourly),
          const SizedBox(height: 10),
          SizedBox(
            height: 104,
            child: ListView.separated(
              key: const ValueKey('weather-hourly'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 14),
              itemCount: hours.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final h = hours[i];
                final label = i == 0
                    ? l10n.weatherNow
                    : DateFormat.j(l10n.localeName).format(h.time);
                return SizedBox(
                  width: 54,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: i == 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      Icon(
                        _iconFor(h.weatherCode, h.isDay),
                        color: Colors.white,
                        size: 24,
                      ),
                      SizedBox(
                        height: 14,
                        child: h.precipProb >= 20
                            ? Text(
                                '${h.precipProb}%',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: const Color(0xFFBFE3FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                      Text(
                        '${h.tempC.round()}°',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final days = forecast.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final lo = days.map((d) => d.minC).reduce(math.min);
    final hi = days.map((d) => d.maxC).reduce(math.max);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    return _Glass(
      child: Column(
        key: const ValueKey('weather-daily'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(Icons.calendar_month_rounded, l10n.weatherDaily),
          const SizedBox(height: 6),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.15)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      i == 0
                          ? l10n.weatherToday
                          : DateFormat.E(l10n.localeName).format(days[i].date),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          WeatherCodes.icon(days[i].weatherCode),
                          color: Colors.white,
                          size: 22,
                        ),
                        if (days[i].precipProb >= 20)
                          Text(
                            '${days[i].precipProb}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFBFE3FF),
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${days[i].minC.round()}°',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RangeBar(
                      start: (days[i].minC - lo) / span,
                      end: (days[i].maxC - lo) / span,
                      now: i == 0 ? (forecast.current.tempC - lo) / span : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '${days[i].maxC.round()}°',
                      maxLines: 1,
                      softWrap: false,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bar julat suhu harian (sejuk → panas) relatif kepada julat 10 hari; titik = suhu sekarang.
class _RangeBar extends StatelessWidget {
  const _RangeBar({required this.start, required this.end, this.now});

  final double start;
  final double end;
  final double? now;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final s = start.clamp(0.0, 1.0) * w;
        final e = math.max(s + 6, end.clamp(0.0, 1.0) * w);
        return SizedBox(
          height: 6,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Positioned(
                left: s,
                width: e - s,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF7DD3FC),
                        Color(0xFFFDE047),
                        Color(0xFFFB923C),
                      ],
                    ),
                  ),
                ),
              ),
              if (now != null)
                Positioned(
                  left: (now!.clamp(0.0, 1.0) * w - 3).clamp(0.0, w - 6),
                  top: 0,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  const _DetailsGrid({required this.forecast});

  final WeatherForecast forecast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = forecast.current;
    final today = forecast.today;
    final nf = NumberFormat.decimalPatternDigits(
      locale: l10n.localeName,
      decimalDigits: 1,
    );
    final cardinals = l10n.weatherCardinals.split(',');
    String? dir(double? deg) => deg == null || cardinals.length != 8
        ? null
        : cardinals[((deg % 360) / 45).round() % 8];
    final uv = c.isDay ? c.uvIndex : (today?.uvMax ?? c.uvIndex);
    final tiles = <Widget>[
      if (c.feelsLikeC != null)
        _DetailTile(
          icon: Icons.thermostat_rounded,
          label: l10n.weatherFeelsLike,
          value: '${c.feelsLikeC!.round()}°',
        ),
      if (c.humidityPct != null)
        _DetailTile(
          icon: Icons.water_drop_outlined,
          label: l10n.weatherHumidity,
          value: '${c.humidityPct}%',
        ),
      if (c.windKmh != null)
        _DetailTile(
          icon: Icons.air_rounded,
          label: l10n.weatherWind,
          value: l10n.weatherSpeedKmh(c.windKmh!.round().toString()),
          sub: dir(c.windDirDeg) == null
              ? null
              : l10n.weatherFrom(dir(c.windDirDeg)!),
          trailing: c.windDirDeg == null
              ? null
              : Transform.rotate(
                  // Anak panah menunjuk ke mana angin bertiup (180° dari arah datang).
                  angle: (c.windDirDeg! + 180) * math.pi / 180,
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
        ),
      if (uv != null)
        _DetailTile(
          icon: Icons.wb_sunny_outlined,
          label: l10n.weatherUv,
          value: nf.format(uv),
          sub: _uvLabel(l10n, uv),
        ),
      if (today?.sunrise != null)
        _DetailTile(
          icon: Icons.wb_twilight_rounded,
          label: l10n.weatherSunrise,
          value: DateFormat.jm(l10n.localeName).format(today!.sunrise!),
          sub: today.sunset == null
              ? null
              : '${l10n.weatherSunset} ${DateFormat.jm(l10n.localeName).format(today.sunset!)}',
        ),
      if (today != null)
        _DetailTile(
          icon: Icons.umbrella_rounded,
          label: l10n.weatherRainToday,
          value: l10n.weatherMm(nf.format(today.precipMm)),
          sub: '${l10n.weatherRainChance} ${today.precipProb}%',
        ),
      if (c.pressureHpa != null)
        _DetailTile(
          icon: Icons.speed_rounded,
          label: l10n.weatherPressure,
          value: l10n.weatherHpa(c.pressureHpa!.round().toString()),
        ),
      if (c.visibilityM != null)
        _DetailTile(
          icon: Icons.visibility_outlined,
          label: l10n.weatherVisibility,
          value: l10n.weatherKm(nf.format(c.visibilityM! / 1000)),
        ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 560 ? 3 : 2;
        const gap = 10.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          key: const ValueKey('weather-details'),
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }

  static String _uvLabel(AppLocalizations l10n, double uv) {
    if (uv < 3) return l10n.weatherUvLow;
    if (uv < 6) return l10n.weatherUvModerate;
    if (uv < 8) return l10n.weatherUvHigh;
    if (uv < 11) return l10n.weatherUvVeryHigh;
    return l10n.weatherUvExtreme;
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sub,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Glass(
      child: SizedBox(
        height: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(icon, label),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (sub != null)
              Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, top + 24, 16, 16),
      child: const Column(
        children: [
          SkeletonBox(width: 160, height: 22),
          SizedBox(height: 18),
          SkeletonBox(width: 140, height: 84),
          SizedBox(height: 18),
          SkeletonBox(width: double.infinity, height: 130, radius: 20),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 260, radius: 20),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.text,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 48),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onAction, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// Cari bandar/tempat (Photon, bias ke lokasi semasa tidak diperlukan) untuk ditambah.
class _WeatherSearchSheet extends ConsumerStatefulWidget {
  const _WeatherSearchSheet();

  @override
  ConsumerState<_WeatherSearchSheet> createState() =>
      _WeatherSearchSheetState();
}

class _WeatherSearchSheetState extends ConsumerState<_WeatherSearchSheet> {
  final _input = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  var _loading = false;
  var _failed = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    final seq = ++_seq;
    if (query.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await ref.read(geocoderProvider).search(query);
      if (!mounted || seq != _seq) return;
      setState(() => _results = results.take(8).toList());
    } on Object {
      if (!mounted || seq != _seq) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && seq == _seq) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const ValueKey('weather-search-input'),
                controller: _input,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText: l10n.weatherSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            if (_failed)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.weatherLoadFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final p = _results[i];
                  return ListTile(
                    leading: const Icon(Icons.location_city_rounded),
                    title: Text(p.name),
                    subtitle: Text(
                      p.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
