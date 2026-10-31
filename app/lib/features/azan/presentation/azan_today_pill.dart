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
    final next = ref.watch(azanControllerProvider.select((s) => s.next));
    final nextAt = ref.watch(azanControllerProvider.select((s) => s.nextAt));
    final now = ref.watch(azanClockProvider)();

    final String label;
    if (next != null && nextAt != null) {
      label = l10n.azanNextIn(
        prayerName(l10n, next),
        formatClock(context, nextAt),
        remainingText(l10n, nextAt.difference(now)),
      );
    } else {
      label = l10n.azanTitle;
    }

    return Semantics(
      button: true,
      label: '${l10n.azanTitle}. $label',
      child: PressScale(
        child: Material(
          key: const ValueKey('azan-pill'),
          color: fg.glassSurface,
          elevation: 2,
          shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => showAzanSheet(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: easy ? 56 : 44),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: easy ? 18 : 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      enabled
                          ? Icons.notifications_active_rounded
                          : Icons.mosque_rounded,
                      size: easy ? 24 : 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (easy
                                    ? theme.textTheme.titleMedium
                                    : theme.textTheme.labelLarge)
                                ?.copyWith(color: theme.colorScheme.onSurface),
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
