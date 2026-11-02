import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../map/data/map_style_loader.dart';
import '../../navigation/data/trip_store.dart';
import '../data/splash_controller.dart';
import 'splash_painter.dart';

/// Splash animasi selepas splash asli (yang berwarna sama): logo F-laluan dibina — laluan dilukis
/// dari titik mula, anak panah arah meluncur masuk, nama app muncul. ~1.9 s; ketuk untuk langkau. Dengan Reduce Motion,
/// logo siap dipudarkan masuk (tiada gerakan besar). Semasa itu gaya peta dimuat dahulu supaya peta pertama tidak menunggu.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Panjang animasi dan masa tahan selepas siap.
  static const animation = Duration(milliseconds: 1700);
  static const hold = Duration(milliseconds: 250);

  /// Perjalanan disimpan sedang dipulihkan: animasi yang sama, lebih pantas.
  static const quickAnimation = Duration(milliseconds: 1100);

  /// Reduce Motion: logo siap dipudarkan masuk, kemudian ditahan sebentar.
  static const reducedMotionReveal = Duration(milliseconds: 450);
  static const reducedMotionHold = Duration(milliseconds: 500);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Kemajuan animasi 0..1 (dibaca oleh [SplashTimeline]).
  final ValueNotifier<double> _progress = ValueNotifier(0);

  /// Kelegapan keseluruhan: 1 untuk animasi penuh; Reduce Motion memudarkan logo siap masuk.
  final ValueNotifier<double> _reveal = ValueNotifier(1);
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;
  Duration _length = SplashPage.animation;
  bool _reduced = false;
  Timer? _holdTimer;
  bool _finished = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _prefetchMapStyle();
  }

  void _prefetchMapStyle() {
    final mode = ref.read(effectiveThemeModeProvider);
    final dark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                Brightness.dark);
    // Hanya memulakan pemuatan (dan cache); keputusannya tidak ditunggu.
    ref.read(mapStyleProvider(dark));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Banyak telefon mematikan "skala animasi" dalam penjimat bateri; Flutter melaporkannya sebagai
    // Reduce Motion. Logo tidak dilukis langkah demi langkah, tetapi tetap muncul lembut (pudar).
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _progress.value = 1;
      _reveal.value = 0;
      _length = SplashPage.reducedMotionReveal;
    } else if (ref.read(tripStoreProvider).read() != null) {
      // Perjalanan disimpan: pemandu mahu kembali ke peta dengan cepat; animasi sama, lebih pantas.
      _length = SplashPage.quickAnimation;
    }
    _ticker.start();
  }

  /// Animasi dimajukan mengikut BINGKAI, bukan jam dinding: bingkai pertama app selalunya berat
  /// (memuat fon, shader, gaya peta), dan pengawal berasaskan masa melangkau terus ke hujung, jadi
  /// telefon sebenar hanya nampak logo siap (tiada animasi). Setiap bingkai dimajukan paling banyak
  /// 1/30 s, jadi setiap peringkat (titik, laluan, simpang, anak panah) sentiasa kelihatan. Had
  /// keseluruhan memastikan telefon yang sangat perlahan tidak tersangkut lama.
  void _onTick(Duration elapsed) {
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    final step = dt > _maxStep ? _maxStep : dt;
    final length = _length.inMicroseconds;
    final done = elapsed > _length * 2.2;
    final delta = step.inMicroseconds / length;
    if (_reduced) {
      _reveal.value = done ? 1 : math.min(1, _reveal.value + delta);
    } else {
      _progress.value = done ? 1 : math.min(1, _progress.value + delta);
    }
    if ((_reduced ? _reveal.value : _progress.value) >= 1) {
      _ticker.stop();
      _holdTimer = Timer(
        _reduced ? SplashPage.reducedMotionHold : SplashPage.hold,
        _finish,
      );
    }
  }

  static const _maxStep = Duration(microseconds: 33333);

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    ref.read(splashDoneProvider.notifier).complete();
  }

  void _skip() {
    if (_finished) return;
    _ticker.stop();
    _progress.value = 1;
    _reveal.value = 1;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 120), _finish);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _ticker.dispose();
    _progress.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Semantics(
        label: l10n.appName,
        button: true,
        onTap: _skip,
        child: GestureDetector(
          key: const ValueKey('splash'),
          behavior: HitTestBehavior.opaque,
          onTap: _skip,
          child: Scaffold(
            backgroundColor: SplashColors.navBottom,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final side = (size.shortestSide * 0.78).clamp(240.0, 420.0);
                // Seni sedikit di atas tengah; nama app di bawahnya.
                final art = Rect.fromCenter(
                  center: Offset(size.width / 2, size.height * 0.42),
                  width: side,
                  height: side,
                );
                return AnimatedBuilder(
                  animation: Listenable.merge([_progress, _reveal]),
                  builder: (context, _) {
                    final tl = SplashTimeline(_progress.value);
                    final reveal = Curves.easeOut.transform(_reveal.value);
                    return Opacity(
                      opacity: reveal,
                      child: Transform.scale(
                        scale: 0.94 + 0.06 * reveal,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: SplashPainter(
                                timeline: tl,
                                artRect: art,
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              top: art.bottom + 4,
                              child: Opacity(
                                opacity: tl.wordmark,
                                child: Transform.translate(
                                  offset: Offset(0, 18 * (1 - tl.wordmark)),
                                  child: Text(
                                    l10n.appName,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          color: SplashColors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              top: art.bottom + 4 + 54,
                              child: Opacity(
                                opacity: tl.tagline,
                                child: Text(
                                  l10n.splashTagline,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: SplashColors.white.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
