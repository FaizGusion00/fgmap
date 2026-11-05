import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/sheet_bottom_inset.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../data/map_layer.dart';
import '../data/map_style_loader.dart';

/// Lembaran "Jenis peta" (seperti butang lapisan Google Maps): Lalai atau Satelit.
Future<void> showMapLayerSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const SheetBottomInset(child: MapLayerSheet()),
    );

/// Satelit dipilih: jika percubaan lepas gagal, cuba lagi; jika masih gagal (tiada internet dan tiada
/// gaya dalam cache), beritahu pengguna bahawa peta biasa dipaparkan, bukan diam.
Future<void> _checkSatellite(BuildContext context, WidgetRef ref) async {
  // Bekas penyedia dan ScaffoldMessenger kekal selepas lembaran ini ditutup.
  final container = ProviderScope.containerOf(context, listen: false);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l10n = AppLocalizations.of(context);
  final previous = container.read(satelliteMapStyleProvider);
  if (!previous.isLoading && previous.value == null) {
    container.invalidate(satelliteMapStyleProvider);
  }
  // Langganan sementara supaya penyedia autoDispose hidup sehingga keputusan diketahui.
  final sub = container.listen(satelliteMapStyleProvider, (_, _) {});
  try {
    final style = await container.read(satelliteMapStyleProvider.future);
    if (style == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.mapLayerSatelliteFailed)),
      );
    }
  } on Object {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.mapLayerSatelliteFailed)),
    );
  } finally {
    sub.close();
  }
}

class MapLayerSheet extends ConsumerWidget {
  const MapLayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = ref.watch(mapLayerProvider);

    Widget option(MapLayer layer, String label, Widget preview) {
      final selected = current == layer;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('map-layer-${layer.name}'),
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              ref.read(mapLayerProvider.notifier).set(layer);
              if (layer == MapLayer.satellite) {
                unawaited(_checkSatellite(context, ref));
              }
              Navigator.of(context).maybePop();
            },
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: preview,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: selected ? theme.colorScheme.primary : null,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.mapLayersTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              option(
                MapLayer.standard,
                l10n.mapLayerStandard,
                const _Preview(satellite: false),
              ),
              const SizedBox(width: 8),
              option(
                MapLayer.satellite,
                l10n.mapLayerSatellite,
                const _Preview(satellite: true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.mapLayerSatelliteHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Gambar kecil jenis peta, dilukis (tiada aset atau rangkaian).
class _Preview extends StatelessWidget {
  const _Preview({required this.satellite});

  final bool satellite;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PreviewPainter(satellite), size: Size.infinite);
}

class _PreviewPainter extends CustomPainter {
  const _PreviewPainter(this.satellite);

  final bool satellite;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (satellite) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF2E4A2B),
      );
      final patches = [
        (const Color(0xFF3F5E36), Rect.fromLTWH(0, 0, w * 0.45, h * 0.55)),
        (
          const Color(0xFF6B6A5E),
          Rect.fromLTWH(w * 0.5, h * 0.1, w * 0.5, h * 0.4),
        ),
        (
          const Color(0xFF8A8577),
          Rect.fromLTWH(w * 0.55, h * 0.6, w * 0.4, h * 0.4),
        ),
        (const Color(0xFF1F3B4D), Rect.fromLTWH(0, h * 0.7, w * 0.4, h * 0.3)),
      ];
      for (final (c, r) in patches) {
        canvas.drawRect(r, Paint()..color = c);
      }
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFEFF2EC),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w * 0.4, h * 0.45),
        Paint()..color = const Color(0xFFCDE8C4),
      );
      canvas.drawRect(
        Rect.fromLTWH(0, h * 0.7, w * 0.4, h * 0.3),
        Paint()..color = const Color(0xFFAAD3EE),
      );
    }
    final road = Paint()
      ..color = satellite
          ? Colors.white.withValues(alpha: 0.6)
          : const Color(0xFFFFFFFF)
      ..strokeWidth = h * 0.09
      ..strokeCap = StrokeCap.round;
    final major = Paint()
      ..color = satellite
          ? const Color(0xFFFFE08A).withValues(alpha: 0.7)
          : const Color(0xFFF6C66B)
      ..strokeWidth = h * 0.12
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.47, -4), Offset(w * 0.47, h + 4), road);
    canvas.drawLine(Offset(-4, h * 0.58), Offset(w + 4, h * 0.58), major);
    canvas.drawLine(Offset(w * 0.1, h + 4), Offset(w * 0.9, -4), road);
  }

  @override
  bool shouldRepaint(_PreviewPainter old) => old.satellite != satellite;
}
