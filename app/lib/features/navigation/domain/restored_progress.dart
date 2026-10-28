import 'dart:math' as math;

import '../../../core/utils/geo.dart';
import 'nav_route.dart';
import 'navigation_session.dart';

/// Kemajuan paparan untuk perjalanan yang dipulihkan, sebelum fix GPS seterusnya tiba.
/// Destinasi, manuver dan baki perjalanan datang daripada laluan yang disimpan, bukan laluan baharu.
NavProgress restoredProgress({
  required NavRoute route,
  required double alongM,
  required GeoPoint position,
  required double bearing,
  required double speedMps,
  bool arrived = false,
}) {
  final along = alongM.clamp(0.0, route.totalM);
  final next = route.nextActionable(along);
  final following = next == null ? null : route.actionableAfter(next);
  String? street;
  if (route.maneuvers.isNotEmpty) {
    final index = (route.maneuverAt(along)?.index ?? 0).clamp(
      0,
      route.maneuvers.length - 1,
    );
    for (var i = index; i >= 0; i--) {
      final name = route.maneuvers[i].street;
      if (name != null) {
        street = name;
        break;
      }
    }
  }
  return NavProgress(
    status: arrived ? NavStatus.arrived : NavStatus.onRoute,
    alongM: along,
    remainingM: math.max(0.0, route.totalM - along),
    remainingS: route.plannedRemainingTime(along),
    next: next,
    distanceToNextM: next == null
        ? null
        : math.max(0.0, next.startM - along),
    following: following,
    position: position,
    bearing: bearing,
    speedMps: speedMps,
    accuracyM: 15,
    crossTrackM: 0,
    street: street,
    gpsWeak: false,
  );
}
