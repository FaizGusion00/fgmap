import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/generated/app_localizations.dart';
import 'error_log.dart';

/// Memasang pengendali ralat global supaya ralat tidak menghilang senyap dan tidak mencetak URL atau
/// koordinat ke konsol dalam release:
///  - `FlutterError.onError`: ralat rangka kerja (pelukisan, gelagat widget).
///  - `PlatformDispatcher.onError`: ralat asinkron yang tidak ditangkap. Mengembalikan `true` bermakna
///    ralat dianggap dikendalikan (app tidak ditamatkan oleh engine bagi ralat pengguna Dart biasa).
///  - `ErrorWidget.builder`: dalam release, widget yang gagal dilukis memaparkan kad ringkas yang ramah,
///    bukan skrin merah/kelabu kosong.
void installGlobalErrorHandling(ErrorLog log) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    log.record('flutter', details.exception, details.stack);
    if (kDebugMode) {
      // Dalam pembangunan kekalkan laporan penuh Flutter (dengan pembersihan di log kita sahaja).
      previous?.call(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.record('async', error, stack);
    return true;
  };
  ErrorWidget.builder = (details) {
    if (kDebugMode) return ErrorWidget(details.exception);
    return const FriendlyErrorWidget();
  };
}

/// Pengganti ramah untuk widget yang gagal dilukis dalam release.
class FriendlyErrorWidget extends StatelessWidget {
  const FriendlyErrorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                l10n?.errorWidgetMessage ??
                    'Bahagian ini tidak dapat dipaparkan.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
