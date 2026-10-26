import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Pita "Memulakan navigasi ke {nama} dalam 3… [Batal]". Kiraan mundur [seconds] saat; panggil
/// [onDone] sekali apabila sampai sifar, atau [onCancel] jika pengguna menekan Batal. Pemasa
/// dihentikan apabila widget dibuang (cth. laluan berubah), jadi tiada permulaan tersembunyi.
class AutoStartBanner extends StatefulWidget {
  const AutoStartBanner({
    super.key,
    required this.name,
    required this.onDone,
    required this.onCancel,
    this.seconds = 3,
  });

  final String name;
  final VoidCallback onDone;
  final VoidCallback onCancel;
  final int seconds;

  @override
  State<AutoStartBanner> createState() => _AutoStartBannerState();
}

class _AutoStartBannerState extends State<AutoStartBanner> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_left <= 1) {
        timer.cancel();
        setState(() => _left = 0);
        widget.onDone();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fg = context.fg;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final text = l10n.autoStartCountdown(widget.name, _left);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Material(
        key: const ValueKey('auto-start-banner'),
        color: fg.glassSurface,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: fg.glassBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    // Dibacakan sekali (bukan setiap saat) oleh pembaca skrin.
                    child: Semantics(
                      liveRegion: _left == widget.seconds,
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('auto-start-cancel'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(64, 48),
                    ),
                    onPressed: widget.onCancel,
                    child: Text(l10n.autoStartCancel),
                  ),
                ],
              ),
            ),
            if (animate)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(seconds: widget.seconds),
                builder: (_, value, _) =>
                    LinearProgressIndicator(value: value, minHeight: 3),
              )
            else
              const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}
