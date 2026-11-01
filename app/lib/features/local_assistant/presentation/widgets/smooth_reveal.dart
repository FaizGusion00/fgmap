import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Mendedahkan [text] aksara demi aksara pada kadar yang licin (satu langkah setiap bingkai),
/// bukan perkataan demi perkataan yang tersentak-sentak.
///
/// Dua mod:
///  - teks tetap (jawapan yang sudah siap): dedah dari [initialChars] hingga habis, dan ketik untuk
///    langkau. [maxDuration] menghadkan masa jawapan panjang supaya tidak membosankan.
///  - [live]: teks sedang bertambah (token dialirkan dalam suapan yang tidak sekata). Dedah dengan
///    kelajuan sekata dan mengejar tunggakan dengan lembut (~200 ms), jadi suapan token yang
///    datang berkelompok tampak mengalir.
///
/// [onProgress] dipanggil setiap kali ada aksara baharu (untuk mengikut hujung senarai), [onShown]
/// melaporkan bilangan aksara yang kelihatan, dan [onDone] sekali apabila teks tetap habis.
class SmoothReveal extends StatefulWidget {
  const SmoothReveal({
    super.key,
    required this.text,
    required this.builder,
    this.charsPerSecond = 90,
    this.maxDuration = const Duration(milliseconds: 2600),
    this.live = false,
    this.initialChars = 0,
    this.onProgress,
    this.onShown,
    this.onDone,
  });

  final String text;
  final Widget Function(BuildContext context, String visible, bool done)
  builder;
  final double charsPerSecond;
  final Duration maxDuration;
  final bool live;
  final int initialChars;
  final VoidCallback? onProgress;
  final ValueChanged<int>? onShown;
  final VoidCallback? onDone;

  /// Bahagian [visible] yang selamat dipaparkan: tidak memotong pasangan surrogat (emoji) dan
  /// menahan penanda separuh taip (`**`, `[2`) supaya tidak berkelip sebagai tanda baca mentah.
  static String visiblePrefix(String text, int chars) {
    final len = text.length;
    var n = chars.clamp(0, len);
    if (n >= len) return text;
    if (n > 0 && _isHighSurrogate(text.codeUnitAt(n - 1))) n++;
    return text.substring(0, n).replaceFirst(_halfTyped, '');
  }

  static final _halfTyped = RegExp(r'(\*+|\[\d{0,2})$');

  static bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;

  @override
  State<SmoothReveal> createState() => _SmoothRevealState();
}

class _SmoothRevealState extends State<SmoothReveal>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  late double _shown = widget.initialChars
      .clamp(0, widget.text.length)
      .toDouble();
  Duration _last = Duration.zero;
  bool _doneFired = false;
  bool? _reduce;

  int get _len => widget.text.length;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce == _reduce) return;
    _reduce = reduce;
    if (reduce) {
      _shown = _len.toDouble();
      _ticker.stop();
      _fireDone();
    } else {
      _run();
    }
  }

  @override
  void didUpdateWidget(SmoothReveal old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    // Teks diganti (bukan sekadar bertambah): kekalkan hanya bahagian yang sama.
    final keep = _commonPrefix(old.text, widget.text);
    if (_shown > keep) _shown = keep.toDouble();
    if (_reduce ?? false) {
      _shown = _len.toDouble();
    } else {
      _run();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  static int _commonPrefix(String a, String b) {
    final max = math.min(a.length, b.length);
    var i = 0;
    while (i < max && a.codeUnitAt(i) == b.codeUnitAt(i)) {
      i++;
    }
    return i;
  }

  void _run() {
    if (_shown >= _len && !widget.live) {
      _fireDone();
      return;
    }
    if (_shown >= _len || _ticker.isActive) return;
    _last = Duration.zero;
    unawaited(_ticker.start());
  }

  void _fireDone() {
    if (widget.live || _doneFired) return;
    _doneFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onDone?.call();
        widget.onProgress?.call();
      }
    });
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final backlog = _len - _shown;
    var rate = widget.charsPerSecond;
    if (!widget.live && widget.maxDuration > Duration.zero) {
      rate = math.max(rate, _len / (widget.maxDuration.inMilliseconds / 1000));
    }
    if (widget.live) rate = math.max(rate, backlog * 5);
    final next = math.min(_len.toDouble(), _shown + rate * dt);
    final changed = next.floor() != _shown.floor();
    _shown = next;
    if (_shown >= _len) _ticker.stop();
    if (changed) {
      setState(() {});
      widget.onShown?.call(_shown.floor());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onProgress?.call();
      });
    }
    if (_shown >= _len) _fireDone();
  }

  void _skip() {
    if (_shown >= _len) return;
    setState(() => _shown = _len.toDouble());
    _ticker.stop();
    widget.onShown?.call(_len);
    _fireDone();
  }

  @override
  Widget build(BuildContext context) {
    final done = !widget.live && _shown >= _len;
    final visible = SmoothReveal.visiblePrefix(widget.text, _shown.floor());
    final child = widget.builder(context, visible, done);
    if (widget.live) return child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: done ? null : _skip,
      child: child,
    );
  }
}
