import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../core/theme/fgmap_theme_extension.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../saved_places/presentation/assign_place_flow.dart';
import '../domain/place.dart';
import 'search_history_controller.dart';

/// Baris pintasan di atas peta: Rumah, Kerja, kemudian destinasi terkini. Satu ketukan terus mengira
/// laluan (Rumah/Kerja: terus mula navigasi melalui [onGo]). Rumah/Kerja yang belum ditetapkan membuka
/// pilihan cari alamat atau guna lokasi semasa; tekan lama pada
/// yang sudah ditetapkan untuk menukar atau memadam. Digunakan di bawah pil carian pada skrin utama.
class RecentPlacesBar extends ConsumerWidget {
  const RecentPlacesBar({
    super.key,
    required this.onPick,
    this.onAssign,
    this.onGo,
    this.limit = 6,
  });

  final ValueChanged<Place> onPick;

  /// Dipanggil apabila Rumah/Kerja yang sudah ditetapkan diketik (cth. terus mula navigasi). Jika
  /// null, [onPick] digunakan.
  final ValueChanged<Place>? onGo;

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
          tint: const Color(0xFF2563EB),
          label: l10n.savedHome,
          set: byId(SavedPlace.homeId) != null,
          onTap: () {
            final home = byId(SavedPlace.homeId);
            home == null
                ? onAssign!(SavedKind.home)
                : (onGo ?? onPick)(home.place);
          },
          onLongPress: () {
            final home = byId(SavedPlace.homeId);
            if (home != null) {
              manageSavedPlace(
                context,
                ref,
                home,
                onChange: () => onAssign!(SavedKind.home),
              );
            }
          },
        ),
        _ShortcutChip(
          key: const ValueKey('shortcut-work'),
          icon: Icons.work_rounded,
          tint: const Color(0xFFD97706),
          label: l10n.savedWork,
          set: byId(SavedPlace.workId) != null,
          onTap: () {
            final work = byId(SavedPlace.workId);
            work == null
                ? onAssign!(SavedKind.work)
                : (onGo ?? onPick)(work.place);
          },
          onLongPress: () {
            final work = byId(SavedPlace.workId);
            if (work != null) {
              manageSavedPlace(
                context,
                ref,
                work,
                onChange: () => onAssign!(SavedKind.work),
              );
            }
          },
        ),
      ],
      for (final place in places.take(limit))
        _ShortcutChip(
          key: ValueKey('recent-${place.point.lat}-${place.point.lng}'),
          icon: Icons.history_rounded,
          tint: Theme.of(context).colorScheme.onSurfaceVariant,
          label: place.name,
          set: true,
          onTap: () => onPick(place),
        ),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    // Mod mudah: cip Rumah/Kerja setinggi 56 dp (sasaran sentuhan besar) dengan teks lebih besar.
    return SizedBox(
      height: EasyModeScope.of(context) ? 56 : 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => entries[i],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.set,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;

  /// Warna ikon dan latar bulat lembutnya.
  final Color tint;
  final String label;

  /// Belum ditetapkan (Rumah/Kerja kosong): dipaparkan dengan tanda tambah.
  final bool set;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final fg = context.fg;
    final theme = Theme.of(context);
    final easy = EasyModeScope.of(context);
    final badge = easy ? 40.0 : 28.0;
    return Material(
      color: fg.glassSurface,
      elevation: 2,
      shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: easy ? 240 : 190,
            minHeight: easy ? 56 : 40,
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(6, 0, easy ? 18 : 14, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lencana bulat bertinta: Rumah biru, Kerja jingga, terkini kelabu. Belum ditetapkan:
                // lencana pudar dengan tanda tambah.
                Container(
                  width: badge,
                  height: badge,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: set ? 0.14 : 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: easy ? 24 : 16,
                    color: set ? tint : tint.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(width: easy ? 10 : 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (easy
                                ? theme.textTheme.titleMedium
                                : theme.textTheme.labelLarge)
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: set
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                  ),
                ),
                if (!set) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: easy ? 22 : 16,
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
