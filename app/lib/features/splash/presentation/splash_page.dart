import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../map/data/map_style_loader.dart';
import '../data/splash_controller.dart';
import 'splash_painter.dart';

/// Splash animasi selepas splash asli (yang berwarna sama): laluan dilukis dari titik mula ke
/// destinasi, penanda mendarat, nama app muncul. ~1.9 s; ketuk untuk langkau. Dengan Reduce Motion,
/// logo statik sebentar sahaja. Semasa itu gaya peta dimuat dahulu supaya peta pertama tidak menunggu.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// Panjang animasi dan masa tahan selepas siap.
  static const animation = Duration(milliseconds: 1700);
  static const hold = Duration(milliseconds: 250);
  static const reducedMotionHold = Duration(milliseconds: 600);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SplashPage.animation,
  );
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
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _holdTimer = Timer(SplashPage.reducedMotionHold, _finish);
    } else {
      _controller.forward().whenComplete(() {
        if (mounted && !_finished) {
          _holdTimer = Timer(SplashPage.hold, _finish);
        }
      });
    }
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    ref.read(splashDoneProvider.notifier).complete();
  }

  void _skip() {
    if (_finished) return;
    _controller.value = 1;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(milliseconds: 120), _finish);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
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
                  animation: _controller,
                  builder: (context, _) {
                    final tl = SplashTimeline(_controller.value);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: SplashPainter(timeline: tl, artRect: art),
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
                                style: theme.textTheme.displaySmall?.copyWith(
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
