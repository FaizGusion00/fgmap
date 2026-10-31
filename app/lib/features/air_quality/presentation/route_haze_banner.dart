import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../route_preview/domain/route_option.dart';
import '../domain/air_quality.dart';
import 'air_quality_controller.dart';

/// Banner IPU tinggi sepanjang koridor laluan (pratonton). Soft-fail jika offline.
class RouteHazeBanner extends ConsumerStatefulWidget {
  const RouteHazeBanner({super.key, required this.route});

  final RouteOption route;

  @override
  ConsumerState<RouteHazeBanner> createState() => _RouteHazeBannerState();
}

class _RouteHazeBannerState extends ConsumerState<RouteHazeBanner> {
  AirStation? _alert;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant RouteHazeBanner old) {
    super.didUpdateWidget(old);
    if (!identical(old.route.points, widget.route.points)) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    final seq = ++_seq;
    final alert = await ref
        .read(airQualityControllerProvider.notifier)
        .checkRoute(widget.route);
    if (!mounted || seq != _seq) return;
    setState(() => _alert = alert);
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert;
    if (alert == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Material(
      key: ValueKey('haze-${alert.id}-${alert.ipu}'),
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.masks_outlined,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.airQualityRouteAlert(alert.name, alert.ipu),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
