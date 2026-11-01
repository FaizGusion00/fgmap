import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../route_preview/domain/route_option.dart';
import '../../speed_limits/data/speed_limit_service.dart';
import '../domain/junction.dart';
import '../domain/nav_route.dart';
import 'navigation_controller.dart';

/// Bentuk sebenar simpang untuk manuver ke-[index] pada [route] (null = tiada / gagal: gambar
/// anggaran digunakan). Satu permintaan kecil setiap simpang, dibuat sebaik manuver itu menjadi
/// manuver seterusnya, jadi gambar sudah sedia sebelum kotak lorong muncul. Disimpan sepanjang
/// laluan supaya tidak diminta semula.
final junctionProvider =
    FutureProvider.family<Junction?, (NavRoute, int, String)>((ref, key) async {
      final (route, index, costing) = key;
      if (index < 0 || index >= route.maneuvers.length) return null;
      final m = route.maneuvers[index];
      if (!wantsJunction(m)) return null;
      final slice = junctionSlice(route, m);
      if (slice.length < 2) return null;
      final body = await ref
          .read(speedLimitServiceProvider)
          .traceRaw(
            jsonEncode(buildJunctionRequest(slice, costing)),
            offlineFirst: route.option.source == RouteSource.offline,
          );
      if (body == null) return null;
      try {
        return parseJunction(
          body,
          at: route.pointAt(m.startM),
          roundabout: m.kind == ManeuverKind.roundabout,
          roundaboutExit: m.roundaboutExit,
        );
      } on Object {
        return null;
      }
    });

/// Simpang untuk [m] pada laluan navigasi semasa, atau null sementara dimuat / tiada data.
final junctionForProvider = Provider.family<Junction?, NavManeuver>((ref, m) {
  final key = junctionKeyFor(ref, m);
  if (key == null) return null;
  return ref.watch(junctionProvider(key)).value;
});

/// Kunci permintaan simpang untuk [m] pada laluan navigasi semasa; null jika tiada laluan.
(NavRoute, int, String)? junctionKeyFor(Ref ref, NavManeuver m) {
  final (route, vehicle) = ref.watch(
    navigationControllerProvider.select((s) => (s.route, s.query?.vehicle)),
  );
  if (route == null || !wantsJunction(m)) return null;
  return (route, m.index, (vehicle ?? RouteVehicle.car).costing);
}
