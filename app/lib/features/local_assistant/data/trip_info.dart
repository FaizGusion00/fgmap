import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../fuel/data/fuel_settings.dart';
import '../../fuel/domain/fuel.dart';
import '../../navigation/presentation/navigation_controller.dart';
import '../../route_preview/data/route_planner.dart';
import '../../route_preview/domain/route_option.dart';
import '../../route_preview/presentation/route_preview_controller.dart';
import '../domain/intent_router.dart';

/// Jawapan soalan perjalanan ("berapa jauh lagi", "pukul berapa sampai", "berapa tol") daripada data navigasi/laluan
/// yang sudah ada pada peranti: tanpa rangkaian dan tanpa model. Tidak pernah mereka nilai; data tiada -> `error`.
Map<String, Object?> tripInfo(Ref ref, TripInfoKind kind) {
  final nav = ref.read(navigationControllerProvider);
  final preview = ref.read(routePreviewControllerProvider);
  final progress = nav.isActive ? nav.progress : null;
  final ready = preview is RouteReady ? preview : null;

  switch (kind) {
    case TripInfoKind.nextTurn:
      final next = progress?.next;
      if (progress == null || next == null) {
        return {'ok': false, 'error': 'no_nav'};
      }
      return {
        'ok': true,
        'maneuver': next,
        'distance_m': progress.distanceToNextM,
      };
    case TripInfoKind.speedLimit:
      if (progress == null) return {'ok': false, 'error': 'no_nav'};
      final kmh = nav.currentLimitKmh;
      if (kmh == null) return {'ok': false, 'error': 'no_speed_limit'};
      return {'ok': true, 'kmh': kmh};
    case TripInfoKind.distance:
    case TripInfoKind.timeLeft:
    case TripInfoKind.arrival:
      if (progress == null && ready == null) {
        return {'ok': false, 'error': 'no_trip'};
      }
      final meters = progress?.remainingM ?? ready!.selected.distanceM;
      final seconds = progress?.remainingS ?? ready!.selected.durationS;
      return {
        'ok': true,
        'remaining': progress != null,
        'meters': meters.round(),
        'seconds': seconds.round(),
        'arrival': ref
            .read(navClockProvider)()
            .add(Duration(seconds: seconds.round())),
      };
    case TripInfoKind.toll:
      if (ready == null) return {'ok': false, 'error': 'no_trip'};
      final vehicle = ready.query.vehicle;
      final selected = ready.selected;
      if (!selected.hasTolls) return {'ok': true, 'has_tolls': false};
      if (vehicle == RouteVehicle.motorcycle) {
        return {'ok': true, 'has_tolls': true, 'motorcycle': true};
      }
      final est = ready.tollOf(selected);
      if (est == null) return {'ok': true, 'has_tolls': true, 'pending': true};
      if (est.isUnknown) {
        return {'ok': true, 'has_tolls': true, 'unknown': true};
      }
      return {
        'ok': true,
        'has_tolls': true,
        'toll_rm': est.knownRm,
        'toll_partial': est.isPartial,
      };
    case TripInfoKind.fuelCost:
      if (progress == null && ready == null) {
        return {'ok': false, 'error': 'no_trip'};
      }
      final meters = (progress?.remainingM ?? ready!.selected.distanceM)
          .round();
      final vehicle =
          ready?.query.vehicle ??
          nav.query?.vehicle ??
          ref.read(routeVehicleProvider) ??
          RouteVehicle.car;
      final liters = ref.read(fuelSettingsProvider).litersPer100Km(vehicle);
      final price = ref.read(effectiveFuelPriceProvider);
      final cost = estimateFuelCostRm(
        distanceM: meters,
        litersPer100Km: liters,
        pricePerLiter: price,
      );
      if (cost == null) return {'ok': false, 'error': 'no_fuel_price'};
      return {
        'ok': true,
        'fuel_rm': cost,
        'meters': meters,
        'price': price,
        'liters_per_100km': liters,
      };
  }
}
