import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../domain/place.dart';
import 'search_history_controller.dart';

/// Baris pintasan di atas peta: Rumah, Kerja, kemudian destinasi terkini. Satu ketukan terus mengira
/// laluan. Rumah/Kerja yang belum ditetapkan membuka perancang untuk menetapkannya; tekan lama pada
/// yang sudah ditetapkan untuk menukar atau memadam. Digunakan di bawah pil carian pada skrin utama.
class RecentPlacesBar extends ConsumerWidget {
  const RecentPlacesBar({
    super.key,
    required this.onPick,
    this.onAssign,
    this.limit = 6,
  });

  final ValueChanged<Place> onPick;

  /// Dipanggil apabila pengguna mahu menetapkan atau menukar Rumah/Kerja.
  final ValueChanged<SavedKind>? onAssign;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(searchHistoryControllerProvider);
    final saved = ref.watch(savedPlacesControllerProvider);
    SavedPlace? byId(String id) {
      for (final s in saved) {
        if (s.id == id) return s;
      }
      return null;
    }

    final entries = <Widget>[
      if (onAssign != null) ...[
        _ShortcutChip(
          key: const ValueKey('shortcut-home'),
          icon: Icons.home_rounded,
          label: l10n.savedHome,
          set: byId(SavedPlace.homeId) != null,
          onTap: () {
            final home = byId(SavedPlace.homeId);
            home == null ? onAssign!(SavedKind.home) : onPick(home.place);
          },
          onLongPress: () {
            final home = byId(SavedPlace.homeId);
            if (home != null) {
              _manage(context, ref, home, () => onAssign!(SavedKind.home));
            }
          },
        ),
        _ShortcutChip(
          key: const ValueKey('shortcut-work'),
          icon: Icons.work_rounded,
          label: l10n.savedWork,
          set: byId(SavedPlace.workId) != null,
          onTap: () {
            final work = byId(SavedPlace.workId);
            work == null ? onAssign!(SavedKind.work) : onPick(work.place);
          },
          onLongPress: () {
            final work = byId(SavedPlace.workId);
            if (work != null) {
              _manage(context, ref, work, () => onAssign!(SavedKind.work));
            }
          },
        ),
      ],
      for (final place in places.take(limit))
        _ShortcutChip(
          key: ValueKey('recent-${place.point.lat}-${place.point.lng}'),
          icon: Icons.history_rounded,
          label: place.name,
          set: true,
          onTap: () => onPick(place),
        ),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => entries[i],
      ),
    );
  }

  static Future<void> _manage(
    BuildContext context,
    WidgetRef ref,
    SavedPlace item,
    VoidCallback onChange,
  ) {
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
                ref
                    .read(savedPlacesControllerProvider.notifier)
                    .remove(item.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    super.key,
    required this.icon,
    required this.label,
    required this.set,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String label;

  /// Belum ditetapkan (Rumah/Kerja kosong): dipaparkan dengan tanda tambah.
  final bool set;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    final theme = Theme.of(context);
    return Material(
      color: fg.glassSurface,
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: set
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!set) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
