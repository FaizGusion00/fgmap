import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/widgets/press_scale.dart';

/// Pil carian terapung di skrin utama: ikon carian bergelombang di kiri, teks "Ke mana?" dan butang
/// bulat bergradien di kanan. Mengetuknya membuka perancang perjalanan; [hint] (cara tekan-lama)
/// dipaparkan sebagai petunjuk semantik sehingga pengguna mencuba.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.label,
    required this.onTap,
    this.hint,
  });

  final String label;
  final String? hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final badge = easy ? 44.0 : 36.0;
    final radius = BorderRadius.circular(28);
    return Semantics(
      button: true,
      label: label,
      hint: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: PressScale(
        scale: 0.985,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          child: ClipRRect(
            borderRadius: radius,
            // Tanpa BackdropFilter: kabur di atas pandangan peta asli dirender semula setiap kali peta
            // bergerak dan menjejaskan telefon lemah; permukaan kaca sudah separa lutsinar.
            child: Material(
              color: fg.glassSurface,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: BorderSide(color: fg.glassBorder),
              ),
              child: InkWell(
                key: const ValueKey('search-pill'),
                customBorder: RoundedRectangleBorder(borderRadius: radius),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: easy ? 64 : 52),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                    child: Row(
                      children: [
                        SearchWaveIcon(size: badge),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (easy
                                        ? theme.textTheme.titleLarge
                                        : theme.textTheme.titleMedium)
                                    ?.copyWith(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GoCircle(size: badge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lencana carian bergradien dengan gelombang sonar halus yang merebak keluar. Gelombang main
/// seketika kemudian berehat (bukan gelung tanpa henti), jadi ia menarik perhatian tanpa
/// mengganggu, tidak memaksa peta dirender semula sepanjang masa, dan berhenti terus bila
/// Reduce Motion dihidupkan.
class SearchWaveIcon extends StatefulWidget {
  const SearchWaveIcon({
    super.key,
    this.size = 36,
    this.burst = const Duration(milliseconds: 2400),
    this.rest = const Duration(milliseconds: 2800),
    this.firstDelay = const Duration(milliseconds: 900),
  });

  final double size;

  /// Tempoh satu pancaran gelombang.
  final Duration burst;

  /// Jeda sebelum pancaran seterusnya.
  final Duration rest;

  /// Jeda sebelum pancaran pertama selepas dipaparkan.
  final Duration firstDelay;

  @override
  State<SearchWaveIcon> createState() => _SearchWaveIconState();
}

class _SearchWaveIconState extends State<SearchWaveIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.burst,
  );
  Timer? _timer;
  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduce) return;
    _reduce = reduce;
    _timer?.cancel();
    if (reduce) {
      _c.value = 0;
    } else {
      _schedule(widget.firstDelay);
    }
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, () {
      if (!mounted || _reduce != false) return;
      unawaited(
        _c.forward(from: 0).whenComplete(() {
          if (mounted && _reduce == false) _schedule(widget.rest);
        }),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final size = widget.size;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: SearchWavePainter(progress: _c, color: primary),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(primary, Colors.white, 0.22)!, primary],
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.30),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.search_rounded,
              size: size * 0.56,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dua gelombang bulat, berperingkat, yang merebak dari tepi lencana dan pudar. Dilukis di
/// BAWAH lencana (foregroundPainter tidak digunakan) supaya gelombang tampak keluar dari belakangnya.
class SearchWavePainter extends CustomPainter {
  SearchWavePainter({required this.progress, required this.color})
    : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// Berapa jauh gelombang merebak melepasi tepi lencana, sebagai nisbah garis pusat.
  static const reach = 0.42;

  /// Mulanya gelombang kedua (nisbah daripada tempoh pancaran).
  static const stagger = 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2;
    for (var i = 0; i < 2; i++) {
      final p = ((t - i * stagger) / (1 - stagger)).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final r =
          base + size.shortestSide * reach * Curves.easeOutCubic.transform(p);
      final fade = Curves.easeIn.transform(1 - p);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color.withValues(alpha: 0.34 * fade),
      );
      canvas.drawCircle(
        center,
        r,
        Paint()..color = color.withValues(alpha: 0.07 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(SearchWavePainter old) =>
      old.color != color || old.progress != progress;
}

/// Butang "terus" di hujung kanan pil: bulatan bergradien dengan anak panah putih, seiras dengan
/// lencana carian di kiri supaya pil kelihatan sepasang.
class GoCircle extends StatelessWidget {
  const GoCircle({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      key: const ValueKey('search-go'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(primary, Colors.white, 0.22)!, primary],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: size * 0.56,
        color: Colors.white,
      ),
    );
  }
}
