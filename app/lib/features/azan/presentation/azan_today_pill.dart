import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/azan_settings.dart';
import 'azan_controller.dart';
import 'azan_l10n.dart';
import 'azan_sheet.dart';

/// Pil kaca di skrin utama: "Asar 16:28 · 1 j 12 min". Sentiasa kelihatan (tidak terkubur dalam
/// Tetapan); jika notifikasi mati, hanya "Waktu solat". Ketik membuka lembaran waktu.
class AzanTodayPill extends ConsumerWidget {
  const AzanTodayPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fg = context.fg;
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final enabled = ref.watch(azanSettingsProvider.select((s) => s.enabled));
    final next = ref.watch(azanControllerProvider.select((s) => s.upNext));
    final nextAt = ref.watch(azanControllerProvider.select((s) => s.upNextAt));
    final now = ref.watch(azanClockProvider)();

    final String title;
    final String? sub;
    final String full;
    if (next != null && nextAt != null) {
      title = '${prayerName(l10n, next)} ${formatClock(context, nextAt)}';
      sub = l10n.azanRemainingLeft(remainingText(l10n, nextAt.difference(now)));
      full = l10n.azanNextIn(
        prayerName(l10n, next),
        formatClock(context, nextAt),
        remainingText(l10n, nextAt.difference(now)),
      );
    } else {
      title = l10n.azanTitle;
      sub = null;
      full = l10n.azanTitle;
    }
    final primary = theme.colorScheme.primary;
    final badge = easy ? 40.0 : 28.0;

    return Semantics(
      button: true,
      label: '${l10n.azanTitle}. $full',
      child: PressScale(
        child: Material(
          key: const ValueKey('azan-pill'),
          color: fg.glassSurface,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: fg.glassBorder),
          ),
          child: InkWell(
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            onTap: () => showAzanSheet(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: easy ? 60 : 44),
              child: Padding(
                padding: EdgeInsets.fromLTRB(7, 5, easy ? 18 : 12, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lencana bulat bertinta, sama bahasa visual dengan ikon pil carian.
                    Container(
                      width: badge,
                      height: badge,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        enabled
                            ? Icons.notifications_active_rounded
                            : Icons.mosque_rounded,
                        size: easy ? 24 : 16,
                        color: primary,
                      ),
                    ),
                    SizedBox(width: easy ? 12 : 7),
                    // FittedBox: jika ruang sempit, teks mengecil (bukan dipotong) supaya waktu solat
                    // sentiasa terbaca penuh.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (easy
                                          ? theme.textTheme.titleMedium
                                          : theme.textTheme.labelLarge)
                                      ?.copyWith(
                                        color: theme.colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                        height: 1.15,
                                      ),
                            ),
                            if (sub != null)
                              Text(
                                sub,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    (easy
                                            ? theme.textTheme.bodyMedium
                                            : theme.textTheme.labelSmall)
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                          height: 1.15,
                                        ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
