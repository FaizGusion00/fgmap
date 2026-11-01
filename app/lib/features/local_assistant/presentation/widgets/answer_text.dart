import 'package:flutter/material.dart';

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
    final blocks = text.trim().split(RegExp(r'\n\s*\n'));
    final children = <Widget>[];
    for (var b = 0; b < blocks.length; b++) {
      final lines = blocks[b].split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final isLast = b == blocks.length - 1 && i == lines.length - 1;
        final bullet = RegExp(r'^\s*(?:[-*•])\s+').firstMatch(line);
        final numbered = RegExp(r'^\s*(\d+)[.)]\s+').firstMatch(line);
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

  static List<InlineSpan> _inline(String s, TextStyle? base, Color cite) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)(?:\*\*|$)|\[(\d{1,2})\]');
    var last = 0;
    for (final m in re.allMatches(s)) {
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

/// Kursor berkelip di hujung teks yang sedang ditaip.
class BlinkingCaret extends StatefulWidget {
  const BlinkingCaret({super.key, required this.color});

  final Color color;

  @override
  State<BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<BlinkingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
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
    final bar = Container(
      width: 8,
      height: 16,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return bar;
    return FadeTransition(
      opacity: CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      child: bar,
    );
  }
}

/// Animasi menaip perkataan demi perkataan untuk jawapan yang tiba sekaligus. Ketik untuk langkau.
class TypewriterAnswer extends StatefulWidget {
  const TypewriterAnswer({
    super.key,
    required this.text,
    required this.builder,
    this.wordDelay = const Duration(milliseconds: 22),
    this.onDone,
  });

  final String text;
  final Widget Function(BuildContext context, String visible, bool done)
  builder;
  final Duration wordDelay;
  final VoidCallback? onDone;

  @override
  State<TypewriterAnswer> createState() => _TypewriterAnswerState();
}

class _TypewriterAnswerState extends State<TypewriterAnswer>
    with SingleTickerProviderStateMixin {
  late final List<int> _wordEnds = [
    for (final m in RegExp(r'\S+\s*').allMatches(widget.text)) m.end,
  ];
  late final AnimationController _c;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    final words = _wordEnds.length;
    // Jawapan panjang dihadkan ~2.2 s supaya tidak membosankan.
    final total = Duration(
      milliseconds: (widget.wordDelay.inMilliseconds * words).clamp(0, 2200),
    );
    _c = AnimationController(vsync: this, duration: total)
      ..addListener(() {
        final n = (_c.value * words).ceil();
        if (n != _shown) setState(() => _shown = n);
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone?.call();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context) || words == 0) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _c.isCompleted || _shown >= _wordEnds.length;
    final visible = done || _shown == 0
        ? (done ? widget.text : '')
        : widget.text.substring(0, _wordEnds[_shown - 1]);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: done ? null : () => _c.value = 1,
      child: widget.builder(context, visible, done),
    );
  }
}
