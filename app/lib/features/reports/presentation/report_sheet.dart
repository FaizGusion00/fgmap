import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../domain/report.dart';
import 'reports_controller.dart';
import '../../../core/utils/haptics.dart';

/// Nama jenis laporan yang dilokalkan (untuk helaian, dialog dan umum suara).
String reportTypeLabel(AppLocalizations l10n, ReportType type) =>
    switch (type) {
      ReportType.police => l10n.reportTypePolice,
      ReportType.accident => l10n.reportTypeAccident,
      ReportType.hazard => l10n.reportTypeHazard,
      ReportType.trafficJam => l10n.reportTypeJam,
      ReportType.roadClosed => l10n.reportTypeClosed,
      ReportType.brokenDown => l10n.reportTypeBrokenDown,
      ReportType.flood => l10n.reportTypeFlood,
    };

IconData reportTypeIcon(ReportType type) => switch (type) {
  ReportType.police => Icons.local_police_rounded,
  ReportType.accident => Icons.car_crash_rounded,
  ReportType.hazard => Icons.warning_amber_rounded,
  ReportType.trafficJam => Icons.traffic_rounded,
  ReportType.roadClosed => Icons.block_rounded,
  ReportType.brokenDown => Icons.car_repair_rounded,
  ReportType.flood => Icons.water_rounded,
};

/// Membuka helaian laporan. Memulangkan keputusan penciptaan, atau null jika ditutup tanpa melapor.
Future<CreateReportResult?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<CreateReportResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const ReportSheet(),
  );
}

/// Pemilih jenis laporan: butang besar (sasaran sentuh >= 72 dp) untuk 1-2 ketukan semasa memandu
/// (Bahagian 9). Tiada medan teks. Lokasi laporan ialah GPS semasa, bukan input pengguna.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key});

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportType? _sending;

  Future<void> _send(ReportType type) async {
    if (_sending != null) return; // elak ketukan berganda
    unawaited(Haptics.medium());
    setState(() => _sending = type);
    final result = await ref
        .read(reportsControllerProvider.notifier)
        .report(type);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.reportTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final type in ReportType.values)
                _TypeButton(
                  key: ValueKey('report-${type.id}'),
                  type: type,
                  busy: _sending == type,
                  disabled: _sending != null && _sending != type,
                  onTap: () => _send(type),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.reportLocalOnlyNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    super.key,
    required this.type,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  final ReportType type;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = reportTypeLabel(l10n, type);

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      // Tinggi minimum (bukan tetap): pada teks sistem besar label dua baris perlu ruang, jika tidak ia melimpah.
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: 104,
          maxWidth: 104,
          minHeight: 92,
        ),
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: disabled ? 0.4 : 1,
          ),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: disabled || busy ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  busy
                      ? const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : Icon(
                          reportTypeIcon(type),
                          size: 30,
                          color: theme.colorScheme.onSurface,
                        ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog "Masih ada?" semasa melepasi laporan. Memulangkan true (masih ada), false (tiada) atau null (ditutup).
Future<bool?> showStillThereDialog(BuildContext context, Report report) {
  final l10n = AppLocalizations.of(context);
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(reportTypeIcon(report.type)),
      title: Text(
        l10n.reportStillThereTitle(reportTypeLabel(l10n, report.type)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.reportStillThereNo),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.reportStillThereYes),
        ),
      ],
    ),
  );
}
