import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/skeleton.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/place.dart';
import '../../route_preview/presentation/route_format.dart';
import '../../../core/config/app_config.dart';
import '../domain/nearby_category.dart';
import '../../saved_places/data/saved_places_controller.dart';
import '../../saved_places/domain/saved_place.dart';
import '../../saved_places/presentation/save_place_sheet.dart';
import '../domain/place_ranker.dart';
import 'place_search_controller.dart';
import 'search_history_controller.dart';

/// Destinasi pilihan. Asal laluan sentiasa lokasi GPS pengguna.
@immutable
class TripSelection {
  const TripSelection({required this.destination});

  final Place destination;
}

/// Halaman penuh untuk memilih destinasi. Asal lalai ialah
/// "Lokasi saya" dan tidak boleh diubah.
class TripPlannerPage extends ConsumerStatefulWidget {
  const TripPlannerPage({
    super.key,
    this.near,
    this.userLocation,
    this.initialDestinationQuery,
    this.assign,
  });

  /// Jika ditetapkan, tempat yang dipilih disimpan sebagai Rumah/Kerja dan perancang ditutup tanpa
  /// mengira laluan.
  final SavedKind? assign;

  /// Lokasi pengguna (jika diketahui) atau pusat peta, untuk mengutamakan hasil berhampiran.
  final GeoPoint? near;

  /// Lokasi GPS pengguna sahaja; jika ada, setiap hasil memaparkan jaraknya dari sini.
  final GeoPoint? userLocation;
  final String? initialDestinationQuery;

  static Future<TripSelection?> open(
    BuildContext context, {
    GeoPoint? near,
    GeoPoint? userLocation,
    String? initialDestinationQuery,
    SavedKind? assign,
  }) {
    return Navigator.of(context).push<TripSelection>(
      PageRouteBuilder<TripSelection>(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, _, _) => TripPlannerPage(
          near: near,
          userLocation: userLocation,
          initialDestinationQuery: initialDestinationQuery,
          assign: assign,
        ),
        // Naik dari bawah sambil pudar masuk; menghormati Reduce Motion (tempoh sifar).
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends ConsumerState<TripPlannerPage> {
  final _destText = TextEditingController();
  final _destFocus = FocusNode();

  Place? _destination;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialDestinationQuery?.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _destFocus.requestFocus();
    });
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _destText.text = initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(placeSearchControllerProvider.notifier)
            .onQueryChanged(initialQuery, near: widget.near);
      });
    }
  }

  @override
  void dispose() {
    _destText.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _destination = null;
    ref
        .read(placeSearchControllerProvider.notifier)
        .onQueryChanged(text, near: widget.near);
    setState(() {});
  }

  /// Carian kategori sebenar (tag OSM di sekitar lokasi anda), bukan carian nama.
  void _searchNearby(NearbyCategory category, String label) {
    HapticFeedback.selectionClick();
    _destination = null;
    _destText.text = label;
    _destText.selection = TextSelection.collapsed(offset: label.length);
    ref
        .read(placeSearchControllerProvider.notifier)
        .searchNearby(
          category,
          center: widget.userLocation ?? widget.near ?? AppConfig.initialCenter,
          label: label,
          fallbackName: label,
        );
    setState(() {});
  }

  Future<void> _assign(Place place, SavedKind kind) async {
    unawaited(HapticFeedback.selectionClick());
    final controller = ref.read(savedPlacesControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    kind == SavedKind.home
        ? await controller.setHome(place)
        : await controller.setWork(place);
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.savedDone(savedKindLabel(l10n, kind)))),
    );
    if (mounted) navigator.pop();
  }

  void _pick(Place place) {
    final assign = widget.assign;
    if (assign != null) {
      unawaited(_assign(place, assign));
      return;
    }
    HapticFeedback.selectionClick();
    ref.read(searchHistoryControllerProvider.notifier).record(place);
    _destination = place;
    _destText.text = place.name;
    ref.read(placeSearchControllerProvider.notifier).clear();
    _finish();
    setState(() {});
  }

  void _finish() {
    final destination = _destination;
    if (destination == null) return;
    Navigator.of(context).pop(TripSelection(destination: destination));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final search = ref.watch(placeSearchControllerProvider);
    final history = ref.watch(searchHistoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.assign == null
              ? l10n.tripPlannerTitle
              : l10n.savedAssigning(savedKindLabel(l10n, widget.assign!)),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _FieldBox(
                        label: l10n.tripFrom,
                        icon: Icons.my_location_rounded,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.myLocation,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _FieldBox(
                        label: l10n.tripTo,
                        icon: Icons.place_rounded,
                        trailing: _destText.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.searchClear,
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _destText.clear();
                                  _onChanged('');
                                },
                              ),
                        child: TextField(
                          key: const ValueKey('destination-field'),
                          controller: _destText,
                          focusNode: _destFocus,
                          textInputAction: TextInputAction.search,
                          onChanged: _onChanged,
                          decoration: InputDecoration(
                            hintText: widget.assign == null
                                ? l10n.searchHint
                                : l10n.savedAssigning(
                                    savedKindLabel(l10n, widget.assign!),
                                  ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _ResultsList(
                    state: search,
                    history: history,
                    userLocation: widget.userLocation,
                    showSaved: widget.assign == null,
                    onPick: _pick,
                    onCategory: _searchNearby,
                    onClearHistory: () => ref
                        .read(searchHistoryControllerProvider.notifier)
                        .clear(),
                    onRetry: () => ref
                        .read(placeSearchControllerProvider.notifier)
                        .retry(near: widget.near),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({
    required this.label,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String label;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: child,
                ),
              ),
              if (trailing != null) trailing! else const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.state,
    required this.history,
    required this.userLocation,
    required this.showSaved,
    required this.onPick,
    required this.onCategory,
    required this.onClearHistory,
    required this.onRetry,
  });

  final PlaceSearchState state;
  final List<Place> history;
  final GeoPoint? userLocation;
  final bool showSaved;
  final ValueChanged<Place> onPick;
  final void Function(NearbyCategory category, String label) onCategory;
  final VoidCallback onClearHistory;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final Widget body = switch (state.status) {
      SearchStatus.idle => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSaved) _SavedSection(onPick: onPick),
          _CategoryChips(onPick: onCategory),
          if (history.isEmpty)
            _Message(icon: Icons.search_rounded, text: l10n.searchPrompt)
          else
            Column(
              children: [
                ListTile(
                  title: Text(l10n.searchHistory),
                  trailing: TextButton(
                    onPressed: onClearHistory,
                    child: Text(l10n.searchClearHistory),
                  ),
                ),
                for (final place in history)
                  ListTile(
                    key: ValueKey(
                      'history-${place.point.lat}-${place.point.lng}',
                    ),
                    leading: _PlaceIcon(icon: _iconFor(place.category)),
                    title: Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: place.subtitle.isEmpty
                        ? null
                        : Text(
                            place.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: showSaved ? _FavoriteStar(place: place) : null,
                    onTap: () => onPick(place),
                  ),
              ],
            ),
        ],
      ),
      SearchStatus.loading => const _ResultsSkeleton(),
      SearchStatus.empty => _Message(
        icon: Icons.search_off_rounded,
        text: state.nearby != null
            ? l10n.searchNoNearby(state.query)
            : l10n.searchNoResults(state.query),
      ),
      SearchStatus.failed => _Message(
        icon: Icons.cloud_off_rounded,
        text: switch (state.failure) {
          GeocodeFailureKind.network => l10n.searchErrorNetwork,
          GeocodeFailureKind.rateLimited => l10n.searchErrorRateLimited,
          GeocodeFailureKind.unavailable => l10n.searchErrorUnavailable,
          _ => l10n.routeErrorGeneric,
        },
        action: TextButton(onPressed: onRetry, child: Text(l10n.routeRetry)),
      ),
      SearchStatus.results => Column(
        children: [
          if (state.cachedAt != null) _SavedBanner(at: state.cachedAt!),
          for (final place in state.results)
            ListTile(
              key: ValueKey('place-${place.point.lat}-${place.point.lng}'),
              leading: _PlaceIcon(icon: _iconFor(place.category)),
              title: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: _ResultSubtitle(
                place: place,
                from: state.origin ?? userLocation,
              ),
              trailing: showSaved ? _FavoriteStar(place: place) : null,
              onTap: () => onPick(place),
            ),
        ],
      ),
    };

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [body],
    );
  }
}

/// Bintang kegemaran pada hasil carian dan sejarah.
class _FavoriteStar extends ConsumerWidget {
  const _FavoriteStar({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saved = ref.watch(
      savedPlacesControllerProvider.select(
        (items) => items.any((s) => s.id == SavedPlace.favoriteId(place)),
      ),
    );
    return IconButton(
      key: ValueKey('star-${place.point.lat}-${place.point.lng}'),
      tooltip: saved ? l10n.savedFavoriteRemove : l10n.savedFavoriteAdd,
      icon: Icon(
        saved ? Icons.star_rounded : Icons.star_outline_rounded,
        color: saved ? Colors.amber.shade700 : null,
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        ref.read(savedPlacesControllerProvider.notifier).toggleFavorite(place);
      },
    );
  }
}

/// Rumah, Kerja dan kegemaran di bahagian atas perancang (keadaan awal).
class _SavedSection extends ConsumerWidget {
  const _SavedSection({required this.onPick});

  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final saved = ref.watch(savedPlacesControllerProvider);
    if (saved.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            l10n.savedSection,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final item in saved)
          ListTile(
            key: ValueKey('saved-${item.id}'),
            leading: _PlaceIcon(icon: savedKindIcon(item.kind)),
            title: Text(
              item.kind == SavedKind.favorite
                  ? item.place.name
                  : savedKindLabel(l10n, item.kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.kind == SavedKind.favorite
                  ? item.place.subtitle
                  : item.place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              tooltip: l10n.savedRemove,
              icon: const Icon(Icons.close_rounded),
              onPressed: () => ref
                  .read(savedPlacesControllerProvider.notifier)
                  .remove(item.id),
            ),
            onTap: () => onPick(item.place),
          ),
        const Divider(height: 24),
      ],
    );
  }
}

/// Diberitahu apabila senarai berasal dari simpanan peranti (pelayan tidak dapat dicapai).
class _SavedBanner extends StatelessWidget {
  const _SavedBanner({required this.at});

  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final when = DateFormat.MMMd(l10n.localeName).add_Hm().format(at);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('nearby-saved-banner'),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.searchNearbySaved(when),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Baris kedua hasil carian: "Jenis · jarak" (menjelaskan kedai vs perhentian bas bernama sama),
/// kemudian alamat.
class _ResultSubtitle extends StatelessWidget {
  const _ResultSubtitle({required this.place, required this.from});

  final Place place;
  final GeoPoint? from;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kind = placeKindOf(place);
    final kindLabel = switch (kind) {
      PlaceKind.shopping => l10n.placeKindShopping,
      PlaceKind.fuel => l10n.placeKindFuel,
      PlaceKind.food => l10n.placeKindFood,
      PlaceKind.worship => l10n.placeKindWorship,
      PlaceKind.health => l10n.placeKindHealth,
      PlaceKind.parking => l10n.placeKindParking,
      PlaceKind.toilets => l10n.placeKindToilets,
      PlaceKind.transit => l10n.placeKindTransit,
      PlaceKind.road => l10n.placeKindRoad,
      PlaceKind.area => l10n.placeKindArea,
      PlaceKind.address => l10n.placeKindAddress,
      PlaceKind.place => l10n.placeKindPlace,
    };
    final origin = from;
    final parts = <String>[
      if (kind == PlaceKind.transit && PlaceRanker.isOppositeSide(place.name))
        '$kindLabel (${l10n.placeOppositeSide})'
      else
        kindLabel,
      if (origin != null)
        formatDistance(l10n, distanceMeters(origin, place.point).round()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (place.subtitle.isNotEmpty)
          Text(place.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _PlaceIcon extends StatelessWidget {
  const _PlaceIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: 20, color: theme.colorScheme.primary),
      ),
    );
  }
}

/// Pintasan kategori berhampiran (minyak, makan, masjid, ...). Mengetuk mengisi medan carian.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.onPick});

  final void Function(NearbyCategory category, String label) onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      (
        Icons.local_gas_station_rounded,
        l10n.searchCatFuel,
        NearbyCategory.fuel,
      ),
      (Icons.restaurant_rounded, l10n.searchCatFood, NearbyCategory.food),
      (Icons.mosque_rounded, l10n.searchCatMosque, NearbyCategory.mosque),
      (Icons.wc_rounded, l10n.searchCatToilet, NearbyCategory.toilets),
      (
        Icons.local_parking_rounded,
        l10n.searchCatParking,
        NearbyCategory.parking,
      ),
      (
        Icons.local_hospital_rounded,
        l10n.searchCatHospital,
        NearbyCategory.hospital,
      ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.searchCategories,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  ActionChip(
                    avatar: Icon(
                      item.$1,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(item.$2),
                    onPressed: () => onPick(item.$3, item.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultsSkeleton extends StatelessWidget {
  const _ResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: AppLocalizations.of(context).routeCalculating,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            for (var i = 0; i < 5; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SkeletonBox(width: 40, height: 40, radius: 20),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(height: 14, radius: 7),
                          SizedBox(height: 8),
                          SkeletonBox(width: 180, height: 12, radius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
        child: Column(
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}

IconData _iconFor(String? category) {
  switch (category) {
    case 'fuel':
      return Icons.local_gas_station_rounded;
    case 'restaurant' || 'fast_food' || 'food_court':
      return Icons.restaurant_rounded;
    case 'cafe':
      return Icons.local_cafe_rounded;
    case 'place_of_worship' || 'mosque':
      return Icons.mosque_rounded;
    case 'hospital' || 'clinic' || 'pharmacy':
      return Icons.local_hospital_rounded;
    case 'bank' || 'atm':
      return Icons.account_balance_rounded;
    case 'parking':
      return Icons.local_parking_rounded;
    case 'toilets':
      return Icons.wc_rounded;
    case 'bus_stop' || 'platform':
      return Icons.directions_bus_rounded;
    case 'station' || 'bus_station' || 'halt' || 'subway_entrance':
      return Icons.train_rounded;
    case 'mall' || 'supermarket' || 'convenience' || 'department_store':
      return Icons.shopping_bag_rounded;
    case 'residential' || 'house' || 'apartments':
      return Icons.home_rounded;
    default:
      return Icons.place_outlined;
  }
}
