import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../../../core/utils/haptics.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../map/presentation/location_prompt.dart';
import '../../search/data/photon_geocoder.dart';
import '../../search/domain/place.dart';
import '../../search/presentation/trip_planner_page.dart';
import '../data/saved_places_controller.dart';
import '../domain/saved_place.dart';
import 'save_place_sheet.dart';

enum _Method { search, current }

/// Menetapkan atau menukar Rumah/Kerja: pengguna memilih sama ada MENCARI alamat atau MENGGUNAKAN
/// LOKASI SEMASA. Digunakan oleh pintasan di skrin utama dan oleh Tetapan.
///
/// [userLocation] (jika diketahui, cth. daripada penjejak peta) dipakai terus untuk "lokasi semasa";
/// jika tidak, GPS diminta. [near] hanya memberi keutamaan hasil carian yang hampir.
Future<void> assignSavedPlace(
  BuildContext context,
  WidgetRef ref,
  SavedKind kind, {
  GeoPoint? near,
  GeoPoint? userLocation,
}) async {
  final method = await showModalBottomSheet<_Method>(
    context: context,
    showDragHandle: true,
    builder: (_) => _MethodSheet(kind: kind),
  );
  if (method == null || !context.mounted) return;
  switch (method) {
    case _Method.search:
      await TripPlannerPage.open(
        context,
        near: near ?? userLocation,
        userLocation: userLocation,
        assign: kind,
      );
    case _Method.current:
      await _assignCurrent(context, ref, kind, userLocation);
  }
}

Future<void> _assignCurrent(
  BuildContext context,
  WidgetRef ref,
  SavedKind kind,
  GeoPoint? known,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final access = await ensureLocationAccess(context, ref);
  if (access != LocationAccess.granted || !context.mounted) return;

  messenger?.showSnackBar(SnackBar(content: Text(l10n.savedLocating)));
  var point = known;
  if (point == null) {
    final fix = await ref
        .read(locationServiceProvider)
        .currentFix(
          timeout: const Duration(seconds: 12),
          fallbackAccuracyMeters: 150,
        );
    point = fix?.point;
  }
  if (!context.mounted) return;
  messenger?.hideCurrentSnackBar();
  if (point == null) {
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.locationFixUnavailable)),
    );
    return;
  }

  // Nama dan alamat daripada geokod songsang; titik yang disimpan ialah kedudukan TEPAT pengguna.
  // Jika geokod gagal, tetap disimpan dengan nama umum (lokasi tepat lebih penting daripada nama).
  Place? named;
  try {
    named = await ref
        .read(reverseGeocoderProvider)
        .reverse(point)
        .timeout(const Duration(seconds: 5));
  } on Object {
    named = null;
  }
  if (!context.mounted) return;
  final place = Place(
    name: named?.name ?? l10n.savedCurrentLocation,
    subtitle: named?.subtitle ?? _coordinates(point),
    point: point,
  );
  final controller = ref.read(savedPlacesControllerProvider.notifier);
  kind == SavedKind.home
      ? await controller.setHome(place)
      : await controller.setWork(place);
  unawaited(Haptics.selection());
  messenger?.showSnackBar(
    SnackBar(content: Text(l10n.savedDone(savedKindLabel(l10n, kind)))),
  );
}

String _coordinates(GeoPoint p) =>
    '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';

class _MethodSheet extends StatelessWidget {
  const _MethodSheet({required this.kind});

  final SavedKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              kind == SavedKind.home ? l10n.savedSetHome : l10n.savedSetWork,
              style: theme.textTheme.titleLarge,
            ),
          ),
          ListTile(
            key: const ValueKey('assign-search'),
            minTileHeight: 64,
            leading: const Icon(Icons.search_rounded),
            title: Text(l10n.savedBySearch),
            subtitle: Text(l10n.savedBySearchHint),
            onTap: () => Navigator.of(context).pop(_Method.search),
          ),
          ListTile(
            key: const ValueKey('assign-current'),
            minTileHeight: 64,
            leading: const Icon(Icons.my_location_rounded),
            title: Text(l10n.savedByCurrent),
            subtitle: Text(l10n.savedByCurrentHint),
            onTap: () => Navigator.of(context).pop(_Method.current),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Lembaran urus untuk Rumah/Kerja yang sudah ditetapkan: Tukar (cari atau lokasi semasa) atau Padam.
Future<void> manageSavedPlace(
  BuildContext context,
  WidgetRef ref,
  SavedPlace item, {
  required VoidCallback onChange,
}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(savedKindIcon(item.kind)),
            title: Text(savedKindLabel(l10n, item.kind)),
            subtitle: Text(
              item.place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            key: const ValueKey('manage-change'),
            minTileHeight: 56,
            leading: const Icon(Icons.edit_rounded),
            title: Text(l10n.savedChange),
            onTap: () {
              Navigator.of(sheetContext).pop();
              onChange();
            },
          ),
          ListTile(
            key: const ValueKey('manage-remove'),
            minTileHeight: 56,
            leading: const Icon(Icons.delete_outline_rounded),
            title: Text(l10n.savedRemove),
            onTap: () {
              Navigator.of(sheetContext).pop();
              ref.read(savedPlacesControllerProvider.notifier).remove(item.id);
            },
          ),
        ],
      ),
    ),
  );
}
