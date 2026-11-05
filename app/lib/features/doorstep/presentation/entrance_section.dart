import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../data/saved_entrances.dart';
import '../domain/entrance.dart';
import 'doorstep_controller.dart';

String entranceKindLabel(AppLocalizations l10n, EntranceKind kind) =>
    switch (kind) {
      EntranceKind.saved => l10n.doorstepSaved,
      EntranceKind.main => l10n.doorstepMain,
      EntranceKind.visitor => l10n.doorstepVisitor,
      EntranceKind.parking => l10n.doorstepParking,
      EntranceKind.gate => l10n.doorstepGate,
      EntranceKind.loading => l10n.doorstepLoading,
      EntranceKind.service => l10n.doorstepService,
      EntranceKind.door => l10n.doorstepDoor,
    };

IconData entranceKindIcon(EntranceKind kind) => switch (kind) {
  EntranceKind.saved => Icons.star_rounded,
  EntranceKind.main => Icons.door_front_door_rounded,
  EntranceKind.visitor => Icons.security_rounded,
  EntranceKind.parking => Icons.local_parking_rounded,
  EntranceKind.gate => Icons.fence_rounded,
  EntranceKind.loading => Icons.local_shipping_rounded,
  EntranceKind.service => Icons.meeting_room_rounded,
  EntranceKind.door => Icons.sensor_door_rounded,
};

/// "Pintu masuk" dalam pratonton laluan: pin destinasi + pintu OSM/pengguna. Tekan = laluan terus ke
/// pintu itu; tekan lama = jadikan/buang pintu lalai untuk tempat ini. Tiada data -> tiada bahagian.
class EntranceSection extends ConsumerWidget {
  const EntranceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final door = ref.watch(doorstepProvider);
    final place = door.place;
    if (place == null) return const SizedBox.shrink();
    final found = ref.watch(entrancesProvider(place)).value;
    if (found == null || found.isEmpty) return const SizedBox.shrink();
    // Pintu yang sedang dituju didahulukan (sentiasa kelihatan selepas pin, tidak tertolak ke luar skrin).
    final chosen = door.selected;
    final entrances = chosen == null
        ? found
        : [
            ...found.where((e) => distanceMeters(e.point, chosen.point) < 1),
            ...found.where((e) => distanceMeters(e.point, chosen.point) >= 1),
          ];
    final saved = ref
        .watch(savedEntrancesProvider)
        .where(
          (s) =>
              distanceMeters(s.place, place) <=
              SavedEntrancesController.matchRadiusM,
        )
        .firstOrNull;
    final selected = door.selected;

    Future<void> menu(Entrance e) async {
      final isDefault =
          saved != null && distanceMeters(saved.point, e.point) < 2;
      final choice = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  isDefault ? Icons.star_outline_rounded : Icons.star_rounded,
                ),
                title: Text(
                  isDefault
                      ? l10n.doorstepRemoveDefault
                      : l10n.doorstepMakeDefault,
                ),
                onTap: () => Navigator.pop(context, !isDefault),
              ),
            ],
          ),
        ),
      );
      if (choice == null) return;
      final store = ref.read(savedEntrancesProvider.notifier);
      if (choice) {
        await store.save(place, e, placeName: door.placeLabel);
      } else {
        await store.remove(place);
      }
    }

    return Padding(
      key: const ValueKey('doorstep-section'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.door_front_door_rounded,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(l10n.doorstepTitle, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _EntranceChip(
                  key: const ValueKey('doorstep-pin'),
                  icon: Icons.place_rounded,
                  title: l10n.doorstepPin,
                  subtitle: null,
                  selected: selected == null,
                  onTap: selected == null
                      ? null
                      : () => unawaited(
                          ref.read(doorstepProvider.notifier).usePin(),
                        ),
                ),
                for (var i = 0; i < entrances.length; i++)
                  _EntranceChip(
                    key: ValueKey('doorstep-$i'),
                    icon: entranceKindIcon(entrances[i].kind),
                    title: entranceKindLabel(l10n, entrances[i].kind),
                    subtitle: [
                      ?entrances[i].detail,
                      if (entrances[i].distanceM >= 5)
                        formatDistance(l10n, entrances[i].distanceM.round()),
                    ].join(' · '),
                    starred:
                        saved != null &&
                        distanceMeters(saved.point, entrances[i].point) < 2,
                    selected:
                        selected != null &&
                        distanceMeters(selected.point, entrances[i].point) < 1,
                    onTap: () => unawaited(
                      ref.read(doorstepProvider.notifier).use(entrances[i]),
                    ),
                    onLongPress: () => unawaited(menu(entrances[i])),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.doorstepSource,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntranceChip extends StatelessWidget {
  const _EntranceChip({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.starred = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final bool starred;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, maxWidth: 220),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: fg,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (starred) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: scheme.tertiary,
                                ),
                              ],
                            ],
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty)
                            Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: fg.withValues(alpha: 0.75),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
