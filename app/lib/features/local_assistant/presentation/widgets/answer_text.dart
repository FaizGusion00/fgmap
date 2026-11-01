import 'package:flutter/material.dart';

import 'smooth_reveal.dart';
import 'ai_motion.dart';

/// Teks jawapan dengan format ringan: perenggan, senarai "- ", **tebal**, dan penanda petikan "[2]"
/// sebagai lencana kecil. Tahan teks separuh (semasa animasi menaip): "**" tanpa penutup ditebalkan
/// hingga hujung.
class AnswerText extends StatelessWidget {
  const AnswerText(
    this.text, {
    super.key,
    this.style,
    this.citationColor,
    this.trailing,
  });

  final String text;
  final TextStyle? style;
  final Color? citationColor;

  /// Widget sebaris di hujung (cth. kursor berkelip semasa menaip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base =
        style ??
        theme.textTheme.bodyLarge?.copyWith(height: 1.5, fontSize: 15.5);
    final cite = citationColor ?? theme.colorScheme.primary;
    final blocks = text.trim().split(_blockBreak);
    final children = <Widget>[];
    for (var b = 0; b < blocks.length; b++) {
      final lines = blocks[b].split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final isLast = b == blocks.length - 1 && i == lines.length - 1;
        final bullet = _bulletRe.firstMatch(line);
        final numbered = _numberedRe.firstMatch(line);
        final content = bullet != null
            ? line.substring(bullet.end)
            : numbered != null
            ? line.substring(numbered.end)
            : line;
        final spans = _inline(content, base, cite);
        if (isLast && trailing != null) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: trailing!,
            ),
          );
        }
        final rich = Text.rich(TextSpan(children: spans), style: base);
        if (bullet != null || numbered != null) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: Text(
                      numbered != null ? '${numbered.group(1)}.' : '•',
                      style: base?.copyWith(
                        color: cite,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(child: rich),
                ],
              ),
            ),
          );
        } else {
          children.add(
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 2),
              child: rich,
            ),
          );
        }
      }
      if (b < blocks.length - 1) children.add(const SizedBox(height: 10));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static final _blockBreak = RegExp(r'\n\s*\n');
  static final _bulletRe = RegExp(r'^\s*(?:[-*•])\s+');
  static final _numberedRe = RegExp(r'^\s*(\d+)[.)]\s+');
  static final _inlineRe = RegExp(r'\*\*(.+?)(?:\*\*|$)|\[(\d{1,2})\]');

  static List<InlineSpan> _inline(String s, TextStyle? base, Color cite) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in _inlineRe.allMatches(s)) {
      if (m.start > last) spans.add(TextSpan(text: s.substring(last, m.start)));
      if (m.group(1) != null) {
        spans.add(
          TextSpan(
            text: m.group(1),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      } else {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: cite.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                m.group(2)!,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: cite,
                ),
              ),
            ),
          ),
        );
      }
      last = m.end;
    }
    if (last < s.length) spans.add(TextSpan(text: s.substring(last)));
    return spans;
  }
}

/// Kursor di hujung teks yang sedang ditaip: bar kecil bergradien yang "bernafas" (denyut lembut),
/// bukan berkelip kasar yang kelihatan tersentak ketika teks bergerak.
class TypingCaret extends StatefulWidget {
  const TypingCaret({super.key, required this.color});

  final Color color;

  @override
  State<TypingCaret> createState() => _TypingCaretState();
}

class _TypingCaretState extends State<TypingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AiMotion.reduce(context)) {
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
    final bar = Container(
      width: 3,
      height: 17,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [widget.color, widget.color.withValues(alpha: 0.55)],
        ),
        boxShadow: [
          BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
    if (AiMotion.reduce(context)) return bar;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.35,
        end: 1,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: bar,
    );
  }
}

/// Animasi menaip untuk jawapan yang tiba sekaligus: aksara demi aksara pada kadar licin (lihat
/// [SmoothReveal]). Ketik untuk langkau. [initialChars] menyambung daripada jawapan yang sudah
/// dialirkan supaya peralihan daripada paparan langsung tidak melompat.
class TypewriterAnswer extends StatelessWidget {
  const TypewriterAnswer({
    super.key,
    required this.text,
    required this.builder,
    this.charsPerSecond = 90,
    this.initialChars = 0,
    this.onProgress,
    this.onDone,
  });

  final String text;
  final Widget Function(BuildContext context, String visible, bool done)
  builder;
  final double charsPerSecond;
  final int initialChars;
  final VoidCallback? onProgress;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return SmoothReveal(
      text: text,
      charsPerSecond: charsPerSecond,
      initialChars: initialChars,
      onProgress: onProgress,
      onDone: onDone,
      builder: builder,
    );
  }
}
