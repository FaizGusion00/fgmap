import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/system_settings.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/azan_settings.dart';
import 'azan_controller.dart';
import 'azan_l10n.dart';

/// Hidupkan/matikan azan dengan maklum balas yang jelas pada setiap hasil. Sebelum ini ketukan
/// pada suis tidak menunjukkan apa-apa apabila kebenaran ditolak atau penjadual gagal.
///
/// - Hidup: minta kebenaran notifikasi (dialog sistem). Ditolak/disekat -> dialog dengan butang
///   ke tetapan notifikasi app. Dibenarkan -> ambil lokasi segar dan waktu rasmi, jadualkan, dan
///   jika Android 12+ belum membenarkan penggera tepat, terangkan dan buka tetapannya.
/// - Mati: batalkan semua notifikasi terjadual.
Future<void> setAzanEnabled(
  BuildContext context,
  WidgetRef ref,
  bool on,
) async {
  final controller = ref.read(azanControllerProvider.notifier);
  if (!on) {
    await controller.disable();
    return;
  }
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final systemSettings = ref.read(systemSettingsProvider);
  // Teks notifikasi mesti ada sebelum menjadualkan; skrin peta mungkin belum dibina (onboarding).
  controller.setTexts(
    azanNotificationTexts(l10n, Localizations.localeOf(context)),
  );
  final result = await controller.enable();
  if (!context.mounted) return;
  switch (result) {
    case AzanEnableResult.permissionDenied:
      if (await _confirm(
        context,
        title: l10n.azanDeniedTitle,
        body: l10n.azanDeniedBody,
        action: l10n.azanOpenAppSettings,
        later: l10n.azanNotNow,
      )) {
        await systemSettings.openNotificationSettings();
      }
    case AzanEnableResult.needsExactAlarm:
      _snack(messenger, l10n, ref);
      if (await _confirm(
        context,
        title: l10n.azanExactDialogTitle,
        body: l10n.azanExactDialogBody,
        action: l10n.azanOpenAppSettings,
        later: l10n.azanNotNow,
      )) {
        await controller.openExactAlarmSettings();
      }
    case AzanEnableResult.enabled:
      _snack(messenger, l10n, ref);
  }
}

void _snack(
  ScaffoldMessengerState? messenger,
  AppLocalizations l10n,
  WidgetRef ref,
) {
  final azan = ref.read(azanControllerProvider);
  final settings = ref.read(azanSettingsProvider);
  messenger?.showSnackBar(
    SnackBar(
      content: Text(
        l10n.azanEnabledSnack(azanSourceText(l10n, azan, settings)),
      ),
    ),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  required String later,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('azan-dialog'),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(later),
          ),
          FilledButton(
            key: const ValueKey('azan-dialog-action'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

/// Apakah sumber waktu semasa: rasmi JAKIM (zon) atau dikira pada telefon (kaedah).
String azanSourceText(
  AppLocalizations l10n,
  AzanState azan,
  AzanSettings settings,
) => azan.isOfficial
    ? l10n.azanSourceOfficial(azan.zone!)
    : l10n.azanSourceCalculated(azanMethodName(l10n, settings.method));
