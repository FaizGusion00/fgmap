import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/fgmap_theme_extension.dart';
import '../domain/place.dart';
import 'search_history_controller.dart';

/// Baris pintasan destinasi terkini di atas peta: satu ketukan terus mengira laluan. Tersembunyi jika
/// tiada sejarah. Digunakan di bawah pil carian pada skrin utama.
class RecentPlacesBar extends ConsumerWidget {
  const RecentPlacesBar({super.key, required this.onPick, this.limit = 6});

  final ValueChanged<Place> onPick;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(searchHistoryControllerProvider);
    if (places.isEmpty) return const SizedBox.shrink();
    final fg = context.fg;
    final theme = Theme.of(context);
    final shown = places.take(limit).toList();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final place = shown[i];
          return Material(
            key: ValueKey('recent-${place.point.lat}-${place.point.lng}'),
            color: fg.glassSurface,
            elevation: 2,
            shape: StadiumBorder(side: BorderSide(color: fg.glassBorder)),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => onPick(place),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
