import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Pastikan kebenaran lokasi, dengan penjelasan SEBELUM dialog sistem (Bahagian 12.3: kebenaran
/// berperingkat dengan sebab yang jelas). Memulangkan keadaan akhir.
///
/// Dialog sistem tidak pernah dipaparkan tanpa pengguna menekan "Benarkan" pada penjelasan kita.
Future<LocationAccess> ensureLocationAccess(
  BuildContext context,
  WidgetRef ref,
) async {
  final service = ref.read(locationServiceProvider);
  final notifier = ref.read(locationAccessProvider.notifier);

  final current = await service.access();
  if (current == LocationAccess.granted) {
    await notifier.refresh();
    return current;
  }
  if (!context.mounted) return current;

  final l10n = AppLocalizations.of(context);
  switch (current) {
    case LocationAccess.granted:
      return current;
    case LocationAccess.askable:
      final allowed = await _confirm(
        context,
        title: l10n.locationRationaleTitle,
        body: l10n.locationRationaleBody,
        confirmLabel: l10n.locationAllow,
        cancelLabel: l10n.locationNotNow,
      );
      if (allowed != true) return current;
      return notifier.request();
    case LocationAccess.deniedForever:
      final open = await _confirm(
        context,
        title: l10n.locationRationaleTitle,
        body: l10n.locationDeniedForeverBody,
        confirmLabel: l10n.locationOpenSettings,
        cancelLabel: l10n.locationNotNow,
      );
      if (open == true) await service.openAppSettings();
      return current;
    case LocationAccess.serviceDisabled:
      final open = await _confirm(
        context,
        title: l10n.locationRationaleTitle,
        body: l10n.locationServiceOffBody,
        confirmLabel: l10n.locationOpenSettings,
        cancelLabel: l10n.locationNotNow,
      );
      if (open == true) await service.openLocationSettings();
      return current;
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.my_location_rounded),
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
