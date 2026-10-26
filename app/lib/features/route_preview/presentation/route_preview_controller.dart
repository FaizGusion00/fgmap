import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/utils/geo.dart';
import '../data/route_planner.dart';
import '../data/toll_finder.dart';
import '../domain/route_option.dart';
import '../domain/toll.dart';
import '../domain/route_options_merge.dart' show isSameRoute;
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
  const RouteLoading({
    required this.destination,
    this.query,
    this.destinationLabel,
  });

  final GeoPoint destination;
  final RouteQuery? query;
  final String? destinationLabel;
}

class RouteReady extends RoutePreviewState {
  const RouteReady({
    required this.query,
    required this.options,
    this.selectedIndex = 0,
    this.loadingMore = false,
    this.expanded = false,
    this.tolls = const {},
  });

  final RouteQuery query;
  final List<RouteOption> options;
  final int selectedIndex;

  /// Laluan lain masih dicari; [options] boleh bertambah.
  final bool loadingMore;

  /// Pengguna menekan "Lagi": semua pilihan (sehingga 10) dipaparkan, bukan [collapsedCount] sahaja.
  final bool expanded;

  /// Anggaran tol mengikut [routeKey]; diisi di latar selepas laluan dipaparkan. Kosong = belum/
  /// tidak diketahui (kegagalan carian plaza tidak menghalang laluan).
  final Map<String, TollEstimate> tolls;

  TollEstimate? tollOf(RouteOption option) => tolls[routeKey(option)];

  /// Bilangan kad yang dipaparkan sebelum pengguna menekan "Lagi".
  static const collapsedCount = 6;

  RouteOption get selected => options[selectedIndex];

  /// Pilihan yang dipaparkan (kad dan garisan peta).
  List<RouteOption> get visibleOptions =>
      expanded || options.length <= collapsedCount
      ? options
      : options.sublist(0, collapsedCount);

  /// Bilangan pilihan tersembunyi di sebalik "Lagi".
  int get hiddenCount => options.length - visibleOptions.length;

  /// Permintaan yang menghasilkan laluan terpilih. Navigasi menggunakannya untuk mengira semula
  /// bila menyimpang, jadi pilihan pengguna (cth. laluan tanpa tol) dikekalkan sepanjang perjalanan.
  RouteQuery get selectedQuery => query.copyWith(
    avoidTolls: selected.label == RouteLabel.noTolls,
    avoidHighways: selected.label == RouteLabel.noHighways,
    shortest: selected.label == RouteLabel.shortest,
  );

  RouteReady copyWith({
    List<RouteOption>? options,
    int? selectedIndex,
    bool? loadingMore,
    bool? expanded,
    Map<String, TollEstimate>? tolls,
  }) => RouteReady(
    query: query,
    options: options ?? this.options,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    loadingMore: loadingMore ?? this.loadingMore,
    expanded: expanded ?? this.expanded,
    tolls: tolls ?? this.tolls,
  );

  RouteReady withSelected(int index) => copyWith(selectedIndex: index);
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
  double? _radiusM;

  @override
  RoutePreviewState build() => const RouteIdle();

  /// Kira laluan ke [destination].
  ///
  /// Asal sentiasa GPS semasa; laluan tidak dikira jika GPS tiada fix yang boleh digunakan.
  Future<void> planTo(
    GeoPoint destination, {
    String? destinationLabel,
    double? radiusM,
  }) async {
    final seq = ++_seq;
    _radiusM = radiusM;
    state = RouteLoading(
      destination: destination,
      destinationLabel: destinationLabel,
    );

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
      vehicle: ref.read(routeVehicleProvider),
      destinationLabel: destinationLabel,
      destinationRadiusM: radiusM,
    );
    await _fetch(query, seq);
  }

  /// Menukar kenderaan (kereta/motosikal), menyimpannya, dan mengira semula laluan aktif.
  Future<void> setVehicle(RouteVehicle vehicle) async {
    await ref.read(routeVehicleProvider.notifier).set(vehicle);
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query.copyWith(vehicle: vehicle), ++_seq);
  }

  Future<void> retry() async {
    final current = state;
    if (current is RouteLocationUnavailable) {
      await planTo(
        current.destination,
        destinationLabel: current.destinationLabel,
        radiusM: _radiusM,
      );
      return;
    }
    final query = _currentQuery;
    if (query == null) return;
    await _fetch(query, ++_seq);
  }

  /// Laluan yang dipilih sendiri oleh pengguna: kekal terpilih walaupun senarai disusun semula
  /// apabila laluan lain tiba. Null = ikut laluan utama (indeks 0).
  RouteOption? _pinned;

  void select(int index) {
    final current = state;
    if (current is RouteReady && index >= 0 && index < current.options.length) {
      _pinned = index == 0 ? null : current.options[index];
      state = current.withSelected(index);
    }
  }

  /// Papar semua pilihan (sehingga 10).
  void showMore() {
    final current = state;
    if (current is RouteReady && !current.expanded) {
      state = current.copyWith(expanded: true);
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
    _pinned = null;
    state = RouteLoading(
      destination: query.destination,
      query: query,
      destinationLabel: query.destinationLabel,
    );
    var received = false;
    try {
      await for (final batch in watchRoutes(
        ref.read(routeOptionsPlannerProvider),
        query,
      )) {
        if (seq != _seq) return;
        received = true;
        _applyBatch(query, batch);
      }
    } on RoutingFailure catch (failure) {
      if (seq != _seq) return;
      if (received) return _finishLoading();
      state = RouteFailed(query: query, kind: failure.kind);
    } on Object catch (e, st) {
      // Kegagalan tidak dijangka mesti tidak meninggalkan lembaran "mengira" selama-lamanya.
      debugPrint('Pengiraan laluan gagal: $e\n$st');
      if (seq != _seq) return;
      if (received) return _finishLoading();
      state = RouteFailed(query: query, kind: RoutingFailureKind.generic);
    }
    if (seq == _seq && state is RouteReady) {
      _finishLoading();
      unawaited(_loadTolls(seq));
    }
  }

  /// Mengesan plaza tol dan menganggar harga untuk laluan bertol yang dipaparkan (terpilih dahulu).
  /// Berjalan di latar dan senyap: kegagalan hanya bermakna anggaran tidak dipaparkan.
  Future<void> _loadTolls(int seq) async {
    if (!ref.read(tollLookupEnabledProvider)) return;
    final first = state;
    if (first is! RouteReady) return;
    final order = [
      first.selected,
      for (final o in first.visibleOptions)
        if (!identical(o, first.selected)) o,
    ].where((o) => o.hasTolls).toList();
    if (order.isEmpty) return;

    final TollRates rates;
    try {
      rates = await ref.read(tollRatesProvider.future);
    } on Object {
      return;
    }
    if (!ref.mounted || seq != _seq) return;
    final finder = ref.read(tollPlazaFinderProvider);
    for (final option in order) {
      try {
        final plazas = await finder.find(option);
        if (!ref.mounted || seq != _seq) return;
        final current = state;
        if (current is! RouteReady) return;
        state = current.copyWith(
          tolls: {
            ...current.tolls,
            routeKey(option): rates.estimate(plazas, current.query.vehicle),
          },
        );
      } on TollLookupFailure {
        if (!ref.mounted || seq != _seq) return;
      }
    }
  }

  /// Tamatkan penunjuk "mencari laluan lain" (aliran tamat atau gagal selepas pilihan sedia ada).
  void _finishLoading() {
    final current = state;
    if (current is RouteReady && current.loadingMore) {
      state = current.copyWith(loadingMore: false);
    }
  }

  void _applyBatch(RouteQuery query, RouteBatch batch) {
    final options = batch.options;
    if (options.isEmpty) {
      state = RouteFailed(query: query, kind: RoutingFailureKind.noRoute);
      return;
    }
    final previous = state;
    final expanded = previous is RouteReady && previous.expanded;
    var selected = 0;
    final pinned = _pinned;
    if (pinned != null) {
      // Laluan pilihan pengguna kekal terpilih walaupun kedudukannya berubah.
      final index = options.indexWhere(
        (o) => identical(o.points, pinned.points),
      );
      final fallback = index >= 0
          ? index
          : options.indexWhere((o) => isSameRoute(o, pinned, threshold: 0.9));
      if (fallback >= 0) {
        selected = fallback;
        _pinned = options[fallback];
      } else {
        _pinned = null;
      }
    }
    state = RouteReady(
      query: query,
      options: options,
      selectedIndex: selected,
      loadingMore: !batch.done,
      // Laluan terpilih di luar kad yang dipaparkan: buka semua supaya ia kelihatan.
      expanded: expanded || selected >= RouteReady.collapsedCount,
    );
  }
}

final routePreviewControllerProvider =
    NotifierProvider<RoutePreviewController, RoutePreviewState>(
      RoutePreviewController.new,
    );

/// Pencarian plaza tol dan anggaran harga di latar. Dimatikan dalam ujian yang tidak menguji tol.
final tollLookupEnabledProvider = Provider<bool>((ref) => true);
