import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../data/route_planner.dart';
import '../domain/route_option.dart';
import '../domain/routing_failure.dart';

@immutable
sealed class RoutePreviewState {
  const RoutePreviewState();
}

class RouteIdle extends RoutePreviewState {
  const RouteIdle();
}

class RouteLoading extends RoutePreviewState {
  /// [query] masih null selagi asal (lokasi pengguna) sedang dicari.
  const RouteLoading({required this.destination, this.query});

  final GeoPoint destination;
  final RouteQuery? query;
}

class RouteReady extends RoutePreviewState {
  const RouteReady({
    required this.query,
    required this.options,
    this.selectedIndex = 0,
  });

  final RouteQuery query;
  final List<RouteOption> options;
  final int selectedIndex;

  RouteOption get selected => options[selectedIndex];

  RouteReady withSelected(int index) =>
      RouteReady(query: query, options: options, selectedIndex: index);
}

class RouteFailed extends RoutePreviewState {
  const RouteFailed({required this.query, required this.kind});

  final RouteQuery query;
  final RoutingFailureKind kind;
}

class RouteLocationUnavailable extends RoutePreviewState {
  const RouteLocationUnavailable({
    required this.destination,
    this.destinationLabel,
  });

  final GeoPoint destination;
  final String? destinationLabel;
}

class RoutePreviewController extends Notifier<RoutePreviewState> {
  /// Nombor permintaan terkini. Keputusan permintaan lama dibuang supaya tidak menimpa yang baharu
  /// (cth. pengguna menukar destinasi atau memadam laluan semasa menunggu).
  int _seq = 0;

  /// Pilihan "Elak tol" kekal merentas destinasi dalam satu sesi.
  bool _avoidTolls = false;

  @override
  RoutePreviewState build() => const RouteIdle();

  /// Kira laluan ke [destination].
  ///
  /// Asal sentiasa GPS semasa; laluan tidak dikira jika GPS tiada fix yang boleh digunakan.
  Future<void> planTo(GeoPoint destination, {String? destinationLabel}) async {
    final seq = ++_seq;
    state = RouteLoading(destination: destination);

    final fix = await ref
        .read(locationServiceProvider)
        .currentFix(timeout: const Duration(seconds: 6));
    if (seq != _seq) return;
    if (fix == null) {
      state = RouteLocationUnavailable(
        destination: destination,
        destinationLabel: destinationLabel,
      );
      return;
    }

    final query = RouteQuery(
      origin: fix.point,
      destination: destination,
      headingDegrees: fix.headingDegrees,
      avoidTolls: _avoidTolls,
      destinationLabel: destinationLabel,
    );
    await _fetch(query, seq);
  }

  Future<void> setAvoidTolls(bool value) async {
    _avoidTolls = value;
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query.copyWith(avoidTolls: value), ++_seq);
  }

  Future<void> retry() async {
    final current = state;
    if (current is RouteLocationUnavailable) {
      await planTo(
        current.destination,
        destinationLabel: current.destinationLabel,
      );
      return;
    }
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query, ++_seq);
  }

  void select(int index) {
    final current = state;
    if (current is RouteReady && index >= 0 && index < current.options.length) {
      state = current.withSelected(index);
    }
  }

  void clear() {
    _seq++;
    state = const RouteIdle();
  }

  RouteQuery? get _currentQuery {
    final s = state;
    return switch (s) {
      RouteReady() => s.query,
      RouteFailed() => s.query,
      RouteLoading() => s.query,
      RouteLocationUnavailable() => null,
      RouteIdle() => null,
    };
  }

  Future<void> _fetch(RouteQuery query, int seq) async {
    state = RouteLoading(destination: query.destination, query: query);
    try {
      final options = await ref.read(routePlannerProvider).plan(query);
      if (seq != _seq) return;
      state = RouteReady(query: query, options: options);
    } on RoutingFailure catch (failure) {
      if (seq != _seq) return;
      state = RouteFailed(query: query, kind: failure.kind);
    }
  }
}

final routePreviewControllerProvider =
    NotifierProvider<RoutePreviewController, RoutePreviewState>(
      RoutePreviewController.new,
    );
