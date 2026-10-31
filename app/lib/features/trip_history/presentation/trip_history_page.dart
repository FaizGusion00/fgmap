import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/settings/easy_mode_scope.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/presentation/route_format.dart';
import '../data/trip_history_store.dart';
import '../domain/trip_summary.dart';

Future<void> showTripHistoryPage(BuildContext context) => Navigator.of(
  context,
).push<void>(MaterialPageRoute<void>(builder: (_) => const TripHistoryPage()));

class TripHistoryPage extends ConsumerStatefulWidget {
  const TripHistoryPage({super.key});

  @override
  ConsumerState<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends ConsumerState<TripHistoryPage> {
  late List<TripSummary> _trips;

  @override
  void initState() {
    super.initState();
    _trips = ref.read(tripHistoryStoreProvider).read();
  }

  void _reload() {
    setState(() => _trips = ref.read(tripHistoryStoreProvider).read());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final store = ref.read(tripHistoryStoreProvider);
    final stats = MonthlyTripStats.from(_trips);
    final easy = EasyModeScope.of(context);
    final hours = (stats.durationS / 3600).floor();
    final mins = ((stats.durationS % 3600) / 60).round();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripHistoryTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Text(l10n.tripHistoryMonth, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Text(
                      l10n.tripHistoryTrips(stats.tripCount),
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      l10n.tripHistoryKm(
                        (stats.distanceM / 1000).toStringAsFixed(0),
                      ),
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      l10n.tripHistoryDuration(hours, mins),
                      style: theme.textTheme.bodyLarge,
                    ),
                    if (stats.tollRm > 0)
                      Text(
                        l10n.tripHistoryToll(stats.tollRm.toStringAsFixed(0)),
                        style: theme.textTheme.bodyLarge,
                      ),
                  ],
                ),
                if (!easy) ...[
                  const SizedBox(height: 20),
                  Text(
                    l10n.tripHistoryRetention,
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    key: const ValueKey('trip-retention'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 30,
                        label: Text(l10n.tripHistoryRetentionDays(30)),
                      ),
                      ButtonSegment(
                        value: 90,
                        label: Text(l10n.tripHistoryRetentionDays(90)),
                      ),
                      ButtonSegment(
                        value: -1,
                        label: Text(l10n.tripHistoryRetentionForever),
                      ),
                      ButtonSegment(
                        value: 0,
                        label: Text(l10n.tripHistoryRetentionOff),
                      ),
                    ],
                    selected: {store.retentionDays},
                    onSelectionChanged: (s) async {
                      await store.setRetentionDays(s.first);
                      _reload();
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: store.exportJson()),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.tripHistoryExported)),
                          );
                        },
                        child: Text(l10n.tripHistoryExport),
                      ),
                      TextButton(
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(l10n.tripHistoryDeleteAll),
                              content: Text(l10n.settingsConfirmBody),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(l10n.settingsConfirmCancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(l10n.settingsConfirmDelete),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) {
                            await store.clear();
                            _reload();
                          }
                        },
                        child: Text(l10n.tripHistoryDeleteAll),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                if (_trips.isEmpty)
                  Text(
                    l10n.tripHistoryEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final t in _trips.take(easy ? 5 : 50))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        t.destinationLabel ?? l10n.tripTo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        DateFormat.yMMMd()
                            .add_Hm()
                            .format(t.completedAt.toLocal()),
                      ),
                      trailing: Text(
                        formatDistance(l10n, t.distanceM.round()),
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
