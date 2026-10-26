import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../search/domain/place.dart';
import '../data/saved_places_controller.dart';
import '../domain/saved_place.dart';
import '../../../core/utils/haptics.dart';

String savedKindLabel(AppLocalizations l10n, SavedKind kind) => switch (kind) {
  SavedKind.home => l10n.savedHome,
  SavedKind.work => l10n.savedWork,
  SavedKind.favorite => l10n.savedFavorite,
};

IconData savedKindIcon(SavedKind kind) => switch (kind) {
  SavedKind.home => Icons.home_rounded,
  SavedKind.work => Icons.work_rounded,
  SavedKind.favorite => Icons.star_rounded,
};

/// Lembaran "Simpan sebagai": Rumah, Kerja atau Kegemaran untuk [place].
Future<void> showSavePlaceSheet(BuildContext context, Place place) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SavePlaceSheet(place: place),
  );
}

class SavePlaceSheet extends ConsumerWidget {
  const SavePlaceSheet({super.key, required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(savedPlacesControllerProvider.notifier);

    Future<void> done(SavedKind kind) async {
      unawaited(Haptics.selection());
      final messenger = ScaffoldMessenger.maybeOf(context);
      final label = savedKindLabel(l10n, kind);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(l10n.savedDone(label))));
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                l10n.savedSheetTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                place.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final kind in SavedKind.values)
              ListTile(
                key: ValueKey('save-as-${kind.name}'),
                minTileHeight: 56,
                leading: Icon(savedKindIcon(kind)),
                title: Text(savedKindLabel(l10n, kind)),
                onTap: () async {
                  switch (kind) {
                    case SavedKind.home:
                      await controller.setHome(place);
                    case SavedKind.work:
                      await controller.setWork(place);
                    case SavedKind.favorite:
                      final saved = await controller.toggleFavorite(place);
                      if (!saved) {
                        if (context.mounted) Navigator.of(context).pop();
                        return;
                      }
                  }
                  if (context.mounted) await done(kind);
                },
              ),
          ],
        ),
      ),
    );
  }
}
