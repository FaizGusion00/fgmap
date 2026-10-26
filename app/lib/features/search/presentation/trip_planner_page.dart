import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/geo.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/place.dart';
import 'place_search_controller.dart';
import 'search_history_controller.dart';

/// Keputusan perancang perjalanan. [origin] null bermaksud "lokasi saya".
@immutable
class TripSelection {
  const TripSelection({required this.destination, this.origin});

  final Place? origin;
  final Place destination;
}

enum _Field { origin, destination }

/// Halaman penuh untuk memilih asal dan destinasi (Bahagian 14.4 pelan, skrin 3). Asal lalai ialah
/// "Lokasi saya"; keduanya boleh dicari.
class TripPlannerPage extends ConsumerStatefulWidget {
  const TripPlannerPage({super.key, this.near, this.initialDestinationQuery});

  /// Pusat peta/lokasi semasa, untuk mengutamakan hasil berhampiran.
  final GeoPoint? near;
  final String? initialDestinationQuery;

  static Future<TripSelection?> open(
    BuildContext context, {
    GeoPoint? near,
    String? initialDestinationQuery,
  }) {
    return Navigator.of(context).push<TripSelection>(
      PageRouteBuilder<TripSelection>(
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => TripPlannerPage(
          near: near,
          initialDestinationQuery: initialDestinationQuery,
        ),
      ),
    );
  }

  @override
  ConsumerState<TripPlannerPage> createState() => _TripPlannerPageState();
}

class _TripPlannerPageState extends ConsumerState<TripPlannerPage> {
  final _originText = TextEditingController();
  final _destText = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();

  Place? _origin; // null = lokasi saya
  Place? _destination;
  _Field _active = _Field.destination;

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
    _originFocus.addListener(() => _onFocus(_Field.origin, _originFocus));
    _destFocus.addListener(() => _onFocus(_Field.destination, _destFocus));
  }

  @override
  void dispose() {
    _originText.dispose();
    _destText.dispose();
    _originFocus.dispose();
    _destFocus.dispose();
    super.dispose();
  }

  void _onFocus(_Field field, FocusNode node) {
    if (!node.hasFocus) return;
    setState(() => _active = field);
    ref
        .read(placeSearchControllerProvider.notifier)
        .onQueryChanged(_textOf(field), near: widget.near);
  }

  String _textOf(_Field f) =>
      (f == _Field.origin ? _originText : _destText).text;

  void _onChanged(_Field field, String text) {
    // Menaip menggantikan pilihan sebelumnya untuk medan itu.
    if (field == _Field.origin) {
      _origin = null;
    } else {
      _destination = null;
    }
    ref
        .read(placeSearchControllerProvider.notifier)
        .onQueryChanged(text, near: widget.near);
    setState(() {});
  }

  void _pick(Place place) {
    HapticFeedback.selectionClick();
    ref.read(searchHistoryControllerProvider.notifier).record(place);
    if (_active == _Field.origin) {
      _origin = place;
      _originText.text = place.name;
      if (_destination == null) {
        _destFocus.requestFocus();
      } else {
        _finish();
      }
    } else {
      _destination = place;
      _destText.text = place.name;
      _finish();
    }
    ref.read(placeSearchControllerProvider.notifier).clear();
    setState(() {});
  }

  void _useMyLocation() {
    HapticFeedback.selectionClick();
    _origin = null;
    _originText.clear();
    ref.read(placeSearchControllerProvider.notifier).clear();
    if (_destination == null) {
      _destFocus.requestFocus();
    } else {
      _finish();
    }
    setState(() {});
  }

  void _finish() {
    final destination = _destination;
    if (destination == null) return;
    // Asal dan destinasi di titik yang sama tidak bermakna: kekal pada halaman supaya pengguna membetulkan.
    if (_origin != null && _origin!.point == destination.point) return;
    Navigator.of(
      context,
    ).pop(TripSelection(origin: _origin, destination: destination));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final search = ref.watch(placeSearchControllerProvider);
    final history = ref.watch(searchHistoryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tripPlannerTitle),
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
                        child: TextField(
                          key: const ValueKey('origin-field'),
                          controller: _originText,
                          focusNode: _originFocus,
                          textInputAction: TextInputAction.next,
                          onChanged: (t) => _onChanged(_Field.origin, t),
                          decoration: InputDecoration(
                            hintText: l10n.myLocation,
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: theme.textTheme.bodyLarge,
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
                                  _onChanged(_Field.destination, '');
                                },
                              ),
                        child: TextField(
                          key: const ValueKey('destination-field'),
                          controller: _destText,
                          focusNode: _destFocus,
                          textInputAction: TextInputAction.search,
                          onChanged: (t) => _onChanged(_Field.destination, t),
                          decoration: InputDecoration(
                            hintText: l10n.searchHint,
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
                    showMyLocation: _active == _Field.origin,
                    onMyLocation: _useMyLocation,
                    onPick: _pick,
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
    required this.showMyLocation,
    required this.onMyLocation,
    required this.onPick,
    required this.onClearHistory,
    required this.onRetry,
  });

  final PlaceSearchState state;
  final List<Place> history;
  final bool showMyLocation;
  final VoidCallback onMyLocation;
  final ValueChanged<Place> onPick;
  final VoidCallback onClearHistory;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final header = <Widget>[
      if (showMyLocation)
        ListTile(
          key: const ValueKey('use-my-location'),
          leading: Icon(
            Icons.my_location_rounded,
            color: theme.colorScheme.primary,
          ),
          title: Text(l10n.myLocation),
          onTap: onMyLocation,
        ),
    ];

    final Widget body = switch (state.status) {
      SearchStatus.idle =>
        history.isEmpty
            ? _Message(icon: Icons.search_rounded, text: l10n.searchPrompt)
            : Column(
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
                      leading: Icon(
                        _iconFor(place.category),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
                      onTap: () => onPick(place),
                    ),
                ],
              ),
      SearchStatus.loading => const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      ),
      SearchStatus.empty => _Message(
        icon: Icons.search_off_rounded,
        text: l10n.searchNoResults(state.query),
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
          for (final place in state.results)
            ListTile(
              key: ValueKey('place-${place.point.lat}-${place.point.lng}'),
              leading: Icon(
                _iconFor(place.category),
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
              onTap: () => onPick(place),
            ),
        ],
      ),
    };

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [...header, body],
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
